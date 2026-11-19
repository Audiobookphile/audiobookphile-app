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
    @State var selectedAuthorName: String?
    @State var selectedNarratorInfo: SelectedNarratorInfo?
    @State var selectedSeriesName: String?
    @State var isListView: Bool = false

    @State var selectedPill: LibraryPill = .library
    
    enum LibraryPill: String, CaseIterable {
        case library = "Library"
        case series = "Series"
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
                VStack(spacing: 20) {
                    // Main library grid
                    if selectedPill == .library {
                        filterChipsBar
                        libraryGridSection
                    } else if selectedPill == .series {
                        seriesTabSection
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
            .searchable(text: $viewModel.filterSearchText, prompt: "Search audiobooks...")
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
        .navigationDestination(isPresented: Binding(
            get: { selectedAuthorName != nil },
            set: { if !$0 { selectedAuthorName = nil } }
        )) {
            if let author = selectedAuthorName {
                AuthorDetailView(authorName: author, libraryId: appState.currentLibraryId)
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedSeriesName != nil },
            set: { if !$0 { selectedSeriesName = nil } }
        )) {
            if let series = selectedSeriesName {
                SeriesDetailView(seriesName: series, libraryId: appState.currentLibraryId)
            }
        }
        .sheet(item: $selectedNarratorInfo) { info in
            NarratorDetailSheet(narratorName: info.name, books: info.books) { book in
                selectedBookForDetails = book
            }
        }
        .audiobookphileNavigationToolbar(title: "Library")
        #if os(iOS) || SKIP
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Library View", selection: $selectedPill) {
                    Text("Library").tag(LibraryPill.library)
                    Text("Series").tag(LibraryPill.series)
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
                    HStack(spacing: 8) {
                        Button {
                            withAnimation(DesignTokens.Spring.snappy) {
                                isListView.toggle()
                            }
                            DesignTokens.Haptics.selection()
                        } label: {
                            Image(systemName: isListView ? "square.grid.2x2" : "list.bullet")
                        }
                        .tint(.primary)
                        .help(isListView ? "Switch to Grid View" : "Switch to List View")

                        sortMenuView
                    }
                }
            }
            #else
            ToolbarItem(placement: .primaryAction) {
                if selectedPill == .library {
                    HStack(spacing: 8) {
                        Button {
                            withAnimation(DesignTokens.Spring.snappy) {
                                isListView.toggle()
                            }
                            DesignTokens.Haptics.selection()
                        } label: {
                            Image(systemName: isListView ? "square.grid.2x2" : "list.bullet")
                        }
                        .tint(.primary)
                        .help(isListView ? "Switch to Grid View" : "Switch to List View")

                        sortMenuView
                    }
                }
            }
            #endif
        }
        .task(id: LibraryLoadTrigger(libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)) {
            await viewModel.loadLibrary(libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)
        }
        .applySensoryFeedback(trigger: selectedBookForDetails != nil)
    }

    // MARK: - Filter Chips Bar

    private var filterChipsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(BookshelfFilter.allCases) { filter in
                    let isSelected = viewModel.selectedFilter == filter
                    let count = viewModel.count(for: filter)

                    Button(action: {
                        DesignTokens.Haptics.selection()
                        withAnimation(DesignTokens.Spring.snappy) {
                            viewModel.setFilter(filter)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: filter.iconName)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            Text(filter.rawValue)
                                .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(isSelected ? Color.white.opacity(0.25) : Color.primary.opacity(0.08))
                                    )
                            }
                        }
                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                        .glassPill(isSelected: isSelected, tint: Color.appPrimary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }

    // MARK: - Sort Menu

    private var sortMenuView: some View {
        Menu {
            Section("Recently Added") {
                Button(action: { changeSort(to: .recentlyAdded) }) {
                    Label("Recently Added", systemImage: viewModel.selectedSort == .recentlyAdded ? "checkmark" : "")
                }
                Button(action: { changeSort(to: .oldestAdded) }) {
                    Label("Oldest Added", systemImage: viewModel.selectedSort == .oldestAdded ? "checkmark" : "")
                }
            }

            Section("Title") {
                Button(action: { changeSort(to: .titleAZ) }) {
                    Label("Title (A-Z)", systemImage: viewModel.selectedSort == .titleAZ ? "checkmark" : "")
                }
                Button(action: { changeSort(to: .titleZA) }) {
                    Label("Title (Z-A)", systemImage: viewModel.selectedSort == .titleZA ? "checkmark" : "")
                }
            }

            Section("Author") {
                Button(action: { changeSort(to: .authorAZ) }) {
                    Label("Author (A-Z)", systemImage: viewModel.selectedSort == .authorAZ ? "checkmark" : "")
                }
                Button(action: { changeSort(to: .authorZA) }) {
                    Label("Author (Z-A)", systemImage: viewModel.selectedSort == .authorZA ? "checkmark" : "")
                }
            }

            Section("Duration") {
                Button(action: { changeSort(to: .longestDuration) }) {
                    Label("Longest Duration", systemImage: viewModel.selectedSort == .longestDuration ? "checkmark" : "")
                }
                Button(action: { changeSort(to: .shortestDuration) }) {
                    Label("Shortest Duration", systemImage: viewModel.selectedSort == .shortestDuration ? "checkmark" : "")
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
        }
        .tint(.primary)
    }

    private func changeSort(to option: BookshelfSortOption) {
        Task {
            await viewModel.changeSort(option: option, libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated)
        }
    }

    // MARK: - Background Layer

    private var backgroundLayer: some View {
        FluidAuraBackground()
    }

    // MARK: - Navigation Pills removed in favor of Toolbar Picker

    // (Continue listening moved to HomeView)

    // MARK: - Library Grid

    private var libraryGridSection: some View {
        BookshelfGridSection(viewModel: viewModel, selectedBookForDetails: $selectedBookForDetails, isListView: isListView)
    }

    // MARK: - Series Section

    private var seriesTabSection: some View {
        let query = viewModel.filterSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let grouped = Dictionary(grouping: viewModel.books.compactMap { b -> (String, Book)? in
            guard let name = b.seriesName?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
                return nil
            }
            return (name, b)
        }, by: { $0.0 })
        .mapValues { pairs in pairs.map { $0.1 } }
        .filter { seriesName, _ in
            query.isEmpty || seriesName.lowercased().contains(query)
        }
        .sorted { $0.key < $1.key }

        return VStack(spacing: 12) {
            if grouped.isEmpty {
                VStack(spacing: 16) {
                    Spacer().frame(height: 60)
                    Image(systemName: "books.vertical")
                        .font(.system(size: 44))
                        .foregroundStyle(.secondary)
                    Text(query.isEmpty ? "No Series Found" : "No Series Matching \"\(viewModel.filterSearchText)\"")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(grouped, id: \.key) { seriesName, books in
                    let totalDuration = books.reduce(0.0) { $0 + $1.duration }
                    GlassCard {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.appPrimary.opacity(0.15))
                                    .frame(width: 52, height: 52)

                                Image(systemName: "books.vertical.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.appPrimary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(seriesName)
                                    .font(.headline)
                                    .foregroundStyle(.primary)

                                HStack(spacing: 8) {
                                    Text("\(books.count) \(books.count == 1 ? "Audiobook" : "Audiobooks")")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if totalDuration > 0 {
                                        Text("•")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                        Text(formatSeriesDuration(totalDuration))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                    .onTapGesture {
                        DesignTokens.Haptics.selection()
                        selectedSeriesName = seriesName
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func formatSeriesDuration(_ duration: TimeInterval) -> String {
        let total = Int(max(0, duration))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
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
                        selectedAuthorName = author
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
                        selectedNarratorInfo = SelectedNarratorInfo(name: narrator, books: books)
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
}

public struct SelectedNarratorInfo: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let books: [Book]

    public init(name: String, books: [Book]) {
        self.id = name
        self.name = name
        self.books = books
    }
}
