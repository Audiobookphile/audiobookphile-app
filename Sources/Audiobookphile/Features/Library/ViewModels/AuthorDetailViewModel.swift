//
//  AuthorDetailViewModel.swift
//  Audiobookphile
//
//  ViewModel for Author Detail views with Liquid Glass design system.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Observation

@Observable
@MainActor
public class AuthorDetailViewModel {
    public let authorName: String
    public let libraryId: String?
    public var authorSummary: AuthorSummary?
    public var books: [Book] = []
    public var isLoading = true
    public var errorMessage: String?

    public var service: LibraryServiceProtocol

    public init(authorName: String, libraryId: String?, service: LibraryServiceProtocol? = nil) {
        self.authorName = authorName
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
        return count == 1 ? "1 Audiobook" : "\(count) Audiobooks"
    }

    public var initials: String {
        let components = authorName.split(separator: " ")
        if components.count >= 2, let first = components.first?.first, let last = components.last?.first {
            return "\(first)\(last)".uppercased()
        }
        return String(authorName.prefix(2)).uppercased()
    }

    public func loadAuthor() async {
        isLoading = true
        errorMessage = nil

        do {
            let booksResult = try await service.fetchBooksByAuthor(authorName: authorName, libraryId: libraryId)
            let authorsResult = try await service.fetchAuthors(libraryId: libraryId, page: 0, sort: "name")

            self.books = booksResult
            self.authorSummary = authorsResult.authors.first {
                $0.name.localizedCaseInsensitiveCompare(authorName) == .orderedSame ||
                $0.name.localizedCaseInsensitiveContains(authorName)
            }
            self.isLoading = false
        } catch {
            self.errorMessage = error.localizedDescription
            self.isLoading = false
        }
    }
}
