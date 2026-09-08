import AppKit

@MainActor
final class MemoryMonitor {
    var onChange: ((String) -> Void)?

    private var timer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var hasRendered = false
    private var lastPercentage: Int?

    func start() {
        guard timer == nil else { return }
        refresh()
        let timer = Timer(timeInterval: 2.0, target: self, selector: #selector(refreshFromTimer), userInfo: nil, repeats: true)
        timer.tolerance = 0.25
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let wakeObserver { NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver) }
        wakeObserver = nil
    }

    func refresh() {
        let percentage = MemoryReader.read()?.percentage
        guard !hasRendered || lastPercentage != percentage else { return }
        hasRendered = true
        lastPercentage = percentage
        onChange?(MemoryFormatter.title(percentage))
    }

    @objc private func refreshFromTimer() { refresh() }
}
