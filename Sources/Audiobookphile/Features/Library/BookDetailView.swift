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
        .task {
            await viewModel.fetchDetails(appState: appState)
        }
    }

    // MARK: - Background Layer

    private var backgroundLayer: some View {
        FluidAuraBackground(baseColor: viewModel.colorLoader.isLoaded ? viewModel.colorLoader.backgroundColor.opacity(0.3) : nil)
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
            BookDetailHeader(detailed: detailed, appState: appState, viewModel: viewModel) { author in
                selectedAuthorName = author
            }

            // Play & Download Actions
            BookActionRow(detailed: detailed, viewModel: viewModel)

            // Missing Files Warning
            if detailed.isMissing == true {
                missingFilesWarning
            }

            // Metadata Stats Row
            BookDetailStatsRow(detailed: detailed, viewModel: viewModel) { series in
                selectedSeriesName = series
            }

            // Description (Expandable)
            if let description = detailed.description, !description.isEmpty {
                BookDetailDescriptionSection(text: description, viewModel: viewModel)
            }

            // AudioBooth Metadata Section
            BookDetailMetadataSection(detailed: detailed, viewModel: viewModel)

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


}
