//
//  AppState.swift
//  Audiobookphile
//
//  Shared application state, compatible with Swift 6.3 and Skip.
//

import Foundation
import Observation
import SkipFuse
import SwiftUI

@Observable
@MainActor
public class AppState {
    public static let shared = AppState()

    public var isAuthenticated = false
    public var isLoading = true
    public var currentUser: User?
    public var requires2FAChallenge = false
    public var pending2FAUserId: String?
    public var pending2FATempToken: String?
    public var pending2FAServerURL: String?
    public var pending2FAMethods: TwoFactorMethodsMap?
    public var selectedLibraryId: String?
    public var navigation = NavigationState.shared

    // Real API loaded libraries
    public var libraries: [Library] = []
    public var currentLibraryId: String?

    // Global settings loaded from Supabase
    public var settings = AppSettings()

    public var serverURL: String = ""
    public var pendingUsername: String?
    public var pendingPassword: String?
    public var token: String = ""


    public var currentLibrary: Library? {
        libraries.first { $0.id == currentLibraryId } ?? libraries.first
    }

    public init() {
        Task {
            await checkAuthentication()
        }
    }

        public func checkAuthentication() async {
        await AuthManager.shared.checkAuthentication(appState: self)
    }

    /// Called when the app returns to foreground (ScenePhase.active / onResume).
    /// Silently refreshes the access token if it's likely expired without
    /// disrupting the UI or showing the login screen for transient errors.
        public func refreshSessionIfNeeded() async {
        await AuthManager.shared.refreshSessionIfNeeded(appState: self)
    }

    public func fetchLibraries() async {
        do {
            let fetched = try await AudiobookphileAPI.shared.getLibraries()
            self.libraries = fetched
            
            // Validate that currentLibraryId still exists in the fetched libraries
            if let libId = self.currentLibraryId, !fetched.contains(where: { $0.id == libId }) {
                self.currentLibraryId = nil
            }
            
            if self.currentLibraryId == nil {
                self.currentLibraryId = fetched.first?.id
            }
            // Persist selected library for next launch
            if let libId = self.currentLibraryId {
                UserDefaults.standard.set(libId, forKey: StorageKeys.lastLibraryId)
            }
            print("[AppState] Successfully fetched \(fetched.count) libraries.")
        } catch {
            print("[AppState] Failed to fetch libraries: \(error)")
            // If unauthorized/authenticated failed, log out
            if let apiError = error as? APIError {
                switch apiError {
                case .authenticationFailed, .sessionExpired:
                    logout()
                case .serverError(let statusCode, _, let code):
                    if statusCode == 401 || code == "UNAUTHORIZED" {
                        logout()
                    }
                default:
                    break
                }
            }
        }
    }

        public func login(serverURL: String, username: String, password: String) async throws {
        try await AuthManager.shared.login(serverURL: serverURL, username: username, password: password, appState: self)
    }

        public func verify2FAChallenge(code: String, method: String? = nil) async throws {
        try await AuthManager.shared.verify2FAChallenge(code: code, method: method, appState: self)
    }

        public func verify2FAPasskey() async throws {
        try await AuthManager.shared.verify2FAPasskey(appState: self)
    }

        public func cancel2FAChallenge() {
        self.requires2FAChallenge = false
        self.pending2FAUserId = nil
        self.pending2FATempToken = nil
        self.pending2FAServerURL = nil
        self.pending2FAMethods = nil
    }

        public func logout() {
        AuthManager.shared.logout(appState: self)
    }

    public func deleteAccount() async throws {
        guard let user = currentUser else { return }
        try await AudiobookphileAPI.shared.deleteAccount(userId: user.id)
        logout()
    }

    public func updateSettings(_ newSettings: AppSettings) {
        self.settings = newSettings
        Task {
            do {
                _ = try await AudiobookphileAPI.shared.updatePreferences(newSettings)
            } catch {
                print("[AppState] Failed to update preferences to server: \(error)")
            }
        }
    }

    public func getCoverURL(itemId: String, width: Int = 400, updatedAt: Date? = nil) -> URL? {
        guard !serverURL.isEmpty else { return nil }

        let endpoint = APIEndpoint.getCover(itemId: itemId).urlString(baseURL: serverURL)
        guard var components = URLComponents(string: endpoint) else { return nil }

        var queryItems = [
            URLQueryItem(name: "width", value: "\(width)"),
            URLQueryItem(name: "format", value: "jpeg"),
            URLQueryItem(name: "token", value: token)
        ]

        if let updated = updatedAt {
            queryItems.append(URLQueryItem(name: "ts", value: "\(Int(updated.timeIntervalSince1970))"))
        } else {
            queryItems.append(URLQueryItem(name: "ts", value: "1"))
        }

        let anonKey = EnvironmentConfig.supabaseAnonKey
        if !anonKey.isEmpty {
            queryItems.append(URLQueryItem(name: "apikey", value: anonKey))
        }

        components.queryItems = queryItems
        return components.url
    }

    public func getAuthorImageURL(authorId: String, updatedAt: Date? = nil) -> URL? {
        guard !serverURL.isEmpty else { return nil }

        let endpoint = APIEndpoint.getAuthor(authorId: authorId).urlString(baseURL: serverURL)
        // Add /image suffix since APIEndpoint.getAuthor returns the author details endpoint
        let imageEndpoint = "\(endpoint)/image"
        guard var components = URLComponents(string: imageEndpoint) else { return nil }

        var queryItems = [URLQueryItem]()

        if let updated = updatedAt {
            queryItems.append(URLQueryItem(name: "ts", value: "\(Int(updated.timeIntervalSince1970))"))
        } else {
            queryItems.append(URLQueryItem(name: "ts", value: "1"))
        }

        let anonKey = EnvironmentConfig.supabaseAnonKey
        if !anonKey.isEmpty {
            queryItems.append(URLQueryItem(name: "apikey", value: anonKey))
        }

        components.queryItems = queryItems
        return components.url
    }
}
