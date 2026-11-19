//
//  ChapterListView.swift
//  Audiobookphile
//

import SwiftUI

public struct ChapterListView: View {
    public let detailed: Book
    public let viewModel: BookDetailViewModel
    @Environment(\.dismiss) var dismiss

    @State private var selectedChapterForAI: Chapter?

    public init(detailed: Book, viewModel: BookDetailViewModel) {
        self.detailed = detailed
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chapters (\(detailed.chapters.count))")
                .font(.headline)
                .foregroundStyle(DesignTokens.Color.foreground)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(detailed.chapters) { chapter in
                    HStack(spacing: 8) {
                        Button {
                            viewModel.playBook(detailed, seekToTime: chapter.start, dismiss: dismiss)
                        } label: {
                            HStack {
                                Text(chapter.title)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(DesignTokens.Color.foreground)
                                    .multilineTextAlignment(.leading)

                                Spacer()

                                HStack(spacing: 8) {
                                    Text(viewModel.formatDuration(chapter.start))
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(DesignTokens.Color.foreground.opacity(0.6))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(DesignTokens.Color.foreground.opacity(0.06))
                                        .clipShape(Capsule())

                                    Text(viewModel.formatDuration(chapter.duration))
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(DesignTokens.Color.foreground.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .liquidPressable()

                        // AI Insights Button
                        Button {
                            selectedChapterForAI = chapter
                        } label: {
                            Image(systemName: "sparkles")
                                .font(.body)
                                .foregroundStyle(DesignTokens.Color.accentSecondary)
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(
                                    Circle().strokeBorder(DesignTokens.Color.accentSecondary.opacity(0.4), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .sheet(item: $selectedChapterForAI) { chapter in
            ChapterAIInsightsSheet(
                chapter: chapter,
                bookTitle: detailed.title,
                bookAuthor: detailed.author
            )
            .presentationDetents([.medium, .large])
        }
    }
}
