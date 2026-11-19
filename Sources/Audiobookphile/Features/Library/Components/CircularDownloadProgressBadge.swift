import SwiftUI

// MARK: - Circular Download Progress Badge Component (Apple Podcasts & Spotify Style)
public struct CircularDownloadProgressBadge: View {
    public let progress: Double
    public let status: DownloadStatus?
    public var onTap: (() -> Void)?

    public init(progress: Double = 0, status: DownloadStatus? = nil, onTap: (() -> Void)? = nil) {
        self.progress = progress
        self.status = status
        self.onTap = onTap
    }

    public var body: some View {
        Group {
            if let onTap = onTap {
                Button(action: {
                    DesignTokens.Haptics.light()
                    onTap()
                }) {
                    badgeContent
                }
                .buttonStyle(.plain)
            } else {
                badgeContent
            }
        }
    }

    @ViewBuilder
    private var badgeContent: some View {
        ZStack {
            if let status = status {
                switch status {
                case .pending:
                    ZStack {
                        Circle()
                            .stroke(DesignTokens.Color.warning.opacity(0.25), lineWidth: 2.5)
                        Circle()
                            .trim(from: 0, to: 0.35)
                            .stroke(DesignTokens.Color.warning, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .applyConnectPulseEffect(isAnimating: true)
                        Image(systemName: "arrow.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(DesignTokens.Color.warning)
                    }
                    .frame(width: 26, height: 26)
                    .padding(3)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: DesignTokens.Color.warning.opacity(0.4), radius: 6, x: 0, y: 2)

                case .downloading:
                    ZStack {
                        // Background track
                        Circle()
                            .stroke(DesignTokens.Color.foreground.opacity(0.15), lineWidth: 2.5)

                        // Progress Arc Fill (Apple Podcasts / Spotify style)
                        Circle()
                            .trim(from: 0, to: max(0.06, CGFloat(progress)))
                            .stroke(
                                LinearGradient(colors: [.appSecondary, .appPrimary], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: progress)

                        // Center Stop Square (Apple Podcasts native download stop control)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(DesignTokens.Color.accentSecondary)
                            .frame(width: 7, height: 7)
                    }
                    .frame(width: 26, height: 26)
                    .padding(3)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: DesignTokens.Color.accentSecondary.opacity(0.5), radius: 8, x: 0, y: 2)

                case .paused:
                    ZStack {
                        Circle()
                            .stroke(Color.yellow.opacity(0.4), lineWidth: 2.5)
                        Image(systemName: "play.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.yellow)
                            .offset(x: 0.5)
                    }
                    .frame(width: 26, height: 26)
                    .padding(3)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .yellow.opacity(0.5), radius: 6, x: 0, y: 2)

                case .completed:
                    completedBadge

                case .failed:
                    ZStack {
                        Circle()
                            .fill(Color.red)
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(DesignTokens.Color.foreground)
                    }
                    .frame(width: 26, height: 26)
                    .padding(3)
                    .background(.ultraThinMaterial, in: Circle())
                    .shadow(color: .red.opacity(0.5), radius: 6, x: 0, y: 2)
                }
            } else {
                completedBadge
            }
        }
    }

    private var completedBadge: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(colors: [DesignTokens.Color.success, DesignTokens.Color.success], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(DesignTokens.Color.foreground)
        }
        .frame(width: 22, height: 22)
        .padding(3)
        .background(.ultraThinMaterial, in: Circle())
        .shadow(color: DesignTokens.Color.success.opacity(0.5), radius: 6, x: 0, y: 2)
    }
}
