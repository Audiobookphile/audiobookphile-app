import SwiftUI
import Observation

// MARK: - Mini Player View

public struct MiniPlayerView: View {
    let audioPlayer: AudioPlayerService
    let onTap: () -> Void
    let onClose: () -> Void

    @State private var dragOffset: CGSize = .zero

    public init(audioPlayer: AudioPlayerService, onTap: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.audioPlayer = audioPlayer
        self.onTap = onTap
        self.onClose = onClose
    }

    private var coverURL: URL? {
        guard let itemId = audioPlayer.session?.libraryItemId else { return nil }
        return AppState.shared.getCoverURL(itemId: itemId)
    }

    public var body: some View {
        VStack(spacing: 0) {
        HStack {
            Color.clear
                .frame(width: 44, height: 44)
                .overlay {
                    SmartAsyncImage(url: coverURL, maxPixelSize: CoverDecodeBudget.thumbnail) { image in
                        image
                            .resizable()
                            .scaledToFill()
                    } placeholder: {
                        Image("BookPlaceholder", bundle: .module)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: DesignTokens.Color.surface.opacity(0.3), radius: 4, x: 0, y: 2)

            VStack(alignment: .leading, spacing: 2) {
                Text(audioPlayer.session?.displayTitle ?? "Audiobook")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(audioPlayer.session?.displayAuthor ?? "")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            GlassIconButton(
                icon: audioPlayer.isPlaying ? "pause.fill" : "play.fill",
                fill: true,
                size: .small,
                color: .primary,
                label: audioPlayer.isPlaying ? "Pause" : "Play",
                action: {
                    audioPlayer.togglePlayPause()
                }
            )
            .padding(.trailing, 2)

            GlassIconButton(
                icon: [5, 10, 15, 30, 45, 60, 75, 90].contains(AppState.shared.settings.jumpForwardTime)
                    ? "goforward.\(AppState.shared.settings.jumpForwardTime)"
                    : "goforward.30",
                fill: false,
                size: .small,
                color: .secondary,
                action: {
                    audioPlayer.skipForward(AppState.shared.settings.jumpForwardTime)
                }
            )

            GlassIconButton(
                icon: "xmark",
                fill: false,
                size: .small,
                color: .secondary,
                label: "Close player",
                action: {
                    onClose()
                }
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contextMenu {
            Button(role: .destructive) {
                onClose()
            } label: {
                Label("Stop Playback", systemImage: "xmark.circle")
            }
        }

        // Glowing Progress Bar
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.appBackground.opacity(0.12))

                Rectangle()
                    .fill(
                        LinearGradient(colors: [.appPrimary, .appAccent], startPoint: .leading, endPoint: .trailing)
                    )
                    .frame(width: max(0, min(geometry.size.width, geometry.size.width * CGFloat(audioPlayer.duration > 0 ? audioPlayer.currentTime / audioPlayer.duration : 0))))
                    .shadow(color: DesignTokens.Color.accent.opacity(0.6), radius: 4)
            }
        }
        .frame(height: 3)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: DesignTokens.Color.surface.opacity(0.35), radius: 16, x: 0, y: 8)
        .overlay(content: {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [DesignTokens.Color.foreground.opacity(0.35), DesignTokens.Color.foreground.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        })
        .padding(.horizontal, 12)
        .offset(x: dragOffset.width * 0.45, y: max(0, dragOffset.height * 0.7))
        .gesture(
            DragGesture(minimumDistance: 15)
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    let hTranslation = value.translation.width
                    let vTranslation = value.translation.height

                    // Downward swipe dismisses/stops player
                    if vTranslation > 60 && abs(vTranslation) > abs(hTranslation) {
                        DesignTokens.Haptics.medium()
                        onClose()
                    } else if hTranslation < -50 {
                        // Swipe Left -> Skip Forward
                        DesignTokens.Haptics.light()
                        audioPlayer.skipForward(AppState.shared.settings.jumpForwardTime)
                    } else if hTranslation > 50 {
                        // Swipe Right -> Skip Backward
                        DesignTokens.Haptics.light()
                        audioPlayer.skipBackward(AppState.shared.settings.jumpBackwardsTime)
                    }

                    withAnimation(DesignTokens.Spring.snappy) {
                        dragOffset = .zero
                    }
                }
        )
        .liquidPressable()
        .onTapGesture {
            onTap()
        }
    }
}
