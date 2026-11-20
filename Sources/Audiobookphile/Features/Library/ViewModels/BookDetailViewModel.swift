//
//  BookDetailViewModel.swift
//  Audiobookphile
//

import SwiftUI
import Observation

@Observable
@MainActor
public class BookDetailViewModel {
    public var book: Book
    public var detailedBook: Book?
    public var isLoading = true
    public var playbackError: String?
    public var showPlaybackError = false
    public var isStartingPlayback = false
    public var showRemoveDownloadConfirmation = false
    public var isDescriptionExpanded = false
    public var similarBooks: [Book] = []
    public var previousInSeries: Book?
    public var nextInSeries: Book?
    public var hasCopiedRssFeed = false
    public var hasCopiedShareLink = false
    public var hasAddedToQueue = false

    public var colorLoader = DynamicColorLoader()
    private var downloadService = DownloadService.shared

    public init(book: Book) {
        self.book = book
    }

    public func fetchDetails(appState: AppState) async {
        isLoading = true
        do {
            let detailed = try await AudiobookphileAPI.shared.getLibraryItem(id: book.id)
            self.detailedBook = detailed
            if let coverUrl = appState.getCoverURL(itemId: detailed.id, width: 600, updatedAt: detailed.updatedAt) {
                await colorLoader.loadColor(from: coverUrl)
            }
            // Fetch Similar Books in parallel or sequentially
            let similar = try? await AudiobookphileAPI.shared.getSimilarItems(itemId: book.id)
            if let similar {
                self.similarBooks = similar
            }

            // Fetch Series Continuity if book belongs to a series
            if let sName = detailed.seriesName ?? book.seriesName, !sName.isEmpty {
                await loadSeriesContinuity(seriesName: sName, currentBookId: detailed.id)
            }
        } catch {
            print("[BookDetailViewModel] Error fetching detailed metadata: \(error)")
            playbackError = error.localizedDescription
            showPlaybackError = true
        }
        isLoading = false
    }

    public func loadSeriesContinuity(seriesName: String, currentBookId: String) async {
        let service: LibraryServiceProtocol = AppState.shared.isAuthenticated ? LiveLibraryService() : MockLibraryService()
        let libId = detailedBook?.libraryId ?? book.libraryId
        do {
            let seriesBooks = try await service.fetchBooksBySeries(seriesName: seriesName, libraryId: libId)
            guard !seriesBooks.isEmpty else { return }

            if let idx = seriesBooks.firstIndex(where: { $0.id == currentBookId }) {
                if idx > 0 {
                    self.previousInSeries = seriesBooks[idx - 1]
                }
                if idx + 1 < seriesBooks.count {
                    self.nextInSeries = seriesBooks[idx + 1]
                }
            }
        } catch {
            print("[BookDetailViewModel] Failed to load series continuity: \(error)")
        }
    }

    public func playBook(_ detailed: Book, seekToTime: TimeInterval? = nil, dismiss: DismissAction) {
        Task {
            isStartingPlayback = true
            defer { isStartingPlayback = false }
            do {
                let session = try await AudiobookphileAPI.shared.startPlaybackSession(libraryItemId: detailed.id)

                // If a seek time is supplied (e.g. from tapping a chapter), store it before starting
                if let seekTime = seekToTime {
                    UserDefaults.standard.set(seekTime, forKey: "pendingSeekTime-\(session.id)")
                }

                // Actually start playback (loads tracks, sets up AVPlayer, starts playing)
                AudioPlayerService.shared.startPlayback(session: session)

                dismiss()

                // Open full player using the Coordinator with a slight delay
                // to allow the dismissal animation to complete.
                PlayerCoordinator.shared.presentPlayer(delayMilliseconds: 500)

            } catch {
                print("Failed to start playback session: \(error)")
                playbackError = error.localizedDescription
                showPlaybackError = true
            }
        }
    }
    
    public func removeDownload() {
        if let detailed = detailedBook {
            try? downloadService.deleteDownload(bookId: detailed.id)
        }
    }

    public func toggleFinished() {
        guard let detailed = detailedBook else { return }
        let currentlyFinished = detailed.userMediaProgress?.isFinished ?? false
        let newFinished = !currentlyFinished
        Task {
            do {
                try await AudiobookphileAPI.shared.updateMediaProgress(libraryItemId: detailed.id, isFinished: newFinished)
                let duration = detailed.duration
                let newProgress = MediaProgress(
                    id: detailed.userMediaProgress?.id ?? UUID().uuidString,
                    libraryItemId: detailed.id,
                    episodeId: nil,
                    duration: duration,
                    progress: newFinished ? 1.0 : 0.0,
                    currentTime: newFinished ? duration : 0.0,
                    isFinished: newFinished,
                    hideFromContinueListening: newFinished,
                    lastUpdate: Date(),
                    startedAt: detailed.userMediaProgress?.startedAt ?? Date(),
                    finishedAt: newFinished ? Date() : nil
                )
                detailedBook?.userMediaProgress = newProgress
            } catch {
                print("[BookDetailViewModel] Error toggling finished: \(error)")
            }
        }
    }

    public func resetProgress() {
        guard let detailed = detailedBook else { return }
        Task {
            do {
                try await AudiobookphileAPI.shared.updateMediaProgress(
                    libraryItemId: detailed.id,
                    isFinished: false,
                    currentTime: 0
                )
                let duration = detailed.duration
                let newProgress = MediaProgress(
                    id: detailed.userMediaProgress?.id ?? UUID().uuidString,
                    libraryItemId: detailed.id,
                    episodeId: nil,
                    duration: duration,
                    progress: 0.0,
                    currentTime: 0.0,
                    isFinished: false,
                    hideFromContinueListening: false,
                    lastUpdate: Date(),
                    startedAt: nil,
                    finishedAt: nil
                )
                detailedBook?.userMediaProgress = newProgress
                DesignTokens.Haptics.success()
            } catch {
                print("[BookDetailViewModel] Error resetting progress: \(error)")
            }
        }
    }
    
    public func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    public func copyRssFeed(for book: Book) {
        let serverUrl = AppState.shared.serverURL.isEmpty ? "https://audiobookphile.app" : AppState.shared.serverURL
        let cleanServer = serverUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let feedUrl = "\(cleanServer)/feed/\(book.id)"
        #if !SKIP && os(iOS)
        UIPasteboard.general.string = feedUrl
        #endif
        hasCopiedRssFeed = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            hasCopiedRssFeed = false
        }
    }

    public func shareURL(for book: Book, withTimestamp: Bool = false) -> String {
        let serverUrl = AppState.shared.serverURL.isEmpty ? "https://audiobookphile.app" : AppState.shared.serverURL
        let cleanServer = serverUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let base = "\(cleanServer)/library/\(book.libraryId ?? "default")/item/\(book.id)"
        if withTimestamp, let progress = detailedBook?.userMediaProgress?.currentTime, progress > 0 {
            return "\(base)?t=\(Int(progress))"
        }
        return base
    }

    public func copyShareLink(for book: Book, withTimestamp: Bool = false) {
        let url = shareURL(for: book, withTimestamp: withTimestamp)
        #if !SKIP && os(iOS)
        UIPasteboard.general.string = url
        #endif
        hasCopiedShareLink = true
        DesignTokens.Haptics.success()
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            hasCopiedShareLink = false
        }
    }

    public func addToQueue(_ detailed: Book) {
        Task {
            do {
                let session = try await AudiobookphileAPI.shared.startPlaybackSession(libraryItemId: detailed.id)
                AudioPlayerService.shared.addToPlaybackQueue(session: session)
                hasAddedToQueue = true
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                hasAddedToQueue = false
            } catch {
                print("Failed to add to queue: \(error)")
            }
        }
    }

    public func playNext(_ detailed: Book) {
        Task {
            do {
                let session = try await AudiobookphileAPI.shared.startPlaybackSession(libraryItemId: detailed.id)
                AudioPlayerService.shared.playNextInPlaybackQueue(session: session)
                hasAddedToQueue = true
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                hasAddedToQueue = false
            } catch {
                print("Failed to play next: \(error)")
            }
        }
    }
}
