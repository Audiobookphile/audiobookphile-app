//
//  PlaybackQueueSheet.swift
//  Audiobookphile
//
//  Liquid Glass "Up Next" queue sheet for continuous listening across books and podcasts.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

public struct PlaybackQueueSheet: View {
    @Environment(\.dismiss) private var dismiss
    public let viewModel: AudioPlayerViewModel

    public init(viewModel: AudioPlayerViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                FluidAuraBackground()

                ScrollView {
                    VStack(spacing: 20) {
                        // Now Playing Hero Card
                        nowPlayingCard

                        // Up Next Section
                        upNextSection

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Playback Queue")
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if !viewModel.playbackQueue.isEmpty {
                        Button("Clear") {
                            viewModel.clearPlaybackQueue()
                        }
                        .foregroundStyle(.red)
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .applyToolbarAdapters(isLight: false, isHidden: false)
        }
    }

    // MARK: - Now Playing Card

    private var nowPlayingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "waveform")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor)
                Text("NOW PLAYING")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Text(viewModel.currentTimePretty + " / " + viewModel.durationPretty)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundStyle(DesignTokens.Color.foreground)
                    .lineLimit(2)

                Text(viewModel.author)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            // Progress track
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 4)

                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: max(0, proxy.size.width * CGFloat(viewModel.progress)), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.top, 4)
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Up Next Section

    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("UP NEXT (\(viewModel.playbackQueue.count))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
            }

            if viewModel.playbackQueue.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.accentColor.opacity(0.6))
                        .padding(.top, 16)

                    Text("Your Queue is Empty")
                        .font(.headline)
                        .foregroundStyle(DesignTokens.Color.foreground)

                    Text("Audiobooks and podcast episodes added to Up Next will automatically play in sequence.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
                .frame(maxWidth: .infinity)
                .glassCard(cornerRadius: 16)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(viewModel.playbackQueue.enumerated()), id: \.element.id) { index, session in
                        HStack(spacing: 12) {
                            // Queue index badge
                            Text("\(index + 1)")
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 24, height: 24)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(Circle())

                            // Metadata
                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.displayTitle)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(DesignTokens.Color.foreground)
                                    .lineLimit(1)

                                Text(session.displayAuthor)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            // Play immediately button
                            Button {
                                viewModel.removeFromPlaybackQueue(at: index)
                                AudioPlayerService.shared.startPlayback(session: session)
                            } label: {
                                Image(systemName: "play.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.accentColor)
                            }

                            // Remove from queue button
                            Button {
                                viewModel.removeFromPlaybackQueue(at: index)
                            } label: {
                                Image(systemName: "xmark.circle")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .glassCard(cornerRadius: 12)
                    }
                }
            }
        }
    }
}

