//
//  SeriesDetailView.swift
//  Audiobookphile
//
//  Liquid Glass Series Detail view displaying chronological series books, sequence badges, and stats.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

public struct SeriesDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    @State private var viewModel: SeriesDetailViewModel
    @State private var selectedBook: Book?
    @State private var selectedAuthorName: String?

    public init(seriesName: String, libraryId: String? = nil, service: LibraryServiceProtocol? = nil) {
        self._viewModel = State(wrappedValue: SeriesDetailViewModel(
            seriesName: seriesName,
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
                        // Series Hero Header
                        heroHeader

                        // Series Description (if present)
                        if let desc = viewModel.seriesSummary?.description, !desc.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            descriptionCard(desc: desc)
                        }

                        // Sequenced Books Section
                        booksSection

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle(viewModel.seriesName)
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
            .sheet(item: Binding(
                get: { selectedAuthorName.map { AuthorSheetWrapper(name: $0) } },
                set: { selectedAuthorName = $0?.name }
            )) { wrapper in
                AuthorDetailView(authorName: wrapper.name, libraryId: viewModel.libraryId)
            }
            .task {
                await viewModel.loadSeries()
            }
        }
    }

    // MARK: - Hero Header

    private var heroHeader: some View {
        VStack(spacing: 16) {
            // Series Icon Badge
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.3), Color.appPrimary.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 88, height: 88)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1.5)
                    )

                Image(systemName: "books.vertical.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(Color.accentColor)
            }
            .shadow(color: Color.accentColor.opacity(0.2), radius: 12, x: 0, y: 6)

            // Series Name & Author
            VStack(spacing: 6) {
                Text(viewModel.seriesName)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(DesignTokens.Color.foreground)
                    .multilineTextAlignment(.center)

                if let author = viewModel.primaryAuthor, !author.isEmpty {
                    Button {
                        selectedAuthorName = author
                    } label: {
                        HStack(spacing: 4) {
                            Text("by \(author)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(Color.appPrimary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Color.appPrimary.opacity(0.7))
                        }
                    }
                    .buttonStyle(.plain)
                }

                // Stats Chips Row
                HStack(spacing: 8) {
                    HStack(spacing: 5) {
                        Image(systemName: "number.square.fill")
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
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Description Card

    private func descriptionCard(desc: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                Text("SERIES OVERVIEW")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                Spacer()
            }

            Text(desc)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.Color.foreground.opacity(0.85))
                .lineSpacing(3)
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Books Section

    private var booksSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("SERIES SEQUENCE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.books.count) books")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(Color.accentColor)
                    Text("Loading series sequence...")
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
                    Text("No books found for this series in library")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .glassCard(cornerRadius: 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(viewModel.books.enumerated()), id: \.element.id) { index, book in
                        seriesBookRow(index: index + 1, book: book)
                    }
                }
            }
        }
    }

    private func seriesBookRow(index: Int, book: Book) -> some View {
        Button {
            selectedBook = book
        } label: {
            HStack(spacing: 14) {
                // Sequence Number Badge
                Text("#\(index)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 30, height: 30)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Circle())

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
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )

                // Title & Duration
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignTokens.Color.foreground)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    if book.duration > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                            Text(formatDuration(book.duration))
                                .font(.caption2)
                        }
                        .foregroundStyle(.secondary)
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

public struct AuthorSheetWrapper: Identifiable {
    public let id = UUID()
    public let name: String

    public init(name: String) {
        self.name = name
    }
}

public struct SeriesSheetWrapper: Identifiable {
    public let id = UUID()
    public let name: String

    public init(name: String) {
        self.name = name
    }
}
