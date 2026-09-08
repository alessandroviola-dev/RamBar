import Darwin
import Foundation

struct MemorySample: Equatable {
    let physicalBytes: UInt64
    let usedBytes: UInt64

    var percentage: Int? {
        MemoryFormatter.percentage(usedBytes: usedBytes, physicalBytes: physicalBytes)
    }
}

enum MemoryReader {
    static func read() -> MemorySample? {
        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        var pageSize: vm_size_t = 0
        guard host_page_size(mach_host_self(), &pageSize) == KERN_SUCCESS, pageSize > 0 else { return nil }
        let physicalBytes = ProcessInfo.processInfo.physicalMemory
        guard physicalBytes > 0 else { return nil }

        let pageBytes = UInt64(pageSize)
        // Approximate meaningful physical use as wired + non-purgeable internal +
        // compressor pages. File-backed external pages are excluded as reclaimable cache;
        // compressor_page_count is physical compressor storage and is added exactly once.
        let nonPurgeableInternalPages = statistics.internal_page_count > statistics.purgeable_count
            ? statistics.internal_page_count - statistics.purgeable_count
            : 0
        let pageCounts = [
            UInt64(statistics.wire_count),
            UInt64(nonPurgeableInternalPages),
            UInt64(statistics.compressor_page_count)
        ]
        var usedPages: UInt64 = 0
        for count in pageCounts {
            let addition = usedPages.addingReportingOverflow(count)
            guard !addition.overflow else { return nil }
            usedPages = addition.partialValue
        }
        let byteCount = usedPages.multipliedReportingOverflow(by: pageBytes)
        guard !byteCount.overflow else { return nil }
        return MemorySample(physicalBytes: physicalBytes, usedBytes: min(physicalBytes, byteCount.partialValue))
    }
}
