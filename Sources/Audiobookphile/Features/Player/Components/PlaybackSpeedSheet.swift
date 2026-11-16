//
//  PlaybackSpeedSheet.swift
//  Audiobookphile
//
//  Liquid Glass fine-grained playback speed controller with presets, steppers, and per-book memory.
//  Compatible with Swift 6.3 and Skip.
//

import SwiftUI

public struct PlaybackSpeedSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    public let viewModel: AudioPlayerViewModel

    @State private var currentRate: Double = 1.0

    private let presets: [Double] = [0.75, 0.85, 1.0, 1.15, 1.25, 1.5, 1.75, 2.0, 2.5, 3.0]

    public init(viewModel: AudioPlayerViewModel) {
        self.viewModel = viewModel
        self._currentRate = State(initialValue: Double(viewModel.playbackRate))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                FluidAuraBackground()

                ScrollView {
                    VStack(spacing: 24) {
                        // Hero Speed Card
                        heroSpeedCard

                        // Fine-tuning Stepper Row
                        stepperControlsRow

                        // Slider Card
                        sliderCard

                        // Speed Presets Grid
                        presetsGrid

                        // Per-Book Setting Card
                        perBookSettingCard

                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
            .navigationTitle("Playback Speed")
            #if os(iOS) || SKIP
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .applyToolbarAdapters(isLight: false, isHidden: false)
            .onAppear {
                currentRate = Double(viewModel.playbackRate)
            }
        }
    }

    // MARK: - Hero Speed Card

    private var heroSpeedCard: some View {
        VStack(spacing: 8) {
            Text(String(format: "%.2f×", currentRate))
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .tracking(1)

            Text(speedDescription)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(DesignTokens.Color.foreground.opacity(0.75))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .glassCard(cornerRadius: 20)
    }

    private var speedDescription: String {
        if abs(currentRate - 1.0) < 0.02 {
            return "Normal Speed (1.00×)"
        } else if currentRate > 1.0 {
            let pct = Int(round((currentRate - 1.0) * 100))
            return "\(pct)% Faster than standard"
        } else {
            let pct = Int(round((1.0 - currentRate) * 100))
            return "\(pct)% Slower than standard"
        }
    }

    // MARK: - Stepper Row

    private var stepperControlsRow: some View {
        HStack(spacing: 12) {
            Button {
                updateRate(max(0.5, currentRate - 0.05))
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "minus")
                        .font(.caption.weight(.bold))
                    Text("0.05×")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .glassCard(cornerRadius: 12)

            Button {
                updateRate(1.0)
            } label: {
                Text("1.0× Reset")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(abs(currentRate - 1.0) < 0.02 ? Color.accentColor : DesignTokens.Color.foreground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .glassCard(cornerRadius: 12)

            Button {
                updateRate(min(3.5, currentRate + 0.05))
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.caption.weight(.bold))
                    Text("0.05×")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .glassCard(cornerRadius: 12)
        }
    }

    // MARK: - Slider Card

    private var sliderCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("0.5×")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("FINE ADJUSTMENT")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("3.5×")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Slider(
                value: Binding(
                    get: { currentRate },
                    set: { newRate in
                        let rounded = round(newRate * 20) / 20.0
                        updateRate(rounded)
                    }
                ),
                in: 0.5...3.5,
                step: 0.05
            )
            .tint(Color.accentColor)
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Presets Grid

    private var presetsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PRESETS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(presets, id: \.self) { rate in
                    let isSelected = abs(currentRate - rate) < 0.02
                    Button {
                        updateRate(rate)
                    } label: {
                        Text(String(format: "%.2g×", rate))
                            .font(.system(size: 13, weight: isSelected ? .bold : .semibold, design: .monospaced))
                            .foregroundStyle(isSelected ? Color.white : DesignTokens.Color.foreground)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(isSelected ? Color.accentColor : Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(isSelected ? Color.accentColor : Color.white.opacity(0.12), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    // MARK: - Per-Book Setting Card

    private var perBookSettingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: Binding(
                get: { appState.settings.perBookPlaybackSpeedEnabled },
                set: { appState.settings.perBookPlaybackSpeedEnabled = $0 }
            )) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Remember Speed for This Book")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(DesignTokens.Color.foreground)
                    Text("Automatically restores this playback rate whenever you resume this title.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .tint(Color.accentColor)
        }
        .padding(16)
        .glassCard(cornerRadius: 16)
    }

    private func updateRate(_ rate: Double) {
        currentRate = rate
        viewModel.setPlaybackRate(Float(rate))
    }
}
