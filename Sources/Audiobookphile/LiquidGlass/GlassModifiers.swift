//
//  GlassModifiers.swift
//  AudiobookphileClient
//
//  SwiftUI view modifiers for liquid glass effects
//

import SwiftUI

// MARK: - Glass Background Modifier
struct GlassBackgroundModifier: ViewModifier {
    let material: Material
    let cornerRadius: CGFloat
    let borderOpacity: Double

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(material)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(borderOpacity),
                                        Color.white.opacity(borderOpacity * 0.4),
                                        Color.white.opacity(0.0)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            }
    }
}

extension View {
    /// Apply a glass background effect
    func glassBackground(
        material: Material = .ultraThinMaterial,
        cornerRadius: CGFloat = 16,
        borderOpacity: Double = 0.2
    ) -> some View {
        self.modifier(GlassBackgroundModifier(
            material: material,
            cornerRadius: cornerRadius,
            borderOpacity: borderOpacity
        ))
    }
}

// MARK: - Liquid Gradient Modifier
struct LiquidGradientModifier: ViewModifier {
    let colors: [Color]
    let startPoint: UnitPoint
    let endPoint: UnitPoint

    func body(content: Content) -> some View {
        content
            .background {
                LinearGradient(
                    colors: colors,
                    startPoint: startPoint,
                    endPoint: endPoint
                )
            }
    }
}

extension View {
    /// Apply a liquid gradient background
    func liquidGradient(
        colors: [Color],
        startPoint: UnitPoint = .topLeading,
        endPoint: UnitPoint = .bottomTrailing
    ) -> some View {
        self.modifier(LiquidGradientModifier(
            colors: colors,
            startPoint: startPoint,
            endPoint: endPoint
        ))
    }
}

// MARK: - Glass Overlay Modifier
struct GlassOverlayModifier: ViewModifier {
    let opacity: Double

    func body(content: Content) -> some View {
        content
            .overlay {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(opacity)
            }
    }
}

extension View {
    /// Apply a glass overlay
    func glassOverlay(opacity: Double = 0.3) -> some View {
        self.modifier(GlassOverlayModifier(opacity: opacity))
    }
}

// MARK: - Animated Glass Effect
struct AnimatedGlassModifier: ViewModifier {
    @State var animateGradient = false
    let colors: [Color]

    func body(content: Content) -> some View {
        content
            .background {
                LinearGradient(
                    colors: colors,
                    startPoint: animateGradient ? .topLeading : .bottomLeading,
                    endPoint: animateGradient ? .bottomTrailing : .topTrailing
                )
                .hueRotation(.degrees(animateGradient ? 30 : 0))
            }
            .overlay {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.3)
            }
            .onAppear {
                withAnimation(
                    .easeInOut(duration: 10.0)
                    .repeatForever(autoreverses: true)
                ) {
                    animateGradient.toggle()
                }
            }
    }
}

extension View {
    /// Apply an animated glass effect
    func animatedGlass(colors: [Color] = [.appPrimary, .appAccent]) -> some View {
        self.modifier(AnimatedGlassModifier(colors: colors))
    }
}

// MARK: - Frosted Glass Effect
struct FrostedGlassModifier: ViewModifier {
    let blur: CGFloat
    let saturation: Double

    func body(content: Content) -> some View {
        content
            .blur(radius: blur)
            .saturation(saturation)
            .overlay {
                Rectangle()
                    .fill(.thinMaterial)
                    .opacity(0.5)
            }
    }
}

extension View {
    /// Apply a frosted glass effect (blurred background)
    func frostedGlass(blur: CGFloat = 20, saturation: Double = 1.8) -> some View {
        self.modifier(FrostedGlassModifier(blur: blur, saturation: saturation))
    }
}

// MARK: - Glass Shadow & Ambient Glow
extension View {
    /// Apply a glass-style shadow
    func glassShadow(
        color: Color = .black,
        opacity: Double = 0.1,
        radius: CGFloat = 10,
        x: CGFloat = 0,
        y: CGFloat = 5
    ) -> some View {
        self.shadow(
            color: color.opacity(opacity),
            radius: radius,
            x: x,
            y: y
        )
    }

    /// Apply an ambient colored glow shadow behind elements
    func ambientGlow(
        color: Color = Color.appPrimary,
        radius: CGFloat = 20,
        opacity: Double = 0.35,
        y: CGFloat = 8
    ) -> some View {
        self.shadow(
            color: color.opacity(opacity),
            radius: radius,
            x: 0,
            y: y
        )
    }
}

// MARK: - Liquid Pressable Touch Feedback
public struct LiquidButtonStyle: ButtonStyle {
    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    #if os(iOS) && !SKIP
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                    #endif
                }
            }
    }
}

extension ButtonStyle where Self == LiquidButtonStyle {
    public static var liquid: LiquidButtonStyle { LiquidButtonStyle() }
}

struct LiquidPressableModifier: ViewModifier {
    @State private var isPressed = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            #if os(iOS) && !SKIP
                            let generator = UIImpactFeedbackGenerator(style: .light)
                            generator.impactOccurred()
                            #endif
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                    }
            )
    }
}

extension View {
    /// Apply tactile spring press scale effect with sensory feedback
    func liquidPressable() -> some View {
        self.modifier(LiquidPressableModifier())
    }
}

// MARK: - Shimmer Effect for Glass
struct ShimmerModifier: ViewModifier {
    @State var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .rotationEffect(.degrees(30))
                    .offset(x: phase * geometry.size.width * 2 - geometry.size.width)
                    .onAppear {
                        withAnimation(
                            .linear(duration: 4.0)
                            .repeatForever(autoreverses: false)
                        ) {
                            phase = 1
                        }
                    }
                }
            }
            .clipped()
    }
}

extension View {
    /// Apply a shimmer effect (loading state)
    func shimmer() -> some View {
        self.modifier(ShimmerModifier())
    }
}

// MARK: - Optical Specular Border & Badges
extension View {
    /// Apply an optical specular highlight border simulating light reflection on beveled glass edges
    public func specularBorder(
        cornerRadius: CGFloat = DesignTokens.Radius.step1,
        lineWidth: CGFloat = 1
    ) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(DesignTokens.Glass.borderGradient, lineWidth: lineWidth)
        )
    }

    /// Apply an Apple-grade Liquid Glass pill for filter chips, tags, and category badges
    public func glassPill(isSelected: Bool = false, tint: Color = Color.appPrimary) -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background {
                if isSelected {
                    Capsule()
                        .fill(tint)
                        .shadow(color: tint.opacity(0.35), radius: 8, x: 0, y: 3)
                } else {
                    Capsule()
                        .fill(DesignTokens.Color.surface.opacity(0.55))
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8)
                        )
                }
            }
    }

    /// Apply a frosted glass badge for item status (e.g., Abridged, Explicit, Track count)
    public func glassBadge(tint: Color? = nil) -> some View {
        self
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill((tint ?? Color.black).opacity(0.75))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
            }
    }
}

/*
// MARK: - Preview
#Preview("Glass Modifiers Demo") {
    ScrollView {
        VStack(spacing: 30) {
            // Glass background
            Text("Glass Background")
                .font(.headline)
                .padding()
                .glassBackground()
            
            // Liquid gradient
            Text("Liquid Gradient")
                .font(.headline)
                .foregroundStyle(DesignTokens.Color.foreground)
                .padding()
                .liquidGradient(colors: [.appPrimary, .appAccent])
                .cornerRadius(12)
            
            // Glass overlay on image
            ZStack {
                DesignTokens.Color.warning
                VStack {
                    Image(systemName: "book.fill")
                        .font(.system(size: 60))
                    Text("Glass Overlay")
                        .font(.headline)
                }
                .foregroundStyle(DesignTokens.Color.foreground)
            }
            .frame(height: 150)
            .glassOverlay(opacity: 0.4)
            .cornerRadius(16)
            
            // Animated glass
            Text("Animated Glass")
                .font(.headline)
                .foregroundStyle(DesignTokens.Color.foreground)
                .padding()
                .frame(maxWidth: .infinity)
                .animatedGlass()
                .cornerRadius(16)
            
            // Glass shadow
            Text("Glass Shadow")
                .font(.headline)
                .padding()
                .background(DesignTokens.Color.background)
                .cornerRadius(12)
                .glassShadow(color: DesignTokens.Color.accent, opacity: 0.3, radius: 20)
            
            // Shimmer effect
            RoundedRectangle(cornerRadius: 12)
                .fill(.gray.opacity(0.3))
                .frame(height: 80)
                .shimmer()
        }
        .padding()
    }
    .background {
        LinearGradient(
            colors: [.appPrimary, .appAccent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}
*/
