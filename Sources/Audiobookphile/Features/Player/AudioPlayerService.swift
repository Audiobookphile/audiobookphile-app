import Foundation
#if canImport(OSLog)
import OSLog
#endif
import Observation
import SwiftUI
#if !SKIP && !os(Android)
import AVFoundation
import MediaPlayer
#if os(iOS)
import UIKit
import BackgroundTasks
import WidgetKit
#endif
#endif

@Observable
@MainActor
public class AudioPlayerService: AudioPlayerServiceProtocol {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Audiobookphile", category: "AudioPlayer")
    public static let shared = AudioPlayerService()

    public var session: PlaybackSession?
    public var isPlaying = false
    public var isBuffering = false
    public var currentTime: TimeInterval = 0
    public var playbackRate: Float = 1.0
    public var duration: TimeInterval = 0
    public var playbackError: Error?

    /// User playback *intent*: true between an explicit play (or an autoplay
    /// start) and an explicit pause / end-of-book.
    ///
    /// ── WHY THIS IS SEPARATE FROM `isPlaying` ──
    /// `isPlaying` mirrors AVPlayer's `timeControlStatus`, which is *not* a
    /// reliable record of intent: AVPlayer transiently reports `.paused`
    /// while it swaps items (queue top-up, track advance, item rebuild).
    /// The old code cleared `isPlaying` on that transient pause, and then
    /// resumed via `handleItemReady` -> `if self.isPlaying { self.play() }`.
    /// The flag that got cleared by the transient was the same flag gating the
    /// resume, so the player latched into "not playing and not allowed to
    /// start" -- the reported "plays for a second, then pauses and never
    /// comes back".
    ///
    /// Intent is therefore the authoritative input to every resume path, and
    /// `isPlaying` is derived from the transport as an output for the UI.
    public private(set) var isPlayRequested = false

    /// Set by the only two paths that may end playback on purpose: an explicit
    /// `pause()` (user tap, interruption) and reaching the end of the book.
    /// Everything else that makes AVPlayer report `.paused` is transient.
    private var isExplicitlyPaused = false
    // MARK: - Monotonic Seek Transaction Epochs
    /**
     * ── ARCHITECTURAL INVARIANT: PLAYBACK TIMELINE & SEEK INTEGRITY ──
     * 1. Monotonicity: Time updates from periodic observers MUST be rejected 
     *    while an active seek transaction is unresolved (activeSeekEpoch != acknowledgedSeekEpoch).
     * 2. Inclusive Boundaries: Track indexing MUST evaluate the final track
     *    inclusively (`targetTime <= trackEnd`) to prevent 100% end-of-book drops.
     * 3. Transient Guard: While AVPlayerItem buffers, `currentTime` MUST hold
     *    the target seek time and never fall back to `0.0`.
     */
    public private(set) var activeSeekEpoch: UInt64 = 0
    public private(set) var acknowledgedSeekEpoch: UInt64 = 0

    public var isSeeking: Bool {
        activeSeekEpoch != acknowledgedSeekEpoch
    }
    
    private var currentTrackIndex = 0
    private var retryCount = 0
    private var pendingSeekTimeWithinTrack: TimeInterval?
    /// Dedupe key for the last WidgetKit timeline reload (budget protection).
    private var lastWidgetReloadKey: String?

    // Sub-Managers
    public let bookmarkManager = AudioPlayerBookmarkManager()
    public let sleepTimer = AudioPlayerSleepTimer()
    public let syncManager = AudioPlayerSyncManager()
    public let nowPlayingManager = AudioPlayerNowPlayingManager()
    public let engine = AudioPlayerEngine()

    public var bookmarks: [Bookmark] = []
    
    public var sleepTimerRemaining: TimeInterval? {
        sleepTimer.remaining
    }

    private init() {
        #if os(iOS)
        engine.reconfigureAudioSession()
        
        NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.syncManager.syncProgressImmediately(getSessionData: { [weak self] in
                    return (self?.session, self?.currentTime ?? 0, self?.duration ?? 0)
                }, onSyncComplete: { [weak self] in
                    self?.syncWidgetState()
                })
                self?.syncManager.enqueueOfflineSyncOnBackground()
            }
        }

        NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.syncManager.syncProgressImmediately(getSessionData: { [weak self] in
                    return (self?.session, self?.currentTime ?? 0, self?.duration ?? 0)
                }, onSyncComplete: { [weak self] in
                    self?.syncWidgetState()
                })
            }
        }
        #endif

        setupEngineCallbacks()
    }
    
    private func setupEngineCallbacks() {
        engine.onTimeControlStatusChanged = { [weak self] playing, buffering in
            guard let self = self else { return }
            // The whole "plays for a second then pauses" bug lived in this
            // branch. The rule now lives in PlaybackTransportState so it can be
            // asserted without a live AVPlayer; see that type for why the
            // transient `.paused` must not be allowed to revoke intent.
            let resolved = PlaybackTransportState.resolve(
                transportPlaying: playing,
                transportBuffering: buffering,
                isPlayRequested: self.isPlayRequested,
                isExplicitlyPaused: self.isExplicitlyPaused
            )
            self.isPlaying = resolved.isPlaying
            self.isBuffering = resolved.isBuffering
            if case .playing(let isBuffering) = resolved, !isBuffering {
                self.retryCount = 0
            }
            self.syncWidgetState()
        }
        
        engine.onCurrentItemChanged = { [weak self] item in
            self?.handleCurrentItemChanged(item)
        }
        
        engine.onPeriodicTimeUpdate = { [weak self] time in
            self?.handlePeriodicTimeUpdate(time: time)
        }
        
        engine.onItemReady = { [weak self] item in
            self?.handleItemReady(item)
        }
        
        engine.onItemFailed = { [weak self] error in
            self?.handlePlaybackFailure(error: error)
        }
        
        engine.onItemDidPlayToEndTime = { [weak self] _ in
            self?.handleItemDidPlayToEndTime()
        }
        
        engine.onItemStalled = { [weak self] in
            self?.handlePlaybackStalled()
        }
        
        engine.onAudioRouteLost = { [weak self] in
            self?.pause()
        }
        
        engine.onAudioInterruptionBegan = { [weak self] in
            self?.pause()
        }
        
        engine.onAudioInterruptionEnded = { [weak self] shouldResume in
            if shouldResume { self?.play() }
        }
    }
    
    // MARK: - Playback Control
    
    public func closeSession() async {
        if let activeSession = self.session {
            syncManager.recordClosedSession(session: activeSession, syncTime: self.currentTime, syncDuration: self.duration)
            pause()
            syncManager.stopSyncTimer()
            stopSleepTimer()

            #if !SKIP && !os(Android)
            engine.cleanup()
            #endif
            self.session = nil
        }
    }

    public func startPlayback(session: PlaybackSession) {
        // Capture the outgoing session BEFORE swapping state. The old code
        // spawned `Task { await closeSession() }` which reads `self.session`
        // at execution time — by then it points at the NEW session, so the
        // "cleanup" paused the new engine and engine.cleanup() destroyed the
        // freshly built playback queue (dead/frozen player).
        let outgoingSession = self.session
        let outgoingTime = self.currentTime
        let outgoingDuration = self.duration

        logger.info("startPlayback called - session id: \(session.id)")

        self.session = session

        // Persist the replaced session's listening position. Deliberately does
        // NOT touch the shared engine, sync timers, or player state — those now
        // belong to the incoming session.
        if let outgoing = outgoingSession, outgoing.id != session.id {
            Task { [weak self] in
                self?.syncManager.recordClosedSession(
                    session: outgoing,
                    syncTime: outgoingTime,
                    syncDuration: outgoingDuration
                )
            }
        }
        let tracksDuration = session.audioTracks.last.map { $0.startOffset + $0.duration } ?? session.audioTracks.reduce(0) { $0 + $1.duration }
        self.duration = tracksDuration > 0 ? tracksDuration : session.duration
        self.currentTime = session.currentTime
        // Starting a book IS a play request: record the intent so a transient
        // `.paused` while the first item loads cannot be mistaken for the user
        // hitting pause.
        self.isPlayRequested = true
        self.isExplicitlyPaused = false
        self.isPlaying = true
        self.bookmarks = []
        // A fresh session invalidates any failure from the previous one —
        // otherwise the error overlay from a broken book would linger over
        // the newly opened one.
        self.playbackError = nil
        self.retryCount = 0

        Task {
            let fetched = await bookmarkManager.fetchBookmarks(libraryItemId: session.libraryItemId)
            self.bookmarks = fetched
        }

        self.playbackRate = session.playbackRate
        syncManager.setLastSyncedTime(session.currentTime)

        let pendingKey = "pendingSeekTime-\(session.id)"
        if let pendingSeek = UserDefaults.standard.value(forKey: pendingKey) as? TimeInterval {
            self.currentTime = pendingSeek
            UserDefaults.standard.removeObject(forKey: pendingKey)
        }

        let trackInfo = findTrackIndexAndOffset(for: currentTime)
        self.currentTrackIndex = trackInfo.index

        #if !SKIP && !os(Android)
        nowPlayingManager.setupNowPlayingInfo(
            title: session.displayTitle,
            author: session.displayAuthor,
            duration: session.duration,
            currentTime: currentTime,
            playbackRate: playbackRate
        )
        nowPlayingManager.setupRemoteCommandCenter(
            onPlay: { [weak self] in self?.play() },
            onPause: { [weak self] in self?.pause() },
            onSkipForward: { [weak self] interval in self?.skipForward(Int(interval)) },
            onSkipBackward: { [weak self] interval in self?.skipBackward(Int(interval)) },
            onSeek: { [weak self] time in self?.seek(to: time) }
        )
        loadQueue(from: trackInfo.index, seekTimeWithinTrack: trackInfo.offset, autoPlay: true)
        #endif
        self.isPlayRequested = true
        self.isExplicitlyPaused = false
        self.isPlaying = true
        #if !SKIP && !os(Android)
        nowPlayingManager.updateNowPlaying(rate: playbackRate)
        #endif
        syncWidgetState()
        
        syncManager.startSyncTimer(getSessionData: { [weak self] in
            return (self?.session, self?.currentTime ?? 0, self?.duration ?? 0)
        }, onSyncComplete: { [weak self] in
            self?.syncWidgetState()
        })
    }

    public func play() {
        guard session != nil else { return }
        isPlayRequested = true
        isExplicitlyPaused = false
        isPlaying = true
        engine.play(rate: playbackRate)
        TelemetryService.shared.captureBreadcrumb("playback resumed", level: .info, tags: ["area": "player"])
        #if !SKIP && !os(Android)
        nowPlayingManager.updateNowPlaying(rate: playbackRate, elapsedTime: currentTime)
        #endif
        syncWidgetState()
    }

    /// Manual retry after a surfaced playback failure (error overlay button).
    /// Asynchronously requests a fresh playback session from the server to renew
    /// presigned URLs, with automatic fallback to local tracks if network is unavailable.
    public func retryCurrentTrack() {
        guard let session = session, !session.audioTracks.isEmpty else { return }
        playbackError = nil
        retryCount = 0
        Task { @MainActor in
            do {
                logger.info("Manual retry triggered: refreshing playback session for \(session.libraryItemId)...")
                let refreshed = try await AudiobookphileAPI.shared.startPlaybackSession(
                    libraryItemId: session.libraryItemId,
                    episodeId: session.episodeId
                )
                self.session = refreshed
                let trackInfo = self.findTrackIndexAndOffset(for: self.currentTime)
                self.currentTrackIndex = trackInfo.index
                self.loadQueue(from: trackInfo.index, seekTimeWithinTrack: trackInfo.offset, autoPlay: true)
                self.isPlayRequested = true
                self.isExplicitlyPaused = false
                self.isPlaying = true
            } catch {
                logger.error("Session refresh during retry failed (\(error.localizedDescription)); attempting local queue reload...")
                let index = min(self.currentTrackIndex, session.audioTracks.count - 1)
                self.currentTrackIndex = index
                let track = session.audioTracks[index]
                let seekTime = max(0, self.currentTime - track.startOffset)
                self.loadQueue(from: index, seekTimeWithinTrack: seekTime, autoPlay: true)
                self.isPlayRequested = true
                self.isExplicitlyPaused = false
                self.isPlaying = true
            }
        }
    }

    public func pause() {
        isPlayRequested = false
        isExplicitlyPaused = true
        isPlaying = false
        engine.pause()
        TelemetryService.shared.captureBreadcrumb("playback paused", level: .info, tags: ["area": "player"])
        #if !SKIP && !os(Android)
        nowPlayingManager.updateNowPlaying(rate: 0.0, elapsedTime: currentTime)
        #endif
        syncManager.debounceProgressSync(getSessionData: { [weak self] in
            return (self?.session, self?.currentTime ?? 0, self?.duration ?? 0)
        }, onSyncComplete: { [weak self] in
            self?.syncWidgetState()
        })
        syncWidgetState()
    }

    public func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func skipForward(_ seconds: Int = 15) {
        seek(to: currentTime + TimeInterval(seconds))
    }

    public func skipBackward(_ seconds: Int = 15) {
        seek(to: max(0, currentTime - TimeInterval(seconds)))
    }

    public func setPlaybackRate(_ rate: Float) {
        self.playbackRate = rate
        #if !SKIP && !os(Android)
        if isPlaying {
            engine.play(rate: rate)
            nowPlayingManager.updateNowPlaying(rate: rate, elapsedTime: currentTime)
        }
        #endif
    }

    public func seek(to time: TimeInterval) {
        guard let session = session else { return }

        let effectiveDur = duration > 0 ? duration : (session.duration > 0 ? session.duration : session.audioTracks.reduce(0) { $0 + $1.duration })
        let targetTime = effectiveDur > 0 ? max(0, min(time, effectiveDur)) : max(0, time)
        self.currentTime = targetTime
        
        activeSeekEpoch &+= 1
        let thisEpoch = activeSeekEpoch
        
        #if !SKIP && !os(Android)
        nowPlayingManager.updateNowPlaying(elapsedTime: targetTime)
        #endif
        
        syncWidgetState()

        let trackInfo = findTrackIndexAndOffset(for: targetTime)

        #if !SKIP && !os(Android)
        if trackInfo.index == currentTrackIndex && engine.currentItem != nil {
            if let item = engine.currentItem as? AVPlayerItem, item.status == .readyToPlay {
                let wasPlaying = self.isPlaying
                let seekId = UUID()
                
                if wasPlaying {
                    engine.pause()
                }
                
                executeSeek(to: trackInfo.offset, seekId: seekId, wasPlaying: wasPlaying, epoch: thisEpoch)
            } else {
                // Item is still loading, defer the seek until it is ready
                self.pendingSeekTimeWithinTrack = trackInfo.offset
            }
        } else {
            loadQueue(from: trackInfo.index, seekTimeWithinTrack: trackInfo.offset, autoPlay: isPlaying, epoch: thisEpoch)
        }
        #endif
        
        syncManager.debounceProgressSync(getSessionData: { [weak self] in
            return (self?.session, self?.currentTime ?? 0, self?.duration ?? 0)
        }, onSyncComplete: { [weak self] in
            self?.syncWidgetState()
        })
    }

    private func findTrackIndexAndOffset(for targetTime: TimeInterval) -> (index: Int, offset: TimeInterval) {
        guard let session = session, !session.audioTracks.isEmpty else { return (0, 0) }
        
        let totalDuration = session.audioTracks.last.map { $0.startOffset + $0.duration } ?? 0
        let clampedTarget = totalDuration > 0 ? max(0, min(targetTime, totalDuration)) : max(0, targetTime)
        
        for (index, track) in session.audioTracks.enumerated() {
            let isLast = index == session.audioTracks.count - 1
            let trackEnd = track.startOffset + track.duration
            if clampedTarget >= track.startOffset && (isLast ? clampedTarget <= trackEnd : clampedTarget < trackEnd) {
                let offset = max(0, min(track.duration, clampedTarget - track.startOffset))
                return (index, offset)
            }
        }
        let lastIdx = session.audioTracks.count - 1
        let track = session.audioTracks[lastIdx]
        let offset = max(0, min(track.duration, clampedTarget - track.startOffset))
        return (lastIdx, offset)
    }

    // MARK: - Queue & Engine Handling
    
    private func loadQueue(from index: Int, seekTimeWithinTrack: TimeInterval, autoPlay: Bool = true, epoch: UInt64? = nil) {
        guard let session = session else { return }
        guard index >= 0 && index < session.audioTracks.count else { return }

        self.currentTrackIndex = index
        self.pendingSeekTimeWithinTrack = seekTimeWithinTrack

        #if !SKIP && !os(Android)
        engine.initializePlayer()
        if autoPlay {
            self.isPlayRequested = true
            self.isExplicitlyPaused = false
            self.isPlaying = true
        }
        topUpQueue(from: index)
        #endif
    }

    private func topUpQueue(from startIndex: Int? = nil) {
        guard let session = session else { return }
        #if !SKIP && !os(Android)
        var lastIdx = currentTrackIndex - 1
        if let start = startIndex {
            lastIdx = start - 1
        }

        let maxQueuedItems = 3
        while engine.queuedItemsCount < maxQueuedItems {
            let nextIndex = lastIdx + 1
            guard nextIndex < session.audioTracks.count else { break }
            lastIdx = nextIndex

            if let item = makePlayerItem(for: nextIndex) {
                engine.insertItem(item)
            } else {
                logger.error("Failed to create AVPlayerItem for track index \(nextIndex)")
                TelemetryService.shared.captureMessage("Failed to create AVPlayerItem for track index \(nextIndex)", level: .warning, tags: ["area": "player"])
            }
        }
        #endif
    }
    
    private func makePlayerItem(for index: Int) -> AVPlayerItem? {
        guard let session = session, index >= 0 && index < session.audioTracks.count else { return nil }
        let track = session.audioTracks[index]
        guard let url = getFullTrackURL(from: track.contentUrl, libraryItemId: session.libraryItemId) else {
            return nil
        }
        
        let options: [String: Any] = [AVURLAssetPreferPreciseDurationAndTimingKey: false]
        let asset = AVURLAsset(url: url, options: options)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 60.0
        #if os(iOS)
        item.audioTimePitchAlgorithm = .spectral
        if #available(iOS 15.0, *) {
            item.allowedAudioSpatializationFormats = [.monoAndStereo, .multichannel]
        }
        #endif
        return item
    }

    private func getFullTrackURL(from trackPath: String, libraryItemId: String? = nil) -> URL? {
        let trimmedPath = trackPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if let bookId = libraryItemId,
           let localURL = DownloadService.shared.getLocalTrackURL(bookId: bookId, trackPath: trimmedPath) {
            return localURL
        }

        var finalURLString = ""
        if trimmedPath.hasPrefix("http") {
            finalURLString = trimmedPath
        } else if trimmedPath.hasPrefix("/") {
            let base = UserDefaults.standard.string(forKey: "abp_serverURL") ?? ""
            finalURLString = base + trimmedPath
        } else {
            return nil
        }
        
        guard var components = URLComponents(string: finalURLString) ?? URLComponents(string: finalURLString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            return nil
        }
        
        let token = AppState.shared.token
        if !token.isEmpty && !trimmedPath.hasPrefix("http") {
            var queryItems = components.queryItems ?? []
            if !queryItems.contains(where: { $0.name == "token" }) {
                queryItems.append(URLQueryItem(name: "token", value: token))
            }
            components.queryItems = queryItems
        }
        
        return components.url
    }

    // MARK: - Callbacks

    private func handleCurrentItemChanged(_ item: AVPlayerItem?) {
        guard let session = session else { return }
        guard let item = item else {
            // `currentItem == nil` is emitted transiently while the queue is
            // rebuilt (top-up, track advance), not only at the end of a book.
            // Treating it as end-of-book called pause() and stopped playback
            // mid-book -- the second half of the "plays, then pauses" report.
            // Only conclude end-of-book when we were not asked to keep playing.
            if !isPlayRequested && currentTrackIndex >= session.audioTracks.count - 1 && activeSeekEpoch == acknowledgedSeekEpoch {
                handleItemDidPlayToEndTime()
            }
            return
        }

        if let asset = item.asset as? AVURLAsset,
           let matchedIndex = session.audioTracks.firstIndex(where: {
               getFullTrackURL(from: $0.contentUrl, libraryItemId: session.libraryItemId) == asset.url
           }) {
            if matchedIndex != currentTrackIndex {
                currentTrackIndex = matchedIndex
            }
        }

        topUpQueue()
        #if !SKIP && !os(Android)
        nowPlayingManager.updateNowPlaying(rate: isPlaying ? playbackRate : 0.0, elapsedTime: currentTime)
        #endif
    }
    
    private func handlePeriodicTimeUpdate(time: CMTime) {
        guard isPlaying, activeSeekEpoch == acknowledgedSeekEpoch, let session = session, currentTrackIndex < session.audioTracks.count else { return }
        let track = session.audioTracks[currentTrackIndex]
        let absoluteTime = track.startOffset + time.seconds
        self.currentTime = absoluteTime

        #if !SKIP && !os(Android)
        nowPlayingManager.updateNowPlaying(elapsedTime: absoluteTime)
        #endif

        if let item = engine.currentItem as? AVPlayerItem, item.status == .readyToPlay {
            let itemDur = item.duration.seconds
            if itemDur > 0 && !itemDur.isNaN && (track.duration <= 0 || abs(itemDur - track.duration) > 2) {
                self.session?.audioTracks[self.currentTrackIndex].duration = itemDur
                var currentOffset: TimeInterval = 0
                if let tracks = self.session?.audioTracks {
                    for i in 0..<tracks.count {
                        self.session?.audioTracks[i].startOffset = currentOffset
                        currentOffset += self.session?.audioTracks[i].duration ?? 0
                    }
                    self.duration = currentOffset
                }
            }
        }
    }

    private func handleItemReady(_ item: AVPlayerItem) {
        if let pendingSeek = self.pendingSeekTimeWithinTrack {
            self.pendingSeekTimeWithinTrack = nil
            let seekId = UUID()
            let thisEpoch = self.activeSeekEpoch
            
            if pendingSeek > 0.01 {
                executeSeek(to: pendingSeek, seekId: seekId, wasPlaying: self.isPlaying, epoch: thisEpoch)
            } else {
                if self.activeSeekEpoch == thisEpoch {
                    self.acknowledgedSeekEpoch = thisEpoch
                }
                // Gate on play INTENT, not on the observed transport flag. This
                // is the line the bug hinged on: the transport flag is cleared
                // every time AVPlayer swaps items, and using it here meant a
                // fresh item would never actually start.
                if self.isPlayRequested {
                    self.play()
                }
            }
        } else {
            if self.activeSeekEpoch == self.acknowledgedSeekEpoch {
                // Already in sync
            } else {
                self.acknowledgedSeekEpoch = self.activeSeekEpoch
            }
            if self.isPlayRequested {
                self.play()
            }
        }
    }
    
    private func executeSeek(to targetTimeWithinTrack: TimeInterval, seekId: UUID, wasPlaying: Bool, epoch: UInt64? = nil, retryCount: Int = 0) {
        let cmTime = CMTime(seconds: targetTimeWithinTrack, preferredTimescale: 600)
        let targetEpoch = epoch ?? self.activeSeekEpoch
        
        #if !SKIP && !os(Android)
        if let item = engine.currentItem as? AVPlayerItem {
            if item.status == .failed {
                if self.activeSeekEpoch == targetEpoch {
                    self.acknowledgedSeekEpoch = targetEpoch
                }
                return
            }
            if item.seekableTimeRanges.isEmpty {
                if retryCount < 50 {
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        if self.activeSeekEpoch == targetEpoch {
                            self.executeSeek(to: targetTimeWithinTrack, seekId: seekId, wasPlaying: wasPlaying, epoch: targetEpoch, retryCount: retryCount + 1)
                        }
                    }
                    return
                }
            }
        }
        #endif

        engine.seek(to: cmTime) { [weak self] finished in
            Task { @MainActor in
                guard let self = self else { return }
                guard self.activeSeekEpoch == targetEpoch else { return } // A newer seek transaction was started
                
                if finished {
                    self.acknowledgedSeekEpoch = targetEpoch
                    if wasPlaying { self.play() }
                } else {
                    if retryCount < 50 {
                        Task {
                            try? await Task.sleep(nanoseconds: 100_000_000)
                            if self.activeSeekEpoch == targetEpoch {
                                self.executeSeek(to: targetTimeWithinTrack, seekId: seekId, wasPlaying: wasPlaying, epoch: targetEpoch, retryCount: retryCount + 1)
                            }
                        }
                    } else {
                        self.acknowledgedSeekEpoch = targetEpoch
                        if wasPlaying { self.play() }
                    }
                }
            }
        }
    }

    private func handlePlaybackFailure(error: Error?) {
        guard let session = session else { return }
        if let error {
            TelemetryService.shared.captureError(error, tags: ["area": "player", "op": "playback"])
        }
        if retryCount < 3 {
            retryCount += 1
            let delay = Double(retryCount) * 1.5
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard self.session?.id == session.id else { return }
                let track = session.audioTracks[self.currentTrackIndex]
                let seekTime = max(0, self.currentTime - track.startOffset)
                self.loadQueue(from: self.currentTrackIndex, seekTimeWithinTrack: seekTime, autoPlay: self.isPlaying)
            }
        } else {
            // Attempt to seamlessly refresh the session from the server to obtain fresh presigned URLs
            Task { @MainActor in
                do {
                    logger.info("Presigned URL or stream failed after 3 retries; refreshing session from server for \(session.libraryItemId)...")
                    let refreshed = try await AudiobookphileAPI.shared.startPlaybackSession(
                        libraryItemId: session.libraryItemId,
                        episodeId: session.episodeId
                    )
                    guard self.session?.id == session.id || self.session?.libraryItemId == session.libraryItemId else { return }

                    self.session = refreshed
                    self.retryCount = 0
                    self.playbackError = nil
                    let trackInfo = self.findTrackIndexAndOffset(for: self.currentTime)
                    self.currentTrackIndex = trackInfo.index
                    self.loadQueue(from: trackInfo.index, seekTimeWithinTrack: trackInfo.offset, autoPlay: self.isPlaying)
                } catch {
                    self.retryCount = 0
                    self.pause()
                    self.acknowledgedSeekEpoch = self.activeSeekEpoch
                    self.playbackError = error
                    TelemetryService.shared.captureError(error, tags: ["area": "player", "op": "session-refresh"])
                }
            }
        }
    }

    private func handlePlaybackStalled() {
        guard isPlayRequested else { return }
        isBuffering = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            // Re-check intent as well as buffering: a pause issued during the
            // 3s grace period must not be undone by this recovery path.
            if self.isBuffering && self.isPlayRequested {
                if self.engine.currentItem == nil {
                    self.playbackError = NSError(domain: "AudioPlayerServiceErrorDomain", code: -2, userInfo: [NSLocalizedDescriptionKey: "Audio stream stalled completely."])
                    self.pause()
                } else {
                    self.engine.play(rate: self.playbackRate)
                }
            }
        }
    }

    private func handleItemDidPlayToEndTime() {
        guard let session = self.session else { return }
        if self.currentTrackIndex >= session.audioTracks.count - 1 {
            // End of book is a legitimate reason to stop: clear the intent so
            // the transient-pause guard in the transport observer does not
            // immediately try to resume.
            self.isPlayRequested = false
            self.isExplicitlyPaused = true
            self.pause()
            self.currentTime = self.duration
            self.syncManager.syncProgressImmediately(getSessionData: { [weak self] in
                return (self?.session, self?.currentTime ?? 0, self?.duration ?? 0)
            }, onSyncComplete: { [weak self] in
                self?.syncWidgetState()
            })
            self.syncWidgetState()
        }
    }

    // MARK: - Bookmarks

    public func addBookmark(title: String) {
        guard let session = session else { return }
        let timePos = currentTime
        let bookmarkTitle = title.isEmpty ? "Bookmark at \(currentTime)" : title

        let temp = Bookmark(id: UUID().uuidString, userId: AppState.shared.currentUser?.id ?? "", libraryItemId: session.libraryItemId, timePos: timePos, title: bookmarkTitle, createdAt: Date())
        self.bookmarks.append(temp)
        self.bookmarks.sort(by: { $0.timePos < $1.timePos })

        Task {
            if let saved = await bookmarkManager.addBookmark(title: title, currentTime: timePos, libraryItemId: session.libraryItemId) {
                if let idx = self.bookmarks.firstIndex(where: { $0.id == temp.id }) {
                    self.bookmarks[idx] = saved
                } else {
                    self.bookmarks.append(saved)
                    self.bookmarks.sort(by: { $0.timePos < $1.timePos })
                }
            } else {
                self.bookmarks.removeAll(where: { $0.id == temp.id })
            }
        }
    }

    public func deleteBookmark(_ bookmark: Bookmark) {
        guard let session = session else { return }
        self.bookmarks.removeAll { $0.id == bookmark.id }
        Task {
            let success = await bookmarkManager.deleteBookmark(bookmark, libraryItemId: session.libraryItemId)
            if !success {
                self.bookmarks.append(bookmark)
                self.bookmarks.sort(by: { $0.timePos < $1.timePos })
            }
        }
    }

    // MARK: - Sleep Timer

    public func startSleepTimer(duration: TimeInterval) {
        sleepTimer.setSleepTimer(minutes: Int(duration / 60)) { [weak self] in
            self?.pause()
        }
    }

    public func stopSleepTimer() {
        sleepTimer.stopSleepTimer()
    }

    // MARK: - Sync Passthroughs
    
    public func flushOfflineProgressQueue() async {
        await syncManager.flushOfflineProgressQueue()
    }
    
    // MARK: - Engine Passthroughs
    
    public func applyAudioDSP() {
        engine.applyAudioDSP()
    }
    
    public func reconfigureAudioSession() {
        engine.reconfigureAudioSession()
    }

    // MARK: - Widget State Sync

    private func syncWidgetState() {
        guard let session = session, let defaults = UserDefaults(suiteName: EnvironmentConfig.appGroupIdentifier) else { return }

        var currentChapterName = "Reading"
        for chapter in session.chapters {
            if currentTime >= chapter.start && currentTime < chapter.end {
                currentChapterName = chapter.title
                break
            }
        }

        let stateDict: [String: Any] = [
            "bookTitle": session.displayTitle,
            "author": session.displayAuthor,
            "chapterName": currentChapterName,
            "progress": currentTime,
            "duration": duration,
            "isPlaying": isPlaying,
            "updatedAt": Date().timeIntervalSince1970
        ]
        defaults.set(stateDict, forKey: "audiobookWidgetState")

        // The widget timeline uses .never, so it only refreshes when the app
        // explicitly asks. But WidgetKit's reload budget is ~40-70/day and
        // this method fires on every 15s sync tick — reloading each time
        // would exhaust the budget within ~20 minutes of listening, after
        // which iOS throttles ALL widget updates. Reload only when the
        // visible state meaningfully changed: play-state flip, chapter
        // change, or a 5-minute progress bucket.
        #if os(iOS) && !SKIP
        let reloadKey = "\(isPlaying)|\(currentChapterName)|\(Int(currentTime / 300))"
        if reloadKey != lastWidgetReloadKey {
            lastWidgetReloadKey = reloadKey
            WidgetCenter.shared.reloadAllTimelines()
        }
        #endif
    }
}

@Observable
public final class ProMotionManager: @unchecked Sendable {
    public static let shared = ProMotionManager()
    public init() {}
    public func enableHighPerformanceMode() {
        #if os(iOS)
        print("[ProMotion] High performance mode enabled")
        #endif
    }
    public func optimizedSpring(response: Double = 0.3, dampingFraction: Double = 0.8) -> Animation {
        return .spring(response: response, dampingFraction: dampingFraction)
    }
}
