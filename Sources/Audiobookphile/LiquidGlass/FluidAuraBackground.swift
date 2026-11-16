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
                        .frame(width: width * 0.8, height: width * 0.8)
                        .blur(radius: 80)
                        .offset(x: animate ? width * 0.2 : -width * 0.2,
                                y: animate ? -height * 0.2 : height * 0.2)

                    Circle()
                        .fill(secondaryOrbColor)
                        .frame(width: width * 0.6, height: width * 0.6)
                        .blur(radius: 60)
                        .offset(x: animate ? -width * 0.3 : width * 0.1,
                                y: animate ? height * 0.3 : -height * 0.1)
                }
                .saturation(1.3)
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
}
