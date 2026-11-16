//
//  SeriesDetailViewModel.swift
//  Audiobookphile
//
//  ViewModel for Series Detail views with Liquid Glass design system.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Observation

@Observable
@MainActor
public class SeriesDetailViewModel {
    public let seriesName: String
    public let libraryId: String?
    public var seriesSummary: SeriesSummary?
    public var books: [Book] = []
    public var isLoading = true
    public var errorMessage: String?

    public var service: LibraryServiceProtocol

    public init(seriesName: String, libraryId: String?, service: LibraryServiceProtocol? = nil) {
        self.seriesName = seriesName
        self.libraryId = libraryId
        self.service = service ?? (AppState.shared.isAuthenticated ? LiveLibraryService() : MockLibraryService())
    }

    public var totalDuration: TimeInterval {
        books.reduce(0) { $0 + $1.duration }
    }

    public var totalDurationFormatted: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    public var bookCountText: String {
        let count = books.count
        return count == 1 ? "1 Book" : "\(count) Books"
    }

    public var primaryAuthor: String? {
        books.compactMap { $0.author }.first
    }

    public func loadSeries() async {
        isLoading = true
        errorMessage = nil

        do {
            let booksResult = try await service.fetchBooksBySeries(seriesName: seriesName, libraryId: libraryId)
            let seriesResult = try await service.fetchSeries(libraryId: libraryId, page: 0, sort: "name")

            self.books = booksResult
            self.seriesSummary = seriesResult.results.first {
                $0.name.localizedCaseInsensitiveCompare(seriesName) == .orderedSame ||
                $0.name.localizedCaseInsensitiveContains(seriesName)
            }
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
}
