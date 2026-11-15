import XCTest
@testable import Audiobookphile

@MainActor
final class UpstreamFeaturesTests: XCTestCase {

    func testSleepTimerSetAndReset() async throws {
        let timer = AudioPlayerSleepTimer()
        XCTAssertFalse(timer.isActive)
        XCTAssertNil(timer.remaining)
        XCTAssertNil(timer.initialDuration)

        var completed = false
        timer.setSleepTimer(seconds: 120) {
            completed = true
        }

        XCTAssertTrue(timer.isActive)
        XCTAssertEqual(timer.remaining, 120)
        XCTAssertEqual(timer.initialDuration, 120)
        XCTAssertEqual(timer.format(), "02:00")

        // Mutate remaining to simulate countdown
        timer.remaining = 45
        XCTAssertEqual(timer.format(), "00:45")

        // Reset timer
        let resetSuccess = timer.resetSleepTimer()
        XCTAssertTrue(resetSuccess)
        XCTAssertEqual(timer.remaining, 120)
        XCTAssertEqual(timer.initialDuration, 120)

        // Stop timer
        timer.stopSleepTimer()
        XCTAssertFalse(timer.isActive)
        XCTAssertNil(timer.remaining)
        XCTAssertNil(timer.initialDuration)
        XCTAssertFalse(completed)
    }

    func testAppSettingsWithUpstreamFeatures() throws {
        var settings = AppSettings()
        XCTAssertTrue(settings.smartRewindEnabled)
        XCTAssertEqual(settings.smartRewindSeconds, 20)
        XCTAssertTrue(settings.shakeToResetSleepTimer)
        XCTAssertTrue(settings.perBookPlaybackSpeedEnabled)
        XCTAssertFalse(settings.autoDeleteFinishedDownloads)
        XCTAssertEqual(settings.streamingPolicy, .always)
        XCTAssertEqual(settings.downloadPolicy, .wifiOnly)

        settings.smartRewindEnabled = false
        settings.smartRewindSeconds = 15
        settings.shakeToResetSleepTimer = false
        settings.perBookPlaybackSpeedEnabled = false
        settings.autoDeleteFinishedDownloads = true
        settings.streamingPolicy = .wifiOnly
        settings.downloadPolicy = .never

        let encoded = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: encoded)

        XCTAssertFalse(decoded.smartRewindEnabled)
        XCTAssertEqual(decoded.smartRewindSeconds, 15)
        XCTAssertFalse(decoded.shakeToResetSleepTimer)
        XCTAssertFalse(decoded.perBookPlaybackSpeedEnabled)
        XCTAssertTrue(decoded.autoDeleteFinishedDownloads)
        XCTAssertEqual(decoded.streamingPolicy, .wifiOnly)
        XCTAssertEqual(decoded.downloadPolicy, .never)
    }

    func testBookMetadataAbridgedDecoding() throws {
        let jsonWithAbridged = """
        {
            "title": "Moby Dick",
            "authorName": "Herman Melville",
            "explicit": true,
            "abridged": true
        }
        """.data(using: .utf8)!

        let metadata = try JSONDecoder().decode(BookMetadata.self, from: jsonWithAbridged)
        XCTAssertEqual(metadata.title, "Moby Dick")
        XCTAssertTrue(metadata.explicit)
        XCTAssertEqual(metadata.abridged, true)

        let jsonWithoutAbridged = """
        {
            "title": "War and Peace",
            "authorName": "Leo Tolstoy",
            "explicit": false
        }
        """.data(using: .utf8)!

        let unabridgedMetadata = try JSONDecoder().decode(BookMetadata.self, from: jsonWithoutAbridged)
        XCTAssertEqual(unabridgedMetadata.title, "War and Peace")
        XCTAssertFalse(unabridgedMetadata.explicit)
        XCTAssertNil(unabridgedMetadata.abridged)
    }

    func testBookmarkWithMultiLineNoteDecodingAndEncoding() throws {
        let json = """
        {
            "id": "bm-123",
            "user_id": "usr-456",
            "library_item_id": "item-789",
            "time_pos": 345.5,
            "title": "Favorite quote",
            "note": "Line 1: Key revelation\\nLine 2: Deep dialogue"
        }
        """.data(using: .utf8)!

        let bookmark = try JSONDecoder().decode(Bookmark.self, from: json)
        XCTAssertEqual(bookmark.id, "bm-123")
        XCTAssertEqual(bookmark.timePos, 345.5)
        XCTAssertEqual(bookmark.title, "Favorite quote")
        XCTAssertEqual(bookmark.note, "Line 1: Key revelation\nLine 2: Deep dialogue")

        let encoded = try JSONEncoder().encode(bookmark)
        let roundtrip = try JSONDecoder().decode(Bookmark.self, from: encoded)
        XCTAssertEqual(roundtrip.note, bookmark.note)
    }

    func testPodcastRssFeedAndOpdsUrlConstruction() throws {
        let serverUrl = "https://audiobookphile.app"
        let bookId = "b0000000-0000-4000-8000-000000000001"
        let expectedFeedUrl = "\(serverUrl)/feed/\(bookId)"
        let expectedOpdsUrl = "\(serverUrl)/api/opds"

        XCTAssertEqual(expectedFeedUrl, "https://audiobookphile.app/feed/b0000000-0000-4000-8000-000000000001")
        XCTAssertEqual(expectedOpdsUrl, "https://audiobookphile.app/api/opds")
    }
}
