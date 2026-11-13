//
//  ConnectView.swift
//  Audiobookphile
//
//  Server connection view with Liquid Glass design.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Observation
#if os(iOS) && !SKIP
import UIKit
#endif

public struct RecentServer: Codable, Identifiable {
    public let id: String
    public let address: String
    public let username: String?

    public init(id: String = UUID().uuidString, address: String, username: String? = nil) {
        self.id = id
        self.address = address
        self.username = username
    }
}

public struct ConnectView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State var viewModel = ConnectViewModel()
    @State var serverURL = EnvironmentConfig.serverURL
    @State var username = ""
    @State var password = ""
    @State var showPassword = false
    @State var isAnimating = false
    @State var appearPhase = 0
    @State var magicLinkStatus: MagicLinkStatus = .idle
    @FocusState private var focusedField: ConnectField?

    public init() {}

    enum MagicLinkStatus: Equatable {
        case idle
        case sending
        case sent
        case failed(String)
    }

    public var body: some View {
        @Bindable var appState = appState
        return ZStack(alignment: .topTrailing) {
            // Fluid Aura background — the only layers that should bleed under
            // the safe area; the form below must keep its keyboard-avoidance
            // insets or the lower fields get covered instead of scrolled up.
            FluidAuraBackground()
                .ignoresSafeArea()

            // Particle effects
            GlassParticlesView(particleCount: 20, colors: [DesignTokens.Color.foreground.opacity(0.15), .appPrimary.opacity(0.1)])
                .ignoresSafeArea()

            // Dismiss Button for Sheet presentation
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(DesignTokens.Color.foreground.opacity(0.6))
                    .padding(20)
            }
            .accessibilityIdentifier("abp_connect_dismiss")
            .accessibilityLabel("Close")
            .zIndex(100)

            ScrollView {
                VStack(spacing: 32) {
                    // Logo and title
                    headerSection
                        .opacity(appearPhase > 0 ? 1 : 0)
                        .offset(y: appearPhase > 0 ? 0 : 30)

                    // Connection form
                    formSection
                        .opacity(appearPhase > 1 ? 1 : 0)
                        .offset(y: appearPhase > 1 ? 0 : 30)

                    // Recent Servers
                    if !viewModel.recentServers.isEmpty {
                        recentServersSection
                            .opacity(appearPhase > 2 ? 1 : 0)
                            .offset(y: appearPhase > 2 ? 0 : 30)
                    }

                    Spacer(minLength: 100)
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
            }
            .hideKeyboardOnTap()
        }
        .alert("Connection Error", isPresented: $viewModel.showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .sheet(isPresented: $appState.requires2FAChallenge) {
            TwoFactorChallengeView()
        }
        .onAppear {
            if !appState.serverURL.isEmpty {
                serverURL = appState.serverURL
            } else if let saved = UserDefaults.standard.string(forKey: "abp_serverURL"), !saved.isEmpty {
                serverURL = saved
            } else if serverURL.isEmpty {
                serverURL = "https://audiobookphile.app"
            }
            if let u = appState.pendingUsername, !u.isEmpty {
                username = u
            }
            if let p = appState.pendingPassword, !p.isEmpty {
                password = p
            }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                isAnimating = true
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
                appearPhase = 1
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.2)) {
                appearPhase = 2
            }
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.4)) {
                appearPhase = 3
            }
            // Auto login in simulator/debug for rapid testing
            #if targetEnvironment(simulator)
            Task {
                try? await Task.sleep(for: .seconds(1.0))
                if !serverURL.isEmpty && !username.isEmpty && !password.isEmpty && !appState.isAuthenticated {
                    do {
                        try await appState.login(
                            serverURL: serverURL,
                            username: username,
                            password: password
                        )
                        viewModel.saveRecentServer(address: serverURL, username: username)
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                        viewModel.showError = true
                    }
                }
            }
            #endif
        }
        .onChange(of: appState.serverURL) { _, newServer in
            if !newServer.isEmpty {
                serverURL = newServer
            }
            if let u = appState.pendingUsername, !u.isEmpty {
                username = u
            }
            if let p = appState.pendingPassword, !p.isEmpty {
                password = p
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // App icon
            Image("Logo", bundle: .module)
                .resizable()
                .scaledToFit()
                .frame(width: 120, height: 120)
                .scaleEffect(isAnimating ? 1.05 : 1.0)
                .shadow(color: DesignTokens.Color.accent.opacity(0.5), radius: 25, x: 0, y: 10)

            // Title
            Text("Audiobookphile")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(Color.primary)
                .shadow(color: DesignTokens.Color.surface.opacity(0.1), radius: 2, x: 0, y: 1)

            Text("Sign in to your account")
                .font(.headline.weight(.medium))
                .foregroundStyle(Color.secondary)
                .padding(.top, -4)
        }
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: 16) {
            // 1-Click Live Demo Banner
            Button {
                serverURL = "https://audiobookphile.app"
                username = "demo@audiobookphile.app"
                password = "AudiobookphileDemo2026!"

                #if os(iOS) && !SKIP
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                #endif

                Task {
                    do {
                        try await appState.login(
                            serverURL: "https://audiobookphile.app",
                            username: "demo@audiobookphile.app",
                            password: "AudiobookphileDemo2026!"
                        )
                        viewModel.saveRecentServer(address: "https://audiobookphile.app", username: "demo@audiobookphile.app")
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                        viewModel.showError = true
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.orange)
                    Text("🚀 Try Live Demo (1-Click)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.orange.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)

            // Server URL
            GlassTextField(
                text: $serverURL,
                placeholder: "Server URL",
                icon: "server.rack",
                autocapitalize: false,
                identifier: "abp_server_url_field",
                focus: $focusedField,
                field: .server,
                onSubmit: { focusedField = .email }
            )

            // Username / Email
            GlassTextField(
                text: $username,
                placeholder: "Email address",
                icon: "envelope.fill",
                autocapitalize: false,
                identifier: "abp_email_field",
                focus: $focusedField,
                field: .email,
                onSubmit: { focusedField = .password }
            )

            // Password
            GlassSecureField(
                text: $password,
                placeholder: "Password",
                icon: "lock.fill",
                showPassword: $showPassword,
                identifier: "abp_password_field",
                focus: $focusedField,
                field: .password,
                onSubmit: { focusedField = nil }
            )

            // Connect button
            Button {
                #if os(iOS) && !SKIP
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                #endif

                Task {
                    do {
                        let trimmedURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)

                        try await appState.login(
                            serverURL: trimmedURL,
                            username: trimmedUsername,
                            password: password
                        )
                        viewModel.saveRecentServer(address: trimmedURL, username: trimmedUsername)
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                        viewModel.showError = true
                    }
                }
            } label: {
                HStack {
                    if appState.isLoading {
                        ProgressView()
                            .tint(DesignTokens.Color.foreground)
                            .padding(.trailing, 8)
                    }
                    Text(appState.isLoading ? "Signing in..." : "Sign In")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundStyle(DesignTokens.Color.foreground)
                .background(
                    LinearGradient(colors: [.appPrimary, .appSecondary], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isFormValid || appState.isLoading)
            .padding(.top, 8)

            magicLinkSection
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.appPrimary.opacity(0.05))
                .shadow(color: DesignTokens.Color.surface.opacity(0.2), radius: 30, x: 0, y: 15)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .overlay {
            RoundedRectangle(cornerRadius: 24)
                .strokeBorder(
                    LinearGradient(
                        colors: [DesignTokens.Color.foreground.opacity(0.4), DesignTokens.Color.foreground.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }

    // MARK: - Magic Link Section

    private var magicLinkSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .overlay(DesignTokens.Color.surface.opacity(0.2))

            Text("Or sign in with a magic link")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.secondary)

            Button {
                Task { await sendMagicLink() }
            } label: {
                HStack {
                    if magicLinkStatus == .sending {
                        ProgressView().tint(DesignTokens.Color.foreground)
                            .padding(.trailing, 8)
                    }
                    Text("Email me a sign-in link")
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundStyle(DesignTokens.Color.foreground)
                .background(DesignTokens.Color.surface.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(DesignTokens.Color.foreground.opacity(0.25), lineWidth: 1)
                }
            }
            .disabled(magicLinkStatus == .sending || username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("abp_magic_link_send")

            switch magicLinkStatus {
            case .idle:
                Text("We'll email you a link that opens the app and signs you in.")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            case .sending:
                Text("Sending your link...")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            case .sent:
                Text("Magic link sent! Check your email and open the link on this device to sign in.")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Color.success)
            case .failed(let message):
                Text(message)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Color.error)
            }
        }
    }

    private func sendMagicLink() async {
        let trimmedURL = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEmail = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedURL.isEmpty, !trimmedEmail.isEmpty else {
            magicLinkStatus = .failed("Enter your server address and email first.")
            return
        }
        magicLinkStatus = .sending
        do {
            try await AudiobookphileAPI.shared.sendMagicLink(email: trimmedEmail, serverURL: trimmedURL)
            magicLinkStatus = .sent
        } catch {
            magicLinkStatus = .failed(error.localizedDescription)
        }
    }

    private var isFormValid: Bool {
        !serverURL.isEmpty && !username.isEmpty && !password.isEmpty
    }

    // MARK: - Recent Servers Section

    private var recentServersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Connections")
                .font(.headline)
                .foregroundStyle(Color.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 8) {
                ForEach(viewModel.recentServers) { server in
                    RecentServerRow(server: server) {
                        // Action on tap: pre-fill form
                        withAnimation {
                            serverURL = server.address
                            if let user = server.username {
                                username = user
                            }
                            // Clear password when selecting a new server
                            password = ""
                        }
                    }
                }
            }
        }
        .padding(.top, 16)
    }
}

// MARK: - ViewModel

@Observable
@MainActor
class ConnectViewModel {
    var isLoading = false
    var showError = false
    var errorMessage = ""
    var recentServers: [RecentServer] = []

    init() {
        loadRecentServers()
    }

    private func loadRecentServers() {
        if let data = UserDefaults.standard.data(forKey: "abp_recent_servers"),
           let list = try? JSONDecoder().decode([RecentServer].self, from: data) {
            recentServers = list
        }
    }

    func saveRecentServer(address: String, username: String) {
        let server = RecentServer(address: address, username: username)
        var servers = recentServers.filter { $0.address != address }
        servers.insert(server, at: 0)
        recentServers = Array(servers.prefix(5))

        if let data = try? JSONEncoder().encode(recentServers) {
            UserDefaults.standard.set(data, forKey: "abp_recent_servers")
        }
    }
}

// MARK: - Supporting Views

/// Focus targets for the connect form — the return key walks server → email
/// → password and then dismisses, so the keyboard never traps the lower
/// fields behind the prediction bar on small screens.
enum ConnectField: Hashable {
    case server
    case email
    case password
}

/// Applies an optional `@FocusState` binding without forcing every call site
/// to participate in focus handling.
struct ConnectFieldFocus: ViewModifier {
    var focus: FocusState<ConnectField?>.Binding?
    var field: ConnectField?

    func body(content: Content) -> some View {
        if let focus, let field {
            content.focused(focus, equals: field)
        } else {
            content
        }
    }
}

struct GlassTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    var autocapitalize: Bool = true
    var identifier: String? = nil
    var focus: FocusState<ConnectField?>.Binding? = nil
    var field: ConnectField? = nil
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.primary.opacity(0.6))
                .frame(width: 24)
                .accessibilityHidden(true)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(Color.primary)
                .accessibilityIdentifier(identifier ?? "")
                #if os(iOS) || SKIP
                .textInputAutocapitalization(autocapitalize ? .sentences : .none)
                #endif
                .autocorrectionDisabled()
                .modifier(ConnectFieldFocus(focus: focus, field: field))
                .onSubmit { onSubmit?() }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
        }
    }
}

struct GlassSecureField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String
    @Binding var showPassword: Bool
    var identifier: String? = nil
    var focus: FocusState<ConnectField?>.Binding? = nil
    var field: ConnectField? = nil
    var onSubmit: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.primary.opacity(0.6))
                .frame(width: 24)
                .accessibilityHidden(true)

            if showPassword {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.primary)
                    .accessibilityIdentifier(identifier ?? "")
                    #if os(iOS) || SKIP
                    .textInputAutocapitalization(.none)
                    #endif
                    .autocorrectionDisabled()
                    .modifier(ConnectFieldFocus(focus: focus, field: field))
                    .onSubmit { onSubmit?() }
            } else {
                SecureField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Color.primary)
                    .accessibilityIdentifier(identifier ?? "")
                    .modifier(ConnectFieldFocus(focus: focus, field: field))
                    .onSubmit { onSubmit?() }
            }

            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash" : "eye")
                    .foregroundStyle(Color.primary.opacity(0.6))
            }
            .accessibilityLabel(showPassword ? "Hide Password" : "Show Password")
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
        }
    }
}

struct RecentServerRow: View {
    let server: RecentServer
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "server.rack")
                    .foregroundStyle(Color.appPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(server.address)
                        .font(.subheadline)
                        .foregroundStyle(Color.primary)

                    if let username = server.username {
                        Text(username)
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(Color.secondary.opacity(0.4))
            }
            .padding(12)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}
