import SwiftUI
import Observation

// MARK: - ViewModel

@Observable
@MainActor
public class AudioPlayerViewModel {
    public var useTotalTrack = true

    public var jumpForwardTime: Int {
        return AppState.shared.settings.jumpForwardTime
    }

    public var jumpBackwardTime: Int {
        return AppState.shared.settings.jumpBackwardsTime
    }

    public let session: PlaybackSession

    public var title: String { session.displayTitle }
    public var author: String { session.displayAuthor }
    public var duration: TimeInterval {
        let actual = AudioPlayerService.shared.duration
        if actual > 0 { return actual }
        if session.duration > 0 { return session.duration }
        return session.audioTracks.reduce(0) { $0 + $1.duration }
    }
    public var chapters: [Chapter] { session.chapters }

    public var isPlaying: Bool {
        AudioPlayerService.shared.isPlaying
    }

    public var currentTime: TimeInterval {
        AudioPlayerService.shared.currentTime
    }

    public var libraryItemId: String? {
        AudioPlayerService.shared.session?.libraryItemId
    }

    public var playbackRate: Float {
        AudioPlayerService.shared.playbackRate
    }

    public var isBuffering: Bool {
        AudioPlayerService.shared.isBuffering
    }

    public var isSeeking: Bool {
        AudioPlayerService.shared.isSeeking
    }

    public var progress: Double {
        guard duration > 0, !currentTime.isNaN, !currentTime.isInfinite, !duration.isNaN, !duration.isInfinite else {
            return 0.0
        }
        return min(1.0, max(0.0, currentTime / duration))
    }

    public var bufferedProgress: Double {
        min(1.0, progress + 0.05)
    }

    public var sleepTimerActive: Bool {
        AudioPlayerService.shared.sleepTimerRemaining != nil
    }

    @discardableResult
    public func resetSleepTimer() -> Bool {
        AudioPlayerService.shared.resetSleepTimer()
    }

    @discardableResult
    public func extendSleepTimer(by seconds: TimeInterval) -> Bool {
        AudioPlayerService.shared.extendSleepTimer(by: seconds)
    }

    public var sleepTimerRemainingPretty: String {
        guard let remaining = AudioPlayerService.shared.sleepTimerRemaining, !remaining.isNaN, !remaining.isInfinite, remaining > 0 else { return "" }
        let total = Int(remaining)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    public var playbackQueue: [PlaybackSession] {
        AudioPlayerService.shared.playbackQueue
    }

    public func addToPlaybackQueue(_ session: PlaybackSession) {
        AudioPlayerService.shared.addToPlaybackQueue(session: session)
    }

    public func playNextInPlaybackQueue(_ session: PlaybackSession) {
        AudioPlayerService.shared.playNextInPlaybackQueue(session: session)
    }

    public func removeFromPlaybackQueue(at index: Int) {
        AudioPlayerService.shared.removeFromPlaybackQueue(at: index)
    }

    public func movePlaybackQueueItem(fromIndex: Int, toIndex: Int) {
        AudioPlayerService.shared.movePlaybackQueueItem(fromIndex: fromIndex, toIndex: toIndex)
    }

    public func clearPlaybackQueue() {
        AudioPlayerService.shared.clearPlaybackQueue()
    }

    public var totalQueueDuration: TimeInterval {
        AudioPlayerService.shared.totalQueueDuration
    }

    public var totalQueueDurationPretty: String {
        let total = totalQueueDuration
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    public var currentChapter: Chapter? {
        chapters.first { $0.start <= currentTime && $0.end > currentTime }
    }

    public var currentChapterTitle: String {
        currentChapter?.title ?? ""
    }

    public var hasNextChapter: Bool {
        chapters.contains { $0.start > currentTime }
    }

    public var totalProgress: Double {
        progress
    }

    public enum TimeRemainingMode: Int, CaseIterable, Sendable {
        case totalRemaining = 0
        case chapterRemaining = 1
        case estimatedFinishTime = 2
    }

    public var timeRemainingMode: TimeRemainingMode = .totalRemaining

    public var showChapterTimeRemaining: Bool {
        get { timeRemainingMode == .chapterRemaining }
        set { timeRemainingMode = newValue ? .chapterRemaining : .totalRemaining }
    }

    public var currentTimePretty: String {
        formatTime(currentTime)
    }

    public var durationPretty: String {
        formatTime(duration)
    }

    public var totalTimeRemainingPretty: String {
        let remaining = max(0, duration - currentTime)
        return "-" + formatTime(remaining)
    }

    public var currentChapterTimePretty: String {
        guard let chapter = currentChapter else { return currentTimePretty }
        return formatTime(max(0, currentTime - chapter.start))
    }

    public var timeRemainingPretty: String {
        formattedRemainingTime(for: currentTime)
    }

    public func toggleTimeRemainingMode() {
        let allModes = TimeRemainingMode.allCases
        let nextIndex = (timeRemainingMode.rawValue + 1) % allModes.count
        if nextIndex == 1 && chapters.isEmpty {
            timeRemainingMode = .estimatedFinishTime
        } else {
            timeRemainingMode = allModes[nextIndex]
        }
    }

    public func chapter(at time: TimeInterval) -> Chapter? {
        guard !chapters.isEmpty else { return nil }
        return chapters.first { $0.start <= time && $0.end > time } ?? chapters.last
    }

    public func chapterName(for timePos: Double) -> String? {
        guard !chapters.isEmpty else { return nil }
        let seconds = (timePos > 1000 && timePos > duration) ? (timePos / 1000.0) : timePos
        return chapter(at: seconds)?.title
    }

    public func formattedRemainingTime(for targetTime: TimeInterval, from now: Date = Date()) -> String {
        let rate: Double = Double((playbackRate.isNaN || playbackRate <= 0) ? 1.0 : playbackRate)

        switch timeRemainingMode {
        case .chapterRemaining:
            if let chapter = chapter(at: targetTime) {
                let remaining = max(0, chapter.end - targetTime) / rate
                return "-" + formatTime(remaining)
            }
            fallthrough
        case .totalRemaining:
            let remaining = max(0, duration - targetTime) / rate
            return "-" + formatTime(remaining)
        case .estimatedFinishTime:
            let remaining = max(0, duration - targetTime) / rate
            let finishDate = now.addingTimeInterval(remaining)
            let formatter = DateFormatter()
            let calendar = Calendar.current
            formatter.timeStyle = .short
            formatter.dateStyle = .none
            let timeString = formatter.string(from: finishDate)
            if calendar.isDateInToday(finishDate) {
                return "Ends \(timeString)"
            } else if calendar.isDateInTomorrow(finishDate) {
                return "Ends tom. \(timeString)"
            } else {
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "E"
                return "Ends \(dayFormatter.string(from: finishDate)) \(timeString)"
            }
        }
    }

    public init(session: PlaybackSession) {
        self.session = session

        // Start playback if it's a new or different session
        if AudioPlayerService.shared.session?.id != session.id {
            AudioPlayerService.shared.startPlayback(session: session)
        }
    }

    public func togglePlayPause() {
        AudioPlayerService.shared.togglePlayPause()
    }

    public func seek(to time: TimeInterval) {
        AudioPlayerService.shared.seek(to: time)
    }

    public func jumpForward() {
        AudioPlayerService.shared.skipForward(jumpForwardTime)
    }

    public func jumpBackward() {
        AudioPlayerService.shared.skipBackward(jumpBackwardTime)
    }

    public func skipForward(_ seconds: Int) {
        AudioPlayerService.shared.skipForward(seconds)
    }

    public func skipBackward(_ seconds: Int) {
        AudioPlayerService.shared.skipBackward(seconds)
    }

    public func jumpToChapterStart() {
        if let chapter = currentChapter {
            seek(to: chapter.start)
        }
    }

    public func jumpToNextChapter() {
        if let nextChapter = chapters.first(where: { $0.start > currentTime }) {
            seek(to: nextChapter.start)
        }
    }

    public var bookmarks: [Bookmark] {
        AudioPlayerService.shared.bookmarks
    }

    public var hasBookmarks: Bool {
        !bookmarks.isEmpty
    }

    public func addBookmark(title: String, note: String? = nil) {
        AudioPlayerService.shared.addBookmark(title: title, note: note)
    }

    public func deleteBookmark(_ bookmark: Bookmark) {
        AudioPlayerService.shared.deleteBookmark(bookmark)
    }

    public func updateBookmark(_ bookmark: Bookmark, title: String, note: String?) {
        AudioPlayerService.shared.updateBookmark(bookmark, title: title, note: note)
    }

    public func setPlaybackRate(_ rate: Float) {
        AudioPlayerService.shared.setPlaybackRate(rate)
    }

    public func showBookmarks() {}

    public func formatTime(_ time: TimeInterval) -> String {
        guard !time.isNaN && !time.isInfinite && time >= 0 else { return "0:00" }
        let totalSeconds = Int(time)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    public func exportBookmarksMarkdown() -> String {
        let bookTitle = title.isEmpty ? "Audiobook" : title
        let bookAuthor = author.isEmpty ? "Unknown Author" : author
        var md = "# Bookmarks for \(bookTitle)\n"
        md += "Author: \(bookAuthor)\n"
        md += "Exported from Audiobookphile\n\n"

        for bookmark in bookmarks {
            let timestamp = formatTime(bookmark.timePos)
            let bTitle = bookmark.title ?? "Bookmark at \(timestamp)"
            md += "### [\(timestamp)] \(bTitle)\n"
            if let note = bookmark.note, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                md += "> \(note.replacingOccurrences(of: "\n", with: "\n> "))\n"
            }
            md += "\n"
        }
        return md
    }

    public func exportBookmarksCSV() -> String {
        var csv = "ID,Time Position,Timestamp,Title,Note,Created At\n"
        for bookmark in bookmarks {
            let id = bookmark.id
            let timePos = String(format: "%.2f", bookmark.timePos)
            let timestamp = formatTime(bookmark.timePos)
            let title = (bookmark.title ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            let note = (bookmark.note ?? "").replacingOccurrences(of: "\"", with: "\"\"")
            let createdAt = bookmark.createdAt != nil ? ISO8601DateFormatter().string(from: bookmark.createdAt!) : ""
            csv += "\"\(id)\",\"\(timePos)\",\"\(timestamp)\",\"\(title)\",\"\(note)\",\"\(createdAt)\"\n"
        }
        return csv
    }

    public func exportBookmarksJSON() -> String {
        struct ExportItem: Codable {
            let id: String
            let timePos: Double
            let timestamp: String
            let title: String
            let note: String?
            let createdAt: String?
        }
        struct ExportPayload: Codable {
            let bookTitle: String
            let author: String
            let exportedAt: String
            let totalBookmarks: Int
            let bookmarks: [ExportItem]
        }

        let iso = ISO8601DateFormatter()
        let items: [ExportItem] = bookmarks.map { b in
            ExportItem(
                id: b.id,
                timePos: b.timePos,
                timestamp: formatTime(b.timePos),
                title: b.title ?? "Bookmark at \(formatTime(b.timePos))",
                note: b.note,
                createdAt: b.createdAt != nil ? iso.string(from: b.createdAt!) : nil
            )
        }

        let payload = ExportPayload(
            bookTitle: title.isEmpty ? "Audiobook" : title,
            author: author.isEmpty ? "Unknown Author" : author,
            exportedAt: iso.string(from: Date()),
            totalBookmarks: items.count,
            bookmarks: items
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(payload), let jsonString = String(data: data, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    }
}
