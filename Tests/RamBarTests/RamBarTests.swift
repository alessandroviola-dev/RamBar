import XCTest
@testable import RamBar

final class RamBarTests: XCTestCase {
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

    @MainActor
    func testMonitorLifecycle() {
        let monitor = MemoryMonitor()
        monitor.start()
        monitor.stop()
        monitor.start()
        monitor.stop()
    }
}
