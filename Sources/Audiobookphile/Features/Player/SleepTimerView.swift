import SwiftUI

public struct SleepTimerView: View {
    @Environment(\.dismiss) var dismiss
    @State private var customMinutes: Int = 20

    public let onSetTimer: (TimeInterval?) -> Void
    public let onSetEndOfChapter: () -> Void
    public var onSetEndOfTrack: (() -> Void)? = nil

    public init(
        onSetTimer: @escaping (TimeInterval?) -> Void,
        onSetEndOfChapter: @escaping () -> Void,
        onSetEndOfTrack: (() -> Void)? = nil
    ) {
        self.onSetTimer = onSetTimer
        self.onSetEndOfChapter = onSetEndOfChapter
        self.onSetEndOfTrack = onSetEndOfTrack
    }

    private var isTimerActive: Bool {
        AudioPlayerService.shared.isSleepTimerActive
    }

    private var activeRemainingText: String {
        AudioPlayerService.shared.sleepTimer.format()
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                FluidAuraBackground()

                List {
                    // Active Timer Hero Card
                    if isTimerActive {
                        Section {
                            VStack(spacing: 12) {
                                HStack {
                                    Image(systemName: "moon.zzz.fill")
                                        .font(.title2)
                                        .foregroundStyle(Color.accentColor)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Active Sleep Timer")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(activeRemainingText.isEmpty ? "Counting down..." : activeRemainingText)
                                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                                            .foregroundStyle(DesignTokens.Color.foreground)
                                    }
                                    Spacer()
                                    Button {
                                        onSetTimer(nil)
                                        dismiss()
                                    } label: {
                                        Text("Turn Off")
                                            .font(.caption.bold())
                                            .foregroundStyle(.red)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Color.red.opacity(0.12))
                                            .clipShape(Capsule())
                                    }
                                }

                                HStack(spacing: 10) {
                                    Button {
                                        AudioPlayerService.shared.extendSleepTimer(by: 5 * 60)
                                    } label: {
                                        Label("+5 Min", systemImage: "plus.circle.fill")
                                            .font(.caption.bold())
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(Color.accentColor)

                                    Button {
                                        AudioPlayerService.shared.extendSleepTimer(by: 15 * 60)
                                    } label: {
                                        Label("+15 Min", systemImage: "plus.circle.fill")
                                            .font(.caption.bold())
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(Color.accentColor)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    // Preset Durations
                    Section("Preset Durations") {
                        ForEach([5, 10, 15, 30, 45, 60, 90], id: \.self) { minutes in
                            Button {
                                onSetTimer(TimeInterval(minutes * 60))
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "clock.fill")
                                        .foregroundStyle(Color.appPrimary)
                                        .font(.body)
                                    Text("\(minutes) Minutes")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                            }
                        }
                    }

                    // Custom Minutes
                    Section("Custom Duration") {
                        Stepper(value: $customMinutes, in: 1...180, step: 5) {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundStyle(Color.accentColor)
                                Text("\(customMinutes) Minutes")
                                    .fontWeight(.medium)
                            }
                        }

                        Button {
                            onSetTimer(TimeInterval(customMinutes * 60))
                            dismiss()
                        } label: {
                            HStack {
                                Spacer()
                                Text("Set \(customMinutes) Minute Timer")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color.accentColor)
                                Spacer()
                            }
                        }
                    }

                    // Contextual Triggers
                    Section("Smart Triggers") {
                        Button {
                            onSetEndOfChapter()
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "moon.stars.fill")
                                    .foregroundStyle(.indigo)
                                    .font(.body)
                                Text("End of Chapter")
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                        }

                        if let onSetEndOfTrack = onSetEndOfTrack {
                            Button {
                                onSetEndOfTrack()
                                dismiss()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "forward.end.alt.fill")
                                        .foregroundStyle(.purple)
                                        .font(.body)
                                    Text("End of Track")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                            }
                        }
                    }

                    // Sleep Experience & Nightstand
                    Section("Nightstand & Ambiance") {
                        Toggle(isOn: Binding(
                            get: { AppState.shared.settings.sleepTimerChimeEnabled },
                            set: {
                                AppState.shared.settings.sleepTimerChimeEnabled = $0
                                AudioPlayerService.shared.sleepTimer.chimeEnabled = $0
                            }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Chime Before Sleep")
                                    .font(.subheadline)
                                Text("Gently plays a soft chime 15s before timeout to prompt shake-to-extend.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Toggle(isOn: Binding(
                            get: { AppState.shared.settings.sleepTimerDimScreenEnabled },
                            set: { AppState.shared.settings.sleepTimerDimScreenEnabled = $0 }
                        )) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("OLED Night Dimming")
                                    .font(.subheadline)
                                Text("Dims player display to serene black while timer is running.")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Shake Gestures Footer Tip
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "iphone.radiowaves.left.and.right")
                                .foregroundStyle(Color.accentColor)
                            Text("Shake your phone anytime during playback to reset or extend the timer without looking at the screen.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .scrollContentBackground(.hidden)
                .navigationTitle("Sleep Timer")
                #if os(iOS) || SKIP
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                }
                .applyToolbarAdapters(isLight: false, isHidden: false)
            }
        }
    }
}
