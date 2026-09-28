//
//  AudiobookphileAPI.swift
//  Audiobookphile
//
//  Complete cross-platform API client with token refresh, error handling, and secure storage.
//  Compatible with Swift 6.3 and Skip.
//

import Foundation
#if canImport(OSLog)
import OSLog
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(Security)
import Security
#endif
import Observation

// MARK: - API Client

public actor AudiobookphileAPI {
    public static let shared = AudiobookphileAPI()

    public var isAuthenticated = false
    public var currentUser: User?

    public var baseURL: String = ""
    public var accessToken: String = ""
    public var refreshToken: String = ""
    public var serverConnectionId: String = ""
    public var onTokenRefreshed: (@Sendable (String, String) -> Void)?

    public func setOnTokenRefreshed(_ callback: (@Sendable (String, String) -> Void)?) {
        self.onTokenRefreshed = callback
    }


    private let session: URLSession
    private var refreshTask: Task<Void, Error>?

    private let defaultDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if container.decodeNil() {
                return Date(timeIntervalSince1970: 0)
            }
            if let timestamp = try? container.decode(Double.self) {
                if timestamp > 100_000_000_000 {
                    return Date(timeIntervalSince1970: timestamp / 1000.0)
                } else {
                    return Date(timeIntervalSince1970: timestamp)
                }
            }
            if let dateString = try? container.decode(String.self) {
                if let doubleVal = Double(dateString) {
                    if doubleVal > 100_000_000_000 {
                        return Date(timeIntervalSince1970: doubleVal / 1000.0)
                    } else {
                        return Date(timeIntervalSince1970: doubleVal)
                    }
                }
                let formatter = ISO8601DateFormatter()
                formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                if let date = formatter.date(from: dateString) {
                    return date
                }
                formatter.formatOptions = [.withInternetDateTime]
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            return Date(timeIntervalSince1970: 0)
        }
        return decoder
    }()

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.waitsForConnectivity = true
        config.httpShouldUsePipelining = true
        config.urlCache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 500 * 1024 * 1024,
            diskPath: "audiobookphile_api_cache"
        )
        config.requestCachePolicy = .useProtocolCachePolicy
        self.session = URLSession(configuration: config)
    }

    // MARK: - Configuration

    public func configure(serverURL: String, token: String, refreshToken: String = "", connectionId: String = "") {
        self.baseURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.accessToken = token
        self.refreshToken = refreshToken
        self.serverConnectionId = connectionId
        self.isAuthenticated = !token.isEmpty
        if !token.isEmpty {
            self.onTokenRefreshed?(token, refreshToken)
        }
    }

    /// Send a magic link sign-in email for the iOS client
    public func sendMagicLink(email: String, client: String = "ios", serverURL: String? = nil) async throws {
        if let serverURL {
            self.baseURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        }
        guard let url = URL(string: APIEndpoint.custom(path: "/api/auth/magic-link").urlString(baseURL: baseURL)) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let anonKey = EnvironmentConfig.supabaseAnonKey
        if !anonKey.isEmpty {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
        }

        let body: [String: String] = ["email": email, "client": client, "server": baseURL]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data), let msg = errorResponse.parsedMessage {
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: msg, code: nil)
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Failed to send magic link", code: nil)
        }
    }

    // MARK: - Authentication

    /// Authenticate with username and password
    public func login(serverURL: String, username: String, password: String) async throws -> LoginResponse {
        self.baseURL = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard let url = URL(string: APIEndpoint.login.urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let anonKey = EnvironmentConfig.supabaseAnonKey
        if !anonKey.isEmpty {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
        }

        let body = ["username": username, "password": password]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data), let msg = errorResponse.parsedMessage {
                if httpResponse.statusCode == 401 {
                    throw APIError.authenticationFailed
                }
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: msg, code: errorResponse.error?.code)
            }
            if httpResponse.statusCode == 401 {
                throw APIError.authenticationFailed
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Unknown server error", code: nil)
        }

        let decoder = defaultDecoder
        let loginResponse = try decoder.decode(LoginResponse.self, from: data)

        if loginResponse.requires2FA == true {
            return loginResponse
        }

        guard let user = loginResponse.user else {
            throw APIError.invalidResponse
        }

        self.accessToken = user.token
        self.refreshToken = user.refreshToken ?? ""
        self.currentUser = user
        self.isAuthenticated = true

        // Save to Keychain/Secure preferences
        try KeychainManager.shared.saveCredentials(
            serverURL: baseURL,
            token: accessToken,
            refreshToken: refreshToken
        )

        return loginResponse
    }

    /// Complete 2FA challenge during login
    public func verify2FALogin(userId: String, tempToken: String, code: String, method: String? = nil) async throws -> LoginResponse {
        guard let url = URL(string: APIEndpoint.custom(path: "/api/auth/2fa/verify-login").urlString(baseURL: baseURL)) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: String] = [
            "userId": userId,
            "tempToken": tempToken,
            "code": code
        ]
        if let method = method {
            body["method"] = method
        }
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data), let msg = errorResponse.parsedMessage {
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: msg, code: nil)
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Invalid 2FA code", code: nil)
        }

        let loginResponse = try defaultDecoder.decode(LoginResponse.self, from: data)
        guard let user = loginResponse.user else {
            throw APIError.invalidResponse
        }

        self.accessToken = user.token
        self.refreshToken = user.refreshToken ?? ""
        self.currentUser = user
        self.isAuthenticated = true

        try KeychainManager.shared.saveCredentials(
            serverURL: baseURL,
            token: accessToken,
            refreshToken: refreshToken
        )

        return loginResponse
    }

    /// Fetch 2FA status for the authenticated user
    public func get2FAStatus() async throws -> TwoFactorStatusResponse {
        return try await executeRequest(try createAuthRequest(path: "/api/auth/2fa/status", method: "GET"), responseType: TwoFactorStatusResponse.self)
    }

    /// Enroll in 2FA (generate secret and QR URI)
    public func enroll2FA() async throws -> TwoFactorEnrollResponse {
        return try await executeRequest(try createAuthRequest(path: "/api/auth/2fa/enroll", method: "POST"), responseType: TwoFactorEnrollResponse.self)
    }

    /// Verify code and activate 2FA
    public func verify2FA(code: String) async throws -> TwoFactorActionResponse {
        let body = try JSONEncoder().encode(["code": code])
        return try await executeRequest(try createAuthRequest(path: "/api/auth/2fa/verify", method: "POST", body: body), responseType: TwoFactorActionResponse.self)
    }

    /// Disable 2FA. Requires proof of ownership: a TOTP code, the PIN, or the
    /// account password (the backend accepts any one of the three).
    public func disable2FA(code: String = "", pinCode: String = "", password: String = "") async throws -> TwoFactorActionResponse {
        var body: [String: String] = [:]
        if !code.isEmpty {
            body["code"] = code
        }
        if !pinCode.isEmpty {
            body["pinCode"] = pinCode
        }
        if !password.isEmpty {
            body["password"] = password
        }
        let payload = body.isEmpty ? nil : try JSONEncoder().encode(body)
        return try await executeRequest(try createAuthRequest(path: "/api/auth/2fa/disable", method: "POST", body: payload), responseType: TwoFactorActionResponse.self)
    }

    /// Enroll PIN Code 2FA
    public func enroll2FAPin(pinCode: String) async throws -> TwoFactorActionResponse {
        let body = try JSONEncoder().encode(["pinCode": pinCode])
        return try await executeRequest(try createAuthRequest(path: "/api/auth/2fa/enroll-pin", method: "POST", body: body), responseType: TwoFactorActionResponse.self)
    }

    /// Enroll Biometric 2FA
    /// NOTE: Real passkey enrollment must go through WebAuthn (register/options
    /// + register/verify). This legacy flag-only endpoint is retained only for
    /// backward compatibility and is never called by the app.
    @available(*, deprecated, message: "Use webauthnRegisterOptions/webauthnRegisterVerify instead")
    public func enroll2FABiometric(deviceId: String) async throws -> TwoFactorActionResponse {
        let body = try JSONEncoder().encode(["deviceId": deviceId])
        return try await executeRequest(try createAuthRequest(path: "/api/auth/2fa/enroll-biometric", method: "POST", body: body), responseType: TwoFactorActionResponse.self)
    }

    /// Fetch WebAuthn passkey sign-in options (public, tempToken-scoped)
    public func webauthnLoginOptions(userId: String, tempToken: String) async throws -> WebAuthnLoginOptionsResponse {
        guard let url = URL(string: APIEndpoint.custom(path: "/api/auth/2fa/webauthn/login/options").urlString(baseURL: baseURL)) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["userId": userId, "tempToken": tempToken]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data), let msg = errorResponse.parsedMessage {
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: msg, code: nil)
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Passkey sign-in is unavailable for this account", code: nil)
        }
        return try defaultDecoder.decode(WebAuthnLoginOptionsResponse.self, from: data)
    }

    /// Submit a WebAuthn assertion to complete 2FA sign-in (public, tempToken-scoped)
    public func webauthnLoginVerify(
        userId: String,
        tempToken: String,
        assertion: PasskeyAssertion
    ) async throws -> LoginResponse {
        guard let url = URL(string: APIEndpoint.custom(path: "/api/auth/2fa/webauthn/login/verify").urlString(baseURL: baseURL)) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = [
            "userId": userId,
            "tempToken": tempToken,
            "credentialId": assertion.credentialId,
            "clientDataJSON": assertion.clientDataJSON,
            "authenticatorData": assertion.authenticatorData,
            "signature": assertion.signature,
        ]
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data), let msg = errorResponse.parsedMessage {
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: msg, code: nil)
            }
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Passkey verification failed", code: nil)
        }

        let loginResponse = try defaultDecoder.decode(LoginResponse.self, from: data)
        guard let user = loginResponse.user else {
            throw APIError.invalidResponse
        }

        self.accessToken = user.token
        self.refreshToken = user.refreshToken ?? ""
        self.currentUser = user
        self.isAuthenticated = true

        try KeychainManager.shared.saveCredentials(
            serverURL: baseURL,
            token: accessToken,
            refreshToken: refreshToken
        )

        return loginResponse
    }

    /// Fetch WebAuthn passkey registration options (requires session)
    public func webauthnRegisterOptions(excludeCredentialIds: [String] = []) async throws -> WebAuthnRegisterOptionsResponse {
        let body = excludeCredentialIds.isEmpty
            ? nil
            : try JSONEncoder().encode(["excludeCredentials": excludeCredentialIds])
        return try await executeRequest(
            try createAuthRequest(path: "/api/auth/2fa/webauthn/register/options", method: "POST", body: body),
            responseType: WebAuthnRegisterOptionsResponse.self
        )
    }

    /// Submit a WebAuthn registration attestation to enroll a passkey (requires session)
    public func webauthnRegisterVerify(
        registration: PasskeyRegistration,
        deviceName: String = "iOS Device"
    ) async throws -> WebAuthnActionResponse {
        let body = try JSONEncoder().encode([
            "id": registration.id,
            "clientDataJSON": registration.clientDataJSON,
            "attestationObject": registration.attestationObject,
            "deviceName": deviceName,
        ])
        return try await executeRequest(
            try createAuthRequest(path: "/api/auth/2fa/webauthn/register/verify", method: "POST", body: body),
            responseType: WebAuthnActionResponse.self
        )
    }

    private func createAuthRequest(path: String, method: String, body: Data? = nil) throws -> URLRequest {
        guard let url = URL(string: APIEndpoint.custom(path: path).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        if let body = body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return request
    }

    public func logout() {
        // Notify backend to invalidate server-side session (fire-and-forget)
        if !baseURL.isEmpty && !accessToken.isEmpty {
            let logoutURL = baseURL
            let token = accessToken
            let anonKey = EnvironmentConfig.supabaseAnonKey
            Task.detached {
                guard let url = URL(string: "\(logoutURL)/api/auth/logout") else { return }
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = 3
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                if !anonKey.isEmpty {
                    request.setValue(anonKey, forHTTPHeaderField: "apikey")
                }
                _ = try? await URLSession.shared.data(for: request)
            }
        }

        accessToken = ""
        refreshToken = ""
        currentUser = nil
        isAuthenticated = false

        Task { @MainActor in
            AppState.shared.isAuthenticated = false
        }

        try? KeychainManager.shared.clearCredentials()
    }

    // MARK: - Token Refresh

    /// Refresh the access token using the refresh token
    /// Manually triggers a token refresh, usually called when returning to the foreground
    public func refreshTokensFromForeground() async throws {
        _ = try await refreshAccessToken()
    }

    private func refreshAccessToken() async throws {
        if let existingTask = refreshTask {
            logger.info("Awaiting existing token refresh task...")
            return try await existingTask.value
        }

        let task = Task<Void, Error> {
            try await self.performRefreshToken()
        }

        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func performRefreshToken() async throws {
        guard !self.refreshToken.isEmpty else {
            throw APIError.noRefreshToken
        }

        logger.info("Refreshing access token...")

        guard let url = URL(string: APIEndpoint.authRefresh.urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(self.refreshToken, forHTTPHeaderField: "x-refresh-token")

        let anonKey = EnvironmentConfig.supabaseAnonKey
        if !anonKey.isEmpty {
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
        }
        request.httpBody = "{}".data(using: .utf8)

        let (data, response) = try await self.session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if (400...403).contains(httpResponse.statusCode) {
            throw APIError.authenticationFailed
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Token refresh failed", code: nil)
        }

        let decoder = defaultDecoder
        let refreshResponse = try decoder.decode(LoginResponse.self, from: data)

        guard let user = refreshResponse.user else {
            throw APIError.invalidResponse
        }
        self.accessToken = user.token
        // Preserve the existing refresh token if the backend returns nil.
        // The /authorize endpoint returns null when the JWT is still valid
        // and no rotation occurred — discarding it here was causing the iOS
        // client to lose its refresh token and force re-login next session.
        if let newRefreshToken = user.refreshToken, !newRefreshToken.isEmpty {
            self.refreshToken = newRefreshToken
        }

        // Update Keychain/Secure preferences
        try? KeychainManager.shared.saveCredentials(
            serverURL: self.baseURL,
            token: self.accessToken,
            refreshToken: self.refreshToken
        )
        self.onTokenRefreshed?(self.accessToken, self.refreshToken)
        logger.info("Token refreshed successfully")
    }

    // MARK: - Request Execution

    /// Execute an authenticated request with automatic token refresh
    private func executeRequest<T: Decodable>(_ request: URLRequest, responseType: T.Type, isRetry: Bool = false) async throws -> T {
        var authRequest = request
        authRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        authRequest.setValue("Audiobookphile/2026.1 (Apple)", forHTTPHeaderField: "User-Agent")
        authRequest.setValue("2026.07.24", forHTTPHeaderField: "X-App-Version")

        let anonKey = EnvironmentConfig.supabaseAnonKey
        if !anonKey.isEmpty {
            authRequest.setValue(anonKey, forHTTPHeaderField: "apikey")
        }

        var attempts = 0
        let maxAttempts = isRetry ? 1 : 3

        while true {
            attempts += 1
            do {
                let (data, response) = try await session.data(for: authRequest)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                // Handle 401 or 403 - try token refresh
                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    if isRetry {
                        if httpResponse.statusCode == 401 {
                            logout()
                            throw APIError.sessionExpired
                        } else {
                            throw APIError.serverError(statusCode: 403, message: "Forbidden", code: nil)
                        }
                    }
                    return try await handleUnauthorized(originalRequest: request, responseType: responseType)
                }

                // If 5xx server error, attempt retry with jittered backoff
                if (500...599).contains(httpResponse.statusCode) && attempts < maxAttempts {
                    try? await Task.sleep(nanoseconds: retryDelay(forAttempt: attempts))
                    continue
                }

                guard (200...299).contains(httpResponse.statusCode) else {
                    if let errorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data), let msg = errorResponse.parsedMessage {
                        throw APIError.serverError(statusCode: httpResponse.statusCode, message: msg, code: errorResponse.error?.code)
                    }
                    throw APIError.serverError(statusCode: httpResponse.statusCode, message: "Unknown server error", code: nil)
                }

            let decoder = defaultDecoder

            do {
                // Dump raw JSON for PlaybackSession debugging
                if T.self == PlaybackSession.self {
                    let jsonStr = String(data: data, encoding: .utf8) ?? "unable to decode"
                    let dumpPath = NSTemporaryDirectory() + "playback_session_raw.json"
                    try? jsonStr.write(toFile: dumpPath, atomically: true, encoding: .utf8)
                    logger.info("PlaybackSession raw JSON dumped to: \(dumpPath) (\(data.count) bytes)")
                }
                return try decoder.decode(T.self, from: data)
            } catch let decodingError as DecodingError {
                let errorDetails = "[DecodingError] Details: \(decodingError)\nFor type: \(T.self)\nJSON length: \(data.count) bytes\n"
                if T.self == PlaybackSession.self {
                    let errorPath = NSTemporaryDirectory() + "playback_session_decode_error.txt"
                    try? errorDetails.write(toFile: errorPath, atomically: true, encoding: .utf8)
                }
                try? errorDetails.write(toFile: NSTemporaryDirectory() + "audiobookphile_decoding_error.txt", atomically: true, encoding: .utf8)
                throw decodingError
            } catch {
                throw error
            }

            } catch let error as APIError {
                throw error
            } catch {
                if attempts < maxAttempts {
                    try? await Task.sleep(nanoseconds: retryDelay(forAttempt: attempts))
                    continue
                }
                throw APIError.networkError(underlying: error)
            }
        }
    }

    /// Full-jitter exponential backoff (AWS recommendation): random in
    /// [0, base] where base doubles per attempt (0.5s, 1s, 2s). Jitter avoids
    /// retry-stampedes of concurrent requests, and the tighter budget
    /// (3 attempts vs the previous 4 × 1/2/4s) bounds the worst-case wait
    /// (~33s incl. timeouts) instead of ~47s.
    private func retryDelay(forAttempt attempt: Int) -> UInt64 {
        let base = 0.5 * pow(2.0, Double(attempt - 1))
        return UInt64(Double.random(in: 0...base) * 1_000_000_000)
    }

    /// Handle 401 unauthorized - refresh token and retry
    private func handleUnauthorized<T: Decodable>(originalRequest: URLRequest, responseType: T.Type) async throws -> T {
        do {
            try await refreshAccessToken()
            // Retry original request with new token
            return try await executeRequest(originalRequest, responseType: responseType, isRetry: true)
        } catch APIError.authenticationFailed, APIError.invalidResponse {
            // Refresh explicitly rejected - logout
            logout()
            throw APIError.sessionExpired
        } catch {
            // Other errors (e.g. network offline) - propagate error without logging out
            throw error
        }
    }

    // MARK: - Libraries

    /// Get all libraries
    public func getLibraries() async throws -> [Library] {
        guard let url = URL(string: APIEndpoint.getLibraries.urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)

        let response: LibrariesResponse = try await executeRequest(request, responseType: LibrariesResponse.self)
        return response.libraries
    }

    /// Get library items (books)
    public func getLibraryItems(libraryId: String, limit: Int? = nil, page: Int = 0, sort: String = "addedAt", desc: Bool = true) async throws -> LibraryItemsResponse {
        guard var components = URLComponents(string: APIEndpoint.getLibraryItems(libraryId: libraryId).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        var queryItems = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "desc", value: desc ? "1" : "0"),
            URLQueryItem(name: "include", value: "progress")
        ]
        if let limit = limit {
            queryItems.append(URLQueryItem(name: "limit", value: "\(limit)"))
        }
        components.queryItems = queryItems

        guard let url = components.url else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: LibraryItemsResponse.self)
    }

    /// Trigger Z.AI smart sorting for library items by criteria
    public func smartSortLibraryItems(libraryId: String, criteria: String = "chronological reading order") async throws -> [String] {
        guard let url = URL(string: APIEndpoint.getLibrarySmartSort(libraryId: libraryId).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["criteria": criteria])

        struct SmartSortResponse: Decodable {
            let sortedIds: [String]
            let provider: String?
        }
        let res: SmartSortResponse = try await executeRequest(request, responseType: SmartSortResponse.self)
        return res.sortedIds
    }

    /// Trigger backend deduplication for library items
    public func deduplicateLibraryItems(libraryId: String) async throws -> Int {
        guard let url = URL(string: APIEndpoint.getLibraryDeduplicate(libraryId: libraryId).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        struct DeduplicateResponse: Decodable {
            let success: Bool
            let removedCount: Int?
        }
        let res: DeduplicateResponse = try await executeRequest(request, responseType: DeduplicateResponse.self)
        return res.removedCount ?? 0
    }

    /// Search library
    public func searchLibrary(libraryId: String, query: String, limit: Int = 12) async throws -> SearchResponse {
        guard var components = URLComponents(string: APIEndpoint.searchLibrary(libraryId: libraryId).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        guard let url = components.url else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: SearchResponse.self)
    }

    /// Fetch personalized shelves (continue listening, recently added, etc.)
    public func getLibraryPersonalized(libraryId: String) async throws -> [PersonalizedShelf] {
        guard let url = URL(string: APIEndpoint.getPersonalized(libraryId: libraryId).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: [PersonalizedShelf].self)
    }

    /// Batch fetch multiple library items by IDs in a single HTTP request
    public func getBatchLibraryItems(itemIds: [String]) async throws -> [Book] {
        guard let url = URL(string: APIEndpoint.getBatchItems.urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["itemIds": Array(itemIds.prefix(50))]
        request.httpBody = try JSONEncoder().encode(body)

        struct BatchResponse: Decodable {
            let items: [Book]
        }
        let response: BatchResponse = try await executeRequest(request, responseType: BatchResponse.self)
        return response.items
    }

    private struct SemanticEdgeResponse: Codable, Sendable {
        let results: [Book]?
        let error: String?
    }

    /// Semantic search using Edge Function
    public func searchSemantic(query: String) async throws -> SearchResponse {
        guard let url = URL(string: APIEndpoint.searchSemantic.urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["query": query]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let response = try await executeRequest(request, responseType: SemanticEdgeResponse.self)

        if let error = response.error {
            throw APIError.serverError(statusCode: 500, message: error, code: nil)
        }

        let items = response.results ?? []
        let searchResults = items.map { book in
            SearchResponse.SearchResult(libraryItem: book, matchKey: "title", matchText: book.media.metadata.title)
        }

        return SearchResponse(results: searchResults)
    }

    public struct ChapterAIInsights: Codable, Sendable {
        public let summary: String
        public let keyTakeaways: [String]
        public let mood: String?
    }

    private struct ChapterAIResponse: Codable, Sendable {
        let insights: ChapterAIInsights?
        let error: String?
    }

    /// Fetch AI insights & chapter summaries using Supabase Edge Function
    public func fetchChapterAIInsights(title: String, author: String?, chapterTitle: String, chapterIndex: Int?) async throws -> ChapterAIInsights {
        guard let url = URL(string: APIEndpoint.chapterAI.urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "title": title,
            "chapterTitle": chapterTitle
        ]
        if let author = author, !author.isEmpty { body["author"] = author }
        if let idx = chapterIndex { body["chapterIndex"] = idx }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let response = try await executeRequest(request, responseType: ChapterAIResponse.self)
        if let error = response.error {
            throw APIError.serverError(statusCode: 500, message: error, code: nil)
        }
        guard let insights = response.insights else {
            throw APIError.invalidResponse
        }
        return insights
    }

    public struct BookAIInsights: Codable, Sendable {
        public let bookId: String
        public let title: String
        public let author: String?
        public let summary: String
        public let keyTakeaways: [String]
        public let mood: String
        public let themes: [String]
        public let isCached: Bool
    }

    /// Fetch compiled AI book insights persisted via dedicated Supabase Edge Function
    public func fetchBookAIInsights(bookId: String, title: String, author: String?) async throws -> BookAIInsights {
        guard let url = URL(string: APIEndpoint.bookAI.urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "bookId": bookId,
            "title": title
        ]
        if let author = author, !author.isEmpty { body["author"] = author }

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await executeRequest(request, responseType: BookAIInsights.self)
    }

    // MARK: - Bookmarks

    public func fetchBookmarks(libraryItemId: String) async throws -> [Bookmark] {
        guard let url = URL(string: APIEndpoint.getBookmarks(libraryItemId: libraryItemId).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        let response = try await executeRequest(request, responseType: BookmarksResponse.self)
        return response.bookmarks
    }

    public struct BookmarkCreateRequest: Codable {
        let library_item_id: String
        let time_pos: Double
        let title: String?
    }

    public struct SingleBookmarkResponse: Codable {
        let bookmark: Bookmark
    }

    public func createBookmark(libraryItemId: String, timePos: Double, title: String? = nil) async throws -> Bookmark {
        guard let url = URL(string: APIEndpoint.createBookmark.urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = BookmarkCreateRequest(library_item_id: libraryItemId, time_pos: timePos, title: title)
        request.httpBody = try JSONEncoder().encode(payload)

        let response = try await executeRequest(request, responseType: SingleBookmarkResponse.self)
        return response.bookmark
    }

    public func deleteBookmark(bookmarkId: String) async throws {
        guard let url = URL(string: APIEndpoint.deleteBookmark(bookmarkId: bookmarkId).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await executeRequest(request, responseType: EmptyResponse.self)
    }

    // MARK: - Library Items

    /// Get single library item
    public func getLibraryItem(id: String) async throws -> Book {
        guard let url = URL(string: APIEndpoint.getItemDetails(id: id).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: Book.self)
    }

    // MARK: - Playback

    /// Start a playback session
    public func getDownloadManifest(libraryItemId: String) async throws -> DownloadManifest {
        guard let url = URL(string: APIEndpoint.downloadItem(libraryItemId: libraryItemId).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        return try await executeRequest(request, responseType: DownloadManifest.self)
    }

    public func startPlaybackSession(libraryItemId: String, episodeId: String? = nil) async throws -> PlaybackSession {
        var path = "/api/items/\(libraryItemId)/play"
        if let episodeId = episodeId {
            path = "/api/items/\(libraryItemId)/play/\(episodeId)"
        }

        guard let url = URL(string: APIEndpoint.custom(path: path).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let deviceInfo: [String: Any] = [
            "clientName": "Audiobookphile iOS (Native SKIP)",
            "deviceId": getDeviceId()
        ]
        let body: [String: Any] = [
            "deviceInfo": deviceInfo,
            "mediaPlayer": "SKIP-ExoPlayer",
            "forceDirectPlay": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await executeRequest(request, responseType: PlaybackSession.self)
    }

    /// Sync playback progress — routes through executeRequest for automatic token refresh
    public func syncProgress(sessionId: String, episodeId: String? = nil, currentTime: TimeInterval, duration: TimeInterval, timeListened: TimeInterval = 0) async throws {
        guard let url = URL(string: APIEndpoint.syncSession(sessionId: sessionId).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let progress = duration > 0 ? currentTime / duration : 0
        var body: [String: Any] = [
            "currentTime": currentTime,
            "duration": duration,
            "progress": progress,
            "timeListened": timeListened
        ]
        if let episodeId = episodeId {
            body["episodeId"] = episodeId
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let _: EmptyResponse = try await executeRequest(request, responseType: EmptyResponse.self)
    }

    /// Bulk sync playback progress — routes through executeRequest for automatic token refresh
    public func bulkSyncProgress(items: [ProgressSyncQueueItem]) async throws -> [String] {
        guard !items.isEmpty else { return [] }

        guard let url = URL(string: APIEndpoint.bulkSyncSession.urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payloads = items.map { item -> [String: Any] in
            let progress = item.duration > 0 ? item.currentTime / item.duration : 0
            var body: [String: Any] = [
                "sessionId": item.sessionId,
                "currentTime": item.currentTime,
                "duration": item.duration,
                "progress": progress,
                "timeListened": item.timeListened
            ]
            if let episodeId = item.episodeId {
                body["episodeId"] = episodeId
            }
            return body
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: payloads)

        let result: BulkSyncResponse = try await executeRequest(request, responseType: BulkSyncResponse.self)
        return result.syncedSessionIds ?? []
    }

    /// Close playback session — routes through executeRequest for automatic token refresh
    public func closePlaybackSession(sessionId: String, episodeId: String? = nil, currentTime: TimeInterval, duration: TimeInterval, timeListened: TimeInterval = 0) async throws {
        guard let url = URL(string: APIEndpoint.closeSession(sessionId: sessionId).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "currentTime": currentTime,
            "duration": duration,
            "timeListened": timeListened
        ]
        if let episodeId = episodeId {
            body["episodeId"] = episodeId
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let _: EmptyResponse = try await executeRequest(request, responseType: EmptyResponse.self)
    }

    // MARK: - Progress

    /// Get user media progress
    public func getUserProgress(libraryItemId: String, episodeId: String? = nil) async throws -> MediaProgress? {
        var path = "/api/me/progress/\(libraryItemId)"
        if let episodeId = episodeId {
            path += "/\(episodeId)"
        }

        guard let url = URL(string: APIEndpoint.custom(path: path).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)

        do {
            return try await executeRequest(request, responseType: MediaProgress.self)
        } catch APIError.serverError(let statusCode, _, _) where statusCode == 404 {
            return nil
        }
    }

    // MARK: - Cover Images

    /// Get cover image URL
    public func getCoverURL(itemId: String, width: Int = 400, updatedAt: Date? = nil) -> URL? {
        guard var components = URLComponents(string: APIEndpoint.getCover(itemId: itemId).urlString(baseURL: self.baseURL)) else {
            return nil
        }
        var queryItems = [
            URLQueryItem(name: "width", value: "\(width)"),
            URLQueryItem(name: "format", value: "jpeg"),
            URLQueryItem(name: "token", value: accessToken)
        ]

        if let updated = updatedAt {
            queryItems.append(URLQueryItem(name: "ts", value: "\(Int(updated.timeIntervalSince1970))"))
        } else {
            // Fallback cache buster if updatedAt isn't provided but we want to avoid stale broken redirects
            queryItems.append(URLQueryItem(name: "ts", value: "1"))
        }

        let anonKey = EnvironmentConfig.supabaseAnonKey
        if !anonKey.isEmpty {
            queryItems.append(URLQueryItem(name: "apikey", value: anonKey))
        }

        components.queryItems = queryItems
        return components.url
    }

    // MARK: - Helpers

    private func getDeviceId() -> String {
        if let deviceId = UserDefaults.standard.string(forKey: "absDeviceId") {
            return deviceId
        }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "absDeviceId")
        return newId
    }

    // MARK: - Preferences

    public struct PreferencesResponse: Codable, Sendable {
        public let preferences: AppSettings?
    }

    public func getPreferences() async throws -> AppSettings {
        guard let url = URL(string: APIEndpoint.getPreferences.urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }

        let request = URLRequest(url: url)

        let response = try await executeRequest(request, responseType: PreferencesResponse.self)
        return response.preferences ?? AppSettings()
    }

    public func updatePreferences(_ settings: AppSettings) async throws -> AppSettings {
        guard let url = URL(string: APIEndpoint.getPreferences.urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(settings)

        let response = try await executeRequest(request, responseType: PreferencesResponse.self)
        return response.preferences ?? settings
    }

    // MARK: - Library Stats

    /// Get library statistics (total items, duration, authors, genres, etc.)
    public func getLibraryStats(libraryId: String) async throws -> LibraryStats {
        guard let url = URL(string: APIEndpoint.getLibraryStats(libraryId: libraryId).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: LibraryStats.self)
    }

    // MARK: - Authors

    /// Get paginated authors for a library
    public func getLibraryAuthors(libraryId: String, limit: Int = 24, page: Int = 0, sort: String = "name", desc: Bool = false) async throws -> AuthorsResponse {
        guard var components = URLComponents(string: APIEndpoint.getAuthors(libraryId: libraryId).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "desc", value: desc ? "1" : "0")
        ]
        guard let url = components.url else { throw APIError.invalidResponse }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: AuthorsResponse.self)
    }

    /// Get a single author with their books
    public func getAuthorDetail(authorId: String) async throws -> AuthorSummary {
        guard let url = URL(string: APIEndpoint.getAuthor(authorId: authorId).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: AuthorSummary.self)
    }

    // MARK: - Series

    /// Get paginated series for a library
    public func getLibrarySeries(libraryId: String, limit: Int = 24, page: Int = 0, sort: String = "name", desc: Bool = false) async throws -> SeriesResponse {
        guard var components = URLComponents(string: APIEndpoint.getSeries(libraryId: libraryId).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "desc", value: desc ? "1" : "0")
        ]
        guard let url = components.url else { throw APIError.invalidResponse }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: SeriesResponse.self)
    }

    // MARK: - Collections

    /// Get paginated collections for a library
    public func getLibraryCollections(libraryId: String, limit: Int = 24, page: Int = 0, sort: String = "name", desc: Bool = false) async throws -> CollectionsResponse {
        guard var components = URLComponents(string: APIEndpoint.getCollections(libraryId: libraryId).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "desc", value: desc ? "1" : "0")
        ]
        guard let url = components.url else { throw APIError.invalidResponse }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: CollectionsResponse.self)
    }

    // MARK: - Playlists

    /// Get paginated playlists for a library
    public func getLibraryPlaylists(libraryId: String, limit: Int = 24, page: Int = 0, sort: String = "name", desc: Bool = false) async throws -> PlaylistsResponse {
        guard var components = URLComponents(string: APIEndpoint.getPlaylists(libraryId: libraryId).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        components.queryItems = [
            URLQueryItem(name: "limit", value: "\(limit)"),
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "sort", value: sort),
            URLQueryItem(name: "desc", value: desc ? "1" : "0")
        ]
        guard let url = components.url else { throw APIError.invalidResponse }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: PlaylistsResponse.self)
    }

    // MARK: - Match All

    /// Trigger metadata matching for all items in a library (runs in background)
    public func triggerMatchAll(libraryId: String) async throws {
        guard let url = URL(string: APIEndpoint.matchAll(libraryId: libraryId).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let _: EmptyResponse = try await executeRequest(request, responseType: EmptyResponse.self)
    }

    public func getUserStats() async throws -> UserStatsData {
        guard let url = URL(string: APIEndpoint.getMeStats.urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        return try await executeRequest(request, responseType: UserStatsData.self)
    }

    public func getCurrentUserProfile() async throws -> User {
        guard let url = URL(string: APIEndpoint.getMe.urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        let res: LoginResponse = try await executeRequest(request, responseType: LoginResponse.self)
        guard let user = res.user else {
            throw APIError.invalidResponse
        }
        return user
    }

    public func getSimilarItems(itemId: String) async throws -> [Book] {
        guard let url = URL(string: APIEndpoint.getSimilarItems(itemId: itemId).urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        let res: SimilarItemsResponse = try await executeRequest(request, responseType: SimilarItemsResponse.self)
        return res.similarItems
    }

    // MARK: - Search History

    public func fetchSearchHistory() async throws -> [SearchHistoryItem] {
        guard let url = URL(string: APIEndpoint.getSearchHistory.urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        let request = URLRequest(url: url)
        let response = try await executeRequest(request, responseType: [SearchHistoryItem].self)
        return response
    }

    public func addSearchHistory(query: String) async throws -> SearchHistoryItem {
        guard let url = URL(string: APIEndpoint.getSearchHistory.urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = ["query": query]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await executeRequest(request, responseType: SearchHistoryItem.self)
    }

    public func clearSearchHistory() async throws {
        guard let url = URL(string: APIEndpoint.getSearchHistory.urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        _ = try await executeRequest(request, responseType: EmptyResponse.self)
    }

    // MARK: - Admin: Invite User

    /// Invite a new user by email (admin only).
    /// Calls `POST /api/auth/invite` with the current access token.
    public func inviteUser(email: String, username: String? = nil, userType: String = "user") async throws -> InviteUserResponse {
        guard let url = URL(string: APIEndpoint.authInvite.urlString(baseURL: self.baseURL)) else {
            throw APIError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: String] = ["email": email, "userType": userType]
        if let username, !username.isEmpty {
            body["username"] = username
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await executeRequest(request, responseType: InviteUserResponse.self)
    }
}

// MARK: - Response Models

public struct TwoFactorMethodsMap: Codable, Sendable {
    public let totp: Bool?
    public let pin: Bool?
    public let biometric: Bool?
}

public struct LoginResponse: Codable, Sendable {
    public let user: User?
    public let requires2FA: Bool?
    public let userId: String?
    public let email: String?
    public let tempToken: String?
    public let methods: TwoFactorMethodsMap?
}

public struct TwoFactorEnrollResponse: Codable, Sendable {
    public let secret: String?
    public let uri: String?
    public let error: String?
}

public struct TwoFactorActionResponse: Codable, Sendable {
    public let success: Bool?
    public let error: String?
}

public struct TwoFactorStatusResponse: Codable, Sendable {
    public let enabled: Bool
    public let totpEnrolled: Bool?
    public let pinEnrolled: Bool?
    public let biometricEnrolled: Bool?
    public let passkeys: [TwoFactorPasskeyInfo]?
    public let methods: [String]?
}

public struct TwoFactorPasskeyInfo: Codable, Sendable {
    public let id: String
    public let credentialId: String?
    public let deviceName: String?
    public let createdAt: String?
    public let lastUsedAt: String?
}

// MARK: - WebAuthn (passkeys)

public struct WebAuthnAllowedCredential: Codable, Sendable {
    public let type: String?
    public let id: String
    public let transports: [String]?

    public init(type: String? = nil, id: String, transports: [String]? = nil) {
        self.type = type
        self.id = id
        self.transports = transports
    }
}

public struct WebAuthnLoginOptionsResponse: Codable, Sendable {
    public let challenge: String
    public let rpId: String
    public let origin: String?
    public let timeout: Int?
    public let allowCredentials: [WebAuthnAllowedCredential]?
    public let userVerification: String?
}

public struct WebAuthnRp: Codable, Sendable {
    public let name: String
    public let id: String
}

public struct WebAuthnUser: Codable, Sendable {
    public let id: String
    public let name: String
    public let displayName: String
}

public struct WebAuthnAuthenticatorSelection: Codable, Sendable {
    public let residentKey: String?
    public let userVerification: String?
}

public struct WebAuthnRegisterOptionsResponse: Codable, Sendable {
    public let rp: WebAuthnRp?
    public let user: WebAuthnUser?
    public let challenge: String
    public let excludeCredentials: [WebAuthnAllowedCredential]?
    public let authenticatorSelection: WebAuthnAuthenticatorSelection?
    public let attestation: String?
}

public struct WebAuthnActionResponse: Codable, Sendable {
    public let success: Bool?
    public let enrolled: String?
    public let credentialId: String?
    public let error: String?
}

/// Placeholder response for endpoints that return JSON but we don't need to decode.
public struct EmptyResponse: Codable, Sendable {}

public struct InviteUserResponse: Codable, Sendable {
    public let success: Bool?
    public let error: String?
}

public struct BulkSyncResponse: Codable, Sendable {
    public let success: Bool?
    public let syncedSessionIds: [String]?
    public let error: String?
}

public struct LibrariesResponse: Codable, Sendable {
    public let libraries: [Library]
}

public struct LibraryItemsResponse: Codable, Sendable {
    public let results: [Book]
    public let total: Int
    public let limit: Int
    public let page: Int

    enum CodingKeys: String, CodingKey {
        case results, total, limit, page
    }

    public init(results: [Book], total: Int, limit: Int, page: Int) {
        self.results = results
        self.total = total
        self.limit = limit
        self.page = page
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        results = (try container.decodeIfPresent([Book].self, forKey: .results)) ?? []
        total = (try container.decodeIfPresent(Int.self, forKey: .total)) ?? results.count
        limit = (try container.decodeIfPresent(Int.self, forKey: .limit)) ?? 0
        page = (try container.decodeIfPresent(Int.self, forKey: .page)) ?? 0
    }
}

public struct SearchResponse: Codable, Sendable {
    public struct SearchResult: Codable, Sendable {
        public let libraryItem: Book
        public let matchKey: String?
        public let matchText: String?
    }
    public let results: [SearchResult]
}

public struct PersonalizedShelf: Codable, Sendable {
    public let id: String
    public let label: String
    public let labelStringKey: String
    public let type: String
    public let entities: [Book]
    public let total: Int
}

public struct AuthorsResponse: Codable, Sendable {
    public let authors: [AuthorSummary]
    public let total: Int
    public let limit: Int
    public let page: Int
}

public struct SeriesResponse: Codable, Sendable {
    public let results: [SeriesSummary]
    public let total: Int
    public let limit: Int
    public let page: Int
}

public struct CollectionsResponse: Codable, Sendable {
    public let results: [CollectionSummary]
    public let total: Int
    public let limit: Int
    public let page: Int
}

public struct PlaylistsResponse: Codable, Sendable {
    public let results: [PlaylistSummary]
    public let total: Int
    public let limit: Int
    public let page: Int
}

// MARK: - API Errors

public enum APIError: LocalizedError {
    case invalidResponse
    case authenticationFailed
    case serverError(statusCode: Int, message: String, code: String?)
    case networkError(underlying: Error)
    case noRefreshToken
    case tokenRefreshFailed
    case sessionExpired
    case syncFailed

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .authenticationFailed:
            return "Authentication failed. Check your credentials."
        case .serverError(let statusCode, let message, let code):
            if let code = code {
                return "\(message) (\(code))"
            }
            return "\(message) (status: \(statusCode))"
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .noRefreshToken:
            return "No refresh token available"
        case .tokenRefreshFailed:
            return "Failed to refresh authentication"
        case .sessionExpired:
            return "Your session has expired. Please login again."
        case .syncFailed:
            return "Failed to sync progress"
        }
    }
}

// MARK: - Keychain Manager

public final class KeychainManager: Sendable {
    public static let shared = KeychainManager()
    private init() {}

    private let serverURLKey = "abp_serverURL"
    private let tokenKey = "abp_token"
    private let refreshTokenKey = "abp_refreshToken"

    public func saveCredentials(serverURL: String, token: String, refreshToken: String) throws {
        #if !SKIP && !os(Android)
        // iOS Keychain Implementation
        // kSecAttrAccessibleAfterFirstUnlock ensures credentials survive device
        // lock/restart cycles. Without this, the default "WhenUnlocked" policy
        // makes credentials unreachable after a device restart until the user
        // unlocks the phone — causing the app to show the login screen.
        let credentials = [
            "serverURL": serverURL,
            "token": token,
            "refreshToken": refreshToken
        ]
        let data = try JSONEncoder().encode(credentials)

        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.audiobookphile.native",
            kSecAttrAccount as String: "credentials"
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        var addQuery = deleteQuery
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed
        }
        #else
        // Android: plain SharedPreferences, via Skip's AndroidUserDefaults.
        //
        // NOT secure storage. Skip 1.9.10 exposes no KeyStore or
        // EncryptedSharedPreferences bridge, so `UserDefaults.standard` lands in an
        // unencrypted XML file inside app storage, which is included in Android
        // auto-backup and readable by anything with app-data access. The access
        // and refresh tokens are written here, so on a rooted device or a restored
        // backup they are recoverable, and a refresh token is a long-lived
        // credential.
        //
        // The risk is currently bounded rather than absent: Android playback is a
        // no-op shell in this repo (AudioPlayerEngine has no Media3/ExoPlayer
        // binding and initializePlayer is a no-op under SKIP), so Android cannot
        // reach a streaming URL. The exposure grows the moment playback lands.
        //
        // The fix is a Skip platform bridge over the Android KeyStore, not a
        // change here -- there is no secure API to call from Swift. Until that
        // exists, do not treat this store as safe, and keep the token out of
        // anything that leaves the device.
        UserDefaults.standard.set(serverURL, forKey: serverURLKey)
        UserDefaults.standard.set(token, forKey: tokenKey)
        UserDefaults.standard.set(refreshToken, forKey: refreshTokenKey)
        #endif
    }

    public func loadCredentials() throws -> (serverURL: String, token: String, refreshToken: String)? {
        #if !SKIP && !os(Android)
        // iOS Keychain Retrieval
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.audiobookphile.native",
            kSecAttrAccount as String: "credentials",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let credentials = try? JSONDecoder().decode([String: String].self, from: data),
              let serverURL = credentials["serverURL"],
              let token = credentials["token"] else {
            return nil
        }

        return (serverURL, token, credentials["refreshToken"] ?? "")
        #else
        // Plain SharedPreferences -- see the note on the write path above for why
        // this is not secure storage and what has to change.
        guard let serverURL = UserDefaults.standard.string(forKey: serverURLKey),
              let token = UserDefaults.standard.string(forKey: tokenKey) else {
            return nil
        }
        let refreshToken = UserDefaults.standard.string(forKey: refreshTokenKey) ?? ""
        return (serverURL, token, refreshToken)
        #endif
    }

    public func clearCredentials() throws {
        #if !SKIP && !os(Android)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.audiobookphile.native",
            kSecAttrAccount as String: "credentials"
        ]
        SecItemDelete(query as CFDictionary)
        #else
        UserDefaults.standard.removeObject(forKey: serverURLKey)
        UserDefaults.standard.removeObject(forKey: tokenKey)
        UserDefaults.standard.removeObject(forKey: refreshTokenKey)
        #endif
    }

    public enum KeychainError: Error {
        case saveFailed
        case loadFailed
    }

}
