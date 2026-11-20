//
//  BookDetailView.swift
//  Audiobookphile
//
//  Detailed book view with premium Liquid Glass design, metadata, and chapters.
//

import SwiftUI

public struct BookDetailView: View {
    @State var viewModel: BookDetailViewModel
    @State private var selectedAuthorName: String?
    @State private var selectedSeriesName: String?
    @State private var selectedNarratorInfo: SelectedNarratorInfo?
    @State private var isShowingMediaSpecsSheet = false
    @State private var navigatedBook: Book?
    @Environment(\.dismiss) var dismiss
    @Environment(AppState.self) private var appState

    public init(book: Book) {
        self._viewModel = State(wrappedValue: BookDetailViewModel(book: book))
    }

    public var body: some View {
        ZStack {
            // Background
            backgroundLayer

            ScrollView {
                VStack(spacing: 24) {
                    // Back / Close handle
                    dragHandle

                    if viewModel.isLoading {
                        loadingState
                    } else if let detailed = viewModel.detailedBook {
                        bookDetailsContent(detailed)
                    } else {
                        errorState
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
            }
        }
        .preferredColorScheme(appState.settings.theme.colorScheme)
        .alert("Playback Error", isPresented: $viewModel.showPlaybackError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.playbackError ?? "Unknown error")
        }
        .confirmationDialog(
            "Remove Download",
            isPresented: $viewModel.showRemoveDownloadConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Downloaded File", role: .destructive) {
                viewModel.removeDownload()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to remove this downloaded audiobook from your device?")
        }
        .sheet(item: Binding(
            get: { selectedAuthorName.map { AuthorSheetWrapper(name: $0) } },
            set: { selectedAuthorName = $0?.name }
        )) { wrapper in
            AuthorDetailView(authorName: wrapper.name, libraryId: viewModel.detailedBook?.libraryId)
        }
        .sheet(item: Binding(
            get: { selectedSeriesName.map { SeriesSheetWrapper(name: $0) } },
            set: { selectedSeriesName = $0?.name }
        )) { wrapper in
            SeriesDetailView(seriesName: wrapper.name, libraryId: viewModel.detailedBook?.libraryId)
        }
        .sheet(item: $selectedNarratorInfo) { info in
            NarratorDetailSheet(narratorName: info.name, books: info.books)
        }
        .sheet(isPresented: $isShowingMediaSpecsSheet) {
            if let detailed = viewModel.detailedBook {
                MediaSpecsSheet(detailed: detailed) {
                    isShowingMediaSpecsSheet = false
                }
            }
        }
        .sheet(item: $navigatedBook) { book in
            BookDetailView(book: book)
        }
        .task {
            await viewModel.fetchDetails(appState: appState)
        }
    }

    // MARK: - Background Layer

    private var backgroundLayer: some View {
        FluidAuraBackground(
            baseColor: viewModel.colorLoader.isLoaded ? viewModel.colorLoader.backgroundColor.opacity(0.3) : nil,
            accentColors: viewModel.colorLoader.isLoaded ? viewModel.colorLoader.gradientColors : nil
        )
        .animation(.easeInOut(duration: 0.8), value: viewModel.colorLoader.backgroundColor)
    }

    private var dragHandle: some View {
        Button {
            dismiss()
        } label: {
            Capsule()
                .fill(DesignTokens.Color.foreground.opacity(0.3))
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Close book details")
        .accessibilityHint("Closes the book details")
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 100)
            ProgressView()
                .tint(DesignTokens.Color.accent)
                .scaleEffect(1.5)
            Text("Fetching book details...")
                .font(.headline)
                .foregroundStyle(DesignTokens.Color.foreground.opacity(0.8))
            Spacer(minLength: 100)
        }
    }

    // MARK: - Error State

    private var errorState: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 100)
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(DesignTokens.Color.warning)
            Text("Failed to load details")
                .font(.headline)
                .foregroundStyle(DesignTokens.Color.foreground)
            Button("Retry") {
                Task {
                    await viewModel.fetchDetails(appState: appState)
                }
            }
            .padding()
            .background(DesignTokens.Color.surface.opacity(0.1))
            .clipShape(Capsule())
            Spacer(minLength: 100)
        }
    }

    // MARK: - Book Content

    private func bookDetailsContent(_ detailed: Book) -> some View {
        VStack(spacing: 24) {
            // Header: Large Cover Art, Title & Authors
            BookDetailHeader(
                detailed: detailed,
                appState: appState,
                viewModel: viewModel,
                onAuthorTap: { author in
                    selectedAuthorName = author
                },
                onNarratorTap: { narrator in
                    let candidates = ([detailed] + viewModel.similarBooks).filter {
                        $0.media.metadata.narratorName?.localizedCaseInsensitiveContains(narrator) == true
                    }
                    var uniqueBooks: [Book] = []
                    var seenIds = Set<String>()
                    for b in (candidates.isEmpty ? [detailed] : candidates) {
                        if !seenIds.contains(b.id) {
                            seenIds.insert(b.id)
                            uniqueBooks.append(b)
                        }
                    }
                    selectedNarratorInfo = SelectedNarratorInfo(
                        name: narrator,
                        books: uniqueBooks
                    )
                }
            )

            // Play & Download Actions
            BookActionRow(detailed: detailed, viewModel: viewModel)

            // Missing Files Warning
            if detailed.isMissing == true {
                missingFilesWarning
            }

            // Metadata Stats Row
            BookDetailStatsRow(
                detailed: detailed,
                viewModel: viewModel,
                onSeriesTap: { series in
                    selectedSeriesName = series
                },
                onSpecsTap: {
                    isShowingMediaSpecsSheet = true
                }
            )

            // Series Continuity (Previous & Next book in series)
            seriesContinuitySection(detailed)

            // Description (Expandable)
            if let description = detailed.description, !description.isEmpty {
                BookDetailDescriptionSection(text: description, viewModel: viewModel)
            }

            // AudioBooth Metadata Section
            BookDetailMetadataSection(detailed: detailed, viewModel: viewModel)

            // Audio Tracks & Files (Expandable inspection table)
            if !detailed.audioFiles.isEmpty {
                BookDetailAudioTracksSection(detailed: detailed)
            }

            // Chapters List
            if !detailed.chapters.isEmpty {
                ChapterListView(detailed: detailed, viewModel: viewModel)
            }

            // Similar Books
            if !viewModel.similarBooks.isEmpty {
                BookDetailSimilarBooksSection(viewModel: viewModel)
            }
        }
    }

    private var missingFilesWarning: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(DesignTokens.Color.error)

            VStack(alignment: .leading, spacing: 4) {
                Text("Missing Audio Files")
                    .font(.headline)
                    .foregroundStyle(DesignTokens.Color.foreground)
                Text("The audio files for this book are missing from the server. Playback and downloads are unavailable.")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.Color.foreground.opacity(0.8))
            }
        }
        .padding()
        .background(DesignTokens.Color.error.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(DesignTokens.Color.error.opacity(0.5), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func seriesContinuitySection(_ detailed: Book) -> some View {
        if viewModel.previousInSeries != nil || viewModel.nextInSeries != nil {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.appPrimary)
                    Text("SERIES CONTINUITY")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DesignTokens.Color.foreground.opacity(0.7))
                        .tracking(0.5)
                }

                HStack(spacing: 12) {
                    if let prev = viewModel.previousInSeries {
                        Button {
                            DesignTokens.Haptics.selection()
                            navigatedBook = prev
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.appPrimary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("PREVIOUS")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(.secondary)
                                    Text(prev.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(DesignTokens.Color.foreground)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .glassCard(cornerRadius: 12)
                        }
                        .buttonStyle(.plain)
                    }

                    if let next = viewModel.nextInSeries {
                        Button {
                            DesignTokens.Haptics.selection()
                            navigatedBook = next
                        } label: {
                            HStack(spacing: 8) {
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("NEXT IN SERIES")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundStyle(Color.appPrimary)
                                    Text(next.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(DesignTokens.Color.foreground)
                                        .lineLimit(1)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(Color.appPrimary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .glassCard(cornerRadius: 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}
