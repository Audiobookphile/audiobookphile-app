//
//  NarratorDetailSheet.swift
//  Audiobookphile
//
//  Liquid Glass sheet displaying all audiobooks narrated by a specific narrator.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

public struct NarratorDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var sortOption: CatalogSortOption = .title
    public let narratorName: String
    public let books: [Book]
    public var onSelectBook: ((Book) -> Void)?

    public init(narratorName: String, books: [Book], onSelectBook: ((Book) -> Void)? = nil) {
        self.narratorName = narratorName
        self.books = books
        self.onSelectBook = onSelectBook
    }

    private var sortedBooks: [Book] {
        switch sortOption {
        case .title:
            return books.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .duration:
            return books.sorted { $0.duration > $1.duration }
        case .year:
            return books.sorted { ($0.media.metadata.publishedYear ?? "") > ($1.media.metadata.publishedYear ?? "") }
        }
    }

    private var totalDurationFormatted: String {
        let total = books.reduce(0) { $0 + $1.duration }
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                FluidAuraBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Hero Header Card
                        GlassCard {
                            VStack(spacing: 16) {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.appPrimary.opacity(0.8), Color.purple.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 76, height: 76)
                                    .overlay {
                                        Image(systemName: "mic.fill")
                                            .font(.system(size: 32))
                                            .foregroundStyle(.white)
                                    }
                                    .shadow(color: Color.appPrimary.opacity(0.4), radius: 12, x: 0, y: 6)

                                VStack(spacing: 6) {
                                    Text(narratorName)
                                        .font(.title2.weight(.bold))
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.center)

                                    HStack(spacing: 12) {
                                        Label("\(books.count) \(books.count == 1 ? "Audiobook" : "Audiobooks")", systemImage: "books.vertical.fill")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.secondary)

                                        Text("•")
                                            .foregroundStyle(.tertiary)

                                        Label(totalDurationFormatted, systemImage: "clock.fill")
                                            .font(.subheadline.weight(.medium))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }

                        // Audiobooks List
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Audiobooks")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(.primary)
                                Spacer()
                                Menu {
                                    Picker("Sort by", selection: $sortOption) {
                                        ForEach(CatalogSortOption.allCases) { opt in
                                            Label(opt.rawValue, systemImage: opt.icon).tag(opt)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.arrow.down")
                                            .font(.system(size: 11, weight: .bold))
                                        Text(sortOption.rawValue)
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                    .foregroundStyle(Color.appPrimary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.appPrimary.opacity(0.12))
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 4)

                            ForEach(sortedBooks) { book in
                                GlassCard {
                                    HStack(spacing: 14) {
                                        let coverURL = appState.getCoverURL(itemId: book.id, width: 140, updatedAt: book.updatedAt)
                                        SmartAsyncImage(url: coverURL) { img in
                                            img
                                                .resizable()
                                                .scaledToFill()
                                        } placeholder: {
                                            ZStack {
                                                Color.appSecondaryBackground
                                                Image(systemName: "book.closed")
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        .frame(width: 52, height: 52)
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                        )

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(book.title)
                                                .font(.headline)
                                                .lineLimit(1)
                                                .foregroundStyle(.primary)

                                            Text(book.displayAuthor)
                                                .font(.subheadline)
                                                .lineLimit(1)
                                                .foregroundStyle(.secondary)

                                            if let durationPretty = formatDuration(book.duration) {
                                                Text(durationPretty)
                                                    .font(.caption2.weight(.medium))
                                                    .foregroundStyle(.tertiary)
                                            }
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.caption.bold())
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 4)
                                }
                                .onTapGesture {
                                    onSelectBook?(book)
                                    dismiss()
                                }
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Narrator")
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String? {
        guard duration > 0 else { return nil }
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

