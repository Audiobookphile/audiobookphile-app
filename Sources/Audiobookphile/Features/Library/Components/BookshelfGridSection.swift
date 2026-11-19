import SwiftUI
import Observation

public struct BookshelfGridSection: View {
    @Bindable var viewModel: BookshelfViewModel
    @Environment(AppState.self) private var appState
    @Binding var selectedBookForDetails: Book?
    var isListView: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !viewModel.isLoading && viewModel.filteredBooks.isEmpty && viewModel.errorMessage == nil {
                emptyStateView
            } else if isListView {
                LazyVStack(spacing: 10) {
                    if (appState.isLoading || viewModel.isLoading) && viewModel.filteredBooks.isEmpty {
                        ForEach(0..<12, id: \.self) { _ in
                            BookCardSkeleton()
                        }
                    } else {
                        ForEach(viewModel.filteredBooks) { book in
                            BookshelfListRow(
                                book: book,
                                onTap: {
                                    selectedBookForDetails = book
                                },
                                onToggleFinished: {
                                    Task {
                                        await viewModel.toggleFinished(for: book)
                                    }
                                }
                            )
                            .applyBookshelfScrollTransition()
                            .onAppear {
                                Task {
                                    await viewModel.loadNextPageIfNeeded(
                                        currentBook: book,
                                        libraryId: appState.currentLibraryId,
                                        isAuthenticated: appState.isAuthenticated
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 105, maximum: 160), spacing: 16)
                    ],
                    spacing: 24
                ) {
                    if (appState.isLoading || viewModel.isLoading) && viewModel.filteredBooks.isEmpty {
                        ForEach(0..<12, id: \.self) { _ in
                            BookCardSkeleton()
                        }
                    } else {
                        ForEach(viewModel.filteredBooks) { book in
                            BookCard(
                                book: book,
                                aspectRatio: viewModel.coverAspectRatio,
                                onTap: {
                                    selectedBookForDetails = book
                                },
                                onToggleFinished: {
                                    Task {
                                        await viewModel.toggleFinished(for: book)
                                    }
                                }
                            )
                            .applyBookshelfScrollTransition()
                            .onAppear {
                                Task {
                                    await viewModel.loadNextPageIfNeeded(
                                        currentBook: book,
                                        libraryId: appState.currentLibraryId,
                                        isAuthenticated: appState.isAuthenticated
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }

            if viewModel.isLoadingNextPage {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(DesignTokens.Color.accentSecondary)
                    Text("Loading more audiobooks...")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
            }

            if let errorMessage = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                    Text("Connection Failed")
                        .font(.headline)
                        .foregroundStyle(DesignTokens.Color.foreground)
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Log Out") {
                        AuthManager.shared.logout(appState: appState)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .padding(.top, 8)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .glassCard()
                .padding(.horizontal)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer().frame(height: 32)
            Circle()
                .fill(Color.appPrimary.opacity(0.12))
                .frame(width: 68, height: 68)
                .overlay {
                    Image(systemName: viewModel.selectedFilter.iconName)
                        .font(.system(size: 28))
                        .foregroundStyle(Color.appPrimary)
                }

            Text("No \(viewModel.selectedFilter.rawValue) Audiobooks")
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            Text(emptyFilterDescription)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            if viewModel.selectedFilter != .all || !viewModel.filterSearchText.isEmpty {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        viewModel.resetFilters()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset Filters")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.appPrimary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.appPrimary.opacity(0.12))
                    )
                }
                .padding(.top, 4)
            }

            Spacer().frame(height: 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
    }

    private var emptyFilterDescription: String {
        if !viewModel.filterSearchText.isEmpty {
            return "No titles, authors, or series match \"\(viewModel.filterSearchText)\"."
        }
        switch viewModel.selectedFilter {
        case .all:
            return "This library is currently empty. Add audiobooks to your server to start listening."
        case .inProgress:
            return "You haven't started listening to any audiobooks in this library yet."
        case .notStarted:
            return "All audiobooks in this library have been started or completed."
        case .finished:
            return "No finished audiobooks yet. Completed titles will appear here."
        case .downloaded:
            return "No downloaded audiobooks found on this device for offline playback."
        case .series:
            return "No audiobooks with series metadata found in this library."
        }
    }
}

public struct BookshelfListRow: View {
    @Environment(AppState.self) private var appState
    public let book: Book
    public let onTap: () -> Void
    public var onToggleFinished: (() -> Void)? = nil
    var downloadService = DownloadService.shared

    public init(book: Book, onTap: @escaping () -> Void, onToggleFinished: (() -> Void)? = nil) {
        self.book = book
        self.onTap = onTap
        self.onToggleFinished = onToggleFinished
    }

    private var coverURL: URL? {
        if let path = book.coverPath {
            if path.hasPrefix("http") { return URL(string: path) }
        }
        return appState.getCoverURL(itemId: book.id, updatedAt: book.updatedAt)
    }

    private var isDownloaded: Bool {
        let downloads = downloadService.downloads
        let targetId = book.id
        return downloads.contains { item in
            item.libraryItemId == targetId && item.status == .completed
        }
    }

    public var body: some View {
        Button(action: onTap) {
            GlassCard {
                HStack(spacing: 12) {
                    // Cover Thumbnail
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.appSecondaryBackground)
                            .frame(width: 52, height: 52)

                        if let url = coverURL {
                            SmartAsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                            } placeholder: {
                                Image(systemName: "book.closed.fill")
                                    .foregroundStyle(Color.appPrimary.opacity(0.6))
                            }
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            Image(systemName: "book.closed.fill")
                                .foregroundStyle(Color.appPrimary.opacity(0.6))
                        }
                    }

                    // Book Info
                    VStack(alignment: .leading, spacing: 3) {
                        Text(book.title)
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if let author = book.author, !author.isEmpty {
                            Text(author)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        HStack(spacing: 6) {
                            if book.duration > 0 {
                                Text(formatDuration(book.duration))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }

                            if let series = book.seriesName, !series.isEmpty {
                                Text("•")
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                                Text(series)
                                    .font(.caption2)
                                    .foregroundStyle(Color.appPrimary)
                                    .lineLimit(1)
                            }

                            if let progress = book.userMediaProgress, progress.progress > 0 && !progress.isFinished {
                                Text("• \(Int(progress.progress * 100))%")
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color.appPrimary)
                            } else if book.userMediaProgress?.isFinished == true {
                                Text("• Finished")
                                    .font(.caption2.bold())
                                    .foregroundStyle(Color.green)
                            }
                        }
                    }

                    Spacer()

                    if isDownloaded {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption)
                            .foregroundStyle(Color.appPrimary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption2.bold())
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 2)
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onTap()
            } label: {
                Label("View Details", systemImage: "info.circle")
            }

            Button {
                Task {
                    if let session = try? await AudiobookphileAPI.shared.startPlaybackSession(libraryItemId: book.id) {
                        AudioPlayerService.shared.startPlayback(session: session)
                    }
                }
            } label: {
                Label("Play", systemImage: "play.fill")
            }

            Button {
                Task {
                    if let session = try? await AudiobookphileAPI.shared.startPlaybackSession(libraryItemId: book.id) {
                        AudioPlayerService.shared.playNextInPlaybackQueue(session: session)
                    }
                }
            } label: {
                Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
            }

            Button {
                Task {
                    if let session = try? await AudiobookphileAPI.shared.startPlaybackSession(libraryItemId: book.id) {
                        AudioPlayerService.shared.addToPlaybackQueue(session: session)
                    }
                }
            } label: {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }

            if let onToggleFinished = onToggleFinished {
                Divider()
                Button {
                    onToggleFinished()
                } label: {
                    if book.userMediaProgress?.isFinished == true {
                        Label("Mark as Not Finished", systemImage: "arrow.counterclockwise")
                    } else {
                        Label("Mark as Finished", systemImage: "checkmark.circle")
                    }
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = Int(max(0, duration))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
