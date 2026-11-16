//
//  CollectionsViewModel.swift
//  Audiobookphile
//
//  Manages the state and API calls for the Collections tab.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Observation

@Observable
@MainActor
public class CollectionsViewModel {
    public var series: [SeriesSummary] = []
    public var collections: [CollectionSummary] = []
    public var playlists: [PlaylistSummary] = []
    
    public var isLoading: Bool = false
    public var error: Error?

    public init() {}

    public func loadData(libraryId: String?, isAuthenticated: Bool, type: CollectionsView.CollectionType) async {
        isLoading = true
        error = nil
        
        do {
            switch type {
            case .series:
                if series.isEmpty {
                    let service: LibraryServiceProtocol = isAuthenticated ? LiveLibraryService() : MockLibraryService()
                    let response = try await service.fetchSeries(libraryId: libraryId, page: 0, sort: "name")
                    self.series = response.results
                }
            case .collections:
                if collections.isEmpty {
                    if let libId = libraryId, isAuthenticated {
                        let res = try await AudiobookphileAPI.shared.getLibraryCollections(libraryId: libId)
                        self.collections = res.results
                    } else {
                        // Mock collections for offline/demo exploring
                        self.collections = [
                            CollectionSummary(id: "c1", name: "Award Winners", description: "Hugo, Nebula, and Booker prize-winning audiobooks.", libraryId: nil, addedAt: nil, updatedAt: nil, books: [
                                CollectionBookSummary(id: "b1", order: 1, title: "Dune", cover: nil),
                                CollectionBookSummary(id: "b2", order: 2, title: "Project Hail Mary", cover: nil),
                                CollectionBookSummary(id: "b3", order: 3, title: "The Midnight Library", cover: nil)
                            ], numBooks: 3),
                            CollectionSummary(id: "c2", name: "Bedtime Listening", description: "Calm, gentle narrations to help you unwind and drift off to sleep.", libraryId: nil, addedAt: nil, updatedAt: nil, books: [
                                CollectionBookSummary(id: "b4", order: 1, title: "The Hobbit", cover: nil),
                                CollectionBookSummary(id: "b5", order: 2, title: "1984", cover: nil)
                            ], numBooks: 2),
                            CollectionSummary(id: "c3", name: "Long Road Trips", description: "Captivating multi-hour journeys perfect for extended travel.", libraryId: nil, addedAt: nil, updatedAt: nil, books: [
                                CollectionBookSummary(id: "b6", order: 1, title: "Atomic Habits", cover: nil),
                                CollectionBookSummary(id: "b7", order: 2, title: "The Thursday Murder Club", cover: nil)
                            ], numBooks: 2)
                        ]
                    }
                }
            case .playlists:
                if playlists.isEmpty {
                    if let libId = libraryId, isAuthenticated {
                        let res = try await AudiobookphileAPI.shared.getLibraryPlaylists(libraryId: libId)
                        self.playlists = res.results
                    } else {
                        // Mock playlists for offline/demo exploring
                        self.playlists = [
                            PlaylistSummary(id: "p1", name: "Favorites", description: "Cherished audiobooks you can return to again and again.", libraryId: nil, userId: nil, addedAt: nil, updatedAt: nil, items: [
                                PlaylistItemSummary(id: "pi1", order: 1, title: "Project Hail Mary", cover: nil),
                                PlaylistItemSummary(id: "pi2", order: 2, title: "Dune", cover: nil)
                            ]),
                            PlaylistSummary(id: "p2", name: "Weekend Binge", description: "Gripping thrillers and fast-paced narratives.", libraryId: nil, userId: nil, addedAt: nil, updatedAt: nil, items: [
                                PlaylistItemSummary(id: "pi3", order: 1, title: "The Thursday Murder Club", cover: nil)
                            ])
                        ]
                    }
                }
            }
        } catch {
            print("[CollectionsViewModel] Failed to fetch \(type.rawValue): \(error)")
            self.error = error
        }
        
        isLoading = false
    }
    
    public func refresh(libraryId: String?, isAuthenticated: Bool, type: CollectionsView.CollectionType) async {
        switch type {
        case .series:
            series = []
        case .collections:
            collections = []
        case .playlists:
            playlists = []
        }
        
        await loadData(libraryId: libraryId, isAuthenticated: isAuthenticated, type: type)
    }
}
