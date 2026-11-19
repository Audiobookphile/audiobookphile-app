//
//  DesignTokens.swift
//  Audiobookphile
//
//  Cross-platform design tokens shared across the Audiobookphile ecosystem.
//  Enforces the Apple Human Interface Liquid Glass aesthetic.
//

import SwiftUI
#if !SKIP && os(iOS)
import UIKit
#endif

/// Cross-platform design tokens shared with the web app (Tailwind theme).
public enum DesignTokens {
    /// Core semantic colors (web: `tokens.generated.css` `--design-*`).
    public enum Color {
        public static let background = SwiftUI.Color(red: 0.215686, green: 0.219608, blue: 0.219608)
        public static let surface = SwiftUI.Color(red: 0.137255, green: 0.137255, blue: 0.137255)
        public static let surfaceHover = SwiftUI.Color(red: 0.176471, green: 0.176471, blue: 0.176471)
        public static let foreground = SwiftUI.Color(red: 0.929412, green: 0.929412, blue: 0.929412)
        public static let foregroundMuted = SwiftUI.Color(red: 0.819608, green: 0.835294, blue: 0.862745)
        public static let foregroundSubdued = SwiftUI.Color(red: 0.733333, green: 0.733333, blue: 0.733333)
        public static let border = SwiftUI.Color(red: 0.266667, green: 0.266667, blue: 0.266667)
        public static let glassBg = SwiftUI.Color(red: 0.137255, green: 0.137255, blue: 0.137255, opacity: 0.75)
        public static let accent = SwiftUI.Color(red: 0.976471, green: 0.450980, blue: 0.086275)
        public static let accentSecondary = SwiftUI.Color(red: 0.909804, green: 0.364706, blue: 0.047059)
        public static let accentHighlight = SwiftUI.Color(red: 0.980392, green: 0.549020, blue: 0.149020)
        public static let success = SwiftUI.Color(red: 0.298039, green: 0.686275, blue: 0.313725)
        public static let warning = SwiftUI.Color(red: 0.984314, green: 0.549020, blue: 0.000000)
        public static let error = SwiftUI.Color(red: 1.000000, green: 0.321569, blue: 0.321569)
        public static let info = SwiftUI.Color(red: 0.129412, green: 0.588235, blue: 0.952941)
    }

    /// Spacing scale in points/pixels, mirroring the web spacing scale.
    public enum Spacing {
        public static let step0: CGFloat = 4
        public static let step1: CGFloat = 8
        public static let step2: CGFloat = 12
        public static let step3: CGFloat = 16
        public static let step4: CGFloat = 24
        public static let step5: CGFloat = 32
        public static let step6: CGFloat = 48
    }

    /// Corner radius scale in points/pixels.
    public enum Radius {
        public static let step0: CGFloat = 8
        public static let step1: CGFloat = 12
        public static let step2: CGFloat = 16
        public static let step3: CGFloat = 24
        public static let full: CGFloat = 999
    }

    /// Animation duration scale in seconds.
    public enum Duration {
        public static let fast: Double = 0.15
        public static let normal: Double = 0.3
        public static let slow: Double = 0.5
    }

    /// ProMotion 120Hz Spring Animation curves for Apple-grade tactile fluidity.
    public enum Spring {
        /// Snappy response for buttons, toggles, chips and quick interactions.
        public static let snappy: Animation = .spring(response: 0.25, dampingFraction: 0.65)
        /// Fluid easing for card expansions, view transitions, and sheet presentations.
        public static let fluid: Animation = .spring(response: 0.38, dampingFraction: 0.78)
        /// Bouncy physical spring for celebrations, badges, and milestone alerts.
        public static let bouncy: Animation = .interpolatingSpring(stiffness: 300, damping: 20)
        /// Gentle organic loop for ambient orbs and background gradients.
        public static let ambient: Animation = .easeInOut(duration: 8.0)
    }

    /// Liquid Glass optical refraction, specular highlights, and borders.
    public enum Glass {
        /// Top-left specular rim catch simulating optical light reflection.
        public static let specularGradient = LinearGradient(
            colors: [
                SwiftUI.Color.white.opacity(0.35),
                SwiftUI.Color.white.opacity(0.08),
                SwiftUI.Color.white.opacity(0.0)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Subtle rim stroke for glass cards and pills.
        public static let borderGradient = LinearGradient(
            colors: [
                SwiftUI.Color.white.opacity(0.25),
                SwiftUI.Color.white.opacity(0.06),
                SwiftUI.Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )

        /// Accent tinted specular gradient for active buttons and highlighted badges.
        public static func accentSpecular(color: SwiftUI.Color = Color.accent) -> LinearGradient {
            LinearGradient(
                colors: [
                    color.opacity(0.50),
                    color.opacity(0.15),
                    SwiftUI.Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    /// Spatial Elevation and layered shadow depth system.
    public enum Elevation {
        public static let subtle = ShadowToken(radius: 6, y: 2, opacity: 0.15)
        public static let card = ShadowToken(radius: 12, y: 5, opacity: 0.25)
        public static let floating = ShadowToken(radius: 20, y: 8, opacity: 0.35)
        public static let modal = ShadowToken(radius: 32, y: 14, opacity: 0.50)

        public struct ShadowToken: Sendable {
            public let radius: CGFloat
            public let y: CGFloat
            public let opacity: Double
        }
    }

    /// Centralized cross-platform tactile haptic feedback.
    public enum Haptics {
        public static func selection() {
            #if !SKIP && os(iOS)
            UISelectionFeedbackGenerator().selectionChanged()
            #endif
        }

        public static func light() {
            #if !SKIP && os(iOS)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        }

        public static func medium() {
            #if !SKIP && os(iOS)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
        }

        public static func success() {
            #if !SKIP && os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            #endif
        }

        public static func warning() {
            #if !SKIP && os(iOS)
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            #endif
        }
    }

    /// Text size scale in points (iOS dynamic type overrides when applied).
    public enum Typography {
        public static let xs: CGFloat = 12
        public static let sm: CGFloat = 14
        public static let base: CGFloat = 16
        public static let lg: CGFloat = 18
        public static let xl: CGFloat = 20
        public static let size2xl: CGFloat = 24
        public static let size3xl: CGFloat = 32
        public static let size4xl: CGFloat = 40
    }
}
