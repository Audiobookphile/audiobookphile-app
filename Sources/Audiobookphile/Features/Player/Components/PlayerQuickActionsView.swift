//
//  PlayerQuickActionsView.swift
//  Audiobookphile
//

import SwiftUI

public struct PlayerQuickActionsView: View {
    var viewModel: AudioPlayerViewModel
    var coverIsLight: Bool

    @Binding var showAddBookmark: Bool
    @Binding var showBookmarksList: Bool
    @Binding var showSleepTimer: Bool
    @Binding var showAudioAccessibilitySheet: Bool
    @Binding var showChapters: Bool
    @Binding var showAIInsights: Bool

    /// When the player's Lock Controls toggle is on, this whole row is inert.
    ///
    /// Deliberately NOT defaulted. A defaulted `isUiLocked: Bool = false` compiles
    /// at any call site that forgets it, which is precisely how the transport
    /// controls ended up half-locked in the first place: the flag reached two of
    /// the six controls it was meant to cover. Required means a new or edited call
    /// site that omits it fails to build instead of silently unlocking.
    var isUiLocked: Bool

    public init(
        viewModel: AudioPlayerViewModel,
        coverIsLight: Bool,
        isUiLocked: Bool,
        showAddBookmark: Binding<Bool>,
        showBookmarksList: Binding<Bool>,
        showSleepTimer: Binding<Bool>,
        showAudioAccessibilitySheet: Binding<Bool>,
        showChapters: Binding<Bool>,
        showAIInsights: Binding<Bool>
    ) {
        self.viewModel = viewModel
        self.coverIsLight = coverIsLight
        self.isUiLocked = isUiLocked
        self._showAddBookmark = showAddBookmark
        self._showBookmarksList = showBookmarksList
        self._showSleepTimer = showSleepTimer
        self._showAudioAccessibilitySheet = showAudioAccessibilitySheet
        self._showChapters = showChapters
        self._showAIInsights = showAIInsights
    }

    public var body: some View {
        VStack(spacing: 12) {

            // Tier 1: Primary Action Pills (Playback Speed, Sleep Timer, AI Insights)
            HStack(spacing: 8) {
                // Playback Speed Menu Pill
                Menu {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5], id: \.self) { rate in
                        Button {
                            viewModel.setPlaybackRate(Float(rate))
                        } label: {
                            HStack {
                                Text(String(format: "%.2f×", rate))
                                if abs(viewModel.playbackRate - Float(rate)) < 0.05 {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    GlassPillButton(
                        icon: "gauge.with.dots.needle.50percent",
                        text: String(format: "%.1f×", viewModel.playbackRate),
                        isMonospaced: true,
                        isActive: abs(viewModel.playbackRate - 1.0) > 0.05,
                        activeColor: Color.appPrimary,
                        textColor: coverIsLight ? DesignTokens.Color.background : DesignTokens.Color.foreground,
                        action: {}
                    )
                    .allowsHitTesting(false)
                }

                Spacer(minLength: 0)

                // Sleep Timer Pill
                GlassPillButton(
                    icon: "moon",
                    text: viewModel.sleepTimerActive ? viewModel.sleepTimerRemainingPretty : "Sleep Timer",
                    isMonospaced: viewModel.sleepTimerActive,
                    isActive: viewModel.sleepTimerActive,
                    activeColor: Color.appPrimary,
                    textColor: coverIsLight ? DesignTokens.Color.background : DesignTokens.Color.foreground,
                    action: { showSleepTimer = true }
                )

                Spacer(minLength: 0)

                // AI Insights Pill
                GlassPillButton(
                    icon: "sparkles",
                    text: "AI Insights",
                    isActive: true,
                    activeColor: .cyan,
                    textColor: .cyan,
                    action: { showAIInsights = true }
                )
            }

            // Tier 2: Utility Glass Icon Bar (Bookmarks, Chapters, Audio FX, AirPlay)
            HStack(spacing: 0) {
                // Bookmarks Menu
                Menu {
                    Button {
                        showAddBookmark = true
                    } label: {
                        Label("Add Bookmark", systemImage: "plus")
                    }
                    Button {
                        showBookmarksList = true
                    } label: {
                        Label("View Bookmarks", systemImage: "list.bullet")
                    }
                } label: {
                    GlassIconButton(
                        icon: viewModel.hasBookmarks ? "bookmark.fill" : "bookmark",
                        fill: viewModel.hasBookmarks,
                        size: .medium,
                        color: coverIsLight ? .black : .white,
                        action: {}
                    )
                    .allowsHitTesting(false)
                }

                Spacer()

                // Chapters List Button
                GlassIconButton(
                    icon: "list.bullet",
                    fill: false,
                    size: .medium,
                    color: coverIsLight ? DesignTokens.Color.background : DesignTokens.Color.foreground,
                    action: { showChapters = true }
                )
                .opacity(viewModel.chapters.isEmpty ? 0.3 : 1.0)
                .disabled(viewModel.chapters.isEmpty)

                Spacer()

                // Audio FX / Accessibility Button
                GlassIconButton(
                    icon: "waveform.path.badge.plus",
                    fill: false,
                    size: .medium,
                    color: coverIsLight ? .black : .white,
                    action: { showAudioAccessibilitySheet = true }
                )
                .accessibilityLabel("Audio & Hardware Accessibility")

                Spacer()

                // AirPlay Route Picker Button
                AirPlayButton(color: coverIsLight ? DesignTokens.Color.background : DesignTokens.Color.foreground, size: 40)
            }
        }
        .disabled(isUiLocked)
        .opacity(isUiLocked ? 0.4 : 1.0)
    }
}
