//
//  AuthorDetailView.swift
//  Audiobookphile
//
//  Liquid Glass Author Detail view displaying author biography, audiobooks, and stats.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

public struct AuthorDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel: AuthorDetailViewModel
    @State private var selectedBook: Book?
    @State private var isBioExpanded = false
    @State private var sortOption: CatalogSortOption = .title

    public init(authorName: String, libraryId: String? = nil, service: LibraryServiceProtocol? = nil) {
        self._viewModel = State(wrappedValue: AuthorDetailViewModel(
            authorName: authorName,
            libraryId: libraryId,
            service: service
        ))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                FluidAuraBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        // Author Hero Header
                        heroHeader

                        // Biography (if present)
                        if let bio = viewModel.authorSummary?.description, !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            biographyCard(bio: bio)
                        }

                        // Audiobooks Section
                        audiobooksSection

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle(viewModel.authorName)
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .applyToolbarAdapters(isLight: false, isHidden: false)
            .sheet(item: $selectedBook) { book in
                BookDetailView(book: book)
            }
            .task {
                await viewModel.loadAuthor()
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: 16) {
            // Author Avatar Circle
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.3), Color.appPrimary.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 104, height: 104)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                    )

                if let imagePath = viewModel.authorSummary?.imagePath, let url = URL(string: imagePath) {
                    SmartAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 100, height: 100)
                            .clipShape(Circle())
                    } placeholder: {
                        initialsBadge
                    }
                } else {
                    initialsBadge
                }
            }
            .shadow(color: Color.accentColor.opacity(0.2), radius: 12, x: 0, y: 6)

            // Author Name & Stats
            VStack(spacing: 8) {
                Text(viewModel.authorName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(DesignTokens.Color.foreground)
                    .multilineTextAlignment(.center)

                // Stats Chips Row
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "book.fill")
                            .font(.caption2)
                        Text(viewModel.bookCountText)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(Capsule())

                    if viewModel.totalDuration > 0 {
                        HStack(spacing: 5) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                            Text(viewModel.totalDurationFormatted)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(DesignTokens.Color.foreground.opacity(0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(DesignTokens.Color.surface.opacity(0.15))
                        .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }

    private var initialsBadge: some View {
        Text(viewModel.initials)
            .font(.system(size: 34, weight: .bold, design: .rounded))
            .foregroundStyle(Color.accentColor)
    }

    // MARK: - Biography Card

    private func biographyCard(bio: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "person.text.rectangle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                Text("BIOGRAPHY")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                Spacer()
            }

            Text(bio)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.Color.foreground.opacity(0.85))
                .lineLimit(isBioExpanded ? nil : 4)
                .lineSpacing(3)

            if bio.count > 160 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isBioExpanded.toggle()
                    }
                } label: {
                    Text(isBioExpanded ? "Show Less" : "Read More")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.accentColor)
                }
                .padding(.top, 2)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Audiobooks Section

    private var sortedBooks: [Book] {
        switch sortOption {
        case .title:
            return viewModel.books.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .duration:
            return viewModel.books.sorted { $0.duration > $1.duration }
        case .year:
            return viewModel.books.sorted { ($0.media.metadata.publishedYear ?? "") > ($1.media.metadata.publishedYear ?? "") }
        }
    }

    private var audiobooksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("AUDIOBOOKS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
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
                Text("\(viewModel.books.count)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Color.accentColor)
                    Text("Loading author audiobooks...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .glassCard(cornerRadius: 16)
            } else if viewModel.books.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary.opacity(0.6))
                        .padding(.top, 8)
                    Text("No audiobooks found in this library")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .glassCard(cornerRadius: 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(sortedBooks) { book in
                        bookRow(book: book)
                    }
                }
            }
        }
    }

    private func bookRow(book: Book) -> some View {
        Button {
            selectedBook = book
        } label: {
            HStack(spacing: 14) {
                // Cover Art Thumbnail
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
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

                // Title & Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignTokens.Color.foreground)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        // Duration
                        if book.duration > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text(formatDuration(book.duration))
                                    .font(.caption2)
                            }
                            .foregroundStyle(.secondary)
                        }

                        // Series sequence if available
                        if let series = book.seriesName, !series.isEmpty {
                            Text(series)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Color.accentColor)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.12))
                                .clipShape(Capsule())
                                .lineLimit(1)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary.opacity(0.6))
            }
            .padding(12)
            .glassCard(cornerRadius: 14)
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

