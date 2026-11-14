//
//  BookshelfView.swift
//  Audiobookphile
//
//  Main library view with glass design and parallax.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Observation

/// Main bookshelf/library view
public struct BookshelfView: View {
    @State var viewModel = BookshelfViewModel()
    var proMotion = ProMotionManager.shared
    @Environment(AppState.self) private var appState
    @State var showSearch = false
    @State var searchText = ""
    @State var scrollOffset: CGFloat = 0
    @State var selectedBookForDetails: Book?

    @State var selectedPill: LibraryPill = .library
    
    enum LibraryPill: String, CaseIterable {
        case library = "Library"
        case authors = "Authors"
        case narrators = "Narrators"
    }

    public init() {}

    public var body: some View {
        ZStack {
            // Animated background with particles
            backgroundLayer

            // Main content
            ScrollView {
                VStack(spacing: 24) {
                    // Main library grid
                    if selectedPill == .library {
                        libraryGridSection
                    } else if selectedPill == .authors {
                        authorsTabSection
                    } else {
                        narratorsTabSection
                    }

                    Spacer().frame(height: 100) // Bottom clearance for floating MiniPlayer
                }
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: proxy.frame(in: .named("scroll")).minY)
                })
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                scrollOffset = value
            }
            #if os(iOS) || SKIP
            .refreshable {
                await viewModel.refresh(libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)
            }
            #endif

            // Search overlay
            if showSearch {
                searchOverlay
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .navigationDestination(item: $selectedBookForDetails) { book in
            BookDetailView(book: book)
        }
        .audiobookphileNavigationToolbar(title: "Library")
        #if os(iOS) || SKIP
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Library View", selection: $selectedPill) {
                    Text("Library").tag(LibraryPill.library)
                    Text("Authors").tag(LibraryPill.authors)
                    Text("Narrators").tag(LibraryPill.narrators)
                }
                .pickerStyle(.segmented)
                .controlSize(.large)
                .tint(.appPrimary)
            }
            #if os(iOS) || SKIP
            ToolbarItem(placement: .topBarTrailing) {
                if selectedPill == .library {
                    Menu {
                        Section("Sort By") {
                            Button(action: {
                                Task {
                                    await viewModel.changeSort(sort: "addedAt", desc: true, libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)
                                }
                            }) {
                                Label("Recently Added", systemImage: viewModel.currentSort == "addedAt" && viewModel.currentDesc ? "checkmark" : "")
                            }
                            Button(action: {
                                Task {
                                    await viewModel.changeSort(sort: "title", desc: false, libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)
                                }
                            }) {
                                Label("Title (A-Z)", systemImage: viewModel.currentSort == "title" && !viewModel.currentDesc ? "checkmark" : "")
                            }
                            Button(action: {
                                Task {
                                    await viewModel.changeSort(sort: "author", desc: false, libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)
                                }
                            }) {
                                Label("Author (A-Z)", systemImage: viewModel.currentSort == "author" && !viewModel.currentDesc ? "checkmark" : "")
                            }
                            Button(action: {
                                Task {
                                    await viewModel.changeSort(sort: "duration", desc: true, libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)
                                }
                            }) {
                                Label("Longest Duration", systemImage: viewModel.currentSort == "duration" && viewModel.currentDesc ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .tint(.primary)
                }
            }
            #else
            ToolbarItem(placement: .primaryAction) {
                if selectedPill == .library {
                    Menu {
                        Section("Sort By") {
                            Button(action: {
                                Task {
                                    await viewModel.changeSort(sort: "addedAt", desc: true, libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)
                                }
                            }) {
                                Label("Recently Added", systemImage: viewModel.currentSort == "addedAt" && viewModel.currentDesc ? "checkmark" : "")
                            }
                            Button(action: {
                                Task {
                                    await viewModel.changeSort(sort: "title", desc: false, libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)
                                }
                            }) {
                                Label("Title (A-Z)", systemImage: viewModel.currentSort == "title" && !viewModel.currentDesc ? "checkmark" : "")
                            }
                            Button(action: {
                                Task {
                                    await viewModel.changeSort(sort: "author", desc: false, libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)
                                }
                            }) {
                                Label("Author (A-Z)", systemImage: viewModel.currentSort == "author" && !viewModel.currentDesc ? "checkmark" : "")
                            }
                            Button(action: {
                                Task {
                                    await viewModel.changeSort(sort: "duration", desc: true, libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)
                                }
                            }) {
                                Label("Longest Duration", systemImage: viewModel.currentSort == "duration" && viewModel.currentDesc ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .tint(.primary)
                }
            }
            #endif
        }
        .task(id: LibraryLoadTrigger(libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)) {
            await viewModel.loadLibrary(libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)
        }
        .applySensoryFeedback(trigger: selectedBookForDetails != nil)
    }

    // MARK: - Background Layer

    private var backgroundLayer: some View {
        FluidAuraBackground()
    }

    // MARK: - Navigation Pills removed in favor of Toolbar Picker

    // (Continue listening moved to HomeView)

    // MARK: - Library Grid

    private var libraryGridSection: some View {
        BookshelfGridSection(viewModel: viewModel, selectedBookForDetails: $selectedBookForDetails)
    }

    // MARK: - Authors and Narrators Sections

    private var authorsTabSection: some View {
        let grouped = Dictionary(grouping: viewModel.books, by: { $0.displayAuthor.trimmingCharacters(in: .whitespacesAndNewlines) })
            .filter { !$0.key.isEmpty }
            .sorted { $0.key < $1.key }

        return VStack(spacing: 12) {
            if grouped.isEmpty {
                VStack(spacing: 16) {
                    Spacer().frame(height: 60)
                    Image(systemName: "person.2")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("No Authors Found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(grouped, id: \.key) { author, books in
                    GlassCard {
                        HStack(spacing: 16) {
                            Circle()
                                .fill(Color.appPrimary.opacity(0.15))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(Color.appPrimary)
                                }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(author)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("\(books.count) \(books.count == 1 ? "Audiobook" : "Audiobooks")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .onTapGesture {
                        if let firstBook = books.first {
                            selectedBookForDetails = firstBook
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private var narratorsTabSection: some View {
        let grouped = Dictionary(grouping: viewModel.books, by: { ($0.narrator ?? "Unknown Narrator").trimmingCharacters(in: .whitespacesAndNewlines) })
            .filter { !$0.key.isEmpty }
            .sorted { $0.key < $1.key }

        return VStack(spacing: 12) {
            if grouped.isEmpty {
                VStack(spacing: 16) {
                    Spacer().frame(height: 60)
                    Image(systemName: "mic")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text("No Narrators Found")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(grouped, id: \.key) { narrator, books in
                    GlassCard {
                        HStack(spacing: 16) {
                            Circle()
                                .fill(DesignTokens.Color.surface.opacity(0.15))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Image(systemName: "mic.fill")
                                        .foregroundStyle(DesignTokens.Color.accentSecondary)
                                }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(narrator)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("\(books.count) \(books.count == 1 ? "Audiobook" : "Audiobooks")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .onTapGesture {
                        if let firstBook = books.first {
                            selectedBookForDetails = firstBook
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    // MARK: - Search Overlay

    private var searchOverlay: some View {
        BookshelfSearchOverlay(searchText: $searchText, showSearch: $showSearch, viewModel: viewModel, selectedBookForDetails: $selectedBookForDetails)
    }

    // MARK: - End BookshelfView
}
