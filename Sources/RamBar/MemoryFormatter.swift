import Foundation

enum MemoryFormatter {
    static func percentage(usedBytes: UInt64, physicalBytes: UInt64) -> Int? {
        guard physicalBytes > 0 else { return nil }
        let raw = Double(usedBytes) / Double(physicalBytes) * 100
        guard raw.isFinite else { return nil }
        return min(100, max(0, Int(raw.rounded())))
    }

    static func title(_ percentage: Int?) -> String {
        guard let percentage else { return "RAM ?%" }
        return "RAM \(min(100, max(0, percentage)))%"
    }
}
