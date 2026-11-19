//
//  AudioPlayerServiceProtocol.swift
//  Audiobookphile
//
//  Interface for the playback engine orchestration, enabling dependency
//  injection and test doubles in SwiftUI previews and unit tests.
//  Compatible with Swift 6.3 and Skip.
//
//  References the canonical models in Core/Models (PlaybackSession,
//  AudioTrack, Chapter, Bookmark) — no type redefinitions here.
//  Plain protocol (not ObservableObject): `@Observable` classes satisfy it
//  structurally.
//

import Foundation

@MainActor
public protocol AudioPlayerServiceProtocol: AnyObject {
    // MARK: - Session State

    /// The current playback session, or nil if no session is active.
    var session: PlaybackSession? { get set }

    /// Whether audio is currently playing.
    var isPlaying: Bool { get set }

    /// Whether audio is currently buffering.
    var isBuffering: Bool { get set }

    /// Current playback time in seconds.
    var currentTime: TimeInterval { get set }

    /// Current playback rate (1.0 = normal speed).
    var playbackRate: Float { get set }

    /// Total duration of the current session in seconds.
    var duration: TimeInterval { get set }

    /// The last surfaced playback failure, if any.
    var playbackError: Error? { get set }

    /// The user's bookmarks for the current session.
    var bookmarks: [Bookmark] { get set }

    /// Up Next queue of audiobooks/podcasts to play sequentially.
    var playbackQueue: [PlaybackSession] { get set }

    func addToPlaybackQueue(session: PlaybackSession)
    func playNextInPlaybackQueue(session: PlaybackSession)
    func removeFromPlaybackQueue(at index: Int)
    func movePlaybackQueueItem(fromIndex: Int, toIndex: Int)
    func clearPlaybackQueue()
    var totalQueueDuration: TimeInterval { get }

    // MARK: - Seek Epoch (Architectural Invariant)

    /// The active seek epoch — increments on each seek start.
    var activeSeekEpoch: UInt64 { get }

    /// The acknowledged seek epoch — updated when a seek completes.
    var acknowledgedSeekEpoch: UInt64 { get }

    /// Whether a seek transaction is in flight.
    var isSeeking: Bool { get }

    /// Remaining sleep-timer time, if active.
    var sleepTimerRemaining: TimeInterval? { get }

    // MARK: - Playback Control

    /// Closes the current playback session, recording progress and cleaning up.
    func closeSession() async

    /// Starts playback with the given session.
    /// - Parameter session: The playback session to start.
    func startPlayback(session: PlaybackSession)

    /// Plays audio from the current position.
    func play()

    /// Manual retry after a surfaced playback failure.
    func retryCurrentTrack()

    /// Pauses audio playback.
    func pause()

    /// Toggles between play and pause.
    func togglePlayPause()

    /// Skips forward by the given number of seconds.
    func skipForward(_ seconds: Int)

    /// Skips backward by the given number of seconds.
    func skipBackward(_ seconds: Int)

    /// Sets the playback rate.
    /// - Parameter rate: The playback rate (e.g. 1.0, 1.5, 2.0).
    func setPlaybackRate(_ rate: Float)

    /// Seeks to the given time interval within the current session.
    /// - Parameter time: The target time in seconds.
    func seek(to time: TimeInterval)

    // MARK: - Bookmarks

    /// Adds a bookmark at the current playback position.
    /// - Parameters:
    ///   - title: Title for the bookmark (empty defaults to timestamp).
    ///   - note: Optional multi-line notes or commentary.
    func addBookmark(title: String, note: String?)

    /// Deletes the given bookmark from the current session.
    /// - Parameter bookmark: The bookmark to delete.
    func deleteBookmark(_ bookmark: Bookmark)

    /// Updates an existing bookmark's title and note.
    func updateBookmark(_ bookmark: Bookmark, title: String, note: String?)

    // MARK: - Sleep Timer

    /// Starts the sleep timer for the given duration.
    /// - Parameter duration: The duration in seconds.
    func startSleepTimer(duration: TimeInterval)

    /// Extends the sleep timer by a given number of seconds if active.
    @discardableResult
    func extendSleepTimer(by seconds: TimeInterval) -> Bool

    /// Stops the sleep timer if active.
    func stopSleepTimer()

    // MARK: - Sync & Engine

    /// Flushes any pending offline progress records to the server.
    func flushOfflineProgressQueue() async

    /// Applies audio DSP effects.
    func applyAudioDSP()

    /// Reconfigures the audio session (e.g. when route changes).
    func reconfigureAudioSession()
}

extension AudioPlayerServiceProtocol {
    public func addBookmark(title: String) {
        addBookmark(title: title, note: nil)
    }
}
