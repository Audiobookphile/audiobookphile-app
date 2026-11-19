//
//  MediaSpecsSheet.swift
//  Audiobookphile
//

import SwiftUI

public struct MediaSpecsSheet: View {
    public let detailed: Book
    public let onDismiss: () -> Void

    public init(detailed: Book, onDismiss: @escaping () -> Void) {
        self.detailed = detailed
        self.onDismiss = onDismiss
    }

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    VStack(spacing: 8) {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.accentColor)

                        Text(detailed.title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(DesignTokens.Color.foreground)

                        if let author = detailed.author {
                            Text(author)
                                .font(.subheadline)
                                .foregroundStyle(DesignTokens.Color.foreground.opacity(0.7))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .glassCard(cornerRadius: 18)

                    // Specs Grid
                    VStack(spacing: 12) {
                        specRow(icon: "music.note", label: "Format / Codec", value: formatCodecString)
                        specRow(icon: "speedometer", label: "Bitrate", value: formatBitrateString)
                        specRow(icon: "internaldrive", label: "Total File Size", value: formatSizeString)
                        specRow(icon: "clock", label: "Total Duration", value: formatDurationString)
                        specRow(icon: "square.stack", label: "Audio Tracks", value: "\(detailed.media.audioFiles?.count ?? 1) file(s)")
                        specRow(icon: "list.number", label: "Chapters", value: "\(detailed.chapters.count) chapter(s)")
                        if let mime = detailed.media.audioFiles?.first?.mimeType {
                            specRow(icon: "doc.text", label: "MIME Type", value: mime)
                        }
                    }
                    .padding(16)
                    .glassCard(cornerRadius: 18)
                }
                .padding(16)
            }
            .background(DesignTokens.Color.background.ignoresSafeArea())
            .navigationTitle("Audio & Media Specs")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        DesignTokens.Haptics.selection()
                        onDismiss()
                    }
                }
            }
        }
    }

    private func specRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(Color.accentColor)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(DesignTokens.Color.foreground.opacity(0.75))

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(DesignTokens.Color.foreground)
        }
        .padding(.vertical, 4)
    }

    private var formatCodecString: String {
        if let codec = detailed.media.audioFiles?.first?.codec, !codec.isEmpty {
            return codec.uppercased()
        }
        if let mime = detailed.media.audioFiles?.first?.mimeType, !mime.isEmpty {
            return mime
        }
        return "M4B / AAC"
    }

    private var formatBitrateString: String {
        if let rate = detailed.media.audioFiles?.first?.bitRate, rate > 0 {
            return "\(rate / 1000) kbps"
        }
        return "Standard Bitrate"
    }

    private var formatSizeString: String {
        guard let size = detailed.media.size, size > 0 else {
            return "Unknown"
        }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }

    private var formatDurationString: String {
        let seconds = Int(detailed.duration)
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
