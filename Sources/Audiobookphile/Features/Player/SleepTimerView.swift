import SwiftUI

public struct SleepTimerView: View {
    @Environment(\.dismiss) var dismiss

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

    public var body: some View {
        NavigationStack {
            ZStack {
                FluidAuraBackground()

                List {
                Section {
                    Button {
                        onSetTimer(nil)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .font(.body)
                            Text("Off")
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                }

                Section {
                    Button {
                        onSetTimer(15 * 60)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(Color.appPrimary)
                                .font(.body)
                            Text("15 Minutes")
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }

                    Button {
                        onSetTimer(30 * 60)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(Color.appPrimary)
                                .font(.body)
                            Text("30 Minutes")
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }

                    Button {
                        onSetTimer(60 * 60)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(Color.appPrimary)
                                .font(.body)
                            Text("60 Minutes")
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                    }
                } header: {
                    Text("Time")
                }

                Section {
                    Button {
                        onSetEndOfChapter()
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "moon.zzz.fill")
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
            // iOS 27 Toolbar Styling
            .applyToolbarAdapters(isLight: false, isHidden: false)
            }
        }
    }
}
