import SwiftUI

/// Elevated Bookmarks management list supporting real-time search, multi-line editing,
/// and multi-format export (Markdown, CSV, JSON) conforming to upstream Audiobookshelf specs.
public struct BookmarksListView: View {
    var viewModel: AudioPlayerViewModel
    @Environment(\.dismiss) var dismiss

    @State private var searchText = ""
    @State private var editingBookmark: Bookmark?
    @State private var editTitle: String = ""
    @State private var editNote: String = ""

    public init(viewModel: AudioPlayerViewModel) {
        self.viewModel = viewModel
    }

    private var filteredBookmarks: [Bookmark] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return viewModel.bookmarks }
        return viewModel.bookmarks.filter { b in
            let titleMatch = (b.title ?? "").lowercased().contains(query)
            let noteMatch = (b.note ?? "").lowercased().contains(query)
            let timeMatch = viewModel.formatTime(b.timePos).lowercased().contains(query)
            let chapterMatch = (viewModel.chapterName(for: b.timePos) ?? "").lowercased().contains(query)
            return titleMatch || noteMatch || timeMatch || chapterMatch
        }
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                FluidAuraBackground()

                List {
                    if viewModel.bookmarks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bookmark.slash")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No bookmarks yet")
                                .font(.headline)
                            Text("Tap the bookmark icon in the player to save your favorite moments.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .listRowBackground(Color.clear)
                    } else if filteredBookmarks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            Text("No matching bookmarks")
                                .font(.headline)
                            Text("No bookmarks found matching \"\(searchText)\".")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Clear Search") {
                                searchText = ""
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color.appPrimary)
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(filteredBookmarks) { bookmark in
                            bookmarkRow(bookmark)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        viewModel.deleteBookmark(bookmark)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        startEditing(bookmark)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                .scrollContentBackground(.hidden)
                .searchable(text: $searchText, prompt: "Search title, notes, chapter, or time...")
                .navigationTitle(viewModel.bookmarks.isEmpty ? "Bookmarks" : "Bookmarks (\(viewModel.bookmarks.count))")
                #if os(iOS) || SKIP
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    #if !SKIP
                    if !viewModel.bookmarks.isEmpty {
                        ToolbarItem(placement: .cancellationAction) {
                            Menu {
                                ShareLink(
                                    item: viewModel.exportBookmarksMarkdown(),
                                    subject: Text("\(viewModel.title) Bookmarks"),
                                    message: Text("Exported Bookmarks & Notes (Markdown)")
                                ) {
                                    Label("Export Markdown (.md)", systemImage: "doc.text")
                                }

                                ShareLink(
                                    item: viewModel.exportBookmarksCSV(),
                                    subject: Text("\(viewModel.title) Bookmarks"),
                                    message: Text("Exported Bookmarks & Notes (CSV)")
                                ) {
                                    Label("Export CSV (.csv)", systemImage: "tablecells")
                                }

                                ShareLink(
                                    item: viewModel.exportBookmarksJSON(),
                                    subject: Text("\(viewModel.title) Bookmarks"),
                                    message: Text("Exported Bookmarks & Notes (JSON)")
                                ) {
                                    Label("Export JSON (.json)", systemImage: "curlybraces")
                                }
                            } label: {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                    #endif

                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
                .sheet(item: $editingBookmark) { bookmark in
                    editSheet(bookmark: bookmark)
                }
            }
        }
    }

    @ViewBuilder
    private func bookmarkRow(_ bookmark: Bookmark) -> some View {
        Button {
            viewModel.seek(to: bookmark.timePos)
            dismiss()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "bookmark.fill")
                        .foregroundStyle(Color.appPrimary)
                        .font(.subheadline)
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(bookmark.title ?? "Bookmark")
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        Spacer()

                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(viewModel.formatTime(bookmark.timePos))
                                .font(.caption.monospaced())
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.white.opacity(0.08), in: Capsule())
                    }

                    if let chapterTitle = viewModel.chapterName(for: bookmark.timePos), !chapterTitle.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "bookmark")
                                .font(.system(size: 9))
                            Text(chapterTitle)
                                .font(.caption2.weight(.medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(Color.appPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.appPrimary.opacity(0.12), in: Capsule())
                    }

                    if let note = bookmark.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .padding(.vertical, 2)
                    }
                }

                Button {
                    copyBookmarkLink(bookmark)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                Button {
                    startEditing(bookmark)
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)

                Image(systemName: "play.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.appPrimary)
                    .padding(.top, 4)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                viewModel.seek(to: bookmark.timePos)
                dismiss()
            } label: {
                Label("Play from Bookmark", systemImage: "play.circle")
            }

            Button {
                copyBookmarkLink(bookmark)
            } label: {
                Label("Copy Timestamp Link", systemImage: "doc.on.doc")
            }

            Button {
                startEditing(bookmark)
            } label: {
                Label("Edit Note", systemImage: "pencil")
            }

            Button(role: .destructive) {
                viewModel.deleteBookmark(bookmark)
            } label: {
                Label("Delete Bookmark", systemImage: "trash")
            }
        }
    }

    private func copyBookmarkLink(_ bookmark: Bookmark) {
        let seconds = Int(bookmark.timePos / 1000)
        let itemId = viewModel.libraryItemId ?? ""
        let link = "audiobookphile://item/\(itemId)?t=\(seconds)"
        #if !SKIP && os(iOS)
        UIPasteboard.general.string = link
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        #endif
    }

    private func startEditing(_ bookmark: Bookmark) {
        editTitle = bookmark.title ?? "Bookmark at \(viewModel.formatTime(bookmark.timePos))"
        editNote = bookmark.note ?? ""
        editingBookmark = bookmark
    }

    @ViewBuilder
    private func editSheet(bookmark: Bookmark) -> some View {
        NavigationStack {
            ZStack {
                FluidAuraBackground()

                Form {
                    Section {
                        TextField("Title", text: $editTitle)
                    } header: {
                        Text("Bookmark Title")
                    }

                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(["Quote", "Key Idea", "Plot", "Review", "Vocabulary"], id: \.self) { tag in
                                    Button {
                                        let tagPrefix = "[\(tag)] "
                                        if !editNote.contains(tagPrefix) {
                                            editNote = tagPrefix + editNote
                                        }
                                        DesignTokens.Haptics.selection()
                                    } label: {
                                        Text("+\(tag)")
                                            .font(.caption.weight(.semibold))
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.white.opacity(0.1), in: Capsule())
                                            .foregroundStyle(Color.appPrimary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("Quick Category Tags")
                    }

                    Section {
                        TextEditor(text: $editNote)
                            .frame(minHeight: 120)
                    } header: {
                        Text("Notes & Commentary")
                    } footer: {
                        Text("Timestamp: \(viewModel.formatTime(bookmark.timePos))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Edit Bookmark")
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        editingBookmark = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmedNote = editNote.trimmingCharacters(in: .whitespacesAndNewlines)
                        viewModel.updateBookmark(
                            bookmark,
                            title: editTitle,
                            note: trimmedNote.isEmpty ? nil : trimmedNote
                        )
                        editingBookmark = nil
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

