//
//  AccountView.swift
//  Audiobookphile
//
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
import Observation

public struct AccountView: View {
    @State var viewModel = SettingsViewModel()
    @Environment(\.dismiss) var dismiss
    @Environment(AppState.self) private var appState
    @State private var showingDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var deleteErrorMessage: String?
    @State private var showingDeleteError = false

    public init() {}

    public var body: some View {
        ZStack {
            FluidAuraBackground()

            if let user = appState.currentUser {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 16) {
                            Circle()
                                .fill(LinearGradient(
                                    colors: [.appPrimary, .appSecondary],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .frame(width: 100, height: 100)
                                .overlay {
                                    Text(String(user.username.prefix(1)).uppercased())
                                        .font(.system(size: 40, weight: .bold))
                                        .foregroundStyle(DesignTokens.Color.foreground)
                                }
                                .shadow(color: .appPrimary.opacity(0.3), radius: 20)

                            Text(user.username)
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)

                            Text("Account Type: \(user.type.capitalized)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 40)

                        SettingsSection(title: "Account Details") {
                            SettingsRow(icon: "person.circle", title: "User ID", value: user.id) {}
                            SettingsRow(
                                icon: "server.rack",
                                title: "Server",
                                value: appState.serverURL.isEmpty ? EnvironmentConfig.serverURL : appState.serverURL
                            ) {}
                        }

                        // Navigation to Stats
                        NavigationLink(destination: StatsView()) {
                            HStack {
                                Image(systemName: "chart.bar.fill")
                                    .foregroundStyle(Color.appPrimary)
                                    .frame(width: 28)
                                Text("Listening Stats")
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(12)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Account Actions
                        VStack(spacing: 12) {
                            Button {
                                viewModel.logout()
                                dismiss()
                            } label: {
                                HStack {
                                    Spacer()
                                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                                .padding(16)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }

                            Button(role: .destructive) {
                                showingDeleteConfirmation = true
                            } label: {
                                HStack {
                                    Spacer()
                                    if isDeleting {
                                        ProgressView()
                                            .tint(.red)
                                            .padding(.trailing, 8)
                                    }
                                    Label("Delete Account", systemImage: "trash.fill")
                                        .font(.headline)
                                        .foregroundStyle(.red)
                                    Spacer()
                                }
                                .padding(16)
                                .background(Color.red.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.25), lineWidth: 1)
                                )
                            }
                            .disabled(isDeleting)
                            .accessibilityIdentifier("abp_delete_account_button")
                        }
                        .padding(.top, 24)
                    }
                    .padding(.horizontal, 16)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("Account")
        #if os(iOS) || SKIP
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .confirmationDialog(
            "Delete Account?",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete My Account", role: .destructive) {
                Task {
                    isDeleting = true
                    do {
                        try await appState.deleteAccount()
                        dismiss()
                    } catch {
                        deleteErrorMessage = error.localizedDescription
                        showingDeleteError = true
                        isDeleting = false
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to permanently delete your account? All listening history, bookmarks, and account preferences will be permanently erased. This action cannot be undone.")
        }
        .alert("Error Deleting Account", isPresented: $showingDeleteError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(deleteErrorMessage ?? "An unknown error occurred while deleting your account.")
        }
    }
}
