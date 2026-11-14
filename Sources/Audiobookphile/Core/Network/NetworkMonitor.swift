//
//  NetworkMonitor.swift
//  Audiobookphile
//
//  Monitor network connectivity and metering (WiFi vs Cellular), compatible with Swift 6.3 and Skip.
//

import Foundation
#if !SKIP && !os(Android)
import Network
#endif
import SwiftUI
import Observation

/// Monitors network connectivity and connection type
@Observable
@MainActor
public class NetworkMonitor {
    public static let shared = NetworkMonitor()

    /// Whether the device has any network connection
    public var isConnected = true

    /// Whether the current connection is metered (cellular)
    public var isMetered = false

    /// The current connection type
    public var connectionType: ConnectionType = .unknown

    /// Whether the device has WiFi connectivity
    public var hasWiFi = false

    /// Whether the device has cellular connectivity
    public var hasCellular = false

    #if !SKIP && !os(Android)
    private let monitor = NWPathMonitor()
    #endif
    private let queue = DispatchQueue(label: "NetworkMonitor", qos: .utility)

    public enum ConnectionType: String {
        case wifi = "WiFi"
        case cellular = "Cellular"
        case ethernet = "Ethernet"
        case unknown = "Unknown"
        case none = "No Connection"
    }

    private init() {
        startMonitoring()
    }

    private func startMonitoring() {
        #if !SKIP && !os(Android)
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        monitor.start(queue: queue)
        #endif
    }

    #if !SKIP && !os(Android)
    private func handlePathUpdate(_ path: NWPath) {
        isConnected = path.status == .satisfied
        isMetered = path.isExpensive
        hasWiFi = path.usesInterfaceType(.wifi)
        hasCellular = path.usesInterfaceType(.cellular)

        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else if path.status == .satisfied {
            connectionType = .unknown
        } else {
            connectionType = .none
        }

        print("[NetworkMonitor] Status: \(isConnected ? "Connected" : "Disconnected"), Type: \(connectionType.rawValue), Metered: \(isMetered)")
    }
    #endif

    /// Check if streaming is allowed based on settings
    public func canStream(streamingPolicy: StreamingPolicy) -> Bool {
        switch streamingPolicy {
        case .always:
            return isConnected
        case .wifiOnly:
            return isConnected && !isMetered
        case .never:
            return false
        }
    }

    /// Check if downloading is allowed based on settings
    public func canDownload(downloadPolicy: DownloadPolicy) -> Bool {
        switch downloadPolicy {
        case .always:
            return isConnected
        case .wifiOnly:
            return isConnected && !isMetered
        case .never:
            return false
        }
    }

    deinit {
        #if !SKIP && !os(Android)
        monitor.cancel()
        #endif
    }
}

// MARK: - Settings

public enum StreamingPolicy: String, Codable, CaseIterable, Sendable {
    case always = "ALWAYS"
    case wifiOnly = "WIFI_ONLY"
    case never = "NEVER"

    public var displayName: String {
        switch self {
        case .always: return "Always"
        case .wifiOnly: return "WiFi Only"
        case .never: return "Downloaded Only"
        }
    }
}

public enum DownloadPolicy: String, Codable, CaseIterable, Sendable {
    case always = "ALWAYS"
    case wifiOnly = "WIFI_ONLY"
    case never = "NEVER"

    public var displayName: String {
        switch self {
        case .always: return "Always"
        case .wifiOnly: return "WiFi Only"
        case .never: return "Never"
        }
    }
}

// MARK: - SwiftUI View

public struct NetworkStatusView: View {
    var networkMonitor = NetworkMonitor.shared

    public init() {}

    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)

            Text(networkMonitor.connectionType.rawValue)
                .font(.caption)
                .foregroundStyle(.secondary)

            if networkMonitor.isMetered {
                Text("(Metered)")
                    .font(.caption2)
                    .foregroundStyle(DesignTokens.Color.warning)
            }
        }
    }

    private var statusIcon: String {
        if !networkMonitor.isConnected {
            return "wifi.slash"
        } else if networkMonitor.connectionType == .wifi {
            return "wifi"
        } else if networkMonitor.connectionType == .cellular {
            return "antenna.radiowaves.left.and.right"
        } else {
            return "network"
        }
    }

    private var statusColor: Color {
        if !networkMonitor.isConnected {
            return .red
        } else if networkMonitor.isMetered {
            return DesignTokens.Color.warning
        } else {
            return DesignTokens.Color.success
        }
    }
}
