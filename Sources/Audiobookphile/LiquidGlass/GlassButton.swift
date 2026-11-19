//
//  GlassButton.swift
//  Audiobookphile
//
//  Liquid Glass button with gradient, optical specular highlights,
//  120Hz ProMotion spring physics, and tactile haptic feedback.
//

import SwiftUI

// MARK: - Glass Button Style Variant
public enum GlassButtonStyleType {
    case primary
    case glass
    case tinted(Color)
    case destructive

    var foregroundColor: Color {
        switch self {
        case .primary, .destructive:
            return .white
        case .glass:
            return DesignTokens.Color.foreground
        case .tinted(let color):
            return color
        }
    }
}

// MARK: - Glass Button Size
public enum GlassButtonSize {
    case small
    case medium
    case large

    public var textFont: Font {
        switch self {
        case .small: return .subheadline.weight(.semibold)
        case .medium: return .body.weight(.semibold)
        case .large: return .headline.weight(.bold)
        }
    }

    public var iconFont: Font {
        switch self {
        case .small: return .system(size: 14, weight: .semibold)
        case .medium: return .system(size: 17, weight: .semibold)
        case .large: return .system(size: 20, weight: .bold)
        }
    }

    public var minHeight: CGFloat {
        switch self {
        case .small: return 34
        case .medium: return 44 // Apple Human Interface minimum touch target
        case .large: return 54
        }
    }

    public var horizontalPadding: CGFloat {
        switch self {
        case .small: return 14
        case .medium: return 20
        case .large: return 26
        }
    }

    public var verticalPadding: CGFloat {
        switch self {
        case .small: return 7
        case .medium: return 12
        case .large: return 16
        }
    }

    public var cornerRadius: CGFloat {
        switch self {
        case .small: return 10
        case .medium: return 14
        case .large: return 18
        }
    }

    public var isFullWidth: Bool {
        self == .large
    }
}

// MARK: - Glass Button Style (SwiftUI ButtonStyle)
public struct GlassButtonStyle: ButtonStyle {
    public let styleType: GlassButtonStyleType
    public let size: GlassButtonSize
    public var customColors: [Color]?
    public var isDisabled: Bool

    public init(
        styleType: GlassButtonStyleType = .primary,
        size: GlassButtonSize = .medium,
        customColors: [Color]? = nil,
        isDisabled: Bool = false
    ) {
        self.styleType = styleType
        self.size = size
        self.customColors = customColors
        self.isDisabled = isDisabled
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.textFont)
            .foregroundStyle(styleType.foregroundColor)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .frame(minHeight: size.minHeight)
            .frame(maxWidth: size.isFullWidth ? .infinity : nil)
            .background {
                backgroundSurface(isPressed: configuration.isPressed)
            }
            .clipShape(RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: size.cornerRadius, style: .continuous)
                    .strokeBorder(specularBorder(isPressed: configuration.isPressed), lineWidth: 1)
            }
            .shadow(
                color: shadowColor(isPressed: configuration.isPressed),
                radius: configuration.isPressed ? 4 : (size == .large ? 16 : 10),
                x: 0,
                y: configuration.isPressed ? 2 : (size == .large ? 8 : 4)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(isDisabled ? 0.45 : (configuration.isPressed ? 0.9 : 1.0))
            .animation(DesignTokens.Spring.snappy, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && !isDisabled {
                    DesignTokens.Haptics.light()
                }
            }
    }

    @ViewBuilder
    private func backgroundSurface(isPressed: Bool) -> some View {
        switch styleType {
        case .primary:
            let colors = customColors ?? [.appPrimary, .appAccent]
            LinearGradient(
                colors: isDisabled ? [.gray.opacity(0.5), .gray.opacity(0.3)] : colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                Color.white.opacity(isPressed ? 0.15 : 0.08)
            }

        case .glass:
            ZStack {
                Color.white.opacity(isPressed ? 0.16 : 0.10)
                #if os(iOS) || os(macOS)
                Rectangle().fill(.ultraThinMaterial)
                #endif
            }

        case .tinted(let tint):
            ZStack {
                tint.opacity(isPressed ? 0.25 : 0.15)
                #if os(iOS) || os(macOS)
                Rectangle().fill(.ultraThinMaterial)
                #endif
            }

        case .destructive:
            ZStack {
                Color.red.opacity(isPressed ? 0.8 : 0.65)
                LinearGradient(
                    colors: [Color.red, Color.red.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private func specularBorder(isPressed: Bool) -> LinearGradient {
        switch styleType {
        case .primary, .destructive:
            return LinearGradient(
                colors: [
                    Color.white.opacity(isPressed ? 0.4 : 0.6),
                    Color.white.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .glass:
            return DesignTokens.Glass.specularGradient
        case .tinted(let tint):
            return LinearGradient(
                colors: [tint.opacity(0.6), tint.opacity(0.15)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func shadowColor(isPressed: Bool) -> Color {
        if isDisabled { return .clear }
        switch styleType {
        case .primary:
            let primaryColor = customColors?.first ?? Color.appPrimary
            return primaryColor.opacity(isPressed ? 0.25 : 0.45)
        case .glass:
            return Color.black.opacity(isPressed ? 0.1 : 0.2)
        case .tinted(let tint):
            return tint.opacity(isPressed ? 0.2 : 0.35)
        case .destructive:
            return Color.red.opacity(isPressed ? 0.25 : 0.45)
        }
    }
}

// MARK: - GlassButton View Component
public struct GlassButton: View {
    public typealias ButtonSize = GlassButtonSize

    public let title: String
    public let icon: String?
    public let action: () -> Void

    public var style: GlassButtonStyleType = .primary
    public var size: ButtonSize = .medium
    public var colors: [Color] = [.appPrimary, .appAccent]
    public var isLoading: Bool = false
    public var isDisabled: Bool = false

    public init(
        title: String,
        icon: String? = nil,
        action: @escaping () -> Void,
        size: ButtonSize = .medium,
        colors: [Color] = [.appPrimary, .appAccent],
        isLoading: Bool = false,
        isDisabled: Bool = false
    ) {
        self.title = title
        self.icon = icon
        self.action = action
        self.size = size
        self.colors = colors
        self.style = .primary
        self.isLoading = isLoading
        self.isDisabled = isDisabled
    }

    public init(
        _ title: String,
        icon: String? = nil,
        style: GlassButtonStyleType = .primary,
        size: ButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.size = size
        self.colors = [.appPrimary, .appAccent]
        self.action = action
    }

    public init(
        _ title: String,
        icon: String? = nil,
        size: ButtonSize = .medium,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = .primary
        self.size = size
        self.colors = [.appPrimary, .appAccent]
        self.action = action
    }

    public var body: some View {
        Button(action: handleTap) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else if let icon = icon {
                    Image(systemName: icon)
                        .font(size.iconFont)
                }

                Text(title)
                    .lineLimit(1)
            }
        }
        .buttonStyle(
            GlassButtonStyle(
                styleType: style,
                size: size,
                customColors: colors,
                isDisabled: isDisabled || isLoading
            )
        )
        .disabled(isDisabled || isLoading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityAddTraits(.isButton)
    }

    private func handleTap() {
        DesignTokens.Haptics.medium()
        action()
    }
}
