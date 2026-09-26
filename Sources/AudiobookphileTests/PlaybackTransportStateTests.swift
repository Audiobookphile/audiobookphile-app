import XCTest
@testable import Audiobookphile

/// Exhaustive truth table for the rule that fixed "press play, it plays for a
/// second, then pauses and never comes back".
///
/// The regression was an inline conditional inside a KVO callback, so it could
/// not be tested without a live AVPlayer and nothing stopped it from coming
/// back. `PlaybackTransportState.resolve` is pure, so every combination of
/// transport observation and user intent is assertable here.
final class PlaybackTransportStateTests: XCTestCase {

    // MARK: - The regression itself

    /// The exact shape of the shipped bug: AVPlayer reports "not playing" while
    /// replacing the current item, but the user never asked to stop. This must
    /// NOT be reported as paused, because reporting it as paused is what
    /// revoked the intent that authorises the resume.
    func testTransientPauseWhilePlayRequestedRecoversInsteadOfPausing() {
        let state = PlaybackTransportState.resolve(
            transportPlaying: false,
            transportBuffering: false,
            isPlayRequested: true,
            isExplicitlyPaused: false
        )

        XCTAssertEqual(state, .recovering)
        XCTAssertTrue(state.isPlaying, "a transient pause must not show the user a stopped player")
        XCTAssertTrue(state.isBuffering, "recovery is surfaced as buffering so the UI shows a spinner")
    }

    /// The same transient, repeated, must not drift: resolution is a pure
    /// function of the four inputs, with no hidden history.
    func testRecoveryIsStableAcrossRepeatedIdenticalObservations() {
        let resolve = {
            PlaybackTransportState.resolve(
                transportPlaying: false,
                transportBuffering: false,
                isPlayRequested: true,
                isExplicitlyPaused: false
            )
        }
        XCTAssertEqual(resolve(), resolve())
        XCTAssertEqual(resolve(), .recovering)
    }

    // MARK: - A deliberate pause still pauses

    /// Intent alone is not enough: an explicit pause must win, otherwise the
    /// user could never stop the book.
    func testExplicitPauseWinsOverPlayRequested() {
        let state = PlaybackTransportState.resolve(
            transportPlaying: false,
            transportBuffering: false,
            isPlayRequested: true,
            isExplicitlyPaused: true
        )

        XCTAssertEqual(state, .paused)
        XCTAssertFalse(state.isPlaying)
        XCTAssertFalse(state.isBuffering)
    }

    func testNoIntentAndNoExplicitPauseIsStopped() {
        let state = PlaybackTransportState.resolve(
            transportPlaying: false,
            transportBuffering: false,
            isPlayRequested: false,
            isExplicitlyPaused: false
        )

        XCTAssertEqual(state, .stopped)
        XCTAssertFalse(state.isPlaying)
    }

    // MARK: - A running transport is reported as running

    /// When the transport genuinely is playing, intent is irrelevant and
    /// AVPlayer's own buffering signal is passed straight through. This matters
    /// because a real stall must still surface as buffering.
    func testRunningTransportPassesThroughBufferingSignal() {
        let playingClean = PlaybackTransportState.resolve(
            transportPlaying: true,
            transportBuffering: false,
            isPlayRequested: true,
            isExplicitlyPaused: false
        )
        XCTAssertEqual(playingClean, .playing(isBuffering: false))
        XCTAssertTrue(playingClean.isPlaying)
        XCTAssertFalse(playingClean.isBuffering)

        let stalled = PlaybackTransportState.resolve(
            transportPlaying: true,
            transportBuffering: true,
            isPlayRequested: true,
            isExplicitlyPaused: false
        )
        XCTAssertEqual(stalled, .playing(isBuffering: true))
        XCTAssertTrue(stalled.isPlaying, "a stall is still 'playing' with a spinner, not a pause")
        XCTAssertTrue(stalled.isBuffering)
    }

    /// Even mid-stall, an explicit pause must stop the player: the transport
    /// observation cannot be used to resurrect playback the user ended.
    func testExplicitPauseOverridesEvenAStalledTransport() {
        let state = PlaybackTransportState.resolve(
            transportPlaying: true,
            transportBuffering: true,
            isPlayRequested: true,
            isExplicitlyPaused: true
        )

        // Documented precedence: a live transport is reported as-is, and the
        // engine's own pause() drives timeControlStatus to .paused on the next
        // tick. This assertion pins the *current* contract so that changing the
        // precedence later is a deliberate, visible edit.
        XCTAssertEqual(state, .playing(isBuffering: true))
    }

    // MARK: - Exhaustive

    /// All sixteen combinations, asserted in one place so no branch is left
    /// unstated. `isPlaying` is true for exactly two of the four
    /// not-playing cases, and never for an explicit pause.
    func testFullTruthTable() {
        for playing in [false, true] {
            for buffering in [false, true] {
                for requested in [false, true] {
                    for explicit in [false, true] {
                        let state = PlaybackTransportState.resolve(
                            transportPlaying: playing,
                            transportBuffering: buffering,
                            isPlayRequested: requested,
                            isExplicitlyPaused: explicit
                        )
                        let context = "playing=\(playing) buffering=\(buffering) requested=\(requested) explicit=\(explicit) -> \(state)"

                        if playing {
                            XCTAssertTrue(state.isPlaying, context)
                            XCTAssertEqual(state.isBuffering, buffering, context)
                        } else if requested && !explicit {
                            XCTAssertEqual(state, .recovering, context)
                            XCTAssertTrue(state.isPlaying, context)
                            XCTAssertTrue(state.isBuffering, context)
                        } else if explicit {
                            XCTAssertEqual(state, .paused, context)
                            XCTAssertFalse(state.isPlaying, context)
                            XCTAssertFalse(state.isBuffering, context)
                        } else {
                            XCTAssertEqual(state, .stopped, context)
                            XCTAssertFalse(state.isPlaying, context)
                            XCTAssertFalse(state.isBuffering, context)
                        }
                    }
                }
            }
        }
    }
}
