//
//  StatsView.swift
//  Audiobookphile
//
//  Rich listening statistics and library analytics backed by the Supabase Edge API.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

public struct StatsView: View {
    @Environment(AppState.self) private var appState

    @State private var selectedTab: StatsTab = .myListening
    @State private var libraryStats: LibraryStats?
    @State private var userStats: UserStatsData?
    @State private var isLoading = true
    @State private var errorMessage: String?

    enum StatsTab: String, CaseIterable, Identifiable {
        case myListening = "My Listening"
        case libraryOverview = "Library Catalog"
        var id: String { rawValue }
    }

    public init() {}

    public var body: some View {
        ZStack {
            FluidAuraBackground()

            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection

                    // Segmented Mode Switcher
                    Picker("Stats View", selection: $selectedTab) {
                        ForEach(StatsTab.allCases) { tab in
                            Text(tab.rawValue).tag(tab)
                        }
                    }
                    .pickerStyle(.segmented)
                    .controlSize(.regular)
                    .tint(.appPrimary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)

                    if isLoading && libraryStats == nil && userStats == nil {
                        statsLoadingSkeleton
                    } else if let error = errorMessage, libraryStats == nil && userStats == nil {
                        errorView(error)
                    } else {
                        if selectedTab == .myListening {
                            myListeningContent
                        } else {
                            libraryOverviewContent
                        }
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 16)
            }
            #if os(iOS) || SKIP
            .refreshable {
                await loadStats()
            }
            #endif
        }
        .navigationTitle("Stats")
        #if os(iOS) || SKIP
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            await loadStats()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar.xaxis.ascending")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.appPrimary, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(.bottom, 4)

            Text("Listening Stats")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text("Your personal listening habits and library overview")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // MARK: - My Listening Tab

    @ViewBuilder
    private var myListeningContent: some View {
        let stats = userStats ?? fallbackUserStats
        let streak = calculateStreak(sessions: stats.recentSessions)
        let totalSeconds = calculateTotalListeningSeconds(sessions: stats.recentSessions, progress: stats.mediaProgress)
        let finishedCount = stats.mediaProgress.filter { $0.isFinished == true }.count
        let weeklyActivity = calculateWeeklyActivity(sessions: stats.recentSessions)

        VStack(spacing: 20) {
            // Hero Streak & Time Card
            heroStreakCard(streak: streak, totalSeconds: totalSeconds, finishedCount: finishedCount)

            // Weekly Listening Bar Chart
            weeklyActivityCard(weeklyActivity: weeklyActivity)

            // In Progress Audiobooks
            let inProgress = stats.mediaProgress.filter { !($0.isFinished ?? false) }
            if !inProgress.isEmpty {
                inProgressSection(inProgress: inProgress)
            }

            // Recent Listening Sessions
            if !stats.recentSessions.isEmpty {
                recentSessionsSection(sessions: stats.recentSessions)
            }
        }
    }

    // MARK: - Hero Streak Card

    private func heroStreakCard(streak: Int, totalSeconds: TimeInterval, finishedCount: Int) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                // Streak Pill / Fire
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.orange, .red],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        Text("\(streak)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }

                    Text(streak == 1 ? "Day Streak" : "Days Streak")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.orange.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.orange.opacity(0.25), lineWidth: 1)
                )

                // Books Finished
                VStack(spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.appPrimary)
                        Text("\(finishedCount)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                    }

                    Text(finishedCount == 1 ? "Book Finished" : "Books Finished")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.appPrimary.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(Color.appPrimary.opacity(0.25), lineWidth: 1)
                )
            }

            // Total Listening Time Banner
            HStack(spacing: 12) {
                Image(systemName: "headphones")
                    .font(.title2)
                    .foregroundStyle(Color.appPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Total Time Listened")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatDuration(totalSeconds))
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(.primary)
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(DesignTokens.Color.surface.opacity(0.4))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Weekly Activity Bar Chart

    private func weeklyActivityCard(weeklyActivity: [DayActivity]) -> some View {
        let maxMinutes = max(weeklyActivity.map(\.minutes).max() ?? 60, 60)
        let totalWeekMinutes = weeklyActivity.map(\.minutes).reduce(0, +)
        let averageDailyMinutes = totalWeekMinutes / 7

        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last 7 Days Activity")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("\(totalWeekMinutes / 60)h \(totalWeekMinutes % 60)m total • ~\(averageDailyMinutes)m / day")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Bars
            HStack(alignment: .bottom, spacing: 12) {
                ForEach(weeklyActivity) { day in
                    VStack(spacing: 6) {
                        // Minutes callout
                        if day.minutes > 0 {
                            Text("\(day.minutes)m")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundStyle(day.isToday ? Color.appPrimary : .secondary)
                        } else {
                            Text("-")
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }

                        // Bar
                        let barHeight = max(CGFloat(day.minutes) / CGFloat(maxMinutes) * 90, 6)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(
                                day.isToday ?
                                    LinearGradient(colors: [.appPrimary, .appAccent], startPoint: .top, endPoint: .bottom) :
                                    LinearGradient(colors: [Color.appPrimary.opacity(day.minutes > 0 ? 0.75 : 0.2), Color.appPrimary.opacity(day.minutes > 0 ? 0.45 : 0.1)], startPoint: .top, endPoint: .bottom)
                            )
                            .frame(height: barHeight)

                        // Weekday label
                        Text(day.weekday)
                            .font(.caption2.weight(day.isToday ? .bold : .regular))
                            .foregroundStyle(day.isToday ? Color.appPrimary : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 130)
            .padding(.top, 4)
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - In Progress Section

    private func inProgressSection(inProgress: [MediaProgressRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("In Progress")
                .font(.headline)
                .foregroundStyle(.primary)

            ForEach(inProgress.prefix(3)) { row in
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.15))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: "book.fill")
                                .font(.caption)
                                .foregroundStyle(Color.appPrimary)
                        }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.title ?? "Unknown Title")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        let dur = row.duration ?? 1
                        let prog = row.progress ?? 0
                        let pct = min(max(Int((prog / dur) * 100), 0), 100)

                        ProgressView(value: prog, total: dur)
                            .tint(Color.appPrimary)

                        HStack {
                            Text("\(pct)% completed")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let remaining = row.duration.map({ $0 - prog }), remaining > 0 {
                                Text("\(formatDuration(remaining)) left")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .padding(12)
                .background(DesignTokens.Color.surface.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Recent Sessions Section

    private func recentSessionsSection(sessions: [PlaybackSessionRow]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Sessions")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(sessions.count) recorded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(sessions.prefix(5)) { session in
                HStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.appPrimary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.displayTitle ?? "Audiobook Session")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if let author = session.displayAuthor, !author.isEmpty {
                            Text(author)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatDuration(session.timeListening ?? 0))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.primary)
                        Text(session.sessionDate ?? "Today")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, 6)

                if session.id != sessions.prefix(5).last?.id {
                    Divider().background(Color.white.opacity(0.08))
                }
            }
        }
        .padding(18)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Library Catalog Tab

    @ViewBuilder
    private var libraryOverviewContent: some View {
        if let stats = libraryStats {
            VStack(spacing: 20) {
                // Main Stat — Total Duration
                VStack(spacing: 8) {
                    Text("Total Library Runtime")
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    Text(formatDuration(stats.totalDuration))
                        .font(.system(size: 34, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity)
                .padding(22)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )

                // Stats Grid
                HStack(spacing: 14) {
                    statCard(
                        title: "Total Books",
                        value: "\(stats.totalBooks)",
                        icon: "book.closed.fill",
                        color: .appPrimary
                    )
                    statCard(
                        title: "Audio Tracks",
                        value: "\(stats.numAudioTracks)",
                        icon: "waveform",
                        color: DesignTokens.Color.accentSecondary
                    )
                }

                HStack(spacing: 14) {
                    statCard(
                        title: "Authors",
                        value: "\(stats.totalAuthors)",
                        icon: "person.2.fill",
                        color: DesignTokens.Color.accentHighlight
                    )
                    statCard(
                        title: "Series",
                        value: "\(stats.totalSeries)",
                        icon: "books.vertical.fill",
                        color: DesignTokens.Color.accent
                    )
                }

                HStack(spacing: 14) {
                    statCard(
                        title: "Added Last 30 Days",
                        value: "\(stats.addedLast30Days)",
                        icon: "plus.circle.fill",
                        color: DesignTokens.Color.success
                    )
                    statCard(
                        title: "Library Size",
                        value: formatBytes(stats.totalSize),
                        icon: "externaldrive.fill",
                        color: DesignTokens.Color.warning
                    )
                }

                // Top Genres
                if !stats.genresWithCount.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Top Genres")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        let sorted = stats.genresWithCount.sorted { $0.count > $1.count }.prefix(6)
                        let maxCount = max(sorted.first?.count ?? 1, 1)

                        ForEach(Array(sorted)) { genre in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(genre.genre)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text("\(genre.count) \(genre.count == 1 ? "book" : "books")")
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }

                                GeometryReader { geometry in
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: [.appPrimary, .appAccent],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(
                                            width: geometry.size.width * CGFloat(genre.count) / CGFloat(maxCount)
                                        )
                                }
                                .frame(height: 6)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(18)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }

                // Top Authors
                if !stats.authorsWithCount.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Top Authors")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        let sorted = stats.authorsWithCount.sorted { $0.count > $1.count }.prefix(6)
                        ForEach(Array(sorted)) { author in
                            HStack {
                                Text(author.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Text("\(author.count) books")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(18)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }

                // Longest Items
                if !stats.longestItems.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Longest Audiobooks")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        ForEach(stats.longestItems.prefix(5)) { item in
                            HStack {
                                Text(item.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Spacer()
                                Text(formatDuration(item.duration ?? 0))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(18)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                    )
                }
            }
        }
    }

    // MARK: - Helpers

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.15))
                .clipShape(Circle())

            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    // MARK: - Error View

    @ViewBuilder
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundStyle(DesignTokens.Color.error)

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button("Retry") {
                Task { await loadStats() }
            }
            .buttonStyle(.borderedProminent)
            .tint(.appPrimary)
        }
        .padding(32)
    }

    // MARK: - Loading Skeleton

    @ViewBuilder
    private var statsLoadingSkeleton: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.primary.opacity(0.05))
                .frame(height: 120)
                .overlay {
                    ProgressView()
                        .tint(.appPrimary)
                }

            HStack(spacing: 16) {
                skeletonCard
                skeletonCard
            }

            HStack(spacing: 16) {
                skeletonCard
                skeletonCard
            }
        }
    }

    private var skeletonCard: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(Color.primary.opacity(0.05))
            .frame(height: 100)
    }

    // MARK: - Data Calculations

    public struct DayActivity: Identifiable, Sendable {
        public let id: String
        public let weekday: String
        public let minutes: Int
        public let isToday: Bool
    }

    private func calculateStreak(sessions: [PlaybackSessionRow]) -> Int {
        return ListeningStreakCalculator.calculateStreak(sessions: sessions)
    }

    private func calculateTotalListeningSeconds(sessions: [PlaybackSessionRow], progress: [MediaProgressRow]) -> TimeInterval {
        let sessionSeconds = sessions.compactMap(\.timeListening).reduce(0, +)
        if sessionSeconds > 0 {
            return sessionSeconds
        }
        // Fallback estimate from progress
        return progress.reduce(0) { total, p in
            total + ((p.progress ?? 0) * (p.duration ?? 0))
        }
    }

    private func calculateWeeklyActivity(sessions: [PlaybackSessionRow]) -> [DayActivity] {
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "E"

        var minutesByDate: [String: Int] = [:]
        for session in sessions {
            guard let time = session.timeListening, time > 0 else { continue }
            let key: String
            if let dateStr = session.sessionDate, !dateStr.isEmpty {
                key = dateStr
            } else if let date = session.updatedAt {
                key = formatter.string(from: date)
            } else {
                continue
            }
            minutesByDate[key, default: 0] += Int(time / 60)
        }

        var result: [DayActivity] = []
        for offset in (0..<7).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            let key = formatter.string(from: date)
            let mins = minutesByDate[key] ?? 0
            let weekday = dayFormatter.string(from: date).prefix(1)
            result.append(DayActivity(
                id: key,
                weekday: String(weekday),
                minutes: mins,
                isToday: offset == 0
            ))
        }
        return result
    }

    // MARK: - Data Loading

    private func loadStats() async {
        isLoading = true
        errorMessage = nil

        let libraryId = appState.currentLibraryId ?? "mock-lib"

        if appState.isAuthenticated {
            do {
                self.libraryStats = try await AudiobookphileAPI.shared.getLibraryStats(libraryId: libraryId)
            } catch {
                print("[StatsView] Failed to fetch live library stats: \(error)")
                self.libraryStats = try? await MockLibraryService().fetchLibraryStats(libraryId: libraryId)
            }

            do {
                self.userStats = try await AudiobookphileAPI.shared.getUserStats()
            } catch {
                print("[StatsView] Failed to fetch live user stats: \(error)")
                self.userStats = fallbackUserStats
            }
        } else {
            self.libraryStats = try? await MockLibraryService().fetchLibraryStats(libraryId: libraryId)
            self.userStats = fallbackUserStats
        }

        isLoading = false
    }

    private var fallbackUserStats: UserStatsData {
        let calendar = Calendar.current
        let today = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let sessions = (0..<7).map { dayOffset -> PlaybackSessionRow in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
            let time = Double([4200, 3600, 5400, 1800, 4800, 7200, 3000][dayOffset])
            let titles = ["Project Hail Mary", "The Way of Kings", "Dune", "Project Hail Mary", "Atomic Habits", "The Way of Kings", "Dune"]
            let authors = ["Andy Weir", "Brandon Sanderson", "Frank Herbert", "Andy Weir", "James Clear", "Brandon Sanderson", "Frank Herbert"]
            return PlaybackSessionRow(
                id: "mock-sess-\(dayOffset)",
                displayTitle: titles[dayOffset],
                displayAuthor: authors[dayOffset],
                timeListening: time,
                sessionDate: formatter.string(from: date),
                updatedAt: date
            )
        }

        let progress = [
            MediaProgressRow(
                id: "prog-1",
                libraryItemId: "mock-book-1",
                duration: 57600,
                progress: 38400,
                isFinished: false,
                finishedAt: nil,
                lastUpdate: today,
                startedAt: calendar.date(byAdding: .day, value: -10, to: today),
                title: "Project Hail Mary"
            ),
            MediaProgressRow(
                id: "prog-2",
                libraryItemId: "mock-book-2",
                duration: 72000,
                progress: 72000,
                isFinished: true,
                finishedAt: calendar.date(byAdding: .day, value: -2, to: today),
                lastUpdate: today,
                startedAt: calendar.date(byAdding: .day, value: -20, to: today),
                title: "The Way of Kings"
            )
        ]

        return UserStatsData(mediaProgress: progress, recentSessions: sessions)
    }

    // MARK: - Formatters

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = Int(seconds) / 60 % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / (1024 * 1024 * 1024)
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        let mb = Double(bytes) / (1024 * 1024)
        return String(format: "%.0f MB", mb)
    }
}
