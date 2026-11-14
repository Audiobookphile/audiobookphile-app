import Foundation
import Observation

/// Handles authentication, token refresh, and login workflows.
@MainActor
public class AuthManager {
    public static let shared = AuthManager()
    
    private let proactiveRefreshThreshold: TimeInterval = 50 * 60
    private var tokenIssuedAt: Date?
    
    public init() {}
    
    private func isJWTExpired(_ jwt: String) -> Bool {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return true }
        var base64 = String(parts[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 {
            base64.append("=")
        }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let exp = json["exp"] as? TimeInterval else {
            return true
        }
        // Consider expired if less than 60 seconds of validity remaining
        return Date().timeIntervalSince1970 >= (exp - 60)
    }

    public func checkAuthentication(appState: AppState) async {
        appState.isLoading = true

        // Wire token refresh callback so any refreshed token immediately updates appState and socket
        await AudiobookphileAPI.shared.setOnTokenRefreshed { [weak appState] newToken, _ in
            Task { @MainActor in
                guard let appState else { return }
                appState.token = newToken
                if !appState.serverURL.isEmpty && !newToken.isEmpty {
                    SocketService.shared.connect(
                        serverAddress: appState.serverURL,
                        token: newToken
                    )
                }
            }
        }
        
        if let credentials = try? KeychainManager.shared.loadCredentials() {
            // Canonical domain is audiobookphile.app; supabase.co (direct) and
            // vercel.app (legacy) remain valid. Anything else is a stale
            // non-Supabase server entry — clear it rather than crash on it.
            if !credentials.serverURL.contains("supabase.co") && !credentials.serverURL.contains("vercel.app") && !credentials.serverURL.contains("audiobookphile.app") {
                print("[AuthManager] Found old non-Supabase server credentials. Migrating/Clearing...")
                logout(appState: appState)
                appState.isLoading = false
                return
            }

            appState.serverURL = credentials.serverURL
            appState.token = credentials.token
            appState.isAuthenticated = true

            await AudiobookphileAPI.shared.configure(
                serverURL: credentials.serverURL,
                token: credentials.token,
                refreshToken: credentials.refreshToken
            )

            // Proactive startup check: If token has expired, refresh before firing hydration requests
            if isJWTExpired(credentials.token) && !credentials.refreshToken.isEmpty {
                print("[AuthManager] Stored token is expired, performing proactive startup refresh...")
                do {
                    try await AudiobookphileAPI.shared.refreshTokensFromForeground()
                    appState.token = await AudiobookphileAPI.shared.accessToken
                    tokenIssuedAt = Date()
                    print("[AuthManager] Startup token refresh succeeded.")
                } catch {
                    print("[AuthManager] Startup token refresh failed: \(error)")
                }
            } else {
                tokenIssuedAt = Date()
            }

            SocketService.shared.connect(
                serverAddress: credentials.serverURL,
                token: appState.token
            )

            // Auth state is established — drop the loading flag before the
            // data hydration below. The three fetches run concurrently
            // (previously sequential), and the UI shouldn't sit on a spinner
            // while they finish.
            appState.isLoading = false

            async let profile: () = hydrateCurrentUser(appState: appState)
            async let preferences: () = hydratePreferences(appState: appState)
            async let libraries: () = appState.fetchLibraries()
            _ = await (profile, preferences, libraries)
        } else {
            appState.isAuthenticated = false
            appState.isLoading = false
        }
    }

    public func refreshSessionIfNeeded(appState: AppState) async {
        guard appState.isAuthenticated else { return }

        let needsRefresh: Bool
        if let issued = tokenIssuedAt {
            needsRefresh = Date().timeIntervalSince(issued) > proactiveRefreshThreshold
        } else {
            needsRefresh = true
        }

        guard needsRefresh else {
            print("[AuthManager] Token still fresh, skipping foreground refresh.")
            return
        }

        print("[AuthManager] Token likely expired, attempting silent foreground refresh...")

        do {
            try await AudiobookphileAPI.shared.refreshTokensFromForeground()
            tokenIssuedAt = Date()
            print("[AuthManager] Silent foreground token refresh succeeded.")
        } catch let error as APIError {
            switch error {
            case .authenticationFailed, .sessionExpired, .noRefreshToken:
                print("[AuthManager] Refresh token rejected, logging out: \(error)")
                logout(appState: appState)
            default:
                print("[AuthManager] Foreground refresh failed (transient): \(error)")
            }
        } catch {
            print("[AuthManager] Foreground refresh failed (transient): \(error)")
        }
    }

    /// Completes a magic-link sign-in: the web callback bounced the GoTrue
    /// session to us via the `audiobookphile://` URL scheme.
    public func completeMagicLinkSession(
        accessToken: String,
        refreshToken: String?,
        userId: String,
        serverURL: String?,
        appState: AppState
    ) async throws {
        appState.isLoading = true

        do {
            var resolvedServer = serverURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if resolvedServer.isEmpty,
               let stored = try? KeychainManager.shared.loadCredentials(),
               !stored.serverURL.isEmpty {
                resolvedServer = stored.serverURL
            }
            if resolvedServer.isEmpty {
                resolvedServer = EnvironmentConfig.serverURL
            }
            guard !resolvedServer.isEmpty, !accessToken.isEmpty else {
                throw APIError.invalidResponse
            }

            let refresh = refreshToken ?? ""
            await AudiobookphileAPI.shared.configure(
                serverURL: resolvedServer,
                token: accessToken,
                refreshToken: refresh
            )
            try KeychainManager.shared.saveCredentials(
                serverURL: resolvedServer,
                token: accessToken,
                refreshToken: refresh
            )

            appState.serverURL = resolvedServer
            appState.token = accessToken
            appState.isAuthenticated = true

            SocketService.shared.connect(
                serverAddress: resolvedServer,
                token: accessToken
            )

            // Sign-in is complete: the session is trusted and persisted. Drop
            // the loading flag now — profile/preferences/libraries hydrate in
            // the background and must not keep the connect sheet on
            // "Signing in..." (they were three sequential awaited calls that
            // gated the whole sign-in on the slowest one).
            appState.isLoading = false

            async let profile: () = hydrateCurrentUser(appState: appState)
            async let preferences: () = hydratePreferences(appState: appState)
            async let libraries: () = appState.fetchLibraries()
            _ = await (profile, preferences, libraries)
        } catch {
            appState.isLoading = false
            throw error
        }
    }

    public func login(serverURL: String, username: String, password: String, appState: AppState) async throws {
        appState.isLoading = true

        do {
            let loginResponse = try await AudiobookphileAPI.shared.login(
                serverURL: serverURL,
                username: username,
                password: password
            )

            if loginResponse.requires2FA == true, let userId = loginResponse.userId, let tempToken = loginResponse.tempToken {
                appState.pending2FAUserId = userId
                appState.pending2FATempToken = tempToken
                appState.pending2FAServerURL = serverURL
                appState.pending2FAMethods = loginResponse.methods
                appState.requires2FAChallenge = true
                appState.isLoading = false
                return
            }

            guard let user = loginResponse.user else {
                throw APIError.invalidResponse
            }

            appState.serverURL = serverURL
            appState.token = user.token
            appState.currentUser = user
            appState.isAuthenticated = true

            SocketService.shared.connect(
                serverAddress: serverURL,
                token: user.token
            )

            async let preferences: () = hydratePreferences(appState: appState)
            async let libraries: () = appState.fetchLibraries()
            _ = await (preferences, libraries)
        } catch {
            appState.isAuthenticated = false
            appState.isLoading = false
            throw error
        }

        appState.isLoading = false
    }

    public func verify2FAChallenge(code: String, method: String? = nil, appState: AppState) async throws {
        guard let userId = appState.pending2FAUserId, let tempToken = appState.pending2FATempToken, let serverURL = appState.pending2FAServerURL else {
            return
        }
        appState.isLoading = true
        do {
            let loginResponse = try await AudiobookphileAPI.shared.verify2FALogin(
                userId: userId,
                tempToken: tempToken,
                code: code,
                method: method
            )
            guard let user = loginResponse.user else {
                throw APIError.invalidResponse
            }
            appState.serverURL = serverURL
            appState.token = user.token
            appState.currentUser = user
            appState.isAuthenticated = true
            appState.requires2FAChallenge = false
            appState.pending2FAUserId = nil
            appState.pending2FATempToken = nil
            appState.pending2FAServerURL = nil
            appState.pending2FAMethods = nil

            SocketService.shared.connect(
                serverAddress: serverURL,
                token: user.token
            )

            async let preferences: () = hydratePreferences(appState: appState)
            async let libraries: () = appState.fetchLibraries()
            _ = await (preferences, libraries)
        } catch {
            appState.isLoading = false
            throw error
        }
        appState.isLoading = false
    }

    /// Completes a 2FA challenge using a native passkey (WebAuthn assertion).
    public func verify2FAPasskey(appState: AppState) async throws {
        guard let userId = appState.pending2FAUserId, let tempToken = appState.pending2FATempToken, let serverURL = appState.pending2FAServerURL else {
            return
        }
        #if os(iOS) && !SKIP
        appState.isLoading = true
        do {
            let options = try await AudiobookphileAPI.shared.webauthnLoginOptions(
                userId: userId,
                tempToken: tempToken
            )

            guard let challengeData = WebAuthnCodec.base64urlDecode(options.challenge) else {
                throw WebAuthnError.invalidChallenge
            }

            let assertion = try await WebAuthnManager.requestAssertion(
                challenge: challengeData,
                rpId: options.rpId,
                allowCredentials: options.allowCredentials ?? [],
                userVerification: options.userVerification ?? "preferred"
            )

            let loginResponse = try await AudiobookphileAPI.shared.webauthnLoginVerify(
                userId: userId,
                tempToken: tempToken,
                assertion: assertion
            )
            guard let user = loginResponse.user else {
                throw APIError.invalidResponse
            }
            appState.serverURL = serverURL
            appState.token = user.token
            appState.currentUser = user
            appState.isAuthenticated = true
            appState.requires2FAChallenge = false
            appState.pending2FAUserId = nil
            appState.pending2FATempToken = nil
            appState.pending2FAServerURL = nil
            appState.pending2FAMethods = nil

            SocketService.shared.connect(
                serverAddress: serverURL,
                token: user.token
            )

            async let preferences: () = hydratePreferences(appState: appState)
            async let libraries: () = appState.fetchLibraries()
            _ = await (preferences, libraries)
        } catch {
            appState.isLoading = false
            throw error
        }
        appState.isLoading = false
        #else
        throw WebAuthnError.unsupportedPlatform
        #endif
    }

    public func logout(appState: AppState) {
        Task {
            await AudiobookphileAPI.shared.logout()
        }
        SocketService.shared.disconnect()
        appState.isAuthenticated = false
        appState.currentUser = nil
        appState.libraries = []
        appState.currentLibraryId = nil
        appState.serverURL = ""
        appState.token = ""
        appState.settings = AppSettings()
        appState.requires2FAChallenge = false
        appState.pending2FAUserId = nil
        appState.pending2FATempToken = nil
        appState.pending2FAServerURL = nil
        appState.pending2FAMethods = nil
        appState.navigation.showingAccount = false
        appState.navigation.showingSettings = false
        appState.navigation.showingStats = false
        UserDefaults.standard.removeObject(forKey: StorageKeys.lastLibraryId)
    }

    // MARK: - Hydration helpers (non-throwing so they can run as `async let`)

    private func hydrateCurrentUser(appState: AppState) async {
        do {
            appState.currentUser = try await AudiobookphileAPI.shared.getCurrentUserProfile()
        } catch {
            print("[AuthManager] Failed to fetch current user profile: \(error)")
            appState.currentUser = User(
                id: "local_user",
                username: "audiobookphile",
                email: nil,
                type: "admin",
                token: appState.token,
                refreshToken: nil,
                mediaProgress: [],
                seriesHideFromContinueListening: [],
                bookmarks: [],
                isActive: true,
                isLocked: false,
                lastSeen: nil,
                createdAt: Date(),
                permissions: UserPermissions(download: true, update: true, delete: true, upload: true, accessAllLibraries: true, accessAllTags: true, accessExplicitContent: true, createEreader: true, selectedTagsNotAccessible: nil),
                librariesAccessible: [],
                itemTagsAccessible: [],
                hasOpenIDLink: nil,
                isOldToken: nil
            )
        }
    }

    private func hydratePreferences(appState: AppState) async {
        do {
            appState.settings = try await AudiobookphileAPI.shared.getPreferences()
        } catch {
            print("[AuthManager] Failed to fetch preferences: \(error)")
        }
    }
}
