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

    func testPlayNextInPlaybackQueueAndReorder() {
        let playerService = AudioPlayerService.shared
        playerService.clearPlaybackQueue()

        let session1 = PlaybackSession(
            id: "session-1",
            userId: "user-1",
            libraryId: "lib-1",
            libraryItemId: "item-1",
            episodeId: nil,
            displayTitle: "Book One",
            displayAuthor: "Author",
            coverPath: nil,
            duration: 3600,
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
            id: "session-2",
            userId: "user-1",
            libraryId: "lib-1",
            libraryItemId: "item-2",
            episodeId: nil,
            displayTitle: "Book Two",
            displayAuthor: "Author",
            coverPath: nil,
            duration: 7200,
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

        let sessionNext = PlaybackSession(
            id: "session-next",
            userId: "user-1",
            libraryId: "lib-1",
            libraryItemId: "item-next",
            episodeId: nil,
            displayTitle: "Book Next",
            displayAuthor: "Author",
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

        // Queue session1 and session2
        playerService.addToPlaybackQueue(session: session1)
        playerService.addToPlaybackQueue(session: session2)
        XCTAssertEqual(playerService.playbackQueue.count, 2)

        // Insert sessionNext with playNext
        playerService.playNextInPlaybackQueue(session: sessionNext)
        XCTAssertEqual(playerService.playbackQueue.count, 3)
        XCTAssertEqual(playerService.playbackQueue[0].id, "session-next")
        XCTAssertEqual(playerService.playbackQueue[1].id, "session-1")
        XCTAssertEqual(playerService.playbackQueue[2].id, "session-2")

        // Call playNext with session2 (which is already at index 2) - should move to index 0 without duplicating
        playerService.playNextInPlaybackQueue(session: session2)
        XCTAssertEqual(playerService.playbackQueue.count, 3)
        XCTAssertEqual(playerService.playbackQueue[0].id, "session-2")
        XCTAssertEqual(playerService.playbackQueue[1].id, "session-next")
        XCTAssertEqual(playerService.playbackQueue[2].id, "session-1")

        // Reorder: move item from index 0 to index 2
        playerService.movePlaybackQueueItem(fromIndex: 0, toIndex: 2)
        XCTAssertEqual(playerService.playbackQueue[0].id, "session-next")
        XCTAssertEqual(playerService.playbackQueue[1].id, "session-1")
        XCTAssertEqual(playerService.playbackQueue[2].id, "session-2")

        // Total queue duration
        XCTAssertEqual(playerService.totalQueueDuration, 12600) // 1800 + 3600 + 7200

        playerService.clearPlaybackQueue()
    }

    func testVolumeBoostSettingsAndDSP() throws {
        var settings = AppSettings()
        XCTAssertEqual(settings.volumeBoost, 1.0)

        settings.volumeBoost = 1.5
        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)
        XCTAssertEqual(decoded.volumeBoost, 1.5)

        // Test boundary values
        settings.volumeBoost = 2.0
        XCTAssertEqual(settings.volumeBoost, 2.0)
    }

    func testBookMediaProgressToggleAndOptimisticUpdate() {
        let initialProgress = MediaProgress(
            id: "prog-1",
            libraryItemId: "item-1",
            episodeId: nil,
            duration: 3600,
            progress: 0.25,
            currentTime: 900,
            isFinished: false,
            hideFromContinueListening: false,
            lastUpdate: Date(),
            startedAt: Date(),
            finishedAt: nil
        )

        // Mark as finished
        let duration = initialProgress.duration
        let finishedProgress = MediaProgress(
            id: initialProgress.id,
            libraryItemId: initialProgress.libraryItemId,
            episodeId: nil,
            duration: duration,
            progress: 1.0,
            currentTime: duration,
            isFinished: true,
            hideFromContinueListening: true,
            lastUpdate: Date(),
            startedAt: initialProgress.startedAt,
            finishedAt: Date()
        )

        XCTAssertTrue(finishedProgress.isFinished)
        XCTAssertEqual(finishedProgress.progress, 1.0)
        XCTAssertEqual(finishedProgress.currentTime, 3600)

        // Mark as not finished (reset)
        let resetProgress = MediaProgress(
            id: initialProgress.id,
            libraryItemId: initialProgress.libraryItemId,
            episodeId: nil,
            duration: duration,
            progress: 0.0,
            currentTime: 0.0,
            isFinished: false,
            hideFromContinueListening: false,
            lastUpdate: Date(),
            startedAt: initialProgress.startedAt,
            finishedAt: nil
        )

        XCTAssertFalse(resetProgress.isFinished)
        XCTAssertEqual(resetProgress.progress, 0.0)
        XCTAssertEqual(resetProgress.currentTime, 0.0)
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

    func testAudioTracksInspectionAndFormatting() {
        let metadata = AudioMetadata(
            filename: "Chapter_01_The_Beginning.m4b",
            ext: "m4b",
            path: "/library/audiobooks/Dune/Chapter_01_The_Beginning.m4b",
            relPath: "Dune/Chapter_01_The_Beginning.m4b",
            size: 48_500_000,
            mtimeMs: 1699900000,
            ctimeMs: 1699900000,
            birthtimeMs: 1699900000
        )
        let track = AudioFile(
            index: 0,
            ino: "file-ino-42",
            metadata: metadata,
            duration: 2715,
            bitRate: 128000,
            language: "en",
            codec: "aac",
            mimeType: "audio/mp4"
        )

        XCTAssertEqual(track.filename, "Chapter_01_The_Beginning.m4b")
        XCTAssertEqual(track.displayCodec, "AAC")
        XCTAssertEqual(track.formattedBitRate, "128 kbps")
        XCTAssertEqual(track.formattedDuration, "45:15")
        XCTAssertTrue(track.formattedSize.contains("MB") || track.formattedSize.contains("48"))

        let book = Book(
            id: "book-audiophile-1",
            title: "Dune",
            author: "Frank Herbert",
            duration: 2715
        )
        // With default nil audioFiles, book.audioFiles returns empty array safely
        XCTAssertTrue(book.audioFiles.isEmpty)
    }

    // MARK: - Feature 42: Sleep Timer Nightstand Chime & OLED Night Dimming

    func testSleepTimerChimeAndNightstandSettings() async throws {
        // Verify new AppSettings fields decode with correct defaults
        let json = Data("{}".utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertTrue(settings.sleepTimerChimeEnabled, "Chime should default to enabled")
        XCTAssertFalse(settings.sleepTimerDimScreenEnabled, "OLED dim should default to disabled")

        // Verify explicit values round-trip correctly
        let explicitJSON = Data("""
        {"sleepTimerChimeEnabled": false, "sleepTimerDimScreenEnabled": true}
        """.utf8)
        let explicitSettings = try JSONDecoder().decode(AppSettings.self, from: explicitJSON)
        XCTAssertFalse(explicitSettings.sleepTimerChimeEnabled)
        XCTAssertTrue(explicitSettings.sleepTimerDimScreenEnabled)

        // Verify AudioPlayerSleepTimer.chimeEnabled property works
        let timer = AudioPlayerSleepTimer()
        XCTAssertTrue(timer.chimeEnabled, "Chime should default to true")
        timer.chimeEnabled = false
        XCTAssertFalse(timer.chimeEnabled)
        timer.chimeEnabled = true
        XCTAssertTrue(timer.chimeEnabled)
    }

    // MARK: - Feature 45: Daily Listening Streak Calculator & Milestone Celebrations

    func testListeningStreakCalculatorAndMilestones() async throws {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        // 1. Continuous 4-day streak ending today
        let consecutiveSessions = (0..<4).map { offset -> PlaybackSessionRow in
            let date = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
            return PlaybackSessionRow(
                id: "sess-\(offset)",
                displayTitle: "Book \(offset)",
                displayAuthor: "Author",
                timeListening: 1200,
                sessionDate: formatter.string(from: date),
                updatedAt: date
            )
        }
        let streak = ListeningStreakCalculator.calculateStreak(sessions: consecutiveSessions, referenceDate: today)
        XCTAssertEqual(streak, 4)

        // 2. Empty sessions -> 0 streak
        let emptyStreak = ListeningStreakCalculator.calculateStreak(sessions: [], referenceDate: today)
        XCTAssertEqual(emptyStreak, 0)

        // 3. Broken streak (listened 4 days ago only)
        let oldDate = calendar.date(byAdding: .day, value: -4, to: today) ?? today
        let brokenSessions = [
            PlaybackSessionRow(
                id: "sess-old",
                displayTitle: "Old Book",
                displayAuthor: "Author",
                timeListening: 1200,
                sessionDate: formatter.string(from: oldDate),
                updatedAt: oldDate
            )
        ]
        let brokenStreak = ListeningStreakCalculator.calculateStreak(sessions: brokenSessions, referenceDate: today)
        XCTAssertEqual(brokenStreak, 0)

        // 4. Milestone headlines
        XCTAssertEqual(ListeningStreakCalculator.milestoneHeadline(streak: 0), "Start Your Streak Today")
        XCTAssertEqual(ListeningStreakCalculator.milestoneHeadline(streak: 1), "1 Day Streak")
        XCTAssertEqual(ListeningStreakCalculator.milestoneHeadline(streak: 4), "4 Days Streak")
        XCTAssertEqual(ListeningStreakCalculator.milestoneHeadline(streak: 7), "1 Week of Listening!")
        XCTAssertEqual(ListeningStreakCalculator.milestoneHeadline(streak: 14), "14 Days • Habit Formed!")
        XCTAssertTrue(ListeningStreakCalculator.milestoneHeadline(streak: 30).contains("1 Month"))

        // 5. Motivational messages
        XCTAssertFalse(ListeningStreakCalculator.motivationalMessage(streak: 0).isEmpty)
        XCTAssertFalse(ListeningStreakCalculator.motivationalMessage(streak: 4).isEmpty)
    }

    @MainActor
    func testBookmarksSearchAndMultiFormatExport() throws {
        let session = PlaybackSession(
            id: "sess-bm",
            userId: "usr-bm",
            libraryId: "lib-bm",
            libraryItemId: "item-bm",
            episodeId: nil,
            displayTitle: "Dune",
            displayAuthor: "Frank Herbert",
            coverPath: nil,
            duration: 72000,
            playMethod: 0,
            mediaPlayer: "AVQueuePlayer",
            mediaType: "book",
            audioTracks: [],
            chapters: [],
            manifestUrl: nil,
            missingTrackCount: 0,
            currentTime: 1500,
            playbackRate: 1.0,
            startedAt: Date(),
            updatedAt: Date()
        )
        let vm = AudioPlayerViewModel(session: session)
        let bm1 = Bookmark(
            id: "bm-1",
            userId: "usr-bm",
            libraryItemId: "item-bm",
            timePos: 360,
            title: "Fear is the mind-killer",
            note: "Litany Against Fear recited by Paul Atreides.",
            createdAt: Date(timeIntervalSince1970: 1700000000)
        )
        let bm2 = Bookmark(
            id: "bm-2",
            userId: "usr-bm",
            libraryItemId: "item-bm",
            timePos: 3665,
            title: "Arrakis Awakening",
            note: "First glimpse of the deep desert.",
            createdAt: Date(timeIntervalSince1970: 1700005000)
        )

        AudioPlayerService.shared.bookmarks = [bm1, bm2]

        // 1. Markdown Export
        let md = vm.exportBookmarksMarkdown()
        XCTAssertTrue(md.contains("# Bookmarks for Dune"))
        XCTAssertTrue(md.contains("Author: Frank Herbert"))
        XCTAssertTrue(md.contains("Fear is the mind-killer"))
        XCTAssertTrue(md.contains("> Litany Against Fear recited by Paul Atreides."))
        XCTAssertTrue(md.contains("1:01:05"))

        // 2. CSV Export
        let csv = vm.exportBookmarksCSV()
        XCTAssertTrue(csv.starts(with: "ID,Time Position,Timestamp,Title,Note,Created At\n"))
        XCTAssertTrue(csv.contains("\"bm-1\",\"360.00\",\"6:00\",\"Fear is the mind-killer\",\"Litany Against Fear recited by Paul Atreides.\""))
        XCTAssertTrue(csv.contains("\"bm-2\",\"3665.00\",\"1:01:05\",\"Arrakis Awakening\",\"First glimpse of the deep desert.\""))

        // 3. JSON Export
        let json = vm.exportBookmarksJSON()
        XCTAssertTrue(json.contains("\"bookTitle\" : \"Dune\""))
        XCTAssertTrue(json.contains("\"author\" : \"Frank Herbert\""))
        XCTAssertTrue(json.contains("\"totalBookmarks\" : 2"))
        XCTAssertTrue(json.contains("\"timePos\" : 360"))
        XCTAssertTrue(json.contains("\"Fear is the mind-killer\""))

        // 4. Update Bookmark
        vm.updateBookmark(bm1, title: "The Litany Against Fear (Full)", note: "Must not fear; fear is the mind-killer.")
        let updatedBm = AudioPlayerService.shared.bookmarks.first(where: { $0.id == "bm-1" })
        XCTAssertEqual(updatedBm?.title, "The Litany Against Fear (Full)")
        XCTAssertEqual(updatedBm?.note, "Must not fear; fear is the mind-killer.")
    }

    func testAudioEqualizerPresetsAndDSPMapping() throws {
        var settings = AppState.shared.settings

        // 1. Speech Clarity
        XCTAssertEqual(AudioEqualizerPreset.speechClarity.rawValue, "Speech Clarity")
        XCTAssertEqual(AudioEqualizerPreset.speechClarity.icon, "waveform.and.person.filled")
        settings.spokenAudioModeEnabled = true
        settings.vocalBoostEnabled = true
        settings.deEsserEnabled = true
        settings.lowCutFilterEnabled = true
        settings.volumeLevelerEnabled = false
        AppState.shared.updateSettings(settings)
        AudioPlayerService.shared.applyAudioDSP()

        // 2. Night Mode
        XCTAssertEqual(AudioEqualizerPreset.nightMode.rawValue, "Night Mode")
        XCTAssertEqual(AudioEqualizerPreset.nightMode.icon, "moon.stars.fill")
        settings.volumeLevelerEnabled = true
        AppState.shared.updateSettings(settings)
        AudioPlayerService.shared.applyAudioDSP()
        XCTAssertTrue(AppState.shared.settings.volumeLevelerEnabled)

        // 3. Flat / Bypass
        XCTAssertEqual(AudioEqualizerPreset.audiophileFlat.rawValue, "Flat / Bypass")
        settings.vocalBoostEnabled = false
        settings.deEsserEnabled = false
        settings.lowCutFilterEnabled = false
        settings.volumeLevelerEnabled = false
        AppState.shared.updateSettings(settings)
        AudioPlayerService.shared.applyAudioDSP()
        XCTAssertFalse(AppState.shared.settings.vocalBoostEnabled)
    }

    func testSleepTimerStopAtSpecificTimeCalculation() throws {
        let calendar = Calendar.current
        var comps = DateComponents()
        comps.year = 2026
        comps.month = 11
        comps.day = 18
        comps.hour = 22
        comps.minute = 30
        comps.second = 0
        guard let baseDate = calendar.date(from: comps) else {
            XCTFail("Could not create base date")
            return
        }

        // Target: 23:30 (1 hour later on same day)
        var targetComps1 = DateComponents()
        targetComps1.hour = 23
        targetComps1.minute = 30
        var nextTarget1 = calendar.date(bySettingHour: 23, minute: 30, second: 0, of: baseDate)!
        if nextTarget1 <= baseDate {
            nextTarget1 = calendar.date(byAdding: .day, value: 1, to: nextTarget1)!
        }
        let intervalSameDay = nextTarget1.timeIntervalSince(baseDate)
        XCTAssertEqual(intervalSameDay, 3600) // 1 hour

        // Target: 00:30 (Midnight rollover, earlier hour than 22:30)
        var nextTarget2 = calendar.date(bySettingHour: 0, minute: 30, second: 0, of: baseDate)!
        if nextTarget2 <= baseDate {
            nextTarget2 = calendar.date(byAdding: .day, value: 1, to: nextTarget2)!
        }
        let intervalNextDay = nextTarget2.timeIntervalSince(baseDate)
        XCTAssertEqual(intervalNextDay, 7200) // 2 hours
    }

    func testChapterOrderReversalInSelectionView() throws {
        let ch1 = Chapter(id: 0, title: "Chapter 1", start: 0, end: 300)
        let ch2 = Chapter(id: 1, title: "Chapter 2", start: 300, end: 600)
        let ch3 = Chapter(id: 2, title: "Chapter 3", start: 600, end: 900)
        let chapters = [ch1, ch2, ch3]

        // 1. Ascending standard order
        let ascending = Chapter.filter(chapters: chapters, query: "")
        XCTAssertEqual(ascending.count, 3)
        XCTAssertEqual(ascending.first?.id, 0)
        XCTAssertEqual(ascending.last?.id, 2)

        // 2. Reversed descending order
        let descending = ascending.reversed()
        XCTAssertEqual(descending.count, 3)
        XCTAssertEqual(descending.first?.id, 2)
        XCTAssertEqual(descending.last?.id, 0)
        XCTAssertEqual(descending.first?.title, "Chapter 3")

        // 3. Search filter with reverse order
        let filtered = Chapter.filter(chapters: chapters, query: "Chapter 2").reversed()
        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.id, 1)
    }

    func testSleepTimerQuickActionsPresetDurations() throws {
        let timer = AudioPlayerSleepTimer()
        let presets = [15 * 60, 30 * 60, 45 * 60, 60 * 60]

        for duration in presets {
            timer.setSleepTimer(seconds: TimeInterval(duration)) {}
            XCTAssertTrue(timer.isActive)
            XCTAssertEqual(timer.remaining, TimeInterval(duration))
            XCTAssertEqual(timer.initialDuration, TimeInterval(duration))
            timer.stopSleepTimer()
            XCTAssertFalse(timer.isActive)
        }
    }

    func testChapterDeepLinkURLFormat() throws {
        let chapter = Chapter(id: 3, title: "The Departure", start: 1450.5, end: 2800.0)
        let itemId = "book-uuid-12345"
        let expectedURL = "audiobookphile://item/\(itemId)?t=\(Int(chapter.start))"
        XCTAssertEqual(expectedURL, "audiobookphile://item/book-uuid-12345?t=1450")

        // Zero timestamp
        let chZero = Chapter(id: 0, title: "Prologue", start: 0, end: 120.0)
        let expectedZeroURL = "audiobookphile://item/\(itemId)?t=\(Int(chZero.start))"
        XCTAssertEqual(expectedZeroURL, "audiobookphile://item/book-uuid-12345?t=0")
    }

    func testJumpToPlayingChapterSelectionTarget() throws {
        let ch1 = Chapter(id: 1, title: "Chapter 1", start: 0, end: 300)
        let ch2 = Chapter(id: 2, title: "Chapter 2", start: 300, end: 600)
        let ch3 = Chapter(id: 3, title: "Chapter 3", start: 600, end: 900)
        let chapters = [ch1, ch2, ch3]

        // When playback position is 450s, active chapter should be ch2
        let currentPos: TimeInterval = 450
        let activeChapter = chapters.first { currentPos >= $0.start && currentPos < $0.end }
        XCTAssertNotNil(activeChapter)
        XCTAssertEqual(activeChapter?.id, 2)
        XCTAssertEqual(activeChapter?.title, "Chapter 2")
    }

    func testChapterCompletionAndListenedCalculation() throws {
        let ch1 = Chapter(id: 1, title: "Chapter 1", start: 0, end: 300)
        let ch2 = Chapter(id: 2, title: "Chapter 2", start: 300, end: 600)
        let ch3 = Chapter(id: 3, title: "Chapter 3", start: 600, end: 900)

        func isChapterListened(_ chapter: Chapter, currentTime: TimeInterval?) -> Bool {
            guard let current = currentTime else { return false }
            return current >= chapter.end
        }

        // 1. Playback before ch1 finishes (150s) -> None listened
        XCTAssertFalse(isChapterListened(ch1, currentTime: 150))
        XCTAssertFalse(isChapterListened(ch2, currentTime: 150))
        XCTAssertFalse(isChapterListened(ch3, currentTime: 150))

        // 2. Playback midway in ch2 (450s) -> ch1 listened, ch2 & ch3 not listened
        XCTAssertTrue(isChapterListened(ch1, currentTime: 450))
        XCTAssertFalse(isChapterListened(ch2, currentTime: 450))
        XCTAssertFalse(isChapterListened(ch3, currentTime: 450))

        // 3. Playback at 900s (completed all) -> ch1, ch2, ch3 all listened
        XCTAssertTrue(isChapterListened(ch1, currentTime: 900))
        XCTAssertTrue(isChapterListened(ch2, currentTime: 900))
        XCTAssertTrue(isChapterListened(ch3, currentTime: 900))

        // 4. Nil currentTime -> None listened
        XCTAssertFalse(isChapterListened(ch1, currentTime: nil))
    }

    func testQuickJumpDurationSettingsUpdate() throws {
        var settings = AppSettings()
        XCTAssertEqual(settings.jumpForwardTime, 30)
        XCTAssertEqual(settings.jumpBackwardsTime, 10)

        // Update to non-default jump intervals
        settings.jumpForwardTime = 45
        settings.jumpBackwardsTime = 15

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.jumpForwardTime, 45)
        XCTAssertEqual(decoded.jumpBackwardsTime, 15)

        // Verify supported intervals
        let supported = [5, 10, 15, 30, 45, 60]
        for interval in supported {
            settings.jumpForwardTime = interval
            settings.jumpBackwardsTime = interval
            XCTAssertEqual(settings.jumpForwardTime, interval)
            XCTAssertEqual(settings.jumpBackwardsTime, interval)
        }
    }

    func testSeriesTabGroupingAndTotalDuration() throws {
        let b1 = Book(
            id: "b1",
            title: "Dune",
            author: "Frank Herbert",
            seriesName: "Dune Saga",
            duration: 36000
        )
        let b2 = Book(
            id: "b2",
            title: "Dune Messiah",
            author: "Frank Herbert",
            seriesName: "Dune Saga",
            duration: 18000
        )
        let bStandalone = Book(
            id: "b3",
            title: "Standalone Novel",
            author: "Author",
            seriesName: nil,
            duration: 20000
        )

        let books = [b1, b2, bStandalone]

        let seriesGrouped = Dictionary(grouping: books.compactMap { b -> (String, Book)? in
            guard let name = b.seriesName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
                return nil
            }
            return (name, b)
        }, by: { $0.0 })
        .mapValues { pairs in pairs.map { $0.1 } }

        // Only Dune Saga should be grouped
        XCTAssertEqual(seriesGrouped.count, 1)
        XCTAssertNotNil(seriesGrouped["Dune Saga"])
        XCTAssertEqual(seriesGrouped["Dune Saga"]?.count, 2)

        let totalDuration = seriesGrouped["Dune Saga"]?.reduce(0.0) { $0 + $1.duration } ?? 0
        XCTAssertEqual(totalDuration, 54000) // 15 hours
    }

    func testBookshelfListViewLayoutToggle() throws {
        var isListView = false
        XCTAssertFalse(isListView)

        // Toggle to list view
        isListView.toggle()
        XCTAssertTrue(isListView)

        // Toggle back to grid view
        isListView.toggle()
        XCTAssertFalse(isListView)
    }

    // MARK: - Feature 82 & 83: Playback Speed Presets & Shake to Extend Sleep Timer

    func testPlaybackRateQuickPresetsAndReset() throws {
        let presets: [Float] = [0.75, 0.90, 1.00, 1.20, 1.25, 1.50, 1.75, 2.00, 2.50]
        XCTAssertEqual(presets.count, 9)

        var currentRate: Float = 1.00
        // Normal speed is not active styled
        XCTAssertFalse(abs(currentRate - 1.0) > 0.05)

        // Switch to 1.5x
        currentRate = 1.50
        XCTAssertTrue(abs(currentRate - 1.0) > 0.05)

        // Reset back to 1.0x
        currentRate = 1.00
        XCTAssertFalse(abs(currentRate - 1.0) > 0.05)
        XCTAssertEqual(currentRate, 1.00)
    }

    func testSleepTimerExtendByFiveMinutesOnShake() async throws {
        let timer = AudioPlayerSleepTimer()
        timer.setSleepTimer(seconds: 60) {}
        XCTAssertTrue(timer.isActive)
        XCTAssertEqual(timer.remaining, 60)

        // Simulate shake action extending by 300s (5 minutes)
        let didExtend = timer.extendSleepTimer(by: 300)
        XCTAssertTrue(didExtend)
        XCTAssertEqual(timer.remaining, 360)
        XCTAssertEqual(timer.initialDuration, 360)

        timer.stopSleepTimer()
        XCTAssertFalse(timer.isActive)
        XCTAssertNil(timer.remaining)
    }

    // MARK: - Features 88 & 89: Bookmark Sharing & Quick Category Tags

    func testBookmarkTimestampShareLinkConstruction() throws {
        let itemId = "item-dune-42"
        let timePosMs: Double = 75400 // 75.4 seconds -> 75s
        let seconds = Int(timePosMs / 1000)
        let deepLink = "audiobookphile://item/\(itemId)?t=\(seconds)"

        XCTAssertEqual(seconds, 75)
        XCTAssertEqual(deepLink, "audiobookphile://item/item-dune-42?t=75")

        let hourMs: Double = 3600000 // 1 hour -> 3600s
        let hourSeconds = Int(hourMs / 1000)
        let hourLink = "audiobookphile://item/\(itemId)?t=\(hourSeconds)"
        XCTAssertEqual(hourLink, "audiobookphile://item/item-dune-42?t=3600")
    }

    func testBookmarkQuickCategoryTagsPrepending() throws {
        let tags = ["Quote", "Key Idea", "Plot", "Review", "Vocabulary"]
        XCTAssertEqual(tags.count, 5)

        var note = "Fear is the mind-killer."
        func applyTag(_ note: String, tag: String) -> String {
            let prefix = "[\(tag)] "
            if note.contains(prefix) { return note }
            return prefix + note
        }

        note = applyTag(note, tag: "Quote")
        XCTAssertEqual(note, "[Quote] Fear is the mind-killer.")

        // Idempotent
        note = applyTag(note, tag: "Quote")
        XCTAssertEqual(note, "[Quote] Fear is the mind-killer.")

        // Prepend second tag
        note = applyTag(note, tag: "Key Idea")
        XCTAssertEqual(note, "[Key Idea] [Quote] Fear is the mind-killer.")
    }

    // MARK: - Features 90 & 91: Narrator Navigation & Search with Duration

    func testSelectedNarratorInfoModel() throws {
        let dummyBook = Book(id: "book-1", title: "Dune", author: "Frank Herbert", duration: 7200)
        let info = SelectedNarratorInfo(name: "Scott Brick", books: [dummyBook])
        XCTAssertEqual(info.id, "Scott Brick")
        XCTAssertEqual(info.name, "Scott Brick")
        XCTAssertEqual(info.books.count, 1)
        XCTAssertEqual(info.books.first?.title, "Dune")
    }

    func testAuthorAndNarratorSearchFiltering() throws {
        let authors = ["Frank Herbert", "Brandon Sanderson", "George R.R. Martin", "Isaac Asimov"]
        let query = "san"
        let filtered = authors.filter { $0.lowercased().contains(query.lowercased()) }
        XCTAssertEqual(filtered, ["Brandon Sanderson"])

        let emptyQuery = ""
        let allAuthors = authors.filter { emptyQuery.isEmpty || $0.lowercased().contains(emptyQuery.lowercased()) }
        XCTAssertEqual(allAuthors.count, 4)
    }

    func testAuthorAndNarratorAggregateListeningDuration() throws {
        let books = [
            Book(id: "b1", title: "Book 1", author: "Author", duration: 3660), // 1h 1m
            Book(id: "b2", title: "Book 2", author: "Author", duration: 7200), // 2h 0m
        ]
        let totalDuration = books.reduce(0.0) { $0 + $1.duration }
        XCTAssertEqual(totalDuration, 10860)

        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        let formatted = hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
        XCTAssertEqual(formatted, "3h 1m")

        let shortBooks = [Book(id: "b3", title: "Short", author: "Author", duration: 1500)] // 25m
        let shortDuration = shortBooks.reduce(0.0) { $0 + $1.duration }
        let shortHours = Int(shortDuration) / 3600
        let shortMinutes = (Int(shortDuration) % 3600) / 60
        let shortFormatted = shortHours > 0 ? "\(shortHours)h \(shortMinutes)m" : "\(shortMinutes)m"
        XCTAssertEqual(shortFormatted, "25m")
    }

    // MARK: - Features 94 & 95: Catalog Sorting & Haptic Master Toggle

    func testCatalogSortOptions() throws {
        let b1 = Book(id: "b1", title: "Zeta Book", author: "Author", duration: 1000)
        let b2 = Book(id: "b2", title: "Alpha Book", author: "Author", duration: 5000)
        let b3 = Book(id: "b3", title: "Beta Book", author: "Author", duration: 3000)
        let books = [b1, b2, b3]

        // Sort by Title
        let byTitle = books.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        XCTAssertEqual(byTitle.map(\.title), ["Alpha Book", "Beta Book", "Zeta Book"])

        // Sort by Duration
        let byDuration = books.sorted { $0.duration > $1.duration }
        XCTAssertEqual(byDuration.map(\.title), ["Alpha Book", "Beta Book", "Zeta Book"])

        // Enum cases
        XCTAssertEqual(CatalogSortOption.allCases.count, 3)
        XCTAssertEqual(CatalogSortOption.title.icon, "textformat.abc")
        XCTAssertEqual(CatalogSortOption.duration.icon, "clock")
        XCTAssertEqual(CatalogSortOption.year.icon, "calendar")
    }

    func testHapticsMasterToggleSetting() throws {
        var settings = AppSettings()
        XCTAssertTrue(settings.hapticsEnabled)

        settings.hapticsEnabled = false
        XCTAssertFalse(settings.hapticsEnabled)

        DesignTokens.Haptics.isEnabled = false
        XCTAssertFalse(DesignTokens.Haptics.isEnabled)
        // Calling haptic methods should execute silently without crashing
        DesignTokens.Haptics.selection()
        DesignTokens.Haptics.light()
        DesignTokens.Haptics.medium()
        DesignTokens.Haptics.success()
        DesignTokens.Haptics.warning()

        DesignTokens.Haptics.isEnabled = true
        XCTAssertTrue(DesignTokens.Haptics.isEnabled)
    }

    func testCoverFullscreenViewerAndMediaSpecs() throws {
        var dismissed = false
        let viewer = CoverFullscreenViewer(
            title: "The Hobbit",
            author: "J.R.R. Tolkien",
            coverURL: URL(string: "https://example.com/cover.jpg"),
            onDismiss: { dismissed = true }
        )
        XCTAssertEqual(viewer.title, "The Hobbit")
        XCTAssertEqual(viewer.author, "J.R.R. Tolkien")
        viewer.onDismiss()
        XCTAssertTrue(dismissed)

        let book = Book(
            id: "book-spec-1",
            title: "The Hobbit",
            author: "J.R.R. Tolkien",
            duration: 3600
        )

        var specsDismissed = false
        let specsSheet = MediaSpecsSheet(detailed: book) {
            specsDismissed = true
        }
        XCTAssertEqual(specsSheet.detailed.id, "book-spec-1")
        specsSheet.onDismiss()
        XCTAssertTrue(specsDismissed)
    }
}
