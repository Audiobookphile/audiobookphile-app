import Foundation

/// ── WHY THIS TYPE EXISTS ──
///
/// The reported bug was "press play, it plays for a second, then pauses and
/// never comes back". The mechanism was a conflation of two different facts:
///
///   * `isPlaying`, which mirrors AVPlayer's `timeControlStatus` — an
///     *observation* of the transport, and
///   * "the user wants this to be playing" — an *intent*.
///
/// AVPlayer transiently reports `.paused` while it swaps items (queue top-up,
/// track advance, item rebuild). The old code cleared `isPlaying` on that
/// transient, and then gated the resume path on `isPlaying`
/// (`handleItemReady` -> `if self.isPlaying { self.play() }`). The flag the
/// transient cleared was the same flag authorising the resume, so the player
/// latched into "not playing and not allowed to start".
///
/// The fix only holds if the rule is stated once, in one place, and is
/// testable. Inline in a KVO callback it is neither: the callback needs a live
/// AVPlayer, so nothing can assert the rule and a future edit can silently
/// reintroduce the bug. So the rule lives here as a pure function over four
/// booleans, and the callback merely applies the answer.
///
/// This is deliberately free of AVFoundation so it transpiles cleanly to Kotlin
/// for the Android/Skip build, and it is `Equatable` so tests can assert on the
/// whole state rather than on two loose booleans that could drift apart.
enum PlaybackTransportState: Equatable {

    /// The transport is running. `isBuffering` reflects AVPlayer's own
    /// `isPlaybackLikelyToKeepUp`/`isPlaybackBufferEmpty` signals.
    case playing(isBuffering: Bool)

    /// The transport says "not playing" but the user still wants playback.
    ///
    /// This is the regression case. It must never be reported as `paused`:
    /// doing so both shows the user a paused player and, historically, revoked
    /// the intent that authorises the resume. It is surfaced as *buffering* so
    /// the UI shows a spinner while the item settles.
    case recovering

    /// The user paused on purpose.
    case paused

    /// Nothing is loaded or the book finished; there is nothing to resume.
    case stopped

    /// Resolves the single rule that maps transport observations plus user
    /// intent onto the state the UI shows.
    ///
    /// - Parameters:
    ///   - transportPlaying: AVPlayer reported a running transport.
    ///   - transportBuffering: AVPlayer reported it is likely to stall.
    ///   - isPlayRequested: the user asked for playback and has not withdrawn it.
    ///   - isExplicitlyPaused: the user paused deliberately (tap/interruption)
    ///     or the book reached its end.
    /// - Returns: The state to display.
    static func resolve(
        transportPlaying: Bool,
        transportBuffering: Bool,
        isPlayRequested: Bool,
        isExplicitlyPaused: Bool
    ) -> PlaybackTransportState {

        if transportPlaying {
            return .playing(isBuffering: transportBuffering)
        }

        // The load-bearing branch. A `.paused` observation while the user still
        // wants playback is a transient of item replacement, not a decision.
        if isPlayRequested && !isExplicitlyPaused {
            return .recovering
        }

        return isExplicitlyPaused ? .paused : .stopped
    }

    /// The `isPlaying` value to publish to the UI and the widget.
    var isPlaying: Bool {
        switch self {
        case .playing, .recovering: return true
        case .paused, .stopped: return false
        }
    }

    /// The `isBuffering` value to publish to the UI.
    ///
    /// `.recovering` always reports buffering: from the user's point of view the
    /// player is between tracks, not paused.
    var isBuffering: Bool {
        switch self {
        case .playing(let isBuffering): return isBuffering
        case .recovering: return true
        case .paused, .stopped: return false
        }
    }
}
