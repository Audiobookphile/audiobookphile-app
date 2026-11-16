import SwiftUI

public struct ChapterSelectionView: View {
    public let chapters: [Chapter]
    public let currentChapter: Chapter?
    public let bookTitle: String
    public let bookAuthor: String?
    public let onSelect: (Chapter) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var selectedChapterForAI: Chapter?
    @State private var searchText = ""

    private var filteredChapters: [Chapter] {
        Chapter.filter(chapters: chapters, query: searchText)
    }

    private var trailingPlacement: ToolbarItemPlacement {
        #if os(iOS) || SKIP
        return .navigationBarTrailing
        #else
        return .primaryAction
        #endif
    }

    public init(
        chapters: [Chapter],
        currentChapter: Chapter?,
        bookTitle: String = "Audiobook",
        bookAuthor: String? = nil,
        onSelect: @escaping (Chapter) -> Void
    ) {
        self.chapters = chapters
        self.currentChapter = currentChapter
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
        self.onSelect = onSelect
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                FluidAuraBackground()

                ScrollViewReader { proxy in
                    List {
                        if filteredChapters.isEmpty && !chapters.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.secondary)
                                Text("No chapters matching \"\(searchText)\"")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                            .listRowBackground(Color.clear)
                        } else {
                            ForEach(filteredChapters) { chapter in
                                HStack {
                                    Button {
                                        onSelect(chapter)
                                    } label: {
                                        HStack(spacing: 12) {
                                            if chapter.id == currentChapter?.id {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.appPrimary)
                                                .frame(width: 4, height: 28)
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(chapter.title)
                                                .font(.headline)
                                                .fontWeight(chapter.id == currentChapter?.id ? .bold : .regular)
                                                .foregroundStyle(chapter.id == currentChapter?.id ? Color.appPrimary : .primary)

                                            Text(formatDuration(chapter.end - chapter.start))
                                                .font(.caption)
                                                .fontWeight(chapter.id == currentChapter?.id ? .bold : .regular)
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        if chapter.id == currentChapter?.id {
                                            Image(systemName: "speaker.wave.2.fill")
                                                .foregroundStyle(Color.appPrimary)
                                        }
                                    }
                                }

                                // AI Insights Button
                                Button {
                                    selectedChapterForAI = chapter
                                } label: {
                                    Image(systemName: "sparkles")
                                        .font(.body)
                                        .foregroundStyle(Color.appPrimary)
                                        .padding(8)
                                        .background(Color.appPrimary.opacity(0.15), in: Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            .applyBookshelfScrollTransition()
                            .id(chapter.id)
                            .listRowBackground(Color.clear)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Search chapters...")
                .onAppear {
                    if let current = currentChapter, searchText.isEmpty {
                        withAnimation {
                            proxy.scrollTo(current.id, anchor: .center)
                        }
                    }
                }
            }
            .navigationTitle("Chapters")
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: trailingPlacement) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .applyToolbarAdapters(isLight: false, isHidden: false)
            .sheet(item: $selectedChapterForAI) { chapter in
                ChapterAIInsightsSheet(
                    chapter: chapter,
                    bookTitle: bookTitle,
                    bookAuthor: bookAuthor
                )
                .presentationDetents([.medium, .large])
            }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
