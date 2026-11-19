//
//  BookshelfViewModel.swift
//  Audiobookphile
//

import SwiftUI
import Observation

public enum BookshelfFilter: String, CaseIterable, Identifiable, Sendable {
    case all = "All"
    case inProgress = "In Progress"
    case notStarted = "Not Started"
    case finished = "Finished"
    case downloaded = "Downloaded"
    case series = "Series"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .all: return "books.vertical.fill"
        case .inProgress: return "waveform"
        case .notStarted: return "circle"
        case .finished: return "checkmark.circle.fill"
        case .downloaded: return "arrow.down.circle.fill"
        case .series: return "square.stack.3d.up.fill"
        }
    }
}

public enum BookshelfSortOption: String, CaseIterable, Identifiable, Sendable {
    case recentlyAdded = "Recently Added"
    case oldestAdded = "Oldest Added"
    case titleAZ = "Title (A-Z)"
    case titleZA = "Title (Z-A)"
    case authorAZ = "Author (A-Z)"
    case authorZA = "Author (Z-A)"
    case longestDuration = "Longest"
    case shortestDuration = "Shortest"

    public var id: String { rawValue }

    public var sortKey: String {
        switch self {
        case .recentlyAdded, .oldestAdded: return "addedAt"
        case .titleAZ, .titleZA: return "title"
        case .authorAZ, .authorZA: return "author"
        case .longestDuration, .shortestDuration: return "duration"
        }
    }

    public var isDesc: Bool {
        switch self {
        case .recentlyAdded, .titleZA, .authorZA, .longestDuration: return true
        case .oldestAdded, .titleAZ, .authorAZ, .shortestDuration: return false
        }
    }

    public static func from(sort: String, desc: Bool) -> BookshelfSortOption {
        switch sort {
        case "title":
            return desc ? .titleZA : .titleAZ
        case "author":
            return desc ? .authorZA : .authorAZ
        case "duration":
            return desc ? .longestDuration : .shortestDuration
        default:
            return desc ? .recentlyAdded : .oldestAdded
        }
    }
}

@Observable
@MainActor
public class BookshelfViewModel {
    public var books: [Book] = []
    public var filteredBooks: [Book] = []
    public var continueListening: [Book] = []
    public var continueSeries: [Book] = []
    public var currentLibrary: Library?
    public var selectedBook: Book?
    public var listeningStreak: Int = 0
    public var isLoading = true
    public var errorMessage: String?

    // Filter & Search State
    public var selectedFilter: BookshelfFilter = .all {
        didSet { applyFilter() }
    }
    public var selectedSort: BookshelfSortOption = .recentlyAdded
    public var filterSearchText: String = "" {
        didSet { applyFilter() }
    }

    // Pagination State
    public var currentPage: Int = 0
    public var pageSize: Int = 48 // Slim list payloads arrive in pages; 0 = unlimited (slow for large libraries)
    public var totalBooksCount: Int = 0
    public var hasMorePages: Bool = false
    public var isLoadingNextPage: Bool = false
    public var currentSort: String = "addedAt"
    public var currentDesc: Bool = true

    public var totalBooks: Int { totalBooksCount > 0 ? totalBooksCount : books.count }
    public var inProgressCount: Int { continueListening.count }
    public var coverAspectRatio: CGFloat {
        // Enforce exact 1:1 square ratio for all audiobooks across all libraries
        return 1.0
    }

    public var totalDurationFormatted: String {
        let totalSeconds = books.reduce(0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        return "\(hours)"
    }

    private var customService: LibraryServiceProtocol?

    public init(service: LibraryServiceProtocol? = nil) {
        self.customService = service
    }

    public struct BookshelfCacheData: Codable, Sendable {
        public let books: [Book]
        public let total: Int
        public let page: Int
    }

    public func loadLibrary(libraryId: String?, isAuthenticated: Bool, sort: String = "addedAt", desc: Bool = true) async {
        let cacheKey = "bookshelf_\(libraryId ?? "default")_\(sort)_\(desc)"

        self.currentPage = 0
        self.currentSort = sort
        self.currentDesc = desc
        self.selectedSort = BookshelfSortOption.from(sort: sort, desc: desc)

        // Instantly populate from disk cache if available for smooth navigation
        if let cached = await LocalCacheService.shared.load(forKey: cacheKey, as: BookshelfCacheData.self), !cached.books.isEmpty {
            self.books = cached.books
            self.totalBooksCount = cached.total
            self.currentPage = cached.page
            self.hasMorePages = pageSize > 0 && self.books.count < cached.total
            applyFilter()
        } else {
            isLoading = true
        }

        errorMessage = nil

        let service = customService ?? (isAuthenticated ? LiveLibraryService() : MockLibraryService())

        // Sync current library from AppState
        if let id = libraryId {
            self.currentLibrary = AppState.shared.libraries.first { $0.id == id }
        }

        do {
            let response = try await service.fetchPaginatedLibraryItems(
                libraryId: libraryId,
                page: 0,
                limit: pageSize,
                sort: sort,
                desc: desc
            )

            self.books = response.results
            self.totalBooksCount = response.total
            self.currentPage = 0
            self.hasMorePages = pageSize > 0 && self.books.count < response.total
            self.errorMessage = nil
            applyFilter()
            
            let cacheData = BookshelfCacheData(books: response.results, total: response.total, page: 0)
            await LocalCacheService.shared.save(cacheData, forKey: cacheKey)
        } catch {
            print("[BookshelfViewModel] Failed to load library items: \(error)")
            self.errorMessage = error.localizedDescription
        }

        // Fetch continue listening independently so failures do not discard library items
        do {
            self.continueListening = try await service.fetchContinueListening(libraryId: libraryId)
        } catch {
            print("[BookshelfViewModel] Failed to fetch continue listening: \(error)")
        }

        // Fetch continue series independently so failures do not discard library items
        do {
            self.continueSeries = try await service.fetchContinueSeries(libraryId: libraryId)
        } catch {
            print("[BookshelfViewModel] Failed to fetch continue series: \(error)")
        }

        // Fetch user listening streak
        if isAuthenticated {
            if let userStats = try? await AudiobookphileAPI.shared.getUserStats() {
                self.listeningStreak = ListeningStreakCalculator.calculateStreak(sessions: userStats.recentSessions)
            }
        } else {
            self.listeningStreak = 3
        }

        isLoading = false
    }

    public func loadNextPageIfNeeded(currentBook book: Book, libraryId: String?, isAuthenticated: Bool) async {
        guard hasMorePages, !isLoadingNextPage, !isLoading else { return }

        // Trigger loading when reaching within 6 books of the end of the loaded list
        guard let index = filteredBooks.firstIndex(where: { $0.id == book.id }),
              index >= filteredBooks.count - 6 else {
            return
        }

        isLoadingNextPage = true
        let nextPage = currentPage + 1

        let service = customService ?? (isAuthenticated ? LiveLibraryService() : MockLibraryService())

        do {
            let response = try await service.fetchPaginatedLibraryItems(
                libraryId: libraryId,
                page: nextPage,
                limit: pageSize,
                sort: currentSort,
                desc: currentDesc
            )

            // Deduplicate items against already loaded items
            let existingIds = Set(self.books.map { $0.id })
            let newItems = response.results.filter { !existingIds.contains($0.id) }

            if !newItems.isEmpty {
                self.books.append(contentsOf: newItems)
                self.currentPage = nextPage
                self.totalBooksCount = response.total
                applyFilter()
            }

            self.hasMorePages = pageSize > 0 && self.books.count < response.total
        } catch {
            print("[BookshelfViewModel] Failed to fetch page \(nextPage): \(error)")
        }

        isLoadingNextPage = false
    }

    public func setFilter(_ filter: BookshelfFilter) {
        self.selectedFilter = filter
        applyFilter()
    }

    public func setSearchText(_ text: String) {
        self.filterSearchText = text
        applyFilter()
    }

    public func resetFilters() {
        self.selectedFilter = .all
        self.filterSearchText = ""
        applyFilter()
    }

    public func count(for filter: BookshelfFilter) -> Int {
        let downloadedIds = Set(DownloadService.shared.downloads.filter { $0.status == .completed }.map { $0.libraryItemId })
        switch filter {
        case .all:
            return books.count
        case .inProgress:
            return books.filter {
                guard let progress = $0.userMediaProgress else { return false }
                return !progress.isFinished && progress.progress > 0
            }.count
        case .notStarted:
            return books.filter {
                guard let progress = $0.userMediaProgress else { return true }
                return !progress.isFinished && progress.progress == 0
            }.count
        case .finished:
            return books.filter { $0.userMediaProgress?.isFinished == true }.count
        case .downloaded:
            return books.filter { downloadedIds.contains($0.id) }.count
        case .series:
            return books.filter {
                if let series = $0.seriesName, !series.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return true
                }
                return false
            }.count
        }
    }

    public func applyFilter() {
        let downloadedIds = Set(DownloadService.shared.downloads.filter { $0.status == .completed }.map { $0.libraryItemId })
        var result = books

        // 1. Filter by category
        switch selectedFilter {
        case .all:
            break
        case .inProgress:
            result = result.filter {
                guard let progress = $0.userMediaProgress else { return false }
                return !progress.isFinished && progress.progress > 0
            }
        case .notStarted:
            result = result.filter {
                guard let progress = $0.userMediaProgress else { return true }
                return !progress.isFinished && progress.progress == 0
            }
        case .finished:
            result = result.filter { $0.userMediaProgress?.isFinished == true }
        case .downloaded:
            result = result.filter { downloadedIds.contains($0.id) }
        case .series:
            result = result.filter {
                if let series = $0.seriesName, !series.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    return true
                }
                return false
            }
        }

        // 2. Filter by search query if present
        let trimmedQuery = filterSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            result = result.filter { book in
                book.title.localizedCaseInsensitiveContains(trimmedQuery) ||
                (book.author?.localizedCaseInsensitiveContains(trimmedQuery) ?? false) ||
                (book.narrator?.localizedCaseInsensitiveContains(trimmedQuery) ?? false) ||
                (book.seriesName?.localizedCaseInsensitiveContains(trimmedQuery) ?? false)
            }
        }

        self.filteredBooks = result
    }

    public func refresh(libraryId: String?, isAuthenticated: Bool) async {
        await loadLibrary(libraryId: libraryId, isAuthenticated: isAuthenticated, sort: currentSort, desc: currentDesc)
    }

    public func selectBook(_ book: Book) {
        selectedBook = book
    }

    public func playBook(_ book: Book) {
        print("Playing: \(book.title)")
    }

    public func searchResults(for query: String) -> [Book] {
        guard !query.isEmpty else { return [] }
        return books.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            ($0.author?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    public func changeSort(option: BookshelfSortOption, libraryId: String?, isAuthenticated: Bool) async {
        self.selectedSort = option
        await changeSort(sort: option.sortKey, desc: option.isDesc, libraryId: libraryId, isAuthenticated: isAuthenticated)
    }

    public func changeSort(sort: String, desc: Bool, libraryId: String?, isAuthenticated: Bool) async {
        self.selectedSort = BookshelfSortOption.from(sort: sort, desc: desc)
        guard sort != currentSort || desc != currentDesc else { return }
        await loadLibrary(libraryId: libraryId, isAuthenticated: isAuthenticated, sort: sort, desc: desc)
    }

    public func showFilterOptions() {}
    public func showSettings() {}
    public func showDownloads() {}
    public func showStats() {}
}

public struct LibraryLoadTrigger: Equatable {
    public let libraryId: String?
    public let isAuthenticated: Bool
    
    public init(libraryId: String?, isAuthenticated: Bool) {
        self.libraryId = libraryId
        self.isAuthenticated = isAuthenticated
    }
}
