//
//  ListeningStreakBanner.swift
//  Audiobookphile
//
//  Interactive Liquid Glass daily listening streak banner with milestone celebrations.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI
#if !SKIP && os(iOS)
import UIKit
#endif

public struct ListeningStreakBanner: View {
    public let streak: Int
    public let onTap: () -> Void

    @State private var isPulsing = false
    @State private var showCelebrationEffect = false

    public init(streak: Int, onTap: @escaping () -> Void) {
        self.streak = streak
        self.onTap = onTap
    }

    public var body: some View {
        Button {
            #if !SKIP && os(iOS)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            #endif
            withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
                showCelebrationEffect = true
            }
            onTap()
            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                withAnimation {
                    showCelebrationEffect = false
                }
            }
        } label: {
            HStack(spacing: 14) {
                // Flame Badge with Animated Glow Halo
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.orange.opacity(isPulsing ? 0.45 : 0.2),
                                    Color.red.opacity(0.0)
                                ],
                                center: .center,
                                startRadius: 4,
                                endRadius: 28
                            )
                        )
                        .frame(width: 46, height: 46)
                        .scaleEffect(isPulsing ? 1.15 : 0.95)

                    Image(systemName: "flame.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.yellow, .orange, .red],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .orange.opacity(0.6), radius: 6, x: 0, y: 2)
                        .scaleEffect(showCelebrationEffect ? 1.25 : 1.0)
                }

                // Streak Typography & Milestone
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(ListeningStreakCalculator.milestoneHeadline(streak: streak))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.primary)

                        if streak >= 3 {
                            Text("🔥")
                                .font(.caption)
                        }
                    }

                    Text(ListeningStreakCalculator.motivationalMessage(streak: streak))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Navigation Chevron & Tap Cue
                HStack(spacing: 4) {
                    Text("Stats")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.appPrimary)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.appPrimary.opacity(0.8))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.appPrimary.opacity(0.12))
                .clipShape(Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.orange.opacity(showCelebrationEffect ? 0.6 : 0.3),
                                Color.white.opacity(0.1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: showCelebrationEffect ? 1.5 : 1
                    )
            )
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
        }
    }
}
