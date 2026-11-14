//
//  BookCard.swift
//  Audiobookphile
//
//  Book card component with Liquid Glass design.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

/// Book card for library grid display
public struct BookCard: View {
    @Environment(AppState.self) private var appState
    let book: Book
    public var aspectRatio: CGFloat = 1.0
    public let onTap: () -> Void
    @State var coverColor: Color = .gray
    var proMotion = ProMotionManager.shared
    var downloadService = DownloadService.shared

    public init(book: Book, aspectRatio: CGFloat = 1.0, onTap: @escaping () -> Void) {
        self.book = book
        self.aspectRatio = aspectRatio
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                // Cover image with glass shadow
                coverImage

                // Book info
                VStack(alignment: .leading, spacing: 3) {
                    Text(book.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                        .foregroundStyle(Color.primary)
                        .multilineTextAlignment(.leading)

                    if let author = book.author, !author.isEmpty, author != "Unknown Author" {
                        Text(author)
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                            .lineLimit(1)
                    } else {
                        Text(" ")
                            .font(.caption)
                            .hidden()
                    }

                    Spacer(minLength: 0)

                    // Progress indicator
                    if let progress = book.userMediaProgress {
                        progressBar(progress: progress.progress)
                    } else {
                        Color.clear
                            .frame(height: 4)
                    }
                }
                .frame(height: 68, alignment: .topLeading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.liquid)
    }

    // MARK: - Cover Image

    private var coverImage: some View {
        ZStack(alignment: .topTrailing) {
            Color.clear
                .aspectRatio(aspectRatio, contentMode: .fit)
                .background {
                    if let url = coverURL {
                        SmartAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                                .blur(radius: 6)
                                .opacity(0.35)
                        } placeholder: {
                            Color.appSecondaryBackground
                        }
                    } else {
                        Color.appSecondaryBackground
                    }
                }
                .overlay {
                    if let url = coverURL {
                        SmartAsyncImage(url: url) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            placeholderCover
                        }
                    } else {
                        placeholderCover
                    }
                }
                .clipped()

            // Badges
            Group {
                if let activeDownload = downloadService.downloads.first(where: { $0.libraryItemId == book.id }) {
                    CircularDownloadProgressBadge(progress: activeDownload.progress, status: activeDownload.status)
                } else if isDownloaded {
                    CircularDownloadProgressBadge(status: .completed)
                } else if book.isMissing == true {
                    missingBadge
                }
            }
            .padding(8)

            // Metadata Badges (Abridged / Explicit)
            if book.media.metadata.abridged == true || book.media.metadata.explicit {
                VStack {
                    Spacer()
                    HStack(spacing: 4) {
                        if book.media.metadata.abridged == true {
                            Text("ABRIDGED")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2.5)
                                .background(.black.opacity(0.75))
                                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        }
                        if book.media.metadata.explicit {
                            Text("E")
                                .font(.system(size: 8, weight: .heavy))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2.5)
                                .background(Color.red.opacity(0.85))
                                .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                        }
                        Spacer()
                    }
                    .padding(6)
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.step1, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [DesignTokens.Color.foreground.opacity(0.3), DesignTokens.Color.foreground.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(
            color: (coverColor == .gray ? Color.appPrimary : coverColor).opacity(0.35),
            radius: 14,
            x: 0,
            y: 8
        )
    }

    private var placeholderCover: some View {
        ZStack {
            Color.white.opacity(0.08)

            Image(systemName: "book.fill")
                .font(.largeTitle)
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    private var downloadBadge: some View {
        Image(systemName: "arrow.down.circle.fill")
            .font(.title3)
            .foregroundStyle(DesignTokens.Color.foreground)
            .padding(4)
            .background {
                Circle()
                    .fill(
                        LinearGradient(colors: [.appSecondary, .appPrimary], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            .background(.ultraThinMaterial, in: Circle())
            .shadow(color: .green.opacity(0.5), radius: 6, x: 0, y: 2)
    }

    private var missingBadge: some View {
        Image(systemName: "exclamationmark.triangle.fill")
            .font(.title3)
            .foregroundStyle(DesignTokens.Color.foreground)
            .padding(4)
            .background {
                Circle()
                    .fill(
                        LinearGradient(colors: [.appAccent, .appSecondary], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
            }
            .background(.ultraThinMaterial, in: Circle())
            .shadow(color: .red.opacity(0.5), radius: 6, x: 0, y: 2)
    }

    // MARK: - Progress Bar

    private func progressBar(progress: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Capsule()
                    .fill(.white.opacity(0.15))
                    .frame(height: 4)

                // Progress
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.appPrimary, .appAccent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(
                        width: geometry.size.width * progress,
                        height: 4
                    )
                    .shadow(color: Color.cyan.opacity(0.5), radius: 4)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Helpers

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
}
