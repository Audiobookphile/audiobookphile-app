import XCTest
@testable import Audiobookphile

@MainActor
final class AudioPlayerServiceTests: XCTestCase {

    override func setUp() async throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() async throws {
        // Every test in this class drives `AudioPlayerService.shared`, a
        // process-wide singleton holding a live AVQueuePlayer, KVO observers, a
        // sync timer and a retry counter. Without this reset the tests inherited
        // each other's engine state, and the swap test below failed on a COLD
        // simulator while passing every warm run -- the signature of a
        // cross-test race rather than a product defect. `closeSession` is the
        // app's own teardown path, so this adds no new production surface.
        await AudioPlayerService.shared.closeSession()
        try? await Task.sleep(nanoseconds: 100_000_000)
    }

    func testInitialState() async throws {
        let service = AudioPlayerService.shared
        XCTAssertFalse(service.isPlaying)
        XCTAssertEqual(service.currentTime, 0)
        XCTAssertNil(service.playbackError)
    }

    func testSeekEpochsAndBounds() async throws {
        let service = AudioPlayerService.shared
        let initialEpoch = service.activeSeekEpoch
        
        let dummySession = PlaybackSession(
            id: "test-session-1",
            userId: "test-user",
            libraryId: "lib-1",
            libraryItemId: "item-1",
            episodeId: nil,
            displayTitle: "Test Audiobook",
            displayAuthor: "Test Author",
            coverPath: nil,
            duration: 1000,
            playMethod: 0,
            mediaPlayer: "AVQueuePlayer",
            mediaType: "book",
            audioTracks: [
                AudioTrack(index: 0, startOffset: 0, duration: 500, title: "Part 1", contentUrl: "https://example.com/1.mp3", mimeType: "audio/mp3", codec: "mp3"),
                AudioTrack(index: 1, startOffset: 500, duration: 500, title: "Part 2", contentUrl: "https://example.com/2.mp3", mimeType: "audio/mp3", codec: "mp3")
            ],
            chapters: [],
            manifestUrl: "/api/items/item-1/manifest.m3u8",
            missingTrackCount: 0,
            currentTime: 0,
            playbackRate: 1.0,
            startedAt: Date(),
            updatedAt: Date()
        )
        service.session = dummySession
        service.duration = dummySession.duration
        
        // Seek forward
        service.seek(to: 250)
        XCTAssertEqual(service.currentTime, 250)
        XCTAssertGreaterThan(service.activeSeekEpoch, initialEpoch)
        
        // Seek beyond bounds (should clamp to duration)
        service.seek(to: 1500)
        XCTAssertEqual(service.currentTime, 1000)
        
        // Seek below 0 (should clamp to 0)
        service.seek(to: -50)
        XCTAssertEqual(service.currentTime, 0)
    }

    func testSeekWithZeroInitialDurationFallback() async throws {
        let service = AudioPlayerService.shared
        
        let dummySession = PlaybackSession(
            id: "test-session-zero-dur",
            userId: "test-user",
            libraryId: "lib-1",
            libraryItemId: "item-2",
            episodeId: nil,
            displayTitle: "Test Audiobook Zero Dur",
            displayAuthor: "Test Author",
            coverPath: nil,
            duration: 1200,
            playMethod: 0,
            mediaPlayer: "AVQueuePlayer",
            mediaType: "book",
            audioTracks: [
                AudioTrack(index: 0, startOffset: 0, duration: 600, title: "Part 1", contentUrl: "https://example.com/1.mp3", mimeType: "audio/mp3", codec: "mp3"),
                AudioTrack(index: 1, startOffset: 600, duration: 600, title: "Part 2", contentUrl: "https://example.com/2.mp3", mimeType: "audio/mp3", codec: "mp3")
            ],
            chapters: [],
            manifestUrl: nil,
            missingTrackCount: 0,
            currentTime: 0,
            playbackRate: 1.0,
            startedAt: Date(),
            updatedAt: Date()
        )
        service.session = dummySession
        service.duration = 0 // Simulating uninitialized service duration
        
        // Seek to 750 (Part 2)
        service.seek(to: 750)
        XCTAssertEqual(service.currentTime, 750, "Should fall back to session duration and not clamp to 0")
    }

    /// Regression: swapping sessions used to spawn `Task { await closeSession() }`
    /// which resolved `self.session` at execution time — i.e. the NEW session —
    /// and engine.cleanup() destroyed the freshly built playback queue.
    func testStartPlaybackSwapPreservesNewQueue() async throws {
        let service = AudioPlayerService.shared

        func makeSession(id: String) -> PlaybackSession {
            PlaybackSession(
                id: id,
                userId: "test-user",
                libraryId: "lib-1",
                libraryItemId: "item-\(id)",
                episodeId: nil,
                displayTitle: "Book \(id)",
                displayAuthor: "Author",
                coverPath: nil,
                duration: 1000,
                playMethod: 0,
                mediaPlayer: "AVQueuePlayer",
                mediaType: "book",
                audioTracks: [
                    AudioTrack(index: 0, startOffset: 0, duration: 500, title: "Part 1", contentUrl: "https://example.com/\(id)-1.mp3", mimeType: "audio/mp3", codec: "mp3"),
                    AudioTrack(index: 1, startOffset: 500, duration: 500, title: "Part 2", contentUrl: "https://example.com/\(id)-2.mp3", mimeType: "audio/mp3", codec: "mp3")
                ],
                chapters: [],
                manifestUrl: nil,
                missingTrackCount: 0,
                currentTime: 0,
                playbackRate: 1.0,
                startedAt: Date(),
                updatedAt: Date()
            )
        }

        // Session A is playing…
        service.startPlayback(session: makeSession(id: "swap-A"))
        // …then the user starts session B without closing A first.
        service.startPlayback(session: makeSession(id: "swap-B"))

        // The queue is built synchronously by loadQueue, but AVPlayer's own
        // settling (and a cold simulator's first AVFoundation work) is not. A
        // fixed sleep is a race: it passed on warm runs and failed cold, and the
        // failure said nothing about why. Wait for the condition instead, with a
        // bounded budget, and report the engine's own view of the world if it
        // never arrives so the next occurrence is diagnosable.
        let deadline = Date().addingTimeInterval(2.0)
        while service.engine.queuedItemsCount == 0 && Date() < deadline {
            try? await Task.sleep(nanoseconds: 25_000_000)
        }

        XCTAssertEqual(service.session?.id, "swap-B")
        XCTAssertGreaterThan(
            service.engine.queuedItemsCount, 0,
            """
            New session's playback queue must survive the session swap. \
            session=\(service.session?.id ?? "nil") \
            queued=\(service.engine.queuedItemsCount) \
            currentTime=\(service.currentTime) \
            isPlaying=\(service.isPlaying) \
            duration=\(service.duration) \
            trackCount=\(service.session?.audioTracks.count ?? 0)
            """
        )
        XCTAssertTrue(service.isPlaying)
    }
}
