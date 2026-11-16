//
//  BookshelfViewModel.swift
//  Audiobookphile
//

import SwiftUI
import Observation

@Observable
@MainActor
public class BookshelfViewModel {
    public var books: [Book] = []
    public var filteredBooks: [Book] = []
    public var continueListening: [Book] = []
    public var continueSeries: [Book] = []
    public var currentLibrary: Library?
    public var selectedBook: Book?
    public var isLoading = true
    public var errorMessage: String?

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

        // Instantly populate from disk cache if available for smooth navigation
        if let cached = await LocalCacheService.shared.load(forKey: cacheKey, as: BookshelfCacheData.self), !cached.books.isEmpty {
            self.books = cached.books
            self.filteredBooks = cached.books
            self.totalBooksCount = cached.total
            self.currentPage = cached.page
            self.hasMorePages = pageSize > 0 && self.books.count < cached.total
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
            self.filteredBooks = response.results
            self.totalBooksCount = response.total
            self.currentPage = 0
            self.hasMorePages = pageSize > 0 && self.books.count < response.total
            self.errorMessage = nil
            
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
                self.filteredBooks = self.books
                self.currentPage = nextPage
                self.totalBooksCount = response.total
            }

            self.hasMorePages = pageSize > 0 && self.books.count < response.total
        } catch {
            print("[BookshelfViewModel] Failed to fetch page \(nextPage): \(error)")
        }

        isLoadingNextPage = false
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

    public func changeSort(sort: String, desc: Bool, libraryId: String?, isAuthenticated: Bool) async {
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
