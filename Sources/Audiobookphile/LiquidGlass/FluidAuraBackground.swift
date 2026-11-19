//
//  FluidAuraBackground.swift
//  Audiobookphile
//
//  Liquid Glass background component.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

public struct FluidAuraBackground: View {
    public let baseColor: Color?
    public let accentColors: [Color]?
    @Environment(\.colorScheme) var colorScheme
    @State private var animate = false

    public init(baseColor: Color? = nil, accentColors: [Color]? = nil) {
        self.baseColor = baseColor
        self.accentColors = accentColors
    }

    public var body: some View {
        ZStack {
            // Base background based on system theme or custom mood aura color
            (baseColor ?? (colorScheme == .dark ? DesignTokens.Color.background : Color(red: 250/255, green: 249/255, blue: 246/255)))
                .ignoresSafeArea()
            
            // Glowing orbs
            GeometryReader { proxy in
                let width = proxy.size.width
                let height = proxy.size.height
                
                ZStack {
                    Circle()
                        .fill(primaryOrbColor)
                        .frame(width: width * 0.85, height: width * 0.85)
                        .blur(radius: 85)
                        .offset(x: animate ? width * 0.22 : -width * 0.18,
                                y: animate ? -height * 0.18 : height * 0.15)

                    Circle()
                        .fill(secondaryOrbColor)
                        .frame(width: width * 0.7, height: width * 0.7)
                        .blur(radius: 70)
                        .offset(x: animate ? -width * 0.25 : width * 0.15,
                                y: animate ? height * 0.25 : -height * 0.12)

                    Circle()
                        .fill(tertiaryOrbColor)
                        .frame(width: width * 0.55, height: width * 0.55)
                        .blur(radius: 55)
                        .offset(x: animate ? width * 0.08 : -width * 0.12,
                                y: animate ? height * 0.05 : -height * 0.22)
                }
                .saturation(1.35)
            }
            
            // Liquid glass noise or overlay layer
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.1)
                .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }

    private var primaryOrbColor: Color {
        if let primary = accentColors?.first {
            return colorScheme == .dark ? primary.opacity(0.65) : primary.opacity(0.4)
        }
        return colorScheme == .dark ? DesignTokens.Color.accent.opacity(0.6) : Color.appPrimary.opacity(0.4)
    }

    private var secondaryOrbColor: Color {
        if let accents = accentColors, accents.count > 1 {
            return colorScheme == .dark ? accents[1].opacity(0.55) : accents[1].opacity(0.6)
        }
        return colorScheme == .dark ? Color(red: 0.8, green: 0.3, blue: 0.0).opacity(0.5) : Color(red: 1.0, green: 0.8, blue: 0.5).opacity(0.7)
    }

    private var tertiaryOrbColor: Color {
        if let accents = accentColors, accents.count > 2 {
            return colorScheme == .dark ? accents[2].opacity(0.45) : accents[2].opacity(0.35)
        }
        return colorScheme == .dark ? DesignTokens.Color.accentHighlight.opacity(0.35) : Color(red: 1.0, green: 0.9, blue: 0.7).opacity(0.45)
    }
}
