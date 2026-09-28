import Foundation
import Observation

@Observable
@MainActor
public class AudioPlayerSleepTimer {
    public var remaining: TimeInterval?
    private var timer: Timer?

    public init() {}

    /// - Parameter seconds: Duration in **seconds**, not minutes. "End of
    ///   Chapter" arms the timer with the exact remaining chapter time, which is
    ///   almost never a whole number of minutes; taking `Int` minutes here
    ///   truncated 8m45s down to 8 (playback stopped 45s early) and mapped
    ///   anything under a minute to 0, which the first tick treats as already
    ///   elapsed and so paused playback after ~1s.
    public func setSleepTimer(seconds: TimeInterval, onComplete: @escaping @MainActor () -> Void) {
        stopSleepTimer()
        remaining = max(1, seconds)

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if let r = self.remaining {
                    if r <= 1 {
                        self.stopSleepTimer()
                        onComplete()
                    } else {
                        self.remaining = r - 1
                    }
                }
            }
        }
    }

    public func stopSleepTimer() {
        timer?.invalidate()
        timer = nil
        remaining = nil
    }

    public func format() -> String {
        guard let r = remaining else { return "" }
        let minutes = Int(r) / 60
        let seconds = Int(r) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
