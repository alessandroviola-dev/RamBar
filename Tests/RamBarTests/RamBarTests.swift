import XCTest
@testable import RamBar

final class RamBarTests: XCTestCase {
    private func counters(
        free: UInt64 = 0,
        speculative: UInt64 = 0,
        external: UInt64 = 0,
        purgeable: UInt64 = 0,
        internalPages: UInt64 = 0,
        wired: UInt64 = 0,
        compressor: UInt64 = 0
    ) -> MemoryCounters {
        MemoryCounters(
            free: free,
            speculative: speculative,
            external: external,
            purgeable: purgeable,
            internalPages: internalPages,
            wired: wired,
            compressor: compressor,
            uncompressedCompressor: 0
        )
    }

    func testPercentageBoundariesAndRounding() {
        XCTAssertEqual(MemoryFormatter.percentage(usedBytes: 0, physicalBytes: 100), 0)
        XCTAssertEqual(MemoryFormatter.percentage(usedBytes: 50, physicalBytes: 100), 50)
        XCTAssertEqual(MemoryFormatter.percentage(usedBytes: 100, physicalBytes: 100), 100)
        XCTAssertEqual(MemoryFormatter.percentage(usedBytes: 614, physicalBytes: 1_000), 61)
        XCTAssertEqual(MemoryFormatter.percentage(usedBytes: 615, physicalBytes: 1_000), 62)
        XCTAssertEqual(MemoryFormatter.percentage(usedBytes: 101, physicalBytes: 100), 100)
        XCTAssertNil(MemoryFormatter.percentage(usedBytes: 1, physicalBytes: 0))
    }

    func testFormatting() {
        XCTAssertEqual(MemoryFormatter.title(0), "RAM 0%")
        XCTAssertEqual(MemoryFormatter.title(1), "RAM 1%")
        XCTAssertEqual(MemoryFormatter.title(61), "RAM 61%")
        XCTAssertEqual(MemoryFormatter.title(100), "RAM 100%")
        XCTAssertEqual(MemoryFormatter.title(nil), "RAM ?%")
        XCTAssertEqual(MemoryFormatter.title(101), "RAM 100%")
        XCTAssertEqual(MemoryFormatter.title(-1), "RAM 0%")
    }

    func testLiveMemorySample() throws {
        let sample = try XCTUnwrap(MemoryReader.read())
        XCTAssertGreaterThan(sample.physicalBytes, 0)
        XCTAssertLessThanOrEqual(sample.usedBytes, sample.physicalBytes)
        XCTAssertNotNil(sample.percentage)
        XCTAssertTrue((0...100).contains(sample.percentage!))
    }

    func testRepeatedMemoryReadsHaveNoState() {
        for _ in 0..<10 {
            let sample = MemoryReader.read()
            XCTAssertNotNil(sample)
            if let sample {
                XCTAssertLessThanOrEqual(sample.usedBytes, sample.physicalBytes)
                XCTAssertTrue((0...100).contains(sample.percentage ?? -1))
            }
        }
    }

    func testActivityMonitorStyleAccountingTreatsReclaimablePagesAsAvailable() {
        let values = counters(free: 100, speculative: 20, external: 200, purgeable: 50)
        XCTAssertEqual(
            MemoryReader.activityMonitorStyleUsedBytes(physicalBytes: 1_000, pageSize: 1, counters: values),
            670
        )
    }

    func testSpeculativePagesAreNotSubtractedTwiceAndResultIsClamped() {
        let speculativeOnly = counters(free: 10, speculative: 20)
        XCTAssertEqual(
            MemoryReader.activityMonitorStyleUsedBytes(physicalBytes: 100, pageSize: 1, counters: speculativeOnly),
            100
        )
        let excessiveReclaimable = counters(free: 200, external: 200, purgeable: 200)
        XCTAssertEqual(
            MemoryReader.activityMonitorStyleUsedBytes(physicalBytes: 100, pageSize: 1, counters: excessiveReclaimable),
            0
        )
        XCTAssertNil(
            MemoryReader.activityMonitorStyleUsedBytes(
                physicalBytes: UInt64.max, pageSize: UInt64.max, counters: counters(free: 2)
            )
        )
    }

    func testNewAccountingAvoidsPreviousInternalOnlyUnderreport() {
        let values = counters(
            free: 10, speculative: 2, external: 200, purgeable: 20,
            internalPages: 550, wired: 100, compressor: 20
        )
        XCTAssertEqual(MemoryReader.previousUsedBytes(pageSize: 1, counters: values), 650)
        XCTAssertEqual(
            MemoryReader.activityMonitorStyleUsedBytes(physicalBytes: 1_000, pageSize: 1, counters: values),
            772
        )
    }

    func testWiredInternalAndCompressorCountersAreImplicitInPhysicalMinusReclaimableAccounting() {
        let base = counters(
            free: 20, speculative: 5, external: 100, purgeable: 50,
            internalPages: 1, wired: 1, compressor: 1
        )
        let changedResidentCounters = counters(
            free: 20, speculative: 5, external: 100, purgeable: 50,
            internalPages: 9_999, wired: 9_999, compressor: 9_999
        )
        XCTAssertEqual(
            MemoryReader.activityMonitorStyleUsedBytes(physicalBytes: 1_000, pageSize: 1, counters: base),
            MemoryReader.activityMonitorStyleUsedBytes(physicalBytes: 1_000, pageSize: 1, counters: changedResidentCounters)
        )
    }

    @MainActor
    func testMonitorLifecycle() {
        let monitor = MemoryMonitor()
        monitor.start()
        monitor.stop()
        monitor.start()
        monitor.stop()
    }
}
