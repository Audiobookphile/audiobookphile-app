import SwiftUI

public struct ChapterSelectionView: View {
    public let chapters: [Chapter]
    public let currentChapter: Chapter?
    public let currentTime: TimeInterval?
    public let bookTitle: String
    public let bookAuthor: String?
    public let onSelect: (Chapter) -> Void

    @Environment(\.dismiss) var dismiss
    @State private var selectedChapterForAI: Chapter?
    @State private var searchText = ""
    @State private var isReversed = false

    private var filteredChapters: [Chapter] {
        let filtered = Chapter.filter(chapters: chapters, query: searchText)
        return isReversed ? filtered.reversed() : filtered
    }

    private var leadingPlacement: ToolbarItemPlacement {
        #if os(iOS) || SKIP
        return .navigationBarLeading
        #else
        return .navigation
        #endif
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
        currentTime: TimeInterval? = nil,
        bookTitle: String = "Audiobook",
        bookAuthor: String? = nil,
        onSelect: @escaping (Chapter) -> Void
    ) {
        self.chapters = chapters
        self.currentChapter = currentChapter
        self.currentTime = currentTime
        self.bookTitle = bookTitle
        self.bookAuthor = bookAuthor
        self.onSelect = onSelect
    }

    public var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ZStack {
                    FluidAuraBackground()

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
                                                    .foregroundStyle(
                                                        chapter.id == currentChapter?.id
                                                            ? Color.appPrimary
                                                            : (isListened(chapter) ? .secondary : .primary)
                                                    )

                                                HStack(spacing: 6) {
                                                    Text(formatTimestamp(chapter.start))
                                                        .font(.caption2.monospaced())
                                                        .fontWeight(.semibold)
                                                        .padding(.horizontal, 6)
                                                        .padding(.vertical, 2)
                                                        .background(Color.white.opacity(0.08))
                                                        .clipShape(Capsule())

                                                    Text(formatDuration(chapter.end - chapter.start))
                                                        .font(.caption)
                                                        .fontWeight(chapter.id == currentChapter?.id ? .bold : .regular)
                                                        .foregroundStyle(.secondary)

                                                    if isListened(chapter) {
                                                        Text("Listened")
                                                            .font(.caption2.bold())
                                                            .foregroundStyle(Color.green)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.green.opacity(0.12))
                                                            .clipShape(Capsule())
                                                    }

                                                    if chapter.id == currentChapter?.id, let current = currentTime {
                                                        let remaining = max(0, chapter.end - current)
                                                        Text("-\(formatDuration(remaining)) left")
                                                            .font(.caption2.bold())
                                                            .foregroundStyle(Color.appPrimary)
                                                            .padding(.horizontal, 6)
                                                            .padding(.vertical, 2)
                                                            .background(Color.appPrimary.opacity(0.15))
                                                            .clipShape(Capsule())
                                                    }
                                                }

                                                if chapter.id == currentChapter?.id, let current = currentTime {
                                                    let chapterDur = chapter.end - chapter.start
                                                    let progress = chapterDur > 0 ? min(1.0, max(0.0, (current - chapter.start) / chapterDur)) : 0.0
                                                    GeometryReader { g in
                                                        ZStack(alignment: .leading) {
                                                            Capsule()
                                                                .fill(Color.white.opacity(0.12))
                                                                .frame(height: 3)
                                                            Capsule()
                                                                .fill(Color.appPrimary)
                                                                .frame(width: max(0, g.size.width * CGFloat(progress)), height: 3)
                                                        }
                                                    }
                                                    .frame(height: 3)
                                                    .padding(.top, 2)
                                                }
                                            }

                                            Spacer()

                                            if chapter.id == currentChapter?.id {
                                                Image(systemName: "speaker.wave.2.fill")
                                                    .foregroundStyle(Color.appPrimary)
                                            } else if isListened(chapter) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .font(.subheadline)
                                                    .foregroundStyle(Color.green.opacity(0.85))
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
                                .contextMenu {
                                    Button {
                                        onSelect(chapter)
                                    } label: {
                                        Label("Play Chapter", systemImage: "play.circle")
                                    }

                                    Button {
                                        copyChapterLink(chapter)
                                    } label: {
                                        Label("Copy Chapter Link", systemImage: "link")
                                    }

                                    Button {
                                        selectedChapterForAI = chapter
                                    } label: {
                                        Label("AI Insights", systemImage: "sparkles")
                                    }
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
                    ToolbarItem(placement: leadingPlacement) {
                        HStack(spacing: 12) {
                            Button {
                                withAnimation(DesignTokens.Spring.snappy) {
                                    isReversed.toggle()
                                }
                                DesignTokens.Haptics.selection()
                            } label: {
                                Image(systemName: isReversed ? "arrow.up.arrow.down.circle.fill" : "arrow.up.arrow.down.circle")
                                    .foregroundStyle(isReversed ? Color.appPrimary : Color.primary)
                            }
                            .help(isReversed ? "Reverse order (Newest first)" : "Standard order (Oldest first)")

                            if currentChapter != nil {
                                Button {
                                    if let current = currentChapter {
                                        withAnimation(DesignTokens.Spring.snappy) {
                                            proxy.scrollTo(current.id, anchor: .center)
                                        }
                                        DesignTokens.Haptics.light()
                                    }
                                } label: {
                                    Image(systemName: "scope")
                                        .foregroundStyle(Color.appPrimary)
                                }
                                .help("Jump to Playing Chapter")
                            }
                        }
                    }

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

    private func formatTimestamp(_ timestamp: TimeInterval) -> String {
        let total = Int(max(0, timestamp))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let total = Int(max(0, duration))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m \(seconds)s"
    }

    private func isListened(_ chapter: Chapter) -> Bool {
        guard let current = currentTime else { return false }
        return current >= chapter.end
    }

    private func copyChapterLink(_ chapter: Chapter) {
        let itemId = AudioPlayerService.shared.session?.libraryItemId ?? ""
        let urlString = "audiobookphile://item/\(itemId)?t=\(Int(chapter.start))"
        #if os(iOS) && !SKIP
        UIPasteboard.general.string = urlString
        #endif
        DesignTokens.Haptics.selection()
    }
}
