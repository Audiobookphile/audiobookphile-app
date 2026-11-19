//
//  GlassCard.swift
//  Audiobookphile
//
//  Liquid Glass card component with blur effects and optical specular translucency
//

import SwiftUI

/// Preset styles for Liquid Glass containers conforming to Apple Human Interface specs.
public enum GlassStyle: Sendable {
    case standard
    case elevated
    case subtle
    case accent(Color)
}

/// Liquid Glass card container with customizable blur, optical specular highlight, and styling.
public struct GlassCard<Content: View>: View {
    let content: Content
    var style: GlassStyle = .standard
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = DesignTokens.Radius.step2
    var material: Material = .ultraThinMaterial

    public init(
        style: GlassStyle = .standard,
        padding: CGFloat = 16,
        cornerRadius: CGFloat = DesignTokens.Radius.step2,
        material: Material = .ultraThinMaterial,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.style = style
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.material = material
    }

    public var body: some View {
        content
            .padding(padding)
            .background {
                ZStack {
                    // Frosted physical material
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(material)

                    // Optional dynamic aura tint
                    if case .accent(let color) = style {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(color.opacity(0.12))
                    }

                    // Optical specular rim highlight
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(strokeGradient, lineWidth: 1)
                }
                .shadow(
                    color: shadowColor,
                    radius: shadowRadius,
                    x: 0,
                    y: shadowY
                )
            }
    }

    private var strokeGradient: LinearGradient {
        switch style {
        case .accent(let color):
            return DesignTokens.Glass.accentSpecular(color: color)
        case .elevated:
            return DesignTokens.Glass.specularGradient
        case .standard, .subtle:
            return DesignTokens.Glass.borderGradient
        }
    }

    private var shadowColor: Color {
        switch style {
        case .accent(let color):
            return color.opacity(0.35)
        case .elevated:
            return DesignTokens.Color.background.opacity(DesignTokens.Elevation.floating.opacity)
        case .standard:
            return DesignTokens.Color.background.opacity(DesignTokens.Elevation.card.opacity)
        case .subtle:
            return DesignTokens.Color.background.opacity(DesignTokens.Elevation.subtle.opacity)
        }
    }

    private var shadowRadius: CGFloat {
        switch style {
        case .accent: return 14
        case .elevated: return DesignTokens.Elevation.floating.radius
        case .standard: return DesignTokens.Elevation.card.radius
        case .subtle: return DesignTokens.Elevation.subtle.radius
        }
    }

    private var shadowY: CGFloat {
        switch style {
        case .accent: return 6
        case .elevated: return DesignTokens.Elevation.floating.y
        case .standard: return DesignTokens.Elevation.card.y
        case .subtle: return DesignTokens.Elevation.subtle.y
        }
    }
}

/// Convenience modifiers to apply liquid glass styling
extension View {
    public func glassCard(
        style: GlassStyle = .standard,
        padding: CGFloat = 16,
        cornerRadius: CGFloat = DesignTokens.Radius.step2,
        material: Material = .ultraThinMaterial
    ) -> some View {
        self.modifier(GlassCardModifier(
            style: style,
            padding: padding,
            cornerRadius: cornerRadius,
            material: material
        ))
    }
}

public struct GlassCardModifier: ViewModifier {
    let style: GlassStyle
    let padding: CGFloat
    let cornerRadius: CGFloat
    let material: Material

    public func body(content: Content) -> some View {
        GlassCard(
            style: style,
            padding: padding,
            cornerRadius: cornerRadius,
            material: material
        ) {
            content
        }
    }
}

/*
 // MARK: - Preview
 #Preview("Glass Card Examples") {
     ZStack {
         // Background gradient
         LinearGradient(
             colors: [.appPrimary, .appAccent],
             startPoint: .topLeading,
             endPoint: .bottomTrailing
         )
         .ignoresSafeArea()
         
         VStack(spacing: 20) {
             // Basic glass card
             GlassCard {
                 VStack(alignment: .leading, spacing: 8) {
                     Text("The Midnight Library")
                         .font(.headline)
                     Text("Matt Haig")
                         .font(.subheadline)
                         .foregroundStyle(DesignTokens.Color.foregroundSubdued)
                 }
             }
             
             // Custom glass card
             GlassCard(
                 padding: 24,
                 cornerRadius: 24,
                 material: .thinMaterial
             ) {
                 HStack {
                     Image(systemName: "book.fill")
                         .font(.largeTitle)
                     VStack(alignment: .leading) {
                         Text("Audiobook")
                             .font(.caption)
                             .foregroundStyle(DesignTokens.Color.foregroundSubdued)
                         Text("8h 32m")
                             .font(.headline)
                     }
                 }
             }
             
             // Using modifier
             Text("View with glass modifier")
                 .glassCard()
         }
         .padding()
     }
 }
 */
