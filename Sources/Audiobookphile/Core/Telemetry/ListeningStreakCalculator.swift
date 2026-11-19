//
//  ListeningStreakCalculator.swift
//  Audiobookphile
//
//  Computes consecutive daily listening streaks and milestone celebrations.
//  Compatible with Swift 6.3 and Skip.
//

import Foundation

public struct ListeningStreakCalculator: Sendable {

    /// Calculates consecutive days of listening up to and including today or yesterday.
    public static func calculateStreak(sessions: [PlaybackSessionRow], referenceDate: Date = Date()) -> Int {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current

        let activeDates = Set(sessions.compactMap { session -> String? in
            guard let time = session.timeListening, time > 0 else { return nil }
            if let dateStr = session.sessionDate, !dateStr.isEmpty {
                return dateStr
            }
            if let date = session.updatedAt {
                return formatter.string(from: date)
            }
            return nil
        })

        guard !activeDates.isEmpty else { return 0 }

        var streak = 0

        for dayOffset in 0..<365 {
            guard let targetDate = calendar.date(byAdding: .day, value: -dayOffset, to: referenceDate) else { break }
            let key = formatter.string(from: targetDate)
            if activeDates.contains(key) {
                streak += 1
            } else if dayOffset == 0 {
                // If no listening recorded today yet, don't break streak if listened yesterday
                continue
            } else {
                break
            }
        }
        return streak
    }

    /// Milestone headline for the streak
    public static func milestoneHeadline(streak: Int) -> String {
        switch streak {
        case 0:
            return "Start Your Streak Today"
        case 1:
            return "1 Day Streak"
        case 2...6:
            return "\(streak) Days Streak"
        case 7...13:
            return "1 Week of Listening!"
        case 14...29:
            return "\(streak) Days • Habit Formed!"
        case 30...99:
            return "1 Month Milestone! 🔥"
        default:
            return "\(streak) Days • Legendary Listener!"
        }
    }

    /// Inspirational motivational subtitle
    public static func motivationalMessage(streak: Int) -> String {
        switch streak {
        case 0:
            return "Press play to build your daily reading habit."
        case 1:
            return "Great start! Listen tomorrow to keep the flame alive."
        case 2...6:
            return "You're building unstoppable reading momentum!"
        case 7...13:
            return "A full week of stories! Your imagination is thriving."
        case 14...29:
            return "Two weeks strong. Listening has become your superpower."
        case 30...99:
            return "Over 30 days of immersive reading! Incredible dedication."
        default:
            return "You are among the top 1% of dedicated audiobook lovers."
        }
    }
}
