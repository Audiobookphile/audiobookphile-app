//
//  ContentView.swift
//  Audiobookphile
//
//  Main application content router, compatible with Swift 6.3 and Skip.
//

import SwiftUI

public struct ContentView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase


    public init() {}

    public var body: some View {
        @Bindable var bindableAppState = appState
        return MainTabView()
            .preferredColorScheme(appState.settings.theme.colorScheme)
            .sheet(isPresented: Bindable(bindableAppState.navigation).showingConnectModal) {
                ConnectView()
            }
            .sheet(isPresented: Bindable(bindableAppState.navigation).showingSettings) {
                NavigationStack {
                    SettingsView()
                }
            }
            .sheet(isPresented: Bindable(bindableAppState.navigation).showingStats) {
                NavigationStack {
                    StatsView()
                }
            }
            .sheet(isPresented: Bindable(bindableAppState.navigation).showingAccount) {
                NavigationStack {
                    AccountView()
                }
            }
            .onAppear {
                if !appState.isAuthenticated && !appState.isLoading {
                    appState.navigation.showingConnectModal = true
                }
            }
            .onChange(of: appState.isLoading) { _, isLoading in
                if !isLoading && !appState.isAuthenticated {
                    appState.navigation.showingConnectModal = true
                }
            }
            .onChange(of: appState.isAuthenticated) { _, isAuthenticated in
                if isAuthenticated {
                    appState.navigation.showingConnectModal = false
                } else if !appState.isLoading {
                    appState.navigation.showingConnectModal = true
                }
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    Task {
                        await appState.refreshSessionIfNeeded()
                    }
                    consumeWidgetPlaybackCommand()
                }
            }
            .onOpenURL { url in
                handleDeepLink(url)
            }
    }

    /// The widget's TogglePlaybackIntent writes a timestamped command to the
    /// shared app group and opens the app; drain it here exactly once.
    private func consumeWidgetPlaybackCommand() {
        #if os(iOS)
        guard let defaults = UserDefaults(suiteName: EnvironmentConfig.appGroupIdentifier) else { return }
        let commandKey = "audiobookWidgetPlaybackCommand"
        guard let issuedAt = defaults.object(forKey: commandKey) as? TimeInterval else { return }
        defaults.removeObject(forKey: commandKey)

        // Ignore stale commands (e.g. app killed before consuming an older one).
        guard Date().timeIntervalSince1970 - issuedAt < 30 else { return }
        AudioPlayerService.shared.togglePlayPause()
        #endif
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "audiobookphile" else {
            print("[ContentView] Ignoring non-audiobookphile scheme: \(url.absoluteString)")
            return
        }
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return
        }
        let params = components.queryItems?.reduce(into: [String: String]()) { result, item in
            result[item.name] = item.value
        } ?? [:]

        // 1. Server configuration deep link: audiobookphile://connect?server=https://...
        if url.host == "connect" || url.path.hasPrefix("/connect") {
            let server = params["server"] ?? ""
            if !server.isEmpty {
                appState.serverURL = server
                UserDefaults.standard.set(server, forKey: "abp_serverURL")
                print("[ContentView] Server address auto-mapped via deep link: \(server)")
            }

            let username = params["username"] ?? ""
            let password = params["password"] ?? ""
            let autoLogin = params["autoLogin"] == "1" || params["autoLogin"] == "true"

            if !username.isEmpty {
                appState.pendingUsername = username
            }
            if !password.isEmpty {
                appState.pendingPassword = password
            }

            if !server.isEmpty && !username.isEmpty && !password.isEmpty && autoLogin {
                Task {
                    do {
                        try await appState.login(
                            serverURL: server,
                            username: username,
                            password: password
                        )
                        ConnectViewModel().saveRecentServer(address: server, username: username)
                        print("[ContentView] 1-Click deep link login succeeded for \(username)")
                    } catch {
                        print("[ContentView] Deep link auto-login failed: \(error)")
                        appState.navigation.showingConnectModal = true
                    }
                }
            } else {
                appState.navigation.showingConnectModal = true
            }
            return
        }

        // 2. Authentication magic link: audiobookphile://auth?server=...&accessToken=...
        if url.host == "auth" || url.path.hasPrefix("/auth") {
            guard let accessToken = params["accessToken"], !accessToken.isEmpty else {
                print("[ContentView] Magic link callback missing access token")
                return
            }

            Task {
                do {
                    try await AuthManager.shared.completeMagicLinkSession(
                        accessToken: accessToken,
                        refreshToken: params["refreshToken"],
                        userId: params["userId"] ?? "",
                        serverURL: params["server"],
                        appState: appState
                    )
                } catch {
                    print("[ContentView] Magic link session completion failed: \(error)")
                }
            }
            return
        }

        print("[ContentView] Ignoring unknown deep link: \(url.absoluteString)")
    }
}

public struct MainTabView: View {
    @Environment(AppState.self) private var appState
    @Environment(AudioPlayerService.self) private var audioPlayer
    @Environment(PlayerCoordinator.self) private var playerCoordinator

    // Value-based navigation paths for deep linking
    @State private var homePath = NavigationPath()
    @State private var libraryPath = NavigationPath()
    @State private var collectionsPath = NavigationPath()
    @State private var downloadsPath = NavigationPath()
    @State private var searchPath = NavigationPath()

    public init() {}

    public var body: some View {
        @Bindable var bindableAppState = appState
        return ZStack(alignment: .bottom) {
            TabView(selection: Bindable(bindableAppState.navigation).selectedTab) {
                // Home Tab
                NavigationStack(path: $homePath) {
                    HomeView()
                }
                .tabItem {
                    Label("Home", systemImage: "house")
                }
                .tag(0)

                // Library Tab
                NavigationStack(path: $libraryPath) {
                    BookshelfView()
                }
                .tabItem {
                    Label("Library", systemImage: "books.vertical.fill")
                }
                .tag(1)

                // Collections Tab
                NavigationStack(path: $collectionsPath) {
                    CollectionsView()
                }
                .tabItem {
                    Label("Collections", systemImage: "square.stack.3d.up.fill")
                }
                .tag(2)

                // Downloads Tab
                NavigationStack(path: $downloadsPath) {
                    DownloadsView()
                }
                .tabItem {
                    Label("Downloads", systemImage: "arrow.down.circle.fill")
                }
                .tag(3)

                // Search Tab
                NavigationStack(path: $searchPath) {
                    SearchView()
                }
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(4)
            }
            .tint(.appPrimary)

            // Mini Player (when audio is playing)
            if audioPlayer.session != nil && !playerCoordinator.isPlayerPresented {
                MiniPlayerView(
                    audioPlayer: audioPlayer,
                    onTap: {
                        playerCoordinator.presentPlayer(delayMilliseconds: 0)
                    },
                    onClose: {
                        Task {
                            await audioPlayer.closeSession()
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 49) // Tab bar height
            }
        }
        #if os(iOS) || SKIP
        .fullScreenCover(isPresented: Bindable(playerCoordinator).isPlayerPresented) {
            if let session = audioPlayer.session {
                AudioPlayerView(session: session)
            }
        }
        #else
        .sheet(isPresented: Bindable(playerCoordinator).isPlayerPresented) {
            if let session = audioPlayer.session {
                AudioPlayerView(session: session)
            }
        }
        #endif
    }
}
