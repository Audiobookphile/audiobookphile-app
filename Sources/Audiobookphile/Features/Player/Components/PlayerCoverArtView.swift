//
//  PlayerCoverArtView.swift
//  Audiobookphile
//

import SwiftUI

public struct PlayerCoverArtView: View {
    var viewModel: AudioPlayerViewModel
    var coverURL: URL?
    var backgroundColor: Color
    @State private var isShowingFullscreenCover = false

    public init(viewModel: AudioPlayerViewModel, coverURL: URL?, backgroundColor: Color) {
        self.viewModel = viewModel
        self.coverURL = coverURL
        self.backgroundColor = backgroundColor
    }

    public var body: some View {
        GeometryReader { geometry in
            let cardSide = min(geometry.size.width * 0.76, geometry.size.height * 0.9)
            ZStack {
                if let url = coverURL {
                    // AudioBooth signature background blur backdrop
                    SmartAsyncImage(url: url, maxPixelSize: CoverDecodeBudget.player) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        backgroundColor
                    }
                    .frame(width: cardSide, height: cardSide)
                    .blur(radius: 12, opaque: true)
                    .opacity(0.4)

                    // AudioBooth unclipped foreground artwork (.fit)
                    SmartAsyncImage(url: url, maxPixelSize: CoverDecodeBudget.player) { image in
                        image
                            .resizable()
                            .scaledToFit()
                    } placeholder: {
                        placeholderCover
                    }
                } else {
                    placeholderCover
                }
            }
            .frame(width: cardSide, height: cardSide)
            .clipped()
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            // AudioBooth signature topLeading Progress Badge
            .overlay(alignment: .topLeading) {
                let p = (viewModel.progress.isNaN || viewModel.progress.isInfinite) ? 0.0 : viewModel.progress
                let progPercent = Int(min(1.0, max(0.0, p)) * 100)
                audiobookphileBadge(text: "\(progPercent)%")
                    .padding(8)
            }
            // AudioBooth signature topTrailing Sleep Timer Badge (if active)
            .overlay(alignment: .topTrailing) {
                if viewModel.sleepTimerActive {
                    audiobookphileBadge(icon: "timer", text: viewModel.sleepTimerRemainingPretty)
                        .padding(8)
                }
            }
            .scaleEffect(viewModel.isPlaying ? 1.02 : 0.96)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: viewModel.isPlaying)
            .shadow(
                color: backgroundColor.opacity(0.55),
                radius: 35,
                y: 18
            )
            .contentShape(Rectangle())
            .onTapGesture {
                DesignTokens.Haptics.selection()
                isShowingFullscreenCover = true
            }
        }
        .frame(height: 280)
        .sheet(isPresented: $isShowingFullscreenCover) {
            CoverFullscreenViewer(
                title: viewModel.title,
                author: viewModel.author,
                coverURL: coverURL,
                onDismiss: { isShowingFullscreenCover = false }
            )
        }
    }

    private func audiobookphileBadge(icon: String? = nil, text: String) -> some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
            }
            Text(text)
        }
        .font(.footnote)
        .fontWeight(.bold)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.75))
        .foregroundColor(.white)
        .clipShape(Capsule())
    }

    private var placeholderCover: some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            backgroundColor.opacity(0.8),
                            DesignTokens.Color.surface
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(spacing: 12) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(DesignTokens.Color.foreground.opacity(0.6))
                
                Text(viewModel.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(DesignTokens.Color.foreground.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}
