//
//  PlayerAIInsightsSheet.swift
//  Audiobookphile
//

import SwiftUI
#if os(iOS) && !SKIP
import UIKit
#endif

public struct PlayerAIInsightsSheet: View {
    public let bookId: String
    public let bookTitle: String
    public let bookAuthor: String?
    
    @State private var insights: AudiobookphileAPI.BookAIInsights?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var copiedText: String? = nil
    @State private var colorLoader = DynamicColorLoader()
    
    @Environment(\.dismiss) var dismiss

    public init(bookId: String, bookTitle: String, bookAuthor: String?) {
        self.bookId = bookId
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
                        Text("AI Insights Engine")
                            .font(.headline)
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    if let insights = insights {
                        HStack(spacing: 4) {
                            Image(systemName: insights.isCached ? "externaldrive.fill" : "bolt.fill")
                                .font(.caption2)
                            Text(insights.isCached ? "DB Cached" : "Live AI Stream")
                                .font(.caption2.bold())
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(insights.isCached ? Color.appPrimary.opacity(0.15) : Color.green.opacity(0.15))
                        .foregroundStyle(insights.isCached ? Color.appPrimary : Color.green)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().strokeBorder((insights.isCached ? Color.appPrimary : Color.green).opacity(0.4), lineWidth: 1)
                        )
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
                    Text(bookTitle)
                        .font(.title3.bold())
                        .foregroundStyle(.white)
                    
                    if let author = bookAuthor, !author.isEmpty {
                        Text("by \(author)")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().background(Color.white.opacity(0.15))

                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .tint(Color.appPrimary)
                            .scaleEffect(1.2)
                        Text("Compiling AI Book Insights...")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                        Text("Querying vector database & generating executive summary")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.yellow)
                        Text("Insights Generation Failed")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button("Retry AI Engine") {
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
                            // Mood & Themes Badges
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "face.smiling.fill")
                                        Text(insights.mood)
                                    }
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.purple.opacity(0.2))
                                    .foregroundStyle(.purple)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().strokeBorder(Color.purple.opacity(0.4), lineWidth: 1))

                                    ForEach(insights.themes, id: \.self) { theme in
                                        Text(theme)
                                            .font(.caption.bold())
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.appPrimary.opacity(0.15))
                                            .foregroundStyle(Color.appPrimary)
                                            .clipShape(Capsule())
                                            .overlay(Capsule().strokeBorder(Color.appPrimary.opacity(0.3), lineWidth: 1))
                                    }
                                }
                            }

                            // Executive Summary Card
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: "text.quote")
                                        .foregroundStyle(Color.appPrimary)
                                    Text("Executive Summary")
                                        .font(.headline)
                                        .foregroundStyle(Color.appPrimary)

                                    Spacer()

                                    Button {
                                        copyToClipboard(insights.summary)
                                    } label: {
                                        Image(systemName: copiedText == insights.summary ? "checkmark" : "doc.on.doc")
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

                            // Key Lessons & Takeaways Card
                            if !insights.keyTakeaways.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Image(systemName: "lightbulb.fill")
                                            .foregroundStyle(.yellow)
                                        Text("Key Lessons & Takeaways")
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
                let res = try await AudiobookphileAPI.shared.fetchBookAIInsights(
                    bookId: bookId,
                    title: bookTitle,
                    author: bookAuthor
                )
                await MainActor.run {
                    self.insights = res
                    self.isLoading = false
                    self.colorLoader.loadColor(fromMood: res.mood)
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
        copiedText = text
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await MainActor.run {
                if copiedText == text {
                    copiedText = nil
                }
            }
        }
    }
}
