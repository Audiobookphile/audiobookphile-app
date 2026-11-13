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

