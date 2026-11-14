import Foundation
import Observation

@Observable
@MainActor
public class AudioPlayerSleepTimer {
    public var remaining: TimeInterval?
    public private(set) var initialDuration: TimeInterval?
    private var onCompleteCallback: (@MainActor () -> Void)?
    private var timer: Timer?

    public init() {}

    public var isActive: Bool {
        remaining != nil
    }

    /// - Parameter seconds: Duration in **seconds**, not minutes. "End of
    ///   Chapter" arms the timer with the exact remaining chapter time, which is
    ///   almost never a whole number of minutes; taking `Int` minutes here
    ///   truncated 8m45s down to 8 (playback stopped 45s early) and mapped
    ///   anything under a minute to 0, which the first tick treats as already
    ///   elapsed and so paused playback after ~1s.
    public func setSleepTimer(seconds: TimeInterval, onComplete: @escaping @MainActor () -> Void) {
        stopSleepTimer(clearInitial: false)
        let duration = max(1, seconds)
        remaining = duration
        initialDuration = duration
        onCompleteCallback = onComplete

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if let r = self.remaining {
                    if r <= 1 {
                        self.stopTimerInternal()
                        onComplete()
                    } else {
                        self.remaining = r - 1
                    }
                }
            }
        }
    }

    /// Resets the sleep timer countdown back to its configured initial duration.
    /// Returns true if the timer was successfully reset.
    @discardableResult
    public func resetSleepTimer() -> Bool {
        guard let initial = initialDuration, let onComplete = onCompleteCallback else { return false }
        setSleepTimer(seconds: initial, onComplete: onComplete)
        return true
    }

    private func stopTimerInternal() {
        timer?.invalidate()
        timer = nil
        remaining = nil
    }

    public func stopSleepTimer(clearInitial: Bool = true) {
        stopTimerInternal()
        if clearInitial {
            initialDuration = nil
            onCompleteCallback = nil
        }
    }

    public func format() -> String {
        guard let r = remaining else { return "" }
        let minutes = Int(r) / 60
        let seconds = Int(r) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
