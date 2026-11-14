//
//  CarModeView.swift
//  Audiobookphile
//
//  Distraction-free, high-contrast Car Mode player designed for safe in-vehicle use.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Observation
#if !SKIP && os(iOS)
import UIKit
#endif

public struct CarModeView: View {
    @Environment(\.dismiss) private var dismiss
    var viewModel: AudioPlayerViewModel
    @State private var bookmarkToast: String?
    @State private var sleepTimerToast: String?

    public init(viewModel: AudioPlayerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            // Pure black OLED background for maximum contrast & zero windshield glare
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Bar
                topBar
                    .padding(.horizontal, 24)
                    .padding(.top, 16)

                Spacer(minLength: 16)

                // Book & Chapter Information
                infoSection
                    .padding(.horizontal, 24)

                Spacer(minLength: 24)

                // High-Contrast Large Transport Controls
                transportControls
                    .padding(.horizontal, 20)

                Spacer(minLength: 24)

                // Quick Car Actions (1-tap Bookmark, Chapter Skip)
                bottomActions
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
            }

            // Toast notifications
            if let toast = bookmarkToast ?? sleepTimerToast {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                        .shadow(radius: 10)
                        .padding(.bottom, 100)
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        #if !SKIP && os(iOS)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .deviceDidShakeNotification)) { _ in
            handleShake()
        }
        #endif
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                    Text("Exit")
                        .font(.headline.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.15))
                .clipShape(Capsule())
            }
            .accessibilityLabel("Exit Car Mode")

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "car.fill")
                    .font(.subheadline)
                Text("CAR MODE")
                    .font(.caption.weight(.black))
            }
            .foregroundStyle(Color.appPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.appPrimary.opacity(0.18))
            .clipShape(Capsule())

            Spacer()

            if viewModel.sleepTimerActive {
                HStack(spacing: 6) {
                    Image(systemName: "moon.fill")
                        .font(.caption)
                    Text(viewModel.sleepTimerRemainingPretty)
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.12))
                .clipShape(Capsule())
            } else {
                Color.clear.frame(width: 60, height: 36)
            }
        }
    }

    // MARK: - Information Section

    private var infoSection: some View {
        VStack(spacing: 12) {
            Text(viewModel.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)

            if !viewModel.currentChapterTitle.isEmpty {
                Text(viewModel.currentChapterTitle)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            } else {
                Text(viewModel.author)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
            }

            // Simple high-visibility progress bar
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 8)

                        Capsule()
                            .fill(Color.appPrimary)
                            .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(viewModel.progress))), height: 8)
                    }
                }
                .frame(height: 8)

                HStack {
                    Text(viewModel.currentTimePretty)
                        .font(.footnote.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer()
                    Text(viewModel.totalTimeRemainingPretty)
                        .font(.footnote.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Massive Transport Controls

    private var transportControls: some View {
        HStack(spacing: 28) {
            // 30s Skip Backward
            Button {
                triggerHaptic()
                viewModel.skipBackward(30)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "gobackward.30")
                        .font(.system(size: 38, weight: .bold))
                    Text("30s")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(width: 84, height: 84)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())
            }
            .accessibilityLabel("Skip Backward 30 Seconds")

            // Huge Play / Pause
            Button {
                triggerHaptic()
                viewModel.togglePlayPause()
            } label: {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 48, weight: .black))
                    .foregroundStyle(.black)
                    .frame(width: 108, height: 108)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: .white.opacity(0.3), radius: 14)
            }
            .accessibilityLabel(viewModel.isPlaying ? "Pause" : "Play")

            // 30s Skip Forward
            Button {
                triggerHaptic()
                viewModel.skipForward(30)
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "goforward.30")
                        .font(.system(size: 38, weight: .bold))
                    Text("30s")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(.white)
                .frame(width: 84, height: 84)
                .background(Color.white.opacity(0.12))
                .clipShape(Circle())
            }
            .accessibilityLabel("Skip Forward 30 Seconds")
        }
    }

    // MARK: - Bottom Actions

    private var bottomActions: some View {
        HStack(spacing: 16) {
            // 1-Tap Bookmark Button
            Button {
                triggerHaptic()
                viewModel.addBookmark(title: "Car Bookmark")
                withAnimation {
                    bookmarkToast = "Bookmark Added"
                }
                Task {
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    withAnimation {
                        bookmarkToast = nil
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bookmark.fill")
                        .font(.headline)
                    Text("Bookmark")
                        .font(.headline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.white.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .accessibilityLabel("Add Bookmark")

            // Next Chapter Button
            if viewModel.hasNextChapter {
                Button {
                    triggerHaptic()
                    if let next = viewModel.chapters.first(where: { $0.start > viewModel.currentTime }) {
                        viewModel.seek(to: next.start)
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "forward.end.fill")
                            .font(.headline)
                        Text("Next Chapter")
                            .font(.headline.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .accessibilityLabel("Next Chapter")
            }
        }
    }

    // MARK: - Helpers

    private func triggerHaptic() {
        #if !SKIP && os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }

    private func handleShake() {
        guard AppState.shared.settings.shakeToResetSleepTimer else { return }
        if AudioPlayerService.shared.isSleepTimerActive {
            triggerNotificationHaptic()
            AudioPlayerService.shared.resetSleepTimer()
            withAnimation {
                sleepTimerToast = "Sleep Timer Reset"
            }
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                withAnimation {
                    sleepTimerToast = nil
                }
            }
        }
    }

    private func triggerNotificationHaptic() {
        #if !SKIP && os(iOS)
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }
}

