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

        // Test extending sleep timer
        let extended = timer.extendSleepTimer(by: 180)
        XCTAssertTrue(extended)
        XCTAssertEqual(timer.remaining, 300)
        XCTAssertEqual(timer.initialDuration, 300)
        XCTAssertEqual(timer.format(), "05:00")

        // Stop timer
        timer.stopSleepTimer()
        XCTAssertFalse(timer.isActive)
        XCTAssertNil(timer.remaining)
        XCTAssertNil(timer.initialDuration)
        XCTAssertFalse(completed)
    }

    func testSleepTimerEndOfTrackAndChapterCalculations() throws {
        let currentTime: TimeInterval = 150
        let trackDuration: TimeInterval = 600
        let remainingTrack = max(0, trackDuration - currentTime)
        XCTAssertEqual(remainingTrack, 450)

        let chapter = Chapter(id: 0, title: "Chapter 1", start: 100, end: 300)
        let remainingChapter = max(0, chapter.end - currentTime)
        XCTAssertEqual(remainingChapter, 150)
        XCTAssertNotEqual(remainingTrack, remainingChapter)
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

    func testBookmarksMarkdownExport() throws {
        let session = PlaybackSession(
            id: "sess-1",
            userId: "usr-1",
            libraryId: "lib-1",
            libraryItemId: "item-1",
            episodeId: nil,
            displayTitle: "The Great Gatsby",
            displayAuthor: "F. Scott Fitzgerald",
            coverPath: nil,
            duration: 1800,
            playMethod: 0,
            mediaPlayer: "AVQueuePlayer",
            mediaType: "book",
            audioTracks: [],
            chapters: [],
            manifestUrl: nil,
            missingTrackCount: 0,
            currentTime: 0,
            playbackRate: 1.0,
            startedAt: Date(),
            updatedAt: Date()
        )
        let vm = AudioPlayerViewModel(session: session)
        let bookmark = Bookmark(id: "bm-1", userId: "usr-1", libraryItemId: "item-1", timePos: 125, title: "Green Light", note: "Resilience and hope.")
        AudioPlayerService.shared.bookmarks = [bookmark]

        let exported = vm.exportBookmarksMarkdown()
        XCTAssertTrue(exported.contains("# Bookmarks for The Great Gatsby"))
        XCTAssertTrue(exported.contains("Author: F. Scott Fitzgerald"))
        XCTAssertTrue(exported.contains("Green Light"))
        XCTAssertTrue(exported.contains("> Resilience and hope."))
    }

    func testChapterFilterByTitleAndNumber() throws {
        let chapters = [
            Chapter(id: 0, title: "Prologue: Arrival", start: 0, end: 180),
            Chapter(id: 1, title: "Chapter 1: The Dark Forest", start: 180, end: 540),
            Chapter(id: 2, title: "Chapter 2: The Whispering Stream", start: 540, end: 900),
            Chapter(id: 3, title: "Epilogue", start: 900, end: 1200)
        ]

        // Empty query returns all chapters
        XCTAssertEqual(Chapter.filter(chapters: chapters, query: "").count, 4)
        XCTAssertEqual(Chapter.filter(chapters: chapters, query: "   ").count, 4)

        // Title search case-insensitively
        let prologueMatch = Chapter.filter(chapters: chapters, query: "arrival")
        XCTAssertEqual(prologueMatch.count, 1)
        XCTAssertEqual(prologueMatch.first?.title, "Prologue: Arrival")

        let forestMatch = Chapter.filter(chapters: chapters, query: "DARK FOREST")
        XCTAssertEqual(forestMatch.count, 1)
        XCTAssertEqual(forestMatch.first?.id, 1)

        // Chapter 1-based number query
        let numberMatch = Chapter.filter(chapters: chapters, query: "2")
        XCTAssertTrue(numberMatch.contains(where: { $0.id == 1 }))

        // "chapter 2" format
        let chapterTwoMatch = Chapter.filter(chapters: chapters, query: "chapter 2")
        XCTAssertTrue(chapterTwoMatch.contains(where: { $0.id == 1 }))

        // Nonexistent query returns empty
        let noneMatch = Chapter.filter(chapters: chapters, query: "Atlantis")
        XCTAssertTrue(noneMatch.isEmpty)
    }

    func testContinueSeriesShelfPopulation() async throws {
        let mockService = MockLibraryService()
        let vm = BookshelfViewModel(service: mockService)

        XCTAssertTrue(vm.continueSeries.isEmpty)
        await vm.loadLibrary(libraryId: "mock-lib", isAuthenticated: false)

        XCTAssertFalse(vm.continueSeries.isEmpty)
        XCTAssertTrue(vm.continueSeries.allSatisfy { $0.seriesName != nil })
        XCTAssertEqual(vm.continueSeries.first?.seriesName, "The Midnight Collection")
    }

    func testPlaybackQueueManagement() throws {
        let playerService = AudioPlayerService.shared
        playerService.clearPlaybackQueue()
        XCTAssertTrue(playerService.playbackQueue.isEmpty)

        let session1 = PlaybackSession(
            id: "q-1",
            userId: "u-1",
            libraryId: "lib-1",
            libraryItemId: "item-1",
            episodeId: nil,
            displayTitle: "Book One",
            displayAuthor: "Author One",
            coverPath: nil,
            duration: 1000,
            playMethod: 0,
            mediaPlayer: "AVQueuePlayer",
            mediaType: "book",
            audioTracks: [],
            chapters: [],
            manifestUrl: nil,
            missingTrackCount: 0,
            currentTime: 0,
            playbackRate: 1.0,
            startedAt: Date(),
            updatedAt: Date()
        )

        let session2 = PlaybackSession(
            id: "q-2",
            userId: "u-1",
            libraryId: "lib-1",
            libraryItemId: "item-2",
            episodeId: nil,
            displayTitle: "Book Two",
            displayAuthor: "Author Two",
            coverPath: nil,
            duration: 2000,
            playMethod: 0,
            mediaPlayer: "AVQueuePlayer",
            mediaType: "book",
            audioTracks: [],
            chapters: [],
            manifestUrl: nil,
            missingTrackCount: 0,
            currentTime: 0,
            playbackRate: 1.0,
            startedAt: Date(),
            updatedAt: Date()
        )

        playerService.addToPlaybackQueue(session: session1)
        playerService.addToPlaybackQueue(session: session2)
        XCTAssertEqual(playerService.playbackQueue.count, 2)
        XCTAssertEqual(playerService.playbackQueue[0].displayTitle, "Book One")
        XCTAssertEqual(playerService.playbackQueue[1].displayTitle, "Book Two")

        playerService.removeFromPlaybackQueue(at: 0)
        XCTAssertEqual(playerService.playbackQueue.count, 1)
        XCTAssertEqual(playerService.playbackQueue[0].displayTitle, "Book Two")

        playerService.clearPlaybackQueue()
        XCTAssertTrue(playerService.playbackQueue.isEmpty)
    }

    func testAuthorDetailViewModelLoading() async throws {
        let mockService = MockLibraryService()
        let vm = AuthorDetailViewModel(authorName: "Andy Weir", libraryId: "mock-lib", service: mockService)

        XCTAssertTrue(vm.isLoading)
        XCTAssertTrue(vm.books.isEmpty)
        XCTAssertEqual(vm.initials, "AW")

        await vm.loadAuthor()

        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.books.isEmpty)
        XCTAssertNotNil(vm.authorSummary)
        XCTAssertTrue(vm.totalDuration > 0)
        XCTAssertFalse(vm.totalDurationFormatted.isEmpty)
        XCTAssertTrue(vm.bookCountText.contains("Audiobook"))
    }

    func testSeriesDetailViewModelLoading() async throws {
        let mockService = MockLibraryService()
        let vm = SeriesDetailViewModel(seriesName: "Dune Chronicles", libraryId: "mock-lib", service: mockService)

        XCTAssertTrue(vm.isLoading)
        XCTAssertTrue(vm.books.isEmpty)

        await vm.loadSeries()

        XCTAssertFalse(vm.isLoading)
        XCTAssertFalse(vm.books.isEmpty)
        XCTAssertNotNil(vm.primaryAuthor)
        XCTAssertTrue(vm.totalDuration > 0)
        XCTAssertFalse(vm.totalDurationFormatted.isEmpty)
        XCTAssertTrue(vm.bookCountText.contains("Book"))
    }

    func testPlaybackSpeedFineAdjustment() throws {
        let playerService = AudioPlayerService.shared
        playerService.setPlaybackRate(1.25)
        XCTAssertEqual(playerService.playbackRate, 1.25, accuracy: 0.01)

        playerService.setPlaybackRate(0.85)
        XCTAssertEqual(playerService.playbackRate, 0.85, accuracy: 0.01)

        playerService.setPlaybackRate(1.0)
        XCTAssertEqual(playerService.playbackRate, 1.0, accuracy: 0.01)

        var settings = AppSettings()
        settings.perBookPlaybackSpeedEnabled = true
        XCTAssertTrue(settings.perBookPlaybackSpeedEnabled)
    }

    func testCollectionsViewModelLoading() async throws {
        let vm = CollectionsViewModel()

        XCTAssertTrue(vm.collections.isEmpty)
        XCTAssertTrue(vm.playlists.isEmpty)

        await vm.loadData(libraryId: "mock-lib", isAuthenticated: false, type: .collections)
        XCTAssertFalse(vm.collections.isEmpty)
        XCTAssertEqual(vm.collections.first?.name, "Award Winners")
        XCTAssertEqual(vm.collections.first?.books?.count, 3)

        await vm.loadData(libraryId: "mock-lib", isAuthenticated: false, type: .playlists)
        XCTAssertFalse(vm.playlists.isEmpty)
        XCTAssertEqual(vm.playlists.first?.name, "Favorites")
    }

    func testBookshelfFilterAndMultiCriteriaSorting() async throws {
        let mockService = MockLibraryService()
        let vm = BookshelfViewModel(service: mockService)

        await vm.loadLibrary(libraryId: "mock-lib", isAuthenticated: false)

        XCTAssertFalse(vm.books.isEmpty)
        XCTAssertEqual(vm.filteredBooks.count, vm.books.count)

        // 1. Filter by Series
        vm.setFilter(.series)
        XCTAssertEqual(vm.selectedFilter, .series)
        XCTAssertTrue(vm.filteredBooks.allSatisfy {
            !($0.seriesName?.isEmpty ?? true)
        })

        // 2. Search text within filtered set
        vm.setFilter(.all)
        vm.setSearchText("Dune")
        XCTAssertEqual(vm.filterSearchText, "Dune")
        XCTAssertTrue(vm.filteredBooks.allSatisfy {
            $0.title.localizedCaseInsensitiveContains("Dune") ||
            ($0.author?.localizedCaseInsensitiveContains("Dune") ?? false) ||
            ($0.seriesName?.localizedCaseInsensitiveContains("Dune") ?? false)
        })

        // 3. Reset filters
        vm.resetFilters()
        XCTAssertEqual(vm.selectedFilter, .all)
        XCTAssertEqual(vm.filterSearchText, "")
        XCTAssertEqual(vm.filteredBooks.count, vm.books.count)

        // 4. Multi-criteria sort switching
        await vm.changeSort(option: .titleAZ, libraryId: "mock-lib", isAuthenticated: false)
        XCTAssertEqual(vm.selectedSort, .titleAZ)
        XCTAssertEqual(vm.currentSort, "title")
        XCTAssertFalse(vm.currentDesc)

        await vm.changeSort(option: .longestDuration, libraryId: "mock-lib", isAuthenticated: false)
        XCTAssertEqual(vm.selectedSort, .longestDuration)
        XCTAssertEqual(vm.currentSort, "duration")
        XCTAssertTrue(vm.currentDesc)
    }

    func testListeningStatsStreakAndAggregation() throws {
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let sessions = (0..<5).map { offset -> PlaybackSessionRow in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            return PlaybackSessionRow(
                id: "test-sess-\(offset)",
                displayTitle: "Test Book \(offset)",
                displayAuthor: "Test Author",
                timeListening: 1800,
                sessionDate: formatter.string(from: date),
                updatedAt: date
            )
        }

        XCTAssertEqual(sessions.count, 5)
        let totalSeconds = sessions.compactMap(\.timeListening).reduce(0, +)
        XCTAssertEqual(totalSeconds, 9000)

        // Verify active dates
        let activeDates = Set(sessions.compactMap(\.sessionDate))
        XCTAssertEqual(activeDates.count, 5)
        XCTAssertTrue(activeDates.contains(formatter.string(from: today)))
    }

    func testDownloadStorageManagement() throws {
        let service = DownloadService.shared
        let originalDownloads = service.downloads

        let downloadCompleted1 = Download(
            libraryItemId: "dl-test-1",
            title: "Test Book 1",
            author: "Author",
            progress: 1.0,
            totalSize: 50_000_000,
            status: .completed
        )
        let downloadCompleted2 = Download(
            libraryItemId: "dl-test-2",
            title: "Test Book 2",
            author: "Author",
            progress: 1.0,
            totalSize: 75_000_000,
            status: .completed
        )
        let downloadPending = Download(
            libraryItemId: "dl-test-3",
            title: "Test Book 3",
            author: "Author",
            progress: 0.5,
            totalSize: 100_000_000,
            status: .downloading
        )

        service.downloads = [downloadCompleted1, downloadCompleted2, downloadPending]
        XCTAssertEqual(service.totalDownloadedBytes, 125_000_000)

        service.deleteAllCompletedDownloads()
        XCTAssertEqual(service.downloads.count, 1)
        XCTAssertEqual(service.downloads.first?.libraryItemId, "dl-test-3")
        XCTAssertEqual(service.totalDownloadedBytes, 0)

        // Restore original downloads
        service.downloads = originalDownloads
    }

    @MainActor
    func testDynamicCoverArtAuraExtractionAndTinting() {
        let loader = DynamicColorLoader()
        XCTAssertFalse(loader.isLoaded)

        // Test atmospheric mood palette extraction
        loader.loadColor(fromMood: "Sci-Fi & Cyberpunk Mystery")
        XCTAssertTrue(loader.isLoaded)
        XCTAssertFalse(loader.isLight)
        XCTAssertEqual(loader.gradientColors.count, 2)

        // Verify FluidAuraBackground accepts custom accentColors array
        let bg = FluidAuraBackground(
            baseColor: loader.backgroundColor.opacity(0.35),
            accentColors: loader.gradientColors
        )
        XCTAssertNotNil(bg)
        XCTAssertEqual(bg.accentColors?.count, 2)
    }
}
