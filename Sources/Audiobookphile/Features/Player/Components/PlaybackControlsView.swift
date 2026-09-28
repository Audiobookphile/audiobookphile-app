//
//  PlaybackControlsView.swift
//  Audiobookphile
//

import SwiftUI

public struct PlaybackControlsView: View {
    var viewModel: AudioPlayerViewModel
    var coverIsLight: Bool
    var isUiLocked: Bool

    public init(viewModel: AudioPlayerViewModel, coverIsLight: Bool, isUiLocked: Bool) {
        self.viewModel = viewModel
        self.coverIsLight = coverIsLight
        self.isUiLocked = isUiLocked
    }

    // Valid SF Symbol jump-time suffixes (system icons exist for these values)
    private static let validJumpTimes: Set<Int> = [5, 10, 15, 30, 45, 60, 75, 90]

    private func jumpIcon(direction: String, time: Int) -> String {
        let safeTime = Self.validJumpTimes.contains(time) ? time : 15
        return "\(direction).\(safeTime)"
    }

    public var body: some View {
        HStack(spacing: 0) {
            GlassIconButton(
                icon: "backward.end.fill",
                size: .medium,
                color: coverIsLight ? .black : .white,
                action: {
                    triggerHaptic(isLight: true)
                    viewModel.jumpToChapterStart()
                }
            )
            // The lock is applied to EVERY transport control, not just the two jump
            // buttons it was originally wired to. Chapter navigation and
            // play/pause stayed live while locked, so "Lock Controls" -- whose whole
            // purpose is not mis-touching playback -- did not actually lock
            // playback.
            .disabled(isUiLocked)
            .opacity(isUiLocked ? 0.3 : 1.0)

            Spacer()

            GlassIconButton(
                icon: jumpIcon(direction: "gobackward", time: viewModel.jumpBackwardTime),
                size: .medium,
                color: coverIsLight ? .black : .white,
                action: {
                    triggerHaptic(isLight: true)
                    viewModel.jumpBackward()
                }
            )
            .disabled(isUiLocked)
            .opacity(isUiLocked ? 0.3 : 1.0)

            Spacer()

            playPauseButton

            Spacer()

            GlassIconButton(
                icon: jumpIcon(direction: "goforward", time: viewModel.jumpForwardTime),
                size: .medium,
                color: coverIsLight ? .black : .white,
                action: {
                    triggerHaptic(isLight: true)
                    viewModel.jumpForward()
                }
            )
            .disabled(isUiLocked)
            .opacity(isUiLocked ? 0.3 : 1.0)

            Spacer()

            GlassIconButton(
                icon: "forward.end.fill",
                size: .medium,
                color: coverIsLight ? .black : .white,
                action: {
                    triggerHaptic(isLight: true)
                    viewModel.jumpToNextChapter()
                }
            )
            .opacity(isUiLocked || !viewModel.hasNextChapter ? 0.3 : 1.0)
            .disabled(isUiLocked || !viewModel.hasNextChapter)
        }
    }

    private func triggerHaptic(isLight: Bool = false) {
        #if os(iOS) && !SKIP
        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = isLight ? .light : .medium
        UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
        #endif
    }

    private var playPauseButton: some View {
        Button {
            triggerHaptic()
            viewModel.togglePlayPause()
        } label: {
            ZStack {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.black)
                    .applyPlayPauseSymbolEffect(isPlaying: viewModel.isPlaying)
                    .opacity(viewModel.isBuffering ? 0.3 : 1.0)
                if viewModel.isBuffering {
                    ProgressView()
                        .tint(.black)
                }
            }
            .frame(width: 76, height: 76)
            .background {
                Circle()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
            }
            .overlay {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.6), .white.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(viewModel.isPlaying ? "Pause" : "Play"))
        .accessibilityAddTraits(.isButton)
        // Play/pause is the control most likely to be hit by accident, and it was
        // the one most conspicuously still live while locked.
        .disabled(isUiLocked)
        .opacity(isUiLocked ? 0.3 : 1.0)
    }
}
