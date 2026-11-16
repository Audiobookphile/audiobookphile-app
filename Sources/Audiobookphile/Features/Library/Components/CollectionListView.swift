//
//  CollectionListView.swift
//  Audiobookphile
//
//  Component view for displaying an interactive list of series, collections, and playlists.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

public struct CollectionListView: View {
    public let type: CollectionsView.CollectionType
    public let series: [SeriesSummary]
    public let collections: [CollectionSummary]
    public let playlists: [PlaylistSummary]
    public let libraryId: String?

    @State private var selectedSeries: SeriesSummary?
    @State private var selectedCollection: CollectionSummary?
    @State private var selectedPlaylist: PlaylistSummary?

    public init(
        type: CollectionsView.CollectionType,
        series: [SeriesSummary],
        collections: [CollectionSummary],
        playlists: [PlaylistSummary],
        libraryId: String? = nil
    ) {
        self.type = type
        self.series = series
        self.collections = collections
        self.playlists = playlists
        self.libraryId = libraryId
    }

    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                switch type {
                case .series:
                    if series.isEmpty {
                        emptyState(for: type)
                    } else {
                        ForEach(series) { item in
                            Button {
                                selectedSeries = item
                            } label: {
                                seriesRow(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                case .collections:
                    if collections.isEmpty {
                        emptyState(for: type)
                    } else {
                        ForEach(collections) { item in
                            Button {
                                selectedCollection = item
                            } label: {
                                collectionRow(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                case .playlists:
                    if playlists.isEmpty {
                        emptyState(for: type)
                    } else {
                        ForEach(playlists) { item in
                            Button {
                                selectedPlaylist = item
                            } label: {
                                playlistRow(item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Spacer().frame(height: 100) // Bottom clearance for floating MiniPlayer
            }
            .padding(16)
        }
        .sheet(item: $selectedSeries) { item in
            SeriesDetailView(seriesName: item.name, libraryId: libraryId)
        }
        .sheet(item: $selectedCollection) { item in
            CollectionDetailSheet(collection: item, libraryId: libraryId)
        }
        .sheet(item: $selectedPlaylist) { item in
            PlaylistDetailSheet(playlist: item, libraryId: libraryId)
        }
    }

    private func seriesRow(_ item: SeriesSummary) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: "books.vertical.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(DesignTokens.Color.foreground)
                    .lineLimit(1)

                Text("\(item.numBooks ?? 0) books in sequence")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary.opacity(0.6))
        }
        .padding(12)
        .glassCard(cornerRadius: 14)
    }

    private func collectionRow(_ item: CollectionSummary) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundStyle(Color.accentColor)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(DesignTokens.Color.foreground)
                    .lineLimit(1)

                Text("\(item.numBooks ?? item.books?.count ?? 0) audiobooks")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary.opacity(0.6))
        }
        .padding(12)
        .glassCard(cornerRadius: 14)
    }

    private func playlistRow(_ item: PlaylistSummary) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 56, height: 56)

                Image(systemName: "music.note.list")
                    .foregroundStyle(Color.accentColor)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(DesignTokens.Color.foreground)
                    .lineLimit(1)

                Text("\(item.items?.count ?? 0) items")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary.opacity(0.6))
        }
        .padding(12)
        .glassCard(cornerRadius: 14)
    }

    private func emptyState(for type: CollectionsView.CollectionType) -> some View {
        VStack(spacing: 16) {
            Image(systemName: iconForType(type))
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor.opacity(0.8))

            Text(type.rawValue)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(DesignTokens.Color.foreground)

            Text("Your customized \(type.rawValue.lowercased()) will appear here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(32)
        .glassCard(cornerRadius: 20)
        .padding(.top, 40)
    }

    private func iconForType(_ type: CollectionsView.CollectionType) -> String {
        switch type {
        case .series:
            return "books.vertical.fill"
        case .collections:
            return "square.stack.3d.up.fill"
        case .playlists:
            return "music.note.list"
        }
    }
}

// MARK: - Collection Detail Sheet

public struct CollectionDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let collection: CollectionSummary
    public let libraryId: String?

    public init(collection: CollectionSummary, libraryId: String?) {
        self.collection = collection
        self.libraryId = libraryId
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                FluidAuraBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.18))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "square.stack.3d.up.fill")
                                    .font(.system(size: 36))
                                    .foregroundStyle(Color.accentColor)
                            }

                            VStack(spacing: 6) {
                                Text(collection.name)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(DesignTokens.Color.foreground)
                                    .multilineTextAlignment(.center)

                                if let desc = collection.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.vertical, 8)

                        // Items list
                        if let books = collection.books, !books.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("AUDIOBOOKS (\(books.count))")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)

                                ForEach(books) { book in
                                    HStack(spacing: 12) {
                                        Text("#\(book.order ?? 1)")
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundStyle(Color.accentColor)
                                            .frame(width: 28, height: 28)
                                            .background(Color.accentColor.opacity(0.12))
                                            .clipShape(Circle())

                                        Text(book.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(DesignTokens.Color.foreground)
                                            .lineLimit(2)

                                        Spacer()
                                    }
                                    .padding(12)
                                    .glassCard(cornerRadius: 12)
                                }
                            }
                        } else {
                            Text("No audiobooks in this collection")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.top, 20)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle(collection.name)
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .applyToolbarAdapters(isLight: false, isHidden: false)
        }
    }
}

// MARK: - Playlist Detail Sheet

public struct PlaylistDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let playlist: PlaylistSummary
    public let libraryId: String?

    public init(playlist: PlaylistSummary, libraryId: String?) {
        self.playlist = playlist
        self.libraryId = libraryId
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                FluidAuraBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.accentColor.opacity(0.18))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "music.note.list")
                                    .font(.system(size: 36))
                                    .foregroundStyle(Color.accentColor)
                            }

                            VStack(spacing: 6) {
                                Text(playlist.name)
                                    .font(.title2.weight(.bold))
                                    .foregroundStyle(DesignTokens.Color.foreground)
                                    .multilineTextAlignment(.center)

                                if let desc = playlist.description, !desc.isEmpty {
                                    Text(desc)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 16)
                                }
                            }
                        }
                        .padding(.vertical, 8)

                        // Items list
                        if let items = playlist.items, !items.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("TRACKS & EPISODES (\(items.count))")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.secondary)

                                ForEach(items) { item in
                                    HStack(spacing: 12) {
                                        Text("#\(item.order ?? 1)")
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundStyle(Color.accentColor)
                                            .frame(width: 28, height: 28)
                                            .background(Color.accentColor.opacity(0.12))
                                            .clipShape(Circle())

                                        Text(item.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(DesignTokens.Color.foreground)
                                            .lineLimit(2)

                                        Spacer()
                                    }
                                    .padding(12)
                                    .glassCard(cornerRadius: 12)
                                }
                            }
                        } else {
                            Text("No tracks in this playlist")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.top, 20)
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle(playlist.name)
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .applyToolbarAdapters(isLight: false, isHidden: false)
        }
    }
}
