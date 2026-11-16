import SwiftUI

public struct CollectionsView: View {
    public enum CollectionType: String, CaseIterable {
        case series = "Series"
        case collections = "Collections"
        case playlists = "Playlists"
    }

    @State private var selectedType: CollectionType = .collections
    @State private var viewModel = CollectionsViewModel()
    @Environment(AppState.self) private var appState

    public init() {}

    public var body: some View {
        ZStack {
            FluidAuraBackground()

            if viewModel.isLoading && viewModel.series.isEmpty && viewModel.collections.isEmpty && viewModel.playlists.isEmpty {
                ProgressView()
                    .controlSize(.large)
                    .tint(.appPrimary)
            } else {
                CollectionListView(
                    type: selectedType,
                    series: viewModel.series,
                    collections: viewModel.collections,
                    playlists: viewModel.playlists,
                    libraryId: appState.currentLibraryId
                )
            }
        }
        .audiobookphileNavigationToolbar(title: "Collections")
        #if os(iOS) || SKIP
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await viewModel.refresh(libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated, type: selectedType)
        }
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Collection Type", selection: $selectedType) {
                    Text("Series").tag(CollectionType.series)
                    Text("Collections").tag(CollectionType.collections)
                    Text("Playlists").tag(CollectionType.playlists)
                }
                .pickerStyle(.segmented)
                .controlSize(.large)
                .tint(.appPrimary)
            }
        }
        .task(id: selectedType) {
            await viewModel.loadData(libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated, type: selectedType)
        }
        .task(id: appState.currentLibraryId) {
            await viewModel.refresh(libraryId: appState.currentLibraryId, isAuthenticated: appState.isAuthenticated, type: selectedType)
        }
    }
}
