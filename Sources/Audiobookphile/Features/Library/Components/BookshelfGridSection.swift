import SwiftUI
import Observation

public struct BookshelfGridSection: View {
    @Bindable var viewModel: BookshelfViewModel
    @Environment(AppState.self) private var appState
    @Binding var selectedBookForDetails: Book?

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if !viewModel.isLoading && viewModel.filteredBooks.isEmpty && viewModel.errorMessage == nil {
                emptyStateView
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
