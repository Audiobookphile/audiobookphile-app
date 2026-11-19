import Foundation
#if canImport(OSLog)
import OSLog
#endif

@MainActor
public class AudioPlayerBookmarkManager {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Audiobookphile", category: "BookmarkManager")

    public init() {}

    public func fetchBookmarks(libraryItemId: String) async -> [Bookmark] {
        do {
            return try await AudiobookphileAPI.shared.fetchBookmarks(libraryItemId: libraryItemId)
        } catch {
            logger.error("Failed to fetch bookmarks: \(error)")
            return []
        }
    }

    public func addBookmark(title: String, note: String? = nil, currentTime: TimeInterval, libraryItemId: String) async -> Bookmark? {
        let newTitle = title.isEmpty ? "Bookmark at \(formatTime(currentTime))" : title
        do {
            return try await AudiobookphileAPI.shared.createBookmark(
                libraryItemId: libraryItemId,
                timePos: currentTime,
                title: newTitle,
                note: note
            )
        } catch {
            logger.error("Failed to add bookmark: \(error)")
            return nil
        }
    }

    public func updateBookmark(bookmarkId: String, title: String? = nil, note: String? = nil, timePos: Double? = nil) async -> Bookmark? {
        do {
            return try await AudiobookphileAPI.shared.updateBookmark(
                bookmarkId: bookmarkId,
                title: title,
                note: note,
                timePos: timePos
            )
        } catch {
            logger.error("Failed to update bookmark: \(error)")
            return nil
        }
    }

    public func deleteBookmark(_ bookmark: Bookmark, libraryItemId: String) async -> Bool {
        do {
            try await AudiobookphileAPI.shared.deleteBookmark(bookmarkId: bookmark.id)
            return true
        } catch {
            logger.error("Failed to delete bookmark: \(error)")
            return false
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
