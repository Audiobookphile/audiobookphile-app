//
//  ChapterAIInsightsSheet.swift
//  Audiobookphile
//

import SwiftUI
#if os(iOS) && !SKIP
import UIKit
#endif

public struct ChapterAIInsightsSheet: View {
    public let chapter: Chapter
    public let bookTitle: String
    public let bookAuthor: String?
    
    @State private var insights: AudiobookphileAPI.ChapterAIInsights?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var copiedTakeaway: String? = nil
    @State private var colorLoader = DynamicColorLoader()

    @Environment(\.dismiss) var dismiss

    public init(chapter: Chapter, bookTitle: String, bookAuthor: String?) {
        self.chapter = chapter
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
    }

    public var body: some View {
        ZStack {
            // Adaptive AI Mood Aura Background
            FluidAuraBackground(baseColor: colorLoader.backgroundColor)

            VStack(spacing: 16) {
                // Header Bar
                HStack {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.title3.bold())
                            .foregroundStyle(Color.appPrimary)
                        Text("Chapter AI Insights")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    if let mood = insights?.mood, !mood.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "face.smiling.fill")
                            Text(mood)
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.2))
                        .foregroundStyle(.purple)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.purple.opacity(0.4), lineWidth: 1))
                    }

                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Chapter \(chapter.id): \(chapter.title)")
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(bookTitle)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().background(Color.white.opacity(0.15))

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(Color.appPrimary)
                            .scaleEffect(1.2)
                        Text("Analyzing Chapter Content...")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                        Text("Extracting key plot points and character insights")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.yellow)
                        Text("Chapter Analysis Failed")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Retry Chapter AI") {
                            loadInsights()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.appPrimary)
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let insights = insights {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            // Chapter Summary Card
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                        .foregroundStyle(Color.appPrimary)
                                    Text("Chapter Summary")
                                        .font(.headline)
                                        .foregroundStyle(Color.appPrimary)

                                    Spacer()

                                    Button {
                                        copyToClipboard(insights.summary)
                                    } label: {
                                        Image(systemName: copiedTakeaway == insights.summary ? "checkmark" : "doc.on.doc")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }

                                Text(insights.summary)
                                    .font(.body)
                                    .foregroundStyle(.white)
                                    .lineSpacing(4)
                            }
                            .glassCard()

                            // Key Takeaways Card
                            if !insights.keyTakeaways.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundStyle(.yellow)
                                        Text("Key Highlights & Takeaways")
                                            .font(.headline)
                                            .foregroundStyle(.yellow)
                                    }

                                    ForEach(insights.keyTakeaways, id: \.self) { takeaway in
                                        HStack(alignment: .top, spacing: 10) {
                                            Image(systemName: "checkmark.seal.fill")
                                                .font(.subheadline)
                                                .foregroundStyle(Color.appPrimary)
                                                .padding(.top, 2)
                                            Text(takeaway)
                                                .font(.subheadline)
                                                .foregroundStyle(.white)
                                                .lineSpacing(2)
                                        }
                                        .onTapGesture {
                                            copyToClipboard(takeaway)
                                        }
                                    }
                                }
                                .glassCard()
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .refreshable {
                        loadInsights()
                    }
                }
            }
            .padding(20)
        }
        .onAppear {
            loadInsights()
        }
    }

    private func loadInsights() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let res = try await AudiobookphileAPI.shared.fetchChapterAIInsights(
                    title: bookTitle,
                    author: bookAuthor,
                    chapterTitle: chapter.title,
                    chapterIndex: chapter.id
                )
                await MainActor.run {
                    self.insights = res
                    self.isLoading = false
                    if let mood = res.mood {
                        self.colorLoader.loadColor(fromMood: mood)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    private func copyToClipboard(_ text: String) {
        #if os(iOS) && !SKIP
        UIPasteboard.general.string = text
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
        copiedTakeaway = text
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                if copiedTakeaway == text {
                    copiedTakeaway = nil
                }
            }
        }
    }
}
