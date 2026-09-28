//
//  AudioPlayerView.swift
//  Audiobookphile
//
//  Full-screen audio player with bleeding-edge Liquid Glass design.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Observation
#if os(iOS) && !SKIP
import UIKit
#endif

public struct AudioPlayerView: View {
    @State var viewModel: AudioPlayerViewModel
    var proMotion = ProMotionManager.shared
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) var dismiss

    @State var showChapters = false
    @State var showSleepTimer = false
    @State var showMoreMenu = false
    @State var isUiLocked = false
    @State var showBookmarksList = false
    @State var showAddBookmark = false
    @State var showAudioAccessibilitySheet = false
    @State var showAIInsights = false
    @State var newBookmarkTitle = ""
    @State var isAnimatingBackground = false
    @State var isRetrying = false

    @State var colorLoader = DynamicColorLoader()

    private var coverIsLight: Bool {
        colorLoader.isLight
    }

    private var coverURL: URL? {
        appState.getCoverURL(itemId: viewModel.session.libraryItemId)
    }

    public init(session: PlaybackSession) {
        _viewModel = State(wrappedValue: AudioPlayerViewModel(session: session))
    }

    public var body: some View {
        ZStack {
            // Background
            backgroundLayer

            // Full-screen player
            fullscreenPlayer

            // Playback failure overlay. Without this, a book whose audio
            // files are gone presented a normal-looking player that silently
            // never played — effectively a black screen.
            if let playbackError = AudioPlayerService.shared.playbackError {
                playbackFailureView(playbackError)
            }
        }
        .applyToolbarAdapters(isLight: colorLoader.isLight, isHidden: isUiLocked)
        .ignoresSafeArea()
        .optimizedForProMotion()
        .alert("Add Bookmark", isPresented: $showAddBookmark) {
            TextField("Bookmark Title (Optional)", text: $newBookmarkTitle)
            Button("Cancel", role: .cancel) {
                newBookmarkTitle = ""
            }
            Button("Save") {
                viewModel.addBookmark(title: newBookmarkTitle)
                newBookmarkTitle = ""
            }
        }
        .sheet(isPresented: $showBookmarksList) {
            BookmarksListView(viewModel: viewModel)
        }
        .sheet(isPresented: $showChapters) {
            ChapterSelectionView(
                chapters: viewModel.chapters,
                currentChapter: viewModel.currentChapter,
                bookTitle: viewModel.title,
                bookAuthor: viewModel.author,
                onSelect: { chapter in
                    viewModel.seek(to: chapter.start)
                    showChapters = false
                }
            )
        }
        .sheet(isPresented: $showSleepTimer) {
            SleepTimerView(
                onSetTimer: { duration in
                    if let duration = duration {
                        AudioPlayerService.shared.startSleepTimer(duration: duration)
                    } else {
                        AudioPlayerService.shared.stopSleepTimer()
                    }
                },
                onSetEndOfChapter: {
                    if let chapter = viewModel.currentChapter {
                        let remaining = chapter.end - viewModel.currentTime
                        if remaining > 0 {
                            AudioPlayerService.shared.startSleepTimer(duration: remaining)
                        }
                    }
                }
            )
        }
        .sheet(isPresented: $showAudioAccessibilitySheet) {
            AudioAccessibilityQuickSheet()
        }
        .sheet(isPresented: $showAIInsights) {
            PlayerAIInsightsSheet(
                bookId: viewModel.session.libraryItemId,
                bookTitle: viewModel.title,
                bookAuthor: viewModel.author
            )
            .presentationDetents([.medium, .large])
        }
        .confirmationDialog("Player Options", isPresented: $showMoreMenu, titleVisibility: .visible) {
            Button("Go to Sleep Timer") { showSleepTimer = true }
            Button("View Chapters") { showChapters = true }
            Button("Add Bookmark") { showAddBookmark = true }
            Button("View Bookmarks") { showBookmarksList = true }
            Button("Audio & Accessibility") { showAudioAccessibilitySheet = true }
            Button("Cancel", role: .cancel) {}
        }
        .task {
            if let url = coverURL {
                await colorLoader.loadColor(from: url)
            }
        }
    }

    /// Full-screen failure card shown when audio tracks fail to load after
    /// retries (e.g. the book's files are missing from storage).
    private func playbackFailureView(_ error: Error) -> some View {
        ZStack {
            Color.black.opacity(0.65).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(Color.appPrimary)
                Text("Playback Unavailable")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(DesignTokens.Color.foreground)
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.Color.foreground.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
                VStack(spacing: 10) {
                    Button {
                        AudioPlayerService.shared.retryCurrentTrack()
                    } label: {
                        Text("Try Again")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .background(Color.appPrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button {
                        AudioPlayerService.shared.playbackError = nil
                        dismiss()
                    } label: {
                        Text("Close Player")
                            .font(.subheadline)
                            .foregroundStyle(DesignTokens.Color.foreground.opacity(0.7))
                    }
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(DesignTokens.Color.surface.opacity(0.95))
            )
            .padding(.horizontal, 40)
        }
    }

    private var backgroundLayer: some View {
        ZStack {
            // Apple Music-style dynamic cover art background with rich fallback
            if let url = coverURL {
                GeometryReader { proxy in
                    SmartAsyncImage(url: url, maxPixelSize: CoverDecodeBudget.standard) { image in
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width * 1.5, height: proxy.size.height * 1.5)
                            .blur(radius: 100, opaque: true)
                            .scaleEffect(isAnimatingBackground ? 1.1 : 1.0)
                            .rotationEffect(.degrees(isAnimatingBackground ? 10 : -10))
                            .offset(x: isAnimatingBackground ? -20 : 20, y: isAnimatingBackground ? -20 : 20)
                    } placeholder: {
                        FluidAuraBackground(baseColor: colorLoader.backgroundColor)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                }
            } else {
                FluidAuraBackground(baseColor: colorLoader.backgroundColor)
            }

            // Darken/Blend overlay to ensure text is readable
            LinearGradient(
                colors: [
                    DesignTokens.Color.surface.opacity(0.25),
                    DesignTokens.Color.background.opacity(0.55)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 15).repeatForever(autoreverses: true)) {
                isAnimatingBackground = true
            }
        }
    }

    private var fullscreenPlayer: some View {
        VStack(spacing: 0) {
            // Top bar
            topBar
                .padding(.top, 50)

            Spacer()

            // Cover art
            PlayerCoverArtView(
                viewModel: viewModel,
                coverURL: coverURL,
                backgroundColor: colorLoader.backgroundColor
            )
                .padding(.vertical, 20)

            // Hardware vDSP Audio Spectrum Visualizer
            VDSPAudioVisualizer(isPlaying: viewModel.isPlaying, color: coverIsLight ? DesignTokens.Color.background : Color.appPrimary)
                .padding(.bottom, 12)

            // Title and author
            titleSection
                .padding(.horizontal, 24)

            // Partial-availability notice: some tracks could not be resolved
            // in storage, so content will skip over missing chapters.
            if let missing = viewModel.session.missingTrackCount, missing > 0 {
                Label(
                    "\(missing) track\(missing == 1 ? "" : "s") unavailable — some content may be skipped",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.footnote)
                .foregroundStyle(Color.appPrimary)
                .padding(.horizontal, 24)
                .padding(.top, 8)
            }

            Spacer()

            // Playback controls
            VStack(spacing: 24) {
                PlayerQuickActionsView(
                    viewModel: viewModel,
                    coverIsLight: coverIsLight,
                    isUiLocked: isUiLocked,
                    showAddBookmark: $showAddBookmark,
                    showBookmarksList: $showBookmarksList,
                    showSleepTimer: $showSleepTimer,
                    showAudioAccessibilitySheet: $showAudioAccessibilitySheet,
                    showChapters: $showChapters,
                    showAIInsights: $showAIInsights
                )
                    .padding(.horizontal, 20)

                PlaybackScrubberView(
                    viewModel: viewModel,
                    coverIsLight: coverIsLight,
                    isUiLocked: isUiLocked
                )
                    .padding(.horizontal, 24)

                PlaybackControlsView(
                    viewModel: viewModel,
                    coverIsLight: coverIsLight,
                    isUiLocked: isUiLocked
                )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)
            }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title2)
                    .foregroundStyle(coverIsLight ? DesignTokens.Color.background : DesignTokens.Color.foreground)
            }
            .accessibilityLabel("Close Player")

            Spacer()

            Button {
                withAnimation {
                    isUiLocked.toggle()
                }
            } label: {
                Image(systemName: isUiLocked ? "lock.fill" : "lock.open")
                    .font(.title2)
                    .foregroundStyle(isUiLocked ? Color.appPrimary : (coverIsLight ? DesignTokens.Color.background : DesignTokens.Color.foreground))
            }
            .accessibilityLabel(isUiLocked ? "Unlock Controls" : "Lock Controls")
            .padding(.trailing, 16)

            Button {
                showMoreMenu = true
            } label: {
                Image(systemName: "ellipsis")
                    .font(.title2)
                    .foregroundStyle(coverIsLight ? DesignTokens.Color.background : DesignTokens.Color.foreground)
            }
            .accessibilityLabel("More Options")
        }
        .padding(.horizontal, 24)
    }


    private var titleSection: some View {
        VStack(spacing: 8) {
            Text(viewModel.currentChapterTitle.isEmpty ? viewModel.title : viewModel.currentChapterTitle)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(coverIsLight ? DesignTokens.Color.background : DesignTokens.Color.foreground)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(viewModel.author)
                .font(.headline)
                .foregroundStyle((coverIsLight ? DesignTokens.Color.background : DesignTokens.Color.foreground).opacity(0.7))
                .multilineTextAlignment(.center)
                .lineLimit(1)
        }
    }

}

// MARK: - Audio Accessibility Quick Sheet

public struct AudioAccessibilityQuickSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = AppState.shared.settings

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 16) {
                    List {
                        Section(header: Text("Spoken Audio & Speech Clarity").foregroundStyle(DesignTokens.Color.foreground.opacity(0.7))) {
                            Toggle("Spoken Audio Optimization", isOn: Binding(
                                get: { settings.spokenAudioModeEnabled },
                                set: { newValue in
                                    settings.spokenAudioModeEnabled = newValue
                                    AppState.shared.updateSettings(settings)
                                    #if os(iOS)
                                    AudioPlayerService.shared.reconfigureAudioSession()
                                    #endif
                                }
                            ))

                            Toggle("Vocal Clarity Boost", isOn: Binding(
                                get: { settings.vocalBoostEnabled },
                                set: { newValue in
                                    settings.vocalBoostEnabled = newValue
                                    AppState.shared.updateSettings(settings)
                                    AudioPlayerService.shared.applyAudioDSP()
                                }
                            ))

                            Toggle("Smart Volume Leveler", isOn: Binding(
                                get: { settings.volumeLevelerEnabled },
                                set: { newValue in
                                    settings.volumeLevelerEnabled = newValue
                                    AppState.shared.updateSettings(settings)
                                    AudioPlayerService.shared.applyAudioDSP()
                                }
                            ))

                            Toggle("Mono Audio Mix", isOn: Binding(
                                get: { settings.monoAudioEnabled },
                                set: { newValue in
                                    settings.monoAudioEnabled = newValue
                                    AppState.shared.updateSettings(settings)
                                }
                            ))
                        }
                        .listRowBackground(DesignTokens.Color.surface.opacity(0.08))

                        Section(header: Text("Audiophile DSP & Fidelity").foregroundStyle(DesignTokens.Color.foreground.opacity(0.7))) {
                            Toggle("High-Res 48kHz Output", isOn: Binding(
                                get: { settings.highResAudioEnabled },
                                set: { newValue in
                                    settings.highResAudioEnabled = newValue
                                    AppState.shared.updateSettings(settings)
                                    #if os(iOS)
                                    AudioPlayerService.shared.reconfigureAudioSession()
                                    #endif
                                    AudioPlayerService.shared.applyAudioDSP()
                                }
                            ))

                            Toggle("Low-Cut Rumble Filter (80Hz)", isOn: Binding(
                                get: { settings.lowCutFilterEnabled },
                                set: { newValue in
                                    settings.lowCutFilterEnabled = newValue
                                    AppState.shared.updateSettings(settings)
                                    AudioPlayerService.shared.applyAudioDSP()
                                }
                            ))

                            Toggle("De-Esser Sibilance Reducer", isOn: Binding(
                                get: { settings.deEsserEnabled },
                                set: { newValue in
                                    settings.deEsserEnabled = newValue
                                    AppState.shared.updateSettings(settings)
                                    AudioPlayerService.shared.applyAudioDSP()
                                }
                            ))
                        }
                        .listRowBackground(DesignTokens.Color.surface.opacity(0.08))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Audio Accessibility")
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appPrimary)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
