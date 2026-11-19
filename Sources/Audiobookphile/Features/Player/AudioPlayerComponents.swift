import SwiftUI

// MARK: - Supporting Components

public struct GlassIconButton: View {
    public let icon: String
    public var fill: Bool = false
    public var size: ButtonSize = .medium
    public var color: Color = DesignTokens.Color.foreground
    public var label: String?
    public let action: () -> Void

    public enum ButtonSize {
        case small, medium, large

        var iconSize: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 19
            case .large: return 26
            }
        }

        var frameSize: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 40
            case .large: return 56
            }
        }
    }

    private var defaultLabel: String {
        if icon.hasPrefix("goforward.") {
            let seconds = icon.replacingOccurrences(of: "goforward.", with: "")
            return "Seek Forward \(seconds) Seconds"
        } else if icon.hasPrefix("gobackward.") {
            let seconds = icon.replacingOccurrences(of: "gobackward.", with: "")
            return "Seek Backward \(seconds) Seconds"
        }

        switch icon {
        case "bookmark", "bookmark.fill": return "Bookmarks"
        case "xmark": return "Close"
        case "ellipsis": return "More options"
        case "moon": return "Sleep Timer"
        case "list.bullet": return "Chapters"
        case "backward.end.fill": return "Previous Chapter"
        case "forward.end.fill": return "Next Chapter"
        case "play.fill": return "Play"
        case "pause.fill": return "Pause"
        default: return "Button"
        }
    }

    public init(icon: String, fill: Bool = false, size: ButtonSize = .medium, color: Color = DesignTokens.Color.foreground, label: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.fill = fill
        self.size = size
        self.color = color
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button {
            DesignTokens.Haptics.light()
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size.iconSize, weight: .semibold))
                .symbolVariant(fill ? .fill : .none)
                .foregroundStyle(color)
                .frame(width: size.frameSize, height: size.frameSize)
                .background {
                    Circle()
                        .fill(Color.white.opacity(0.14))
                        .shadow(color: Color.black.opacity(0.16), radius: 8, x: 0, y: 3)
                }
                .overlay {
                    Circle()
                        .strokeBorder(DesignTokens.Glass.specularGradient, lineWidth: 1)
                }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .ignore)
        // String overload: the Text overload is dropped on some platforms,
        // leaking the raw SF Symbol description ("Go To End") to screen readers.
        .accessibilityLabel(label ?? defaultLabel)
        .accessibilityAddTraits(.isButton)
    }
}

public struct GlassPillButton: View {
    public var icon: String?
    public var text: String
    public var isMonospaced: Bool = false
    public var isActive: Bool = false
    public var activeColor: Color = Color.appPrimary
    public var textColor: Color = DesignTokens.Color.foreground
    public var height: CGFloat = 38
    public var action: () -> Void

    public init(
        icon: String? = nil,
        text: String,
        isMonospaced: Bool = false,
        isActive: Bool = false,
        activeColor: Color = Color.appPrimary,
        textColor: Color = DesignTokens.Color.foreground,
        height: CGFloat = 38,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.text = text
        self.isMonospaced = isMonospaced
        self.isActive = isActive
        self.activeColor = activeColor
        self.textColor = textColor
        self.height = height
        self.action = action
    }

    public var body: some View {
        Button {
            DesignTokens.Haptics.light()
            action()
        } label: {
            HStack(spacing: 5) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isActive ? activeColor : textColor)
                }
                Text(text)
                    .font(isMonospaced
                        ? .system(size: 12, weight: .bold, design: .monospaced)
                        : .system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? activeColor : textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 12)
            .frame(height: height)
            .background(
                isActive
                ? activeColor.opacity(0.22)
                : Color.white.opacity(0.12)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        isActive
                            ? LinearGradient(
                                colors: [activeColor.opacity(0.7), activeColor.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            : DesignTokens.Glass.borderGradient,
                        lineWidth: 1
                    )
            )
            .shadow(color: isActive ? activeColor.opacity(0.25) : Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isButton)
    }
}

public struct ScaleButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1.0)
            .animation(DesignTokens.Spring.snappy, value: configuration.isPressed)
    }
}

