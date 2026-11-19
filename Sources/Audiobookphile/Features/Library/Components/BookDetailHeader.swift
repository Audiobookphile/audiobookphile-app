//
//  BookDetailHeader.swift
//  Audiobookphile
//

import SwiftUI

public struct BookDetailHeader: View {
    public let detailed: Book
    public let appState: AppState
    // Read-only access — no property mutation, so @Bindable is not needed
    public let viewModel: BookDetailViewModel
    public var onAuthorTap: ((String) -> Void)?
    public var onNarratorTap: ((String) -> Void)?
    @State private var isShowingCoverPreview = false

    public init(
        detailed: Book,
        appState: AppState,
        viewModel: BookDetailViewModel,
        onAuthorTap: ((String) -> Void)? = nil,
        onNarratorTap: ((String) -> Void)? = nil
    ) {
        self.detailed = detailed
        self.appState = appState
        self.viewModel = viewModel
        self.onAuthorTap = onAuthorTap
        self.onNarratorTap = onNarratorTap
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Large Cover Art
            coverArtSection
                .contentShape(Rectangle())
                .onTapGesture {
                    DesignTokens.Haptics.selection()
                    isShowingCoverPreview = true
                }

            // Title & Authors
            VStack(spacing: 6) {
                Text(detailed.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(DesignTokens.Color.foreground)

                if let author = detailed.author, !author.isEmpty, author != "Unknown Author" {
                    Button {
                        onAuthorTap?(author)
                    } label: {
                        HStack(spacing: 4) {
                            Text("by \(author)")
                                .font(.headline)
                                .foregroundStyle(Color.appPrimary)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color.appPrimary.opacity(0.7))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("View author \(author)")
                }

                if let narrator = detailed.media.metadata.narratorName, !narrator.isEmpty {
                    if let onNarratorTap {
                        Button {
                            DesignTokens.Haptics.selection()
                            onNarratorTap(narrator)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "mic.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.appPrimary.opacity(0.8))
                                Text("Narrated by \(narrator)")
                                    .font(.subheadline)
                                    .foregroundStyle(DesignTokens.Color.foreground.opacity(0.85))
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.appPrimary.opacity(0.7))
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("View narrator \(narrator)")
                    } else {
                        Text("Narrated by \(narrator)")
                            .font(.subheadline)
                            .foregroundStyle(DesignTokens.Color.foreground.opacity(0.65))
                            .multilineTextAlignment(.center)
                    }
                }

                if detailed.media.metadata.abridged == true || detailed.media.metadata.explicit {
                    HStack(spacing: 8) {
                        if detailed.media.metadata.abridged == true {
                            Text("ABRIDGED")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(DesignTokens.Color.foreground.opacity(0.85))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(DesignTokens.Color.surface.opacity(0.18))
                                .clipShape(Capsule())
                        }
                        if detailed.media.metadata.explicit {
                            HStack(spacing: 4) {
                                Image(systemName: "e.square.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text("EXPLICIT")
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .foregroundStyle(Color.red.opacity(0.9))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red.opacity(0.12))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .sheet(isPresented: $isShowingCoverPreview) {
            CoverFullscreenViewer(
                title: detailed.title,
                author: detailed.author,
                coverURL: appState.getCoverURL(itemId: detailed.id, width: 1200, updatedAt: detailed.updatedAt),
                onDismiss: { isShowingCoverPreview = false }
            )
        }
    }

    private var coverArtSection: some View {
        let coverURL = appState.getCoverURL(itemId: detailed.id, width: 600, updatedAt: detailed.updatedAt)
        return SmartAsyncImage(url: coverURL) { image in
            image
                .resizable()
                .scaledToFit()
        } placeholder: {
            placeholderCover
        }
        .frame(width: 260, height: 260)
        .background {
            SmartAsyncImage(url: coverURL) { image in
                image
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 10)
                    .opacity(0.4)
            } placeholder: {
                Color.appSecondaryBackground
            }
        }
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            DesignTokens.Color.surface.opacity(0.4),
                            DesignTokens.Color.surface.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        )
        .shadow(color: viewModel.colorLoader.backgroundColor.opacity(0.55), radius: 24, x: 0, y: 12)
    }

    private var placeholderCover: some View {
        ZStack {
            Image("BookPlaceholder", bundle: .module)
                .resizable()
                .scaledToFill()

            DesignTokens.Color.background.opacity(0.15)
        }
        .frame(width: 260, height: 260)
    }
}
