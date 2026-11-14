//
//  Models.swift
//  Audiobookphile
//
//  Core data models for Audiobookphile, fully Swift 6.3 and Skip compatible.
//

import Foundation
#if canImport(SwiftUI)
import SwiftUI
#endif

#if canImport(CoreGraphics)
import CoreGraphics
#else
import Foundation
#endif

// MARK: - Podcast (for future support)
public struct Podcast: Identifiable, Codable, Sendable {
    public let id: String
    public let libraryId: String
    public let media: PodcastMedia
    public let addedAt: Date
    public let updatedAt: Date
}

public struct PodcastMedia: Codable, Sendable {
    public let metadata: PodcastMetadata
    public let coverPath: String?
    public let tags: [String]
    public let episodes: [PodcastEpisode]
    public let autoDownloadEpisodes: Bool
    public let autoDownloadSchedule: String?
}

public struct PodcastMetadata: Codable, Sendable {
    public let title: String
    public let author: String?
    public let description: String?
    public let releaseDate: String?
    public let genres: [String]
    public let feedUrl: String?
    public let imageUrl: String?
    public let itunesPageUrl: String?
    public let itunesId: String?
    public let itunesArtistId: String?
    public let explicit: Bool
    public let language: String?
}

public struct PodcastEpisode: Identifiable, Codable, Sendable {
    public let id: String
    public let index: Int
    public let title: String
    public let subtitle: String?
    public let description: String?
    public let pubDate: String?
    public let audioFile: AudioFile?
    public let publishedAt: Date?
    public let addedAt: Date
    public let updatedAt: Date
}

// MARK: - Server Connection
public struct ServerConnection: Codable, Sendable {
    public let url: String
    public let name: String?
    public let lastConnected: Date

    public var displayName: String {
        name ?? url
    }
}

// MARK: - App Settings
public struct AppSettings: Codable, Sendable {
    public var jumpForwardTime: Int = 30
    public var jumpBackwardsTime: Int = 10
    public var lockScreenControls: Bool = true
    public var autoDownloadPodcasts: Bool = false
    public var sleepTimerAutoStart: Bool = false
    public var sleepTimerDefaultTime: Int = 900 // 15 minutes
    public var theme: AppTheme = .system
    public var bookCoverAspectRatio: BookCoverAspectRatio = .square

    // Privacy
    public var crashReportingEnabled: Bool = true

    // UI Settings
    public var autoResume: Bool = true
    public var hapticsEnabled: Bool = true
    public var lockOrientation: Bool = false
    public var defaultPlaybackSpeed: Double = 1.0

    // Upstream Parity: Smart Rewind & Motion Sleep Controls
    public var smartRewindEnabled: Bool = true
    public var smartRewindSeconds: Int = 20
    public var shakeToResetSleepTimer: Bool = true

    // Audio & Hardware Accessibility Settings
    public var spokenAudioModeEnabled: Bool = true
    public var vocalBoostEnabled: Bool = false
    public var volumeLevelerEnabled: Bool = false
    public var monoAudioEnabled: Bool = false
    public var highResAudioEnabled: Bool = true
    public var deEsserEnabled: Bool = false
    public var lowCutFilterEnabled: Bool = true
    public var binauralReverbEnabled: Bool = false
    public var binauralReverbPresetRaw: Int = 0

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        jumpForwardTime = try container.decodeIfPresent(Int.self, forKey: .jumpForwardTime) ?? 30
        jumpBackwardsTime = try container.decodeIfPresent(Int.self, forKey: .jumpBackwardsTime) ?? 10
        lockScreenControls = try container.decodeIfPresent(Bool.self, forKey: .lockScreenControls) ?? true
        autoDownloadPodcasts = try container.decodeIfPresent(Bool.self, forKey: .autoDownloadPodcasts) ?? false
        sleepTimerAutoStart = try container.decodeIfPresent(Bool.self, forKey: .sleepTimerAutoStart) ?? false
        sleepTimerDefaultTime = try container.decodeIfPresent(Int.self, forKey: .sleepTimerDefaultTime) ?? 900
        theme = try container.decodeIfPresent(AppTheme.self, forKey: .theme) ?? .system
        bookCoverAspectRatio = try container.decodeIfPresent(BookCoverAspectRatio.self, forKey: .bookCoverAspectRatio) ?? .square
        crashReportingEnabled = try container.decodeIfPresent(Bool.self, forKey: .crashReportingEnabled) ?? true
        autoResume = try container.decodeIfPresent(Bool.self, forKey: .autoResume) ?? true
        hapticsEnabled = try container.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? true
        lockOrientation = try container.decodeIfPresent(Bool.self, forKey: .lockOrientation) ?? false
        defaultPlaybackSpeed = try container.decodeIfPresent(Double.self, forKey: .defaultPlaybackSpeed) ?? 1.0
        spokenAudioModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .spokenAudioModeEnabled) ?? true
        vocalBoostEnabled = try container.decodeIfPresent(Bool.self, forKey: .vocalBoostEnabled) ?? false
        volumeLevelerEnabled = try container.decodeIfPresent(Bool.self, forKey: .volumeLevelerEnabled) ?? false
        monoAudioEnabled = try container.decodeIfPresent(Bool.self, forKey: .monoAudioEnabled) ?? false
        highResAudioEnabled = try container.decodeIfPresent(Bool.self, forKey: .highResAudioEnabled) ?? true
        deEsserEnabled = try container.decodeIfPresent(Bool.self, forKey: .deEsserEnabled) ?? false
        lowCutFilterEnabled = try container.decodeIfPresent(Bool.self, forKey: .lowCutFilterEnabled) ?? true
        binauralReverbEnabled = try container.decodeIfPresent(Bool.self, forKey: .binauralReverbEnabled) ?? false
        binauralReverbPresetRaw = try container.decodeIfPresent(Int.self, forKey: .binauralReverbPresetRaw) ?? 0
        smartRewindEnabled = try container.decodeIfPresent(Bool.self, forKey: .smartRewindEnabled) ?? true
        smartRewindSeconds = try container.decodeIfPresent(Int.self, forKey: .smartRewindSeconds) ?? 20
        shakeToResetSleepTimer = try container.decodeIfPresent(Bool.self, forKey: .shakeToResetSleepTimer) ?? true
    }

    public enum CodingKeys: String, CodingKey {
        case jumpForwardTime
        case jumpBackwardsTime
        case defaultPlaybackSpeed
        case lockScreenControls
        case autoDownloadPodcasts
        case sleepTimerAutoStart
        case sleepTimerDefaultTime
        case theme
        case bookCoverAspectRatio
        case crashReportingEnabled
        case autoResume
        case hapticsEnabled
        case lockOrientation
        case spokenAudioModeEnabled
        case vocalBoostEnabled
        case volumeLevelerEnabled
        case monoAudioEnabled
        case highResAudioEnabled
        case deEsserEnabled
        case lowCutFilterEnabled
        case binauralReverbEnabled
        case binauralReverbPresetRaw
        case smartRewindEnabled
        case smartRewindSeconds
        case shakeToResetSleepTimer
    }
}

public enum AppTheme: String, Codable, Sendable {
    case light
    case dark
    case system

    #if canImport(SwiftUI)
    /// Maps the user preference to a SwiftUI color scheme. `nil` = follow the system.
    public var colorScheme: SwiftUI.ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
    #endif
}

public enum BookCoverAspectRatio: Int, Codable, Sendable {
    case standard = 0 // 1:1.6
    case square = 1 // 1:1

    #if canImport(CoreGraphics)
    public var ratio: CGFloat {
        self == .square ? 1.0 : (1.0 / 1.6)
    }
    #else
    public var ratio: Double {
        self == .square ? 1.0 : (1.0 / 1.6)
    }
    #endif
}

// MARK: - API Error
public struct APIErrorResponse: Codable, Sendable {
    public struct ErrorDetail: Codable, Sendable {
        public let message: String
        public let code: String?

        public init(message: String, code: String? = nil) {
            self.message = message
            self.code = code
        }
    }
    public let error: ErrorDetail?
    public let message: String?
    public let success: Bool?

    public var parsedMessage: String? {
        if let detailMsg = error?.message, !detailMsg.isEmpty {
            return detailMsg
        }
        if let directMsg = message, !directMsg.isEmpty {
            return directMsg
        }
        return nil
    }

    enum CodingKeys: String, CodingKey {
        case error
        case message
        case success
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.success = try container.decodeIfPresent(Bool.self, forKey: .success)

        if let detail = try? container.decodeIfPresent(ErrorDetail.self, forKey: .error) {
            self.error = detail
            self.message = nil
        } else if let errorString = try? container.decodeIfPresent(String.self, forKey: .error) {
            self.error = ErrorDetail(message: errorString)
            self.message = nil
        } else {
            self.error = nil
            self.message = try container.decodeIfPresent(String.self, forKey: .message)
        }
    }
}

public struct ProgressSyncQueueItem: Codable, Sendable {
    public let sessionId: String
    public let episodeId: String?
    public let currentTime: TimeInterval
    public let duration: TimeInterval
    public let timeListened: TimeInterval
    public let dateAdded: Date

    public init(sessionId: String, episodeId: String? = nil, currentTime: TimeInterval, duration: TimeInterval, timeListened: TimeInterval, dateAdded: Date = Date()) {
        self.sessionId = sessionId
        self.episodeId = episodeId
        self.currentTime = currentTime
        self.duration = duration
        self.timeListened = timeListened
        self.dateAdded = dateAdded
    }
}

// MARK: - Library Stats (from /api/libraries/:id/stats)

public struct GenreCount: Codable, Sendable, Identifiable {
    public let genre: String
    public let count: Int

    public var id: String { genre }
}

public struct AuthorCount: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let count: Int
}

public struct ItemStat: Codable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let duration: TimeInterval?
    public let size: Int64?
}

public struct LibraryStats: Codable, Sendable {
    public let totalItems: Int
    public let totalBooks: Int
    public let totalAuthors: Int
    public let totalSeries: Int
    public let totalDuration: TimeInterval
    public let totalSize: Int64
    public let addedLast30Days: Int
    public let numAudioTracks: Int
    public let genresWithCount: [GenreCount]
    public let authorsWithCount: [AuthorCount]
    public let longestItems: [ItemStat]
    public let largestItems: [ItemStat]
}

// MARK: - Author Summary (from /api/libraries/:id/authors)

public struct AuthorSummary: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let asin: String?
    public let description: String?
    public let imagePath: String?
    public let libraryId: String?
    public let addedAt: Double?
    public let updatedAt: Double?
    public let numBooks: Int
}

// MARK: - Series Summary (from /api/libraries/:id/series)

public struct SeriesBookSummary: Identifiable, Codable, Sendable {
    public let id: String
    public let sequence: String?
    public let title: String
    public let cover: String?
}

public struct SeriesSummary: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let nameIgnorePrefix: String?
    public let description: String?
    public let libraryId: String?
    public let addedAt: Double?
    public let updatedAt: Double?
    public let books: [SeriesBookSummary]?
    public let numBooks: Int?
}

// MARK: - Collection Summary (from /api/libraries/:id/collections)

public struct CollectionBookSummary: Identifiable, Codable, Sendable {
    public let id: String
    public let order: Int?
    public let title: String
    public let cover: String?
}

public struct CollectionSummary: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let libraryId: String?
    public let addedAt: Double?
    public let updatedAt: Double?
    public let books: [CollectionBookSummary]?
    public let numBooks: Int?
}

// MARK: - Playlist Summary (from /api/libraries/:id/playlists)

public struct PlaylistItemSummary: Identifiable, Codable, Sendable {
    public let id: String
    public let order: Int?
    public let title: String
    public let cover: String?
}

public struct PlaylistSummary: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let description: String?
    public let libraryId: String?
    public let userId: String?
    public let addedAt: Double?
    public let updatedAt: Double?
    public let items: [PlaylistItemSummary]?
}

// MARK: - Paginated Response

public struct PaginatedResponse<T: Codable & Sendable>: Codable, Sendable {
    public let results: [T]
    public let total: Int
    public let limit: Int
    public let page: Int
}

// MARK: - Downloads

public struct DownloadManifest: Codable, Sendable {
    public let libraryItemId: String
    public let title: String
    public let author: String
    public let duration: Double
    public let totalSize: Int64
    public let tracks: [DownloadManifestTrack]
}

public struct DownloadManifestTrack: Codable, Sendable {
    public let index: Int
    public let title: String
    public let url: String
    public let size: Int64
    public let duration: Double
    public let mimeType: String
}

public struct BookmarksResponse: Codable, Sendable {
    public let bookmarks: [Bookmark]
}


public struct SearchHistoryItem: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public let query: String
    public let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case query
        case createdAt = "created_at"
    }
}
