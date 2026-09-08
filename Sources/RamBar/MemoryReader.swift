import Darwin
import Foundation

struct MemorySample: Equatable {
    let physicalBytes: UInt64
    let usedBytes: UInt64

    var percentage: Int? {
        MemoryFormatter.percentage(usedBytes: usedBytes, physicalBytes: physicalBytes)
    }
}

struct MemoryCounters: Equatable {
    let free: UInt64
    let speculative: UInt64
    let external: UInt64
    let purgeable: UInt64
    let internalPages: UInt64
    let wired: UInt64
    let compressor: UInt64
    let uncompressedCompressor: UInt64
}

struct MemoryDebugSnapshot {
    let physicalBytes: UInt64
    let pageSize: UInt64
    let counters: MemoryCounters
    let oldUsedBytes: UInt64
    let usedBytes: UInt64

    var oldPercentage: Int? {
        MemoryFormatter.percentage(usedBytes: oldUsedBytes, physicalBytes: physicalBytes)
    }

    var percentage: Int? {
        MemoryFormatter.percentage(usedBytes: usedBytes, physicalBytes: physicalBytes)
    }
}

enum MemoryReader {
    static func read() -> MemorySample? {
        guard let snapshot = snapshot() else { return nil }
        return MemorySample(physicalBytes: snapshot.physicalBytes, usedBytes: snapshot.usedBytes)
    }

    static func debugSnapshot() -> MemoryDebugSnapshot? { snapshot() }

    // Memory Used is physical RAM minus pages immediately reclaimable by macOS:
    // true free (free excludes speculative, which is already file-backed), external
    // file-backed cache, and purgeable pages. Compressor pages are implicit in the
    // physical-minus-reclaimable result, so they must not be added a second time.
    static func activityMonitorStyleUsedBytes(
        physicalBytes: UInt64,
        pageSize: UInt64,
        counters: MemoryCounters
    ) -> UInt64? {
        guard physicalBytes > 0, pageSize > 0 else { return nil }
        let trueFree = counters.free > counters.speculative
            ? counters.free - counters.speculative
            : 0
        let reclaimablePages = addingPages([trueFree, counters.external, counters.purgeable])
        guard let reclaimablePages else { return nil }
        let reclaimableBytes = reclaimablePages.multipliedReportingOverflow(by: pageSize)
        guard !reclaimableBytes.overflow else { return nil }
        return physicalBytes > reclaimableBytes.partialValue
            ? physicalBytes - reclaimableBytes.partialValue
            : 0
    }

    // Retained solely for --memory-debug and regression tests; not used by RamBar.
    static func previousUsedBytes(pageSize: UInt64, counters: MemoryCounters) -> UInt64? {
        let nonPurgeableInternal = counters.internalPages > counters.purgeable
            ? counters.internalPages - counters.purgeable
            : 0
        guard let pages = addingPages([counters.wired, nonPurgeableInternal, counters.compressor]) else {
            return nil
        }
        let bytes = pages.multipliedReportingOverflow(by: pageSize)
        return bytes.overflow ? nil : bytes.partialValue
    }

    private static func snapshot() -> MemoryDebugSnapshot? {
        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        var machPageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &machPageSize) == KERN_SUCCESS, machPageSize > 0 else { return nil }
        let physicalBytes = ProcessInfo.processInfo.physicalMemory
        let pageSize = UInt64(machPageSize)
        guard physicalBytes > 0 else { return nil }

        let counters = MemoryCounters(
            free: UInt64(statistics.free_count),
            speculative: UInt64(statistics.speculative_count),
            external: UInt64(statistics.external_page_count),
            purgeable: UInt64(statistics.purgeable_count),
            internalPages: UInt64(statistics.internal_page_count),
            wired: UInt64(statistics.wire_count),
            compressor: UInt64(statistics.compressor_page_count),
            uncompressedCompressor: statistics.total_uncompressed_pages_in_compressor
        )
        guard let oldUsedBytes = previousUsedBytes(pageSize: pageSize, counters: counters),
              let usedBytes = activityMonitorStyleUsedBytes(
                  physicalBytes: physicalBytes, pageSize: pageSize, counters: counters
              ) else { return nil }
        return MemoryDebugSnapshot(
            physicalBytes: physicalBytes,
            pageSize: pageSize,
            counters: counters,
            oldUsedBytes: min(physicalBytes, oldUsedBytes),
            usedBytes: usedBytes
        )
    }

    private static func addingPages(_ pages: [UInt64]) -> UInt64? {
        var result: UInt64 = 0
        for pageCount in pages {
            let addition = result.addingReportingOverflow(pageCount)
            guard !addition.overflow else { return nil }
            result = addition.partialValue
        }
        return result
    }
}
