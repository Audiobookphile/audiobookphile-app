//
//  PlaybackScrubberView.swift
//  Audiobookphile
//
//  Apple-grade Liquid Glass Scrubber with tactile chapter detents,
//  scrubbing tooltips, and interactive timestamp countdown toggling.
//

import SwiftUI
#if os(iOS) && !SKIP
import UIKit
#endif

public struct PlaybackScrubberView: View {
    var viewModel: AudioPlayerViewModel
    var coverIsLight: Bool
    var isUiLocked: Bool
    var tintColor: Color?

    @State private var isDragging = false
    @State private var draggedProgress: Double = 0
    @State private var pendingSeekTarget: TimeInterval?
    @State private var lastNotchedChapterStart: TimeInterval?
    @State private var lastNotchedDecile: Int = -1

    public init(viewModel: AudioPlayerViewModel, coverIsLight: Bool, isUiLocked: Bool, tintColor: Color? = nil) {
        self.viewModel = viewModel
        self.coverIsLight = coverIsLight
        self.isUiLocked = isUiLocked
        self.tintColor = tintColor
    }

    // Safe duration calculation ensuring no division by zero or NaN
    private var safeDuration: TimeInterval {
        let dur = viewModel.duration
        return (dur.isNaN || dur.isInfinite || dur <= 0) ? 1.0 : dur
    }

    // The progress value to show on the track — frozen to drag position while scrubbing
    private var displayProgress: Double {
        if isDragging {
            return max(0, min(1, draggedProgress))
        }
        if let pending = pendingSeekTarget {
            return max(0, min(1, pending / safeDuration))
        }
        return viewModel.totalProgress
    }

    // The time value shown in the left timestamp label
    private var displayTime: TimeInterval {
        if isDragging {
            return max(0, min(safeDuration, safeDuration * draggedProgress))
        }
        if let pending = pendingSeekTarget {
            return pending
        }
        let current = viewModel.currentTime
        return (current.isNaN || current.isInfinite || current < 0) ? 0 : min(safeDuration, current)
    }

    // The active chapter corresponding to the currently scrubbed or playing time
    private var activeScrubChapter: Chapter? {
        viewModel.chapter(at: displayTime)
    }

    public var body: some View {
        VStack(spacing: 8) {
            // Floating Chapter Preview Tooltip while actively scrubbing
            if isDragging, let chapter = activeScrubChapter, !chapter.title.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 10, weight: .semibold))
                    Text(chapter.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                }
                .foregroundStyle(coverIsLight ? Color.black.opacity(0.85) : Color.white.opacity(0.95))
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(coverIsLight ? Color.black.opacity(0.08) : Color.white.opacity(0.15))
                        .background(.ultraThinMaterial, in: Capsule())
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }

            // Time labels
            HStack {
                Text(viewModel.formatTime(displayTime))
                    .font(.system(.caption, design: .monospaced))

                Spacer()

                // Interactive Remaining Time Button: Tap to toggle between Total Book Remaining, Chapter Remaining, and Estimated Finish Clock Time
                Button {
                    viewModel.toggleTimeRemainingMode()
                    triggerImpactHaptic()
                } label: {
                    HStack(spacing: 3) {
                        Text(viewModel.formattedRemainingTime(for: displayTime))
                        if viewModel.timeRemainingMode == .chapterRemaining && activeScrubChapter != nil {
                            Text("CH")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.appPrimary.opacity(0.2))
                                .foregroundStyle(Color.appPrimary)
                                .clipShape(Capsule())
                        } else if viewModel.timeRemainingMode == .estimatedFinishTime {
                            Image(systemName: "clock")
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(Color.appPrimary.opacity(0.2))
                                .foregroundStyle(Color.appPrimary)
                                .clipShape(Capsule())
                        }
                    }
                    .font(.system(.caption, design: .monospaced))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(coverIsLight ? .black : .white)
            .animation(.easeInOut(duration: 0.15), value: isDragging)

            Slider(
                value: Binding(
                    get: { displayTime },
                    set: { newValue in
                        if !isDragging {
                            isDragging = true
                            triggerImpactHaptic()
                        }
                        let dur = safeDuration
                        let progress = max(0, min(1, newValue / dur))
                        draggedProgress = progress
                        checkChapterBoundaryHaptic(for: progress * dur)
                    }
                ),
                in: 0...safeDuration,
                onEditingChanged: { editing in
                    if editing {
                        isDragging = true
                        lastNotchedChapterStart = nil
                        lastNotchedDecile = -1
                        let dur = safeDuration
                        let current = viewModel.currentTime
                        draggedProgress = max(0, min(1, current / dur))
                        triggerImpactHaptic()
                    } else {
                        let dur = safeDuration
                        let targetTime = max(0, min(dur, draggedProgress * dur))
                        pendingSeekTarget = targetTime
                        viewModel.seek(to: targetTime)
                        triggerImpactHaptic()
                        isDragging = false
                        lastNotchedChapterStart = nil
                        lastNotchedDecile = -1
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 2_500_000_000)
                            if self.pendingSeekTarget == targetTime {
                                self.pendingSeekTarget = nil
                            }
                        }
                    }
                }
            )
            .onChange(of: viewModel.currentTime) { _, newTime in
                if let target = pendingSeekTarget, abs(newTime - target) < 1.5 {
                    pendingSeekTarget = nil
                }
            }
            .tint(tintColor ?? .appPrimary)
            .disabled(isUiLocked)
            .opacity(isUiLocked ? 0.4 : 1.0)
            .frame(height: 44)
        }
    }

    // MARK: - Tactile Haptic Feedback
    
    private func checkChapterBoundaryHaptic(for time: TimeInterval) {
        if !viewModel.chapters.isEmpty {
            if let chapter = viewModel.chapter(at: time) {
                if lastNotchedChapterStart != chapter.start {
                    lastNotchedChapterStart = chapter.start
                    triggerSelectionHaptic()
                }
            }
        } else {
            // Milestone 10% progress notches if book has no discrete chapters
            let currentDecile = Int(draggedProgress * 10)
            if currentDecile != lastNotchedDecile {
                lastNotchedDecile = currentDecile
                triggerSelectionHaptic()
            }
        }
    }

    private func triggerSelectionHaptic() {
        #if os(iOS) && !SKIP
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }

    private func triggerImpactHaptic() {
        #if !SKIP && os(iOS)
        // Use .medium as .light requires iOS 17+ with specific haptic support
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
    }
}
