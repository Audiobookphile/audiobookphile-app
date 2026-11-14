//
//  CollectionListView.swift
//  Audiobookphile
//
//  Component view for displaying a list of collections.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

public struct CollectionListView: View {
    let type: CollectionsView.CollectionType
    let series: [SeriesSummary]
    let collections: [CollectionSummary]
    let playlists: [PlaylistSummary]
    
    public var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                switch type {
                case .series:
                    if series.isEmpty {
                        emptyState(for: type)
                    } else {
                        ForEach(series) { item in
                            seriesRow(item)
                        }
                    }
                case .collections:
                    if collections.isEmpty {
                        emptyState(for: type)
                    } else {
                        ForEach(collections) { item in
                            collectionRow(item)
                        }
                    }
                case .playlists:
                    if playlists.isEmpty {
                        emptyState(for: type)
                    } else {
                        ForEach(playlists) { item in
                            playlistRow(item)
                        }
                    }
                }

                Spacer().frame(height: 100) // Bottom clearance for floating MiniPlayer
            }
            .padding(16)
        }
    }
    
    private func seriesRow(_ item: SeriesSummary) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appSecondaryBackground)
                    .frame(width: 60, height: 60)
                
                Image(systemName: "books.vertical.fill")
                    .foregroundStyle(Color.appPrimary)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                
                Text("\(item.numBooks ?? 0) books")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.textSecondary.opacity(0.5))
        }
        .padding(12)
        .glassBackground(cornerRadius: 12)
    }

    private func collectionRow(_ item: CollectionSummary) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appSecondaryBackground)
                    .frame(width: 60, height: 60)
                
                Image(systemName: "square.stack.3d.up.fill")
                    .foregroundStyle(Color.appPrimary)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                
                Text("\(item.numBooks ?? item.books?.count ?? 0) books")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.textSecondary.opacity(0.5))
        }
        .padding(12)
        .glassBackground(cornerRadius: 12)
    }

    private func playlistRow(_ item: PlaylistSummary) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.appSecondaryBackground)
                    .frame(width: 60, height: 60)
                
                Image(systemName: "music.note.list")
                    .foregroundStyle(Color.appPrimary)
                    .font(.title2)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                
                Text("\(item.items?.count ?? 0) items")
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundStyle(Color.textSecondary.opacity(0.5))
        }
        .padding(12)
        .glassBackground(cornerRadius: 12)
    }
    
    private func emptyState(for type: CollectionsView.CollectionType) -> some View {
        VStack(spacing: 16) {
            Image(systemName: iconForType(type))
                .font(.system(size: 48))
                .foregroundStyle(Color.appPrimary.opacity(0.8))
            
            Text(type.rawValue)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(Color.textPrimary)

            Text("Your customized \(type.rawValue.lowercased()) will appear here.")
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(32)
        .glassBackground(cornerRadius: 20)
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
