//
//  ConnectDeepLink.swift
//  Audiobookphile
//
//  Parses and validates 1-click server connection deep links.
//

import Foundation

public struct ConnectDeepLink: Equatable, Sendable {
    public let server: String
    public let username: String?
    public let password: String?
    public let autoLogin: Bool

    public init(
        server: String,
        username: String? = nil,
        password: String? = nil,
        autoLogin: Bool = false
    ) {
        self.server = server
        self.username = username
        self.password = password
        self.autoLogin = autoLogin
    }

    public static func parse(_ url: URL) -> ConnectDeepLink? {
        guard url.scheme == "audiobookphile" else { return nil }
        guard url.host == "connect" || url.path.hasPrefix("/connect") else { return nil }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let params = components.queryItems?.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        } ?? [:]
        guard let server = params["server"], !server.isEmpty else { return nil }
        let username = params["username"]
        let password = params["password"]
        let autoLogin = params["autoLogin"] == "1" || params["autoLogin"] == "true"
        return ConnectDeepLink(
            server: server,
            username: username,
            password: password,
            autoLogin: autoLogin
        )
    }
}

// MARK: - Audiobook Deep Link

/// Parses and validates deep links to audiobooks, including timestamp offset offsets (?t=seconds).
public struct AudiobookDeepLink: Equatable, Sendable {
    public let itemId: String
    public let timestamp: Double?
    public let autoPlay: Bool

    public init(
        itemId: String,
        timestamp: Double? = nil,
        autoPlay: Bool = false
    ) {
        self.itemId = itemId
        self.timestamp = timestamp
        self.autoPlay = autoPlay
    }

    public static func parse(_ url: URL) -> AudiobookDeepLink? {
        // Support custom scheme: audiobookphile://item/:id?t=123 or audiobookphile://play/:id?t=123
        if url.scheme == "audiobookphile" {
            let host = url.host ?? ""
            let pathComponents = url.pathComponents.filter { $0 != "/" }
            var itemId: String?

            if host == "item" || host == "play" {
                itemId = pathComponents.first
            } else if !host.isEmpty && host != "connect" {
                itemId = host
            }

            guard let finalId = itemId, !finalId.isEmpty else { return nil }

            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let params = components?.queryItems?.reduce(into: [String: String]()) { result, item in
                result[item.name] = item.value
            } ?? [:]

            let timestamp = params["t"].flatMap { Double($0) }
            let autoPlay = host == "play" || params["play"] == "1" || params["play"] == "true"

            return AudiobookDeepLink(
                itemId: finalId,
                timestamp: timestamp,
                autoPlay: autoPlay
            )
        }

        // Support standard web URLs: https://.../share/:slug?t=123 or https://.../library/:lib/item/:id?t=123
        if url.scheme == "http" || url.scheme == "https" {
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
            let pathSegments = components.path.split(separator: "/").map(String.init)

            var extractedId: String?
            if let itemIndex = pathSegments.firstIndex(of: "item"), itemIndex + 1 < pathSegments.count {
                extractedId = pathSegments[itemIndex + 1]
            } else if let shareIndex = pathSegments.firstIndex(of: "share"), shareIndex + 1 < pathSegments.count {
                extractedId = pathSegments[shareIndex + 1]
            }

            guard let finalId = extractedId, !finalId.isEmpty else { return nil }

            let params = components.queryItems?.reduce(into: [String: String]()) { result, item in
                result[item.name] = item.value
            } ?? [:]

            let timestamp = params["t"].flatMap { Double($0) }
            let autoPlay = params["play"] == "1" || params["play"] == "true"

            return AudiobookDeepLink(
                itemId: finalId,
                timestamp: timestamp,
                autoPlay: autoPlay
            )
        }

        return nil
    }
}
