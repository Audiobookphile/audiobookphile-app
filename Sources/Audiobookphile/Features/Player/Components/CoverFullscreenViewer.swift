//
//  CoverFullscreenViewer.swift
//  Audiobookphile
//

import SwiftUI

public struct CoverFullscreenViewer: View {
    public let title: String
    public let author: String?
    public let coverURL: URL?
    public let onDismiss: () -> Void

    public init(
        title: String,
        author: String? = nil,
        coverURL: URL? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.author = author
        self.coverURL = coverURL
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                // Top Header bar with dismiss button
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        if let author, !author.isEmpty {
                            Text(author)
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    Button {
                        DesignTokens.Haptics.selection()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 26))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close cover preview")
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                // Large Artwork
                if let url = coverURL {
                    SmartAsyncImage(url: url) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: .black.opacity(0.8), radius: 32, y: 16)
                    } placeholder: {
                        ProgressView()
                            .tint(.white)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 520)
                    .padding(.horizontal, 16)
                } else {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 96))
                        .foregroundStyle(.white.opacity(0.3))
                }

                Spacer()

                Text("Tap anywhere to close")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.bottom, 24)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            DesignTokens.Haptics.selection()
            onDismiss()
        }
    }
}

