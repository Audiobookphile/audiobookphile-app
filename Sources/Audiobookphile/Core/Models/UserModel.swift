//
//  UserModel.swift
//  Audiobookphile
//
//  Core models for User-related data.
//

import Foundation

// MARK: - User
public struct User: Identifiable, Codable, Sendable {
    public let id: String
    public let username: String
    public let email: String?
    public let type: String
    public let token: String
    public let refreshToken: String?
    public let mediaProgress: [MediaProgress]
    public let seriesHideFromContinueListening: [String]
    public let bookmarks: [Bookmark]
    public let isActive: Bool
    public let isLocked: Bool
    public let lastSeen: Date?
    public let createdAt: Date
    public let permissions: UserPermissions
    public let librariesAccessible: [String]
    public let itemTagsAccessible: [String]
    public let hasOpenIDLink: Bool?
    public let isOldToken: Bool?
}

public struct UserPermissions: Codable, Sendable {
    public let download: Bool
    public let update: Bool
    public let delete: Bool
    public let upload: Bool
    public let accessAllLibraries: Bool
    public let accessAllTags: Bool
    public let accessExplicitContent: Bool
    public let createEreader: Bool?
    public let selectedTagsNotAccessible: Bool?
}

// MARK: - Bookmark
public struct Bookmark: Identifiable, Codable, Hashable, Sendable {
    public let id: String
    public let userId: String
    public let libraryItemId: String
    public let timePos: Double
    public let title: String?
    public let note: String?
    public let createdAt: Date?

    public init(id: String, userId: String, libraryItemId: String, timePos: Double, title: String?, note: String? = nil, createdAt: Date? = nil) {
        self.id = id
        self.userId = userId
        self.libraryItemId = libraryItemId
        self.timePos = timePos
        self.title = title
        self.note = note
        self.createdAt = createdAt
    }

    public enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case libraryItemId = "library_item_id"
        case timePos = "time_pos"
        case title
        case note
        case createdAt = "created_at"
    }
}

// MARK: - API Key
public struct ApiKey: Codable, Hashable, Sendable {
    public let id: String
    public let key: String
    public let createdAt: Date?
}
