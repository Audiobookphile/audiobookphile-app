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

    public var sleepTimerRemainingPretty: String {
        guard let remaining = AudioPlayerService.shared.sleepTimerRemaining, !remaining.isNaN, !remaining.isInfinite, remaining > 0 else { return "" }
        let total = Int(remaining)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
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

    public var showChapterTimeRemaining: Bool = false

    public var currentTimePretty: String {
        formatTime(currentTime)
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
        if showChapterTimeRemaining, let chapter = currentChapter {
            return "-" + formatTime(max(0, chapter.end - currentTime))
        }
        return totalTimeRemainingPretty
    }

    public func toggleTimeRemainingMode() {
        showChapterTimeRemaining.toggle()
    }

    public func chapter(at time: TimeInterval) -> Chapter? {
        guard !chapters.isEmpty else { return nil }
        return chapters.first { $0.start <= time && $0.end > time } ?? chapters.last
    }

    public func formattedRemainingTime(for targetTime: TimeInterval) -> String {
        if showChapterTimeRemaining, let chapter = chapter(at: targetTime) {
            return "-" + formatTime(max(0, chapter.end - targetTime))
        }
        let remaining = max(0, duration - targetTime)
        return "-" + formatTime(remaining)
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

    public func addBookmark(title: String) {
        AudioPlayerService.shared.addBookmark(title: title)
    }

    public func deleteBookmark(_ bookmark: Bookmark) {
        AudioPlayerService.shared.deleteBookmark(bookmark)
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
}
