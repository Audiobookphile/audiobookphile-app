//
//  SettingsView.swift
//  Audiobookphile
//
//  App settings with Liquid Glass design.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Observation

public struct SettingsView: View {
    @State var viewModel = SettingsViewModel()
    @Environment(\.dismiss) var dismiss
    @Environment(AppState.self) private var appState

    public init() {}

    private var trailingPlacement: ToolbarItemPlacement {
        #if os(iOS) || SKIP
        return .navigationBarTrailing
        #else
        return .primaryAction
        #endif
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                // Background
                FluidAuraBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        // Quick Navigation Banner (Return to Library & Admin Dashboard)
                        quickNavigationBanner

                        // User section
                        if let user = appState.currentUser {
                            userSection(user)
                            securitySection
                        }

                        // Admin (visible to admins & root)
                        if let user = appState.currentUser, ["admin", "root"].contains(user.type) {
                            adminSection
                        }

                        // Statistics & Insights
                        statsSection

                        // Playback settings
                        playbackSection

                        // Audio & Hardware Accessibility
                        audioAccessibilitySection

                        // Network settings
                        networkSection

                        // App settings
                        appSection

                        #if !SKIP && os(iOS)
                        // Diagnostics
                        diagnosticsSection
                        #endif

                        // About
                        aboutSection

                        // Logout
                        logoutButton

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Settings")
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        appState.navigation.selectedTab = 0
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Library")
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(Color.appPrimary)
                }

                ToolbarItem(placement: trailingPlacement) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appPrimary)
                }
            }
            .task {
                await viewModel.loadStats(libraryId: appState.currentLibraryId)
            }
        }
    }

    // MARK: - Quick Navigation Banner

    private var quickNavigationBanner: some View {
        VStack(spacing: 10) {
            Button {
                appState.navigation.selectedTab = 0
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.left.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Color.appPrimary)

                    Text("Return to Library")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignTokens.Color.foreground)

                    Spacer()

                    Image(systemName: "books.vertical")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.Color.foreground.opacity(0.4))
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.appPrimary.opacity(0.3), lineWidth: 1)
                        )
                )
            }

            if let user = appState.currentUser, ["admin", "root"].contains(user.type) {
                NavigationLink {
                    AdminDashboardView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "shield.righthalf.filled")
                            .font(.title3)
                            .foregroundStyle(Color.appPrimary)

                        Text("Admin Dashboard")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.appPrimary)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.Color.foreground.opacity(0.4))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(Color.appPrimary.opacity(0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(Color.appPrimary.opacity(0.35), lineWidth: 1)
                            )
                    )
                }
            }
        }
    }

    // MARK: - User Section

    private func userSection(_ user: User) -> some View {
        SettingsSection {
            VStack(spacing: 0) {
                HStack(spacing: 16) {
                    // Avatar
                    Circle()
                        .fill(LinearGradient(
                            colors: [.appPrimary, .appSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 50, height: 50)
                        .overlay {
                            Text(String(user.username.prefix(1)).uppercased())
                                .font(.title2.weight(.bold))
                                .foregroundStyle(DesignTokens.Color.foreground)
                        }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(user.username)
                            .font(.headline)
                            .foregroundStyle(DesignTokens.Color.foreground)

                        Text(user.type.capitalized)
                            .font(.caption)
                            .foregroundStyle(DesignTokens.Color.foreground.opacity(0.6))
                    }

                    Spacer()
                }
                .padding(.bottom, 16)
                
                Divider().background(Color.white.opacity(0.1))
                
                Button {
                    appState.navigation.showingAccount = true
                } label: {
                    HStack {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(Color.appPrimary)
                            .frame(width: 28)

                        Text("Account Details")
                            .foregroundStyle(DesignTokens.Color.foreground)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.Color.foreground.opacity(0.4))
                    }
                    .padding(.vertical, 12)
                }
            }
        }
    }

    // MARK: - Security Section

    private var securitySection: some View {
        SettingsSection(title: "Security & Authentication") {
            NavigationLink {
                TwoFactorSettingsView()
            } label: {
                HStack {
                    Image(systemName: "shield.checkered")
                        .foregroundStyle(Color.appPrimary)
                        .frame(width: 24)

                    Text("Two-Factor Authentication (2FA)")
                        .foregroundStyle(DesignTokens.Color.foreground)
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.Color.foreground.opacity(0.4))
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        SettingsSection(title: "Statistics & Insights") {
            VStack(spacing: 12) {
                if let lStats = viewModel.libraryStats {
                    HStack(spacing: 0) {
                        statCell(label: "Books", value: "\(lStats.totalBooks)", icon: "book.fill")
                        Divider().frame(height: 32).background(DesignTokens.Color.surface.opacity(0.15))
                        statCell(label: "Authors", value: "\(lStats.totalAuthors)", icon: "person.fill")
                        Divider().frame(height: 32).background(DesignTokens.Color.surface.opacity(0.15))
                        statCell(label: "Series", value: "\(lStats.totalSeries)", icon: "books.vertical.fill")
                        Divider().frame(height: 32).background(DesignTokens.Color.surface.opacity(0.15))
                        statCell(label: "Hours", value: "\(Int(lStats.totalDuration / 3600))h", icon: "clock.fill")
                    }
                    .padding(.vertical, 8)

                    Divider().background(.white.opacity(0.1))
                } else if viewModel.isLoadingStats {
                    HStack(spacing: 8) {
                         ProgressView().tint(DesignTokens.Color.accent)
                        Text("Loading stats…")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.Color.foreground.opacity(0.6))
                    }
                    .padding(8)

                    Divider().background(.white.opacity(0.1))
                }

                NavigationLink {
                    StatsView()
                } label: {
                    HStack {
                        Image(systemName: "chart.bar.xaxis")
                            .foregroundStyle(Color.appPrimary)
                            .frame(width: 24)

                        Text("Full Stats & Listening Analytics")
                            .foregroundStyle(DesignTokens.Color.foreground)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.Color.foreground.opacity(0.4))
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding(12)
        }
    }

    private func statCell(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(Color.appPrimary)
                Text(value)
                    .font(.callout.bold())
                    .foregroundStyle(DesignTokens.Color.foreground)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(DesignTokens.Color.foreground.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Playback Section

    private var playbackSection: some View {
        SettingsSection(title: "Playback") {
            // Jump forward time
            Picker(selection: Binding(
                get: { viewModel.jumpForwardTime },
                set: { viewModel.saveJumpForwardTime($0) }
            )) {
                ForEach([5, 10, 15, 30, 45, 60], id: \.self) { seconds in
                    Text("\(seconds) seconds").tag(seconds)
                }
            } label: {
                HStack {
                    Image(systemName: "goforward")
                        .foregroundStyle(Color.appPrimary)
                        .frame(width: 28)
                    Text("Jump Forward")
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 12)
            }

            // Jump backward time
            Picker(selection: Binding(
                get: { viewModel.jumpBackwardTime },
                set: { viewModel.saveJumpBackwardTime($0) }
            )) {
                ForEach([5, 10, 15, 30, 45, 60], id: \.self) { seconds in
                    Text("\(seconds) seconds").tag(seconds)
                }
            } label: {
                HStack {
                    Image(systemName: "gobackward")
                        .foregroundStyle(Color.appPrimary)
                        .frame(width: 28)
                    Text("Jump Backward")
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 12)
            }

            // Playback speed
            Picker(selection: Binding(
                get: { viewModel.defaultPlaybackSpeed },
                set: { viewModel.saveDefaultPlaybackSpeed($0) }
            )) {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0], id: \.self) { speed in
                    Text(String(format: "%.2fx", speed)).tag(speed)
                }
            } label: {
                HStack {
                    Image(systemName: "speedometer")
                        .foregroundStyle(Color.appPrimary)
                        .frame(width: 28)
                    Text("Default Speed")
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 12)
            }

            Divider().background(.white.opacity(0.2))

            // Auto sleep timer
            SettingsToggleRow(
                icon: "moon.fill",
                title: "Auto Sleep Timer",
                isOn: $viewModel.autoSleepTimer
            )

            // Continue playback
            SettingsToggleRow(
                icon: "play.fill",
                title: "Auto Resume",
                isOn: $viewModel.autoResume
            )

            // Smart Rewind on Resume
            SettingsToggleRow(
                icon: "arrow.counterclockwise.circle.fill",
                title: "Smart Rewind on Resume",
                isOn: $viewModel.smartRewindEnabled
            )

            // Shake to Reset Sleep Timer
            SettingsToggleRow(
                icon: "iphone.radiowaves.left.and.right",
                title: "Shake to Reset Sleep Timer",
                isOn: $viewModel.shakeToResetSleepTimer
            )
        }
    }

    // MARK: - Audio & Hardware Accessibility Section

    private var audioAccessibilitySection: some View {
        SettingsSection(title: "Audio & Hardware Accessibility") {
            SettingsToggleRow(
                icon: "waveform.path.badge.plus",
                title: "Spoken Audio Optimization",
                isOn: $viewModel.spokenAudioModeEnabled
            )

            SettingsToggleRow(
                icon: "waveform.and.mic",
                title: "Vocal Clarity Boost",
                isOn: $viewModel.vocalBoostEnabled
            )

            SettingsToggleRow(
                icon: "slider.horizontal.3",
                title: "Smart Volume Leveler",
                isOn: $viewModel.volumeLevelerEnabled
            )

            SettingsToggleRow(
                icon: "speaker.wave.1.fill",
                title: "Mono Audio Mix",
                isOn: $viewModel.monoAudioEnabled
            )

            Divider().background(.white.opacity(0.2))

            SettingsToggleRow(
                icon: "hifispeaker.fill",
                title: "High-Res 48kHz Output",
                isOn: $viewModel.highResAudioEnabled
            )

            SettingsToggleRow(
                icon: "line.3.horizontal.decrease.circle",
                title: "Low-Cut Rumble Filter (80Hz)",
                isOn: $viewModel.lowCutFilterEnabled
            )

            SettingsToggleRow(
                icon: "sparkles",
                title: "De-Esser Sibilance Reducer",
                isOn: $viewModel.deEsserEnabled
            )

            SettingsToggleRow(
                icon: "waveform.path.badge.plus",
                title: "3D Binaural Studio Acoustics",
                isOn: $viewModel.binauralReverbEnabled
            )
        }
    }

    // MARK: - Network Section

    private var networkSection: some View {
        SettingsSection(title: "Network") {
            // Streaming on cellular
            SettingsRow(
                icon: "antenna.radiowaves.left.and.right",
                title: "Stream on Cellular",
                value: viewModel.streamingPolicy.displayName
            ) {
                // Action
            }

            // Download on cellular
            SettingsRow(
                icon: "arrow.down.circle",
                title: "Download on Cellular",
                value: viewModel.downloadPolicy.displayName
            ) {
                // Action
            }
        }
    }

    // MARK: - App Section

    private var appSection: some View {
        SettingsSection(title: "App") {
            // Theme
            Picker(selection: Binding(
                get: { viewModel.selectedTheme },
                set: { viewModel.saveTheme($0) }
            )) {
                Text("System").tag("System")
                Text("Dark").tag("Dark")
                Text("Light").tag("Light")
            } label: {
                HStack {
                    Image(systemName: "paintpalette")
                        .foregroundStyle(Color.appPrimary)
                        .frame(width: 28)
                    Text("Theme")
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 12)
            }

            // Haptics
            SettingsToggleRow(
                icon: "waveform",
                title: "Haptic Feedback",
                isOn: $viewModel.hapticsEnabled
            )

            // Lock orientation
            SettingsToggleRow(
                icon: "lock.rotation",
                title: "Lock Orientation",
                isOn: $viewModel.lockOrientation
            )

            // Crash reporting (only shown when a DSN is configured)
            if TelemetryService.shared.isConfigured {
                SettingsToggleRow(
                    icon: "exclamationmark.triangle",
                    title: "Crash & Error Reporting",
                    isOn: $viewModel.crashReportingEnabled
                )
            }
        }
    }

    // MARK: - Diagnostics Section

    #if !SKIP && os(iOS)
    private var diagnosticsSection: some View {
        SettingsSection(title: "Diagnostics") {
            NavigationLink {
                CrashDiagnosticsView()
            } label: {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Color.appPrimary)
                        .frame(width: 28)

                    Text("Crash Diagnostics")
                        .foregroundStyle(.primary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(12)
            }
        }
    }
    #endif

    // MARK: - About Section

    private var aboutSection: some View {
        SettingsSection(title: "About") {
            SettingsRow(
                icon: "info.circle",
                title: "Version",
                value: "1.0.0"
            ) {}

            SettingsRow(
                icon: "server.rack",
                title: "Server",
                value: viewModel.serverURL
            ) {}
        }
    }

    // MARK: - Admin Section

    private var adminSection: some View {
        SettingsSection(title: "Administration") {
            VStack(spacing: 0) {
                // Server Connection
                VStack(alignment: .leading, spacing: 4) {
                    Text("Server Connection")
                        .font(.caption2)
                        .foregroundStyle(DesignTokens.Color.foreground.opacity(0.6))
                    
                    HStack {
                        Image(systemName: "server.rack")
                            .foregroundStyle(Color.appPrimary)
                            .frame(width: 28)
                            
                        Text(appState.serverURL.isEmpty ? "No Server Connected" : appState.serverURL)
                            .foregroundStyle(DesignTokens.Color.foreground)
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            
                        Spacer()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                
                Button {
                    appState.navigation.showingConnectModal = true
                } label: {
                    HStack {
                        Image(systemName: "network")
                            .foregroundStyle(Color.appPrimary)
                            .frame(width: 28)

                        Text("Manage Server Connection")
                            .foregroundStyle(DesignTokens.Color.foreground)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.Color.foreground.opacity(0.4))
                    }
                    .padding(12)
                }
                
                Divider()
                    .background(Color.white.opacity(0.1))
                
                // Admin Dashboard
                NavigationLink {
                    AdminDashboardView()
                } label: {
                    HStack {
                        Image(systemName: "shield.righthalf.filled")
                            .foregroundStyle(Color.orange)
                            .frame(width: 28)

                        Text("Open Admin Dashboard")
                            .foregroundStyle(DesignTokens.Color.foreground)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.Color.foreground.opacity(0.4))
                    }
                    .padding(12)
                }

                Divider()
                    .background(Color.white.opacity(0.1))

                // Invite Users
                NavigationLink {
                    AdminInviteView()
                } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .foregroundStyle(Color.appPrimary)
                            .frame(width: 28)

                        Text("Invite User by Email")
                            .foregroundStyle(DesignTokens.Color.foreground)
                            .font(.subheadline.weight(.semibold))

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(DesignTokens.Color.foreground.opacity(0.4))
                    }
                    .padding(12)
                }
            }
        }
    }

    // MARK: - Logout Button

    private var logoutButton: some View {
        Button {
            viewModel.logout()
        } label: {
            HStack {
                Spacer()

                Label("Disconnect", systemImage: "rectangle.portrait.and.arrow.right")
                    .font(.headline)
                    .foregroundStyle(.red)

                Spacer()
            }
            .padding(16)
            .background(.red.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.top, 16)
    }
}

// MARK: - ViewModel

@Observable
@MainActor
public class SettingsViewModel {
    public var serverURL = ""

    // Bindings to AppState
    public var jumpForwardTime: Int {
        get { AppState.shared.settings.jumpForwardTime }
        set { 
            var s = AppState.shared.settings
            s.jumpForwardTime = newValue
            AppState.shared.updateSettings(s)
        }
    }

    public var jumpBackwardTime: Int {
        get { AppState.shared.settings.jumpBackwardsTime }
        set { 
            var s = AppState.shared.settings
            s.jumpBackwardsTime = newValue
            AppState.shared.updateSettings(s)
        }
    }

    public var defaultPlaybackSpeed: Double {
        get { AppState.shared.settings.defaultPlaybackSpeed }
        set { 
            var s = AppState.shared.settings
            s.defaultPlaybackSpeed = newValue
            AppState.shared.updateSettings(s)
        }
    }

    public var autoSleepTimer: Bool {
        get { AppState.shared.settings.sleepTimerAutoStart }
        set { 
            var s = AppState.shared.settings
            s.sleepTimerAutoStart = newValue
            AppState.shared.updateSettings(s)
        }
    }

    public var autoResume: Bool {
        get { AppState.shared.settings.autoResume }
        set { 
            var s = AppState.shared.settings
            s.autoResume = newValue
            AppState.shared.updateSettings(s)
        }
    }

    public var smartRewindEnabled: Bool {
        get { AppState.shared.settings.smartRewindEnabled }
        set {
            var s = AppState.shared.settings
            s.smartRewindEnabled = newValue
            AppState.shared.updateSettings(s)
        }
    }

    public var shakeToResetSleepTimer: Bool {
        get { AppState.shared.settings.shakeToResetSleepTimer }
        set {
            var s = AppState.shared.settings
            s.shakeToResetSleepTimer = newValue
            AppState.shared.updateSettings(s)
        }
    }

    public var hapticsEnabled: Bool {
        get { AppState.shared.settings.hapticsEnabled }
        set { 
            var s = AppState.shared.settings
            s.hapticsEnabled = newValue
            AppState.shared.updateSettings(s)
        }
    }

    public var lockOrientation: Bool {
        get { AppState.shared.settings.lockOrientation }
        set { 
            var s = AppState.shared.settings
            s.lockOrientation = newValue
            AppState.shared.updateSettings(s)
        }
    }

    public var crashReportingEnabled: Bool {
        get { AppState.shared.settings.crashReportingEnabled }
        set {
            var s = AppState.shared.settings
            s.crashReportingEnabled = newValue
            AppState.shared.updateSettings(s)
            TelemetryService.shared.isEnabled = newValue
        }
    }

    public var spokenAudioModeEnabled: Bool {
        get { AppState.shared.settings.spokenAudioModeEnabled }
        set { 
            var s = AppState.shared.settings
            s.spokenAudioModeEnabled = newValue
            AppState.shared.updateSettings(s)
            #if os(iOS)
            AudioPlayerService.shared.reconfigureAudioSession()
            #endif
        }
    }

    public var vocalBoostEnabled: Bool {
        get { AppState.shared.settings.vocalBoostEnabled }
        set { 
            var s = AppState.shared.settings
            s.vocalBoostEnabled = newValue
            AppState.shared.updateSettings(s)
            AudioPlayerService.shared.applyAudioDSP()
        }
    }

    public var volumeLevelerEnabled: Bool {
        get { AppState.shared.settings.volumeLevelerEnabled }
        set { 
            var s = AppState.shared.settings
            s.volumeLevelerEnabled = newValue
            AppState.shared.updateSettings(s)
            AudioPlayerService.shared.applyAudioDSP()
        }
    }

    public var monoAudioEnabled: Bool {
        get { AppState.shared.settings.monoAudioEnabled }
        set { 
            var s = AppState.shared.settings
            s.monoAudioEnabled = newValue
            AppState.shared.updateSettings(s)
        }
    }

    public var highResAudioEnabled: Bool {
        get { AppState.shared.settings.highResAudioEnabled }
        set { 
            var s = AppState.shared.settings
            s.highResAudioEnabled = newValue
            AppState.shared.updateSettings(s)
            #if os(iOS)
            AudioPlayerService.shared.reconfigureAudioSession()
            #endif
            AudioPlayerService.shared.applyAudioDSP()
        }
    }

    public var lowCutFilterEnabled: Bool {
        get { AppState.shared.settings.lowCutFilterEnabled }
        set { 
            var s = AppState.shared.settings
            s.lowCutFilterEnabled = newValue
            AppState.shared.updateSettings(s)
            AudioPlayerService.shared.applyAudioDSP()
        }
    }

    public var deEsserEnabled: Bool {
        get { AppState.shared.settings.deEsserEnabled }
        set { 
            var s = AppState.shared.settings
            s.deEsserEnabled = newValue
            AppState.shared.updateSettings(s)
            AudioPlayerService.shared.applyAudioDSP()
        }
    }

    public var binauralReverbEnabled: Bool {
        get { AppState.shared.settings.binauralReverbEnabled }
        set {
            var s = AppState.shared.settings
            s.binauralReverbEnabled = newValue
            AppState.shared.updateSettings(s)
            AudioPlayerService.shared.applyAudioDSP()
        }
    }

    public var selectedTheme: String {
        get { 
            switch AppState.shared.settings.theme {
            case .dark: return "Dark"
            case .light: return "Light"
            case .system: return "System"
            }
        }
        set { 
            var s = AppState.shared.settings
            switch newValue {
            case "Dark": s.theme = .dark
            case "Light": s.theme = .light
            default: s.theme = .system
            }
            AppState.shared.updateSettings(s)
        }
    }

    public var streamingPolicy: StreamingPolicy = .always
    public var downloadPolicy: DownloadPolicy = .wifiOnly

    public var libraryStats: LibraryStats?
    public var userStats: UserStatsData?
    public var isLoadingStats: Bool = false

    public func loadStats(libraryId: String?) async {
        guard let libraryId = libraryId else { return }
        isLoadingStats = true
        do {
            async let fetchLibraryStats = AudiobookphileAPI.shared.getLibraryStats(libraryId: libraryId)
            async let fetchUserStats = AudiobookphileAPI.shared.getUserStats()
            let (lStats, uStats) = try await (fetchLibraryStats, fetchUserStats)
            self.libraryStats = lStats
            self.userStats = uStats
        } catch {
            print("[SettingsViewModel] Error loading backend stats: \(error)")
        }
        isLoadingStats = false
    }

    public func saveJumpForwardTime(_ val: Int) {
        self.jumpForwardTime = val
    }

    public func saveJumpBackwardTime(_ val: Int) {
        self.jumpBackwardTime = val
    }

    public func saveDefaultPlaybackSpeed(_ val: Double) {
        self.defaultPlaybackSpeed = val
    }

    public func saveTheme(_ val: String) {
        self.selectedTheme = val
    }

    public func logout() {
        AppState.shared.logout()
    }
}

// MARK: - Supporting Views

public struct SettingsSection<Content: View>: View {
    public var title: String?
    @ViewBuilder public let content: Content

    public init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = title {
                Text(title.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
            }

            VStack(spacing: 0) {
                content
            }
            .padding(4)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.primary.opacity(0.25), Color.primary.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
        }
    }
}

public struct SettingsRow: View {
    public let icon: String
    public let title: String
    public let value: String
    public let action: () -> Void

    public init(icon: String, title: String, value: String, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.value = value
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(Color.appPrimary)
                    .frame(width: 28)

                Text(title)
                    .foregroundStyle(.primary)

                Spacer()

                Text(value)
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
    }
}

public struct SettingsToggleRow: View {
    public let icon: String
    public let title: String
    @Binding public var isOn: Bool

    public init(icon: String, title: String, isOn: Binding<Bool>) {
        self.icon = icon
        self.title = title
        self._isOn = isOn
    }

    public var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.appPrimary)
                .frame(width: 28)

            Text(title)
                .foregroundStyle(.primary)

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
                .tint(DesignTokens.Color.accent)
        }
        .padding(12)
    }
}
