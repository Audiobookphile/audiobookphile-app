import Foundation

@MainActor
public protocol LibraryServiceProtocol {
    func fetchLibraryItems(libraryId: String?) async throws -> [Book]
    func fetchPaginatedLibraryItems(libraryId: String?, page: Int, limit: Int?, sort: String, desc: Bool) async throws -> LibraryItemsResponse
    func smartSortLibrary(libraryId: String?, criteria: String) async throws -> [String]
    func deduplicateLibrary(libraryId: String?) async throws -> Int
    func fetchContinueListening(libraryId: String?) async throws -> [Book]
    func fetchContinueSeries(libraryId: String?) async throws -> [Book]
    func fetchLibraryStats(libraryId: String?) async throws -> LibraryStats
    func fetchAuthors(libraryId: String?, page: Int, sort: String) async throws -> AuthorsResponse
    func fetchSeries(libraryId: String?, page: Int, sort: String) async throws -> SeriesResponse
}

@MainActor
public class LiveLibraryService: LibraryServiceProtocol {
    public init() {}

    public func fetchLibraryItems(libraryId: String?) async throws -> [Book] {
        guard let libId = libraryId else {
            return []
        }
        let response = try await AudiobookphileAPI.shared.getLibraryItems(libraryId: libId, limit: 0)
        return response.results
    }

    public func fetchPaginatedLibraryItems(libraryId: String?, page: Int = 0, limit: Int? = nil, sort: String = "addedAt", desc: Bool = true) async throws -> LibraryItemsResponse {
        guard let libId = libraryId else {
            throw APIError.invalidResponse
        }
        return try await AudiobookphileAPI.shared.getLibraryItems(libraryId: libId, limit: limit, page: page, sort: sort, desc: desc)
    }

    public func smartSortLibrary(libraryId: String?, criteria: String = "chronological reading order") async throws -> [String] {
        guard let libId = libraryId else {
            return []
        }
        return try await AudiobookphileAPI.shared.smartSortLibraryItems(libraryId: libId, criteria: criteria)
    }

    public func deduplicateLibrary(libraryId: String?) async throws -> Int {
        guard let libId = libraryId else {
            return 0
        }
        return try await AudiobookphileAPI.shared.deduplicateLibraryItems(libraryId: libId)
    }

    public func fetchContinueListening(libraryId: String?) async throws -> [Book] {
        guard let libId = libraryId else {
            return []
        }
        let shelves = try await AudiobookphileAPI.shared.getLibraryPersonalized(libraryId: libId)
        return shelves.first { $0.id == "continue-listening" }?.entities ?? []
    }

    public func fetchContinueSeries(libraryId: String?) async throws -> [Book] {
        guard let libId = libraryId else {
            return []
        }
        let shelves = try await AudiobookphileAPI.shared.getLibraryPersonalized(libraryId: libId)
        return shelves.first { $0.id == "continue-series" }?.entities ?? []
    }

    public func fetchLibraryStats(libraryId: String?) async throws -> LibraryStats {
        guard let libId = libraryId else {
            throw APIError.invalidResponse
        }
        return try await AudiobookphileAPI.shared.getLibraryStats(libraryId: libId)
    }

    public func fetchAuthors(libraryId: String?, page: Int = 0, sort: String = "name") async throws -> AuthorsResponse {
        guard let libId = libraryId else {
            throw APIError.invalidResponse
        }
        return try await AudiobookphileAPI.shared.getLibraryAuthors(libraryId: libId, page: page, sort: sort)
    }

    public func fetchSeries(libraryId: String?, page: Int = 0, sort: String = "name") async throws -> SeriesResponse {
        guard let libId = libraryId else {
            throw APIError.invalidResponse
        }
        return try await AudiobookphileAPI.shared.getLibrarySeries(libraryId: libId, page: page, sort: sort)
    }
}

@MainActor
public class MockLibraryService: LibraryServiceProtocol {
    public init() {}

    private let mockCovers = [
        "https://images.unsplash.com/photo-1544947950-fa07a98d237f?auto=format&fit=crop&q=80&w=400", // The Midnight Library
        "https://images.unsplash.com/photo-1451187580459-43490279c0fa?auto=format&fit=crop&q=80&w=400", // Project Hail Mary
        "https://images.unsplash.com/photo-1587876931567-564ce588bfbd?auto=format&fit=crop&q=80&w=400", // The Thursday Murder Club
        "https://images.unsplash.com/photo-1506126613408-eca07ce68773?auto=format&fit=crop&q=80&w=400", // Atomic Habits
        "https://images.unsplash.com/photo-1509316975850-ff9c5deb0cd9?auto=format&fit=crop&q=80&w=400", // Dune
        "https://images.unsplash.com/photo-1543002588-bfa74002ed7e?auto=format&fit=crop&q=80&w=400", // 1984
        "https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&q=80&w=400"  // The Hobbit
    ]

    private let bookTitles = [
        "The Midnight Library",
        "Project Hail Mary",
        "The Thursday Murder Club",
        "Atomic Habits",
        "Dune",
        "1984",
        "The Hobbit"
    ]

    private let authors = [
        "Matt Haig",
        "Andy Weir",
        "Richard Osman",
        "James Clear",
        "Frank Herbert",
        "George Orwell",
        "J.R.R. Tolkien"
    ]

    private let seriesList = [
        "The Midnight Collection",
        "The Hail Mary Odyssey",
        "Thursday Murder Club Mysteries",
        "Habits Series",
        "Dune Chronicles",
        "Orwell Classics",
        "Middle-earth Legendarium"
    ]

    public func fetchPaginatedLibraryItems(libraryId: String?, page: Int = 0, limit: Int? = nil, sort: String = "addedAt", desc: Bool = true) async throws -> LibraryItemsResponse {
        let allBooks = try await fetchLibraryItems(libraryId: libraryId)
        let effectiveLimit = limit ?? 0
        if effectiveLimit <= 0 {
            return LibraryItemsResponse(results: allBooks, total: allBooks.count, limit: 0, page: 0)
        }
        let start = page * effectiveLimit
        if start >= allBooks.count {
            return LibraryItemsResponse(results: [], total: allBooks.count, limit: effectiveLimit, page: page)
        }
        let end = min(start + effectiveLimit, allBooks.count)
        let pagedBooks = Array(allBooks[start..<end])
        return LibraryItemsResponse(results: pagedBooks, total: allBooks.count, limit: effectiveLimit, page: page)
    }

    public func smartSortLibrary(libraryId: String?, criteria: String = "chronological reading order") async throws -> [String] {
        let books = try await fetchLibraryItems(libraryId: libraryId)
        return books.map { $0.id }
    }

    public func deduplicateLibrary(libraryId: String?) async throws -> Int {
        return 0
    }

    public func fetchLibraryItems(libraryId: String?) async throws -> [Book] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        return (0..<60).map { (idx: Int) -> Book in
            let titleIndex = idx % bookTitles.count
            let coverURL = mockCovers[titleIndex]

            return Book(
                id: "book-\(idx)",
                libraryId: libraryId ?? "lib1",
                folderId: nil,
                path: "/books/book\(idx)",
                relPath: "book\(idx)",
                isMissing: nil,
                libraryFiles: nil,
                media: BookMedia(
                    libraryFiles: [],
                    chapters: [],
                    duration: TimeInterval.random(in: 10000...50000),
                    size: 0,
                    metadata: BookMetadata(
                        title: bookTitles[titleIndex],
                        subtitle: nil,
                        authorName: authors[titleIndex],
                        narratorName: "Narrator \(idx)",
                        seriesName: idx % 2 == 0 ? seriesList[titleIndex] : nil,
                        genres: ["Fiction", "Audiobookphile Mock"],
                        publishedYear: "2024",
                        publishedDate: nil,
                        publisher: nil,
                        description: "This is a mock description for \(bookTitles[titleIndex]). It provides a sample of what the actual audiobook description would look like in the app.",
                        isbn: nil,
                        asin: nil,
                        language: "en",
                        explicit: false
                    ),
                    coverPath: coverURL, // Set Unsplash URL as the coverPath!
                    tags: [],
                    audioFiles: [],
                    ebookFile: nil
                ),
                userMediaProgress: idx % 3 == 0 ? MediaProgress(
                    id: "progress-\(idx)",
                    libraryItemId: "book-\(idx)",
                    episodeId: nil,
                    duration: 28800,
                    progress: Double.random(in: 0.1...0.9),
                    currentTime: 10000,
                    isFinished: false,
                    hideFromContinueListening: false,
                    lastUpdate: Date(),
                    startedAt: Date(),
                    finishedAt: nil
                ) : nil,
                    addedAt: Date(),
                    updatedAt: Date()
            )
        }
    }

    public func fetchContinueListening(libraryId: String?) async throws -> [Book] {
        // Simulate network delay
        try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds

        // Return only mock books that have progress (every 3rd book),
        // mimicking the server-driven continue-listening shelf.
        return try await fetchLibraryItems(libraryId: libraryId).filter { $0.userMediaProgress != nil }
    }

    public func fetchContinueSeries(libraryId: String?) async throws -> [Book] {
        try await Task.sleep(nanoseconds: 200_000_000)
        let items = try await fetchLibraryItems(libraryId: libraryId)
        return Array(items.filter { $0.seriesName != nil }.prefix(6))
    }

    public func fetchLibraryStats(libraryId: String?) async throws -> LibraryStats {
        try await Task.sleep(nanoseconds: 300_000_000)
        return LibraryStats(
            totalItems: 42,
            totalBooks: 42,
            totalAuthors: 15,
            totalSeries: 8,
            totalDuration: 145 * 3600 + 30 * 60,
            totalSize: 25_000_000_000,
            addedLast30Days: 5,
            numAudioTracks: 312,
            genresWithCount: [
                GenreCount(genre: "Fiction", count: 20),
                GenreCount(genre: "Science Fiction", count: 12),
                GenreCount(genre: "Fantasy", count: 10),
            ],
            authorsWithCount: [
                AuthorCount(id: "a1", name: "Andy Weir", count: 3),
                AuthorCount(id: "a2", name: "J.R.R. Tolkien", count: 5),
                AuthorCount(id: "a3", name: "Frank Herbert", count: 4),
            ],
            longestItems: [
                ItemStat(id: "i1", title: "Dune", duration: 72000, size: nil),
                ItemStat(id: "i2", title: "The Hobbit", duration: 54000, size: nil),
            ],
            largestItems: [
                ItemStat(id: "i1", title: "Dune", duration: nil, size: 2_000_000_000),
            ]
        )
    }

    public func fetchAuthors(libraryId: String?, page: Int = 0, sort: String = "name") async throws -> AuthorsResponse {
        try await Task.sleep(nanoseconds: 200_000_000)
        return AuthorsResponse(
            authors: authors.enumerated().map { idx, name in
                AuthorSummary(id: "author-\(idx)", name: name, asin: nil, description: nil, imagePath: nil, libraryId: nil, addedAt: nil, updatedAt: nil, numBooks: Int.random(in: 1...10))
            },
            total: authors.count,
            limit: 24,
            page: 0
        )
    }

    public func fetchSeries(libraryId: String?, page: Int = 0, sort: String = "name") async throws -> SeriesResponse {
        try await Task.sleep(nanoseconds: 200_000_000)
        return SeriesResponse(
            results: [
                SeriesSummary(id: "s1", name: "The Lord of the Rings", nameIgnorePrefix: nil, description: nil, libraryId: nil, addedAt: nil, updatedAt: nil, books: nil, numBooks: 3),
                SeriesSummary(id: "s2", name: "Dune", nameIgnorePrefix: nil, description: nil, libraryId: nil, addedAt: nil, updatedAt: nil, books: nil, numBooks: 6),
            ],
            total: 2,
            limit: 24,
            page: 0
        )
    }
}
