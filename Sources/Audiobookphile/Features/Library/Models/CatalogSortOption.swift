//
//  CatalogSortOption.swift
//  Audiobookphile
//
//  Cross-platform catalog sorting options for Author and Narrator views.
//  Compatible with Swift 6.3 and Skip.
//

import Foundation

public enum CatalogSortOption: String, CaseIterable, Identifiable, Sendable {
    case title = "Title"
    case duration = "Duration"
    case year = "Year"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .title: return "textformat.abc"
        case .duration: return "clock"
        case .year: return "calendar"
        }
    }
}

