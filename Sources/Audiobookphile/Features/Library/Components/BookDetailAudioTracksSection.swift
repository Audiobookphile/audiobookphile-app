//
//  BookDetailAudioTracksSection.swift
//  Audiobookphile
//
//  Expandable Audio Tracks & Files inspection table for audiophile verification.
//  Corresponds to AudioTracksTable in audiobookphile-web.
//

import SwiftUI
#if os(iOS) && !SKIP
import UIKit
#endif

public struct BookDetailAudioTracksSection: View {
    public let detailed: Book
    @State private var isExpanded = false
    @State private var selectedTrack: AudioFile?
    @State private var copiedFilename: String?

    public init(detailed: Book) {
        self.detailed = detailed
    }

    private var tracks: [AudioFile] {
        detailed.audioFiles
    }

    private var totalBytes: Int64 {
        tracks.reduce(0) { $0 + ($1.metadata.size ?? 0) }
    }

    private var formattedTotalSize: String {
        guard totalBytes > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }

    private var dominantCodec: String {
        guard let first = tracks.first else { return "AUDIO" }
        return first.displayCodec
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header Button
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
                triggerHaptic()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "opticaldisc.fill")
                        .font(.headline)
                        .foregroundStyle(Color.appPrimary)

                    Text("Audio Tracks & Files")
                        .font(.headline)
                        .foregroundStyle(DesignTokens.Color.foreground)

                    Text("\(tracks.count)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.appPrimary.opacity(0.18))
                        .foregroundStyle(Color.appPrimary)
                        .clipShape(Capsule())

                    Spacer()

                    if !isExpanded {
                        Text(formattedTotalSize)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 12) {
                    // Summary Stats Strip
                    HStack(spacing: 12) {
                        summaryPill(icon: "clock", label: "Duration", value: formatTotalDuration(detailed.duration))
                        summaryPill(icon: "internaldrive", label: "Size", value: formattedTotalSize)
                        summaryPill(icon: "waveform", label: "Format", value: dominantCodec)
                    }
                    .padding(.top, 4)

                    Divider()
                        .background(DesignTokens.Color.foreground.opacity(0.1))

                    // Track Rows
                    VStack(spacing: 8) {
                        ForEach(tracks) { track in
                            trackRow(track)
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .sheet(item: $selectedTrack) { track in
            audioTrackDetailSheet(track)
                .presentationDetents([.medium])
        }
    }

    // MARK: - Track Row

    private func trackRow(_ track: AudioFile) -> some View {
        HStack(spacing: 12) {
            // Index Pill
            Text("#\(track.index + 1)")
                .font(.caption2.monospaced().weight(.semibold))
                .foregroundStyle(DesignTokens.Color.foreground.opacity(0.7))
                .frame(width: 30, height: 26)
                .background(DesignTokens.Color.surface.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            // Filename & Metadata
            VStack(alignment: .leading, spacing: 3) {
                Text(track.filename)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(DesignTokens.Color.foreground)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    // Codec chip
                    Text(track.displayCodec)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color.appPrimary.opacity(0.15))
                        .foregroundStyle(Color.appPrimary)
                        .clipShape(Capsule())

                    if track.bitRate != nil {
                        Text(track.formattedBitRate)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.secondary)
                    }

                    Text("•")
                        .font(.caption2)
                        .foregroundStyle(.secondary.opacity(0.5))

                    Text(track.formattedSize)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Duration
            Text(track.formattedDuration)
                .font(.caption.monospaced())
                .foregroundStyle(DesignTokens.Color.foreground.opacity(0.85))

            // Info / More button
            Button {
                selectedTrack = track
                triggerHaptic(isLight: true)
            } label: {
                Image(systemName: "info.circle")
                    .font(.subheadline)
                    .foregroundStyle(Color.appPrimary.opacity(0.85))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(.ultraThinMaterial.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Summary Pill

    private func summaryPill(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(Color.appPrimary)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(DesignTokens.Color.foreground)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(DesignTokens.Color.surface.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Detailed Sheet

    private func audioTrackDetailSheet(_ track: AudioFile) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(Color.appPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.filename)
                            .font(.headline)
                            .lineLimit(2)
                        Text("Track \(track.index + 1) of \(tracks.count)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 10)

                VStack(spacing: 10) {
                    detailRow(title: "Codec / Format", value: track.displayCodec)
                    detailRow(title: "Bitrate", value: track.formattedBitRate)
                    detailRow(title: "Duration", value: track.formattedDuration)
                    detailRow(title: "File Size", value: track.formattedSize)
                    if let mimeType = track.mimeType, !mimeType.isEmpty {
                        detailRow(title: "MIME Type", value: mimeType)
                    }
                    if let path = track.metadata.path, !path.isEmpty {
                        detailRow(title: "Server Path", value: path, isMonospaced: true)
                    }
                    detailRow(title: "File Inode", value: track.ino, isMonospaced: true)
                }
                .padding()
                .glassCard()

                // Copy Filename Button
                Button {
                    copyToClipboard(track.filename)
                    triggerHaptic()
                } label: {
                    HStack {
                        Image(systemName: copiedFilename == track.filename ? "checkmark" : "doc.on.doc")
                        Text(copiedFilename == track.filename ? "Filename Copied!" : "Copy Track Filename")
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.appPrimary.opacity(0.18))
                    .foregroundStyle(Color.appPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(20)
            .navigationTitle("Track Info")
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        selectedTrack = nil
                    }
                }
            }
        }
    }

    private func detailRow(title: String, value: String, isMonospaced: Bool = false) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(isMonospaced ? .caption.monospaced() : .caption.weight(.semibold))
                .foregroundStyle(DesignTokens.Color.foreground)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }

    private func formatTotalDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func copyToClipboard(_ text: String) {
        #if !SKIP && os(iOS)
        UIPasteboard.general.string = text
        #endif
        copiedFilename = text
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if copiedFilename == text {
                copiedFilename = nil
            }
        }
    }

    private func triggerHaptic(isLight: Bool = false) {
        #if os(iOS) && !SKIP
        let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = isLight ? .light : .medium
        UIImpactFeedbackGenerator(style: feedbackStyle).impactOccurred()
        #endif
    }
}
