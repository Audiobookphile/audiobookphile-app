import SwiftUI

// MARK: - Supporting Components

public struct GlassIconButton: View {
    public let icon: String
    public var fill: Bool = false
    public var size: ButtonSize = .medium
    public var color: Color = DesignTokens.Color.foreground
    public var label: String?
    public let action: () -> Void

    public enum ButtonSize {
        case small, medium, large

        var iconSize: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 19
            case .large: return 26
            }
        }

        var frameSize: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 40
            case .large: return 56
            }
        }
    }

    private var defaultLabel: String {
        if icon.hasPrefix("goforward.") {
            let seconds = icon.replacingOccurrences(of: "goforward.", with: "")
            return "Seek Forward \(seconds) Seconds"
        } else if icon.hasPrefix("gobackward.") {
            let seconds = icon.replacingOccurrences(of: "gobackward.", with: "")
            return "Seek Backward \(seconds) Seconds"
        }

        switch icon {
        case "bookmark", "bookmark.fill": return "Bookmarks"
        case "xmark": return "Close"
        case "ellipsis": return "More options"
        case "moon": return "Sleep Timer"
        case "list.bullet": return "Chapters"
        case "backward.end.fill": return "Previous Chapter"
        case "forward.end.fill": return "Next Chapter"
        case "play.fill": return "Play"
        case "pause.fill": return "Pause"
        default: return "Button"
        }
    }

    public init(icon: String, fill: Bool = false, size: ButtonSize = .medium, color: Color = DesignTokens.Color.foreground, label: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.fill = fill
        self.size = size
        self.color = color
        self.label = label
        self.action = action
    }

    public var body: some View {
        Button {
            #if os(iOS) && !SKIP
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            #endif
            action()
        } label: {
            Image(systemName: icon)
                .font(.system(size: size.iconSize, weight: .semibold))
                .symbolVariant(fill ? .fill : .none)
                .foregroundStyle(color)
                .frame(width: size.frameSize, height: size.frameSize)
                .background {
                    Circle()
                        .fill(Color.white.opacity(0.14))
                        .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                }
                .overlay {
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .ignore)
        // String overload: the Text overload is dropped on some platforms,
        // leaking the raw SF Symbol description ("Go To End") to screen readers.
        .accessibilityLabel(label ?? defaultLabel)
        .accessibilityAddTraits(.isButton)
    }
}

public struct GlassPillButton: View {
    public var icon: String?
    public var text: String
    public var isMonospaced: Bool = false
    public var isActive: Bool = false
    public var activeColor: Color = Color.appPrimary
    public var textColor: Color = DesignTokens.Color.foreground
    public var height: CGFloat = 38
    public var action: () -> Void

    public init(
        icon: String? = nil,
        text: String,
        isMonospaced: Bool = false,
        isActive: Bool = false,
        activeColor: Color = Color.appPrimary,
        textColor: Color = DesignTokens.Color.foreground,
        height: CGFloat = 38,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.text = text
        self.isMonospaced = isMonospaced
        self.isActive = isActive
        self.activeColor = activeColor
        self.textColor = textColor
        self.height = height
        self.action = action
    }

    public var body: some View {
        Button {
            #if os(iOS) && !SKIP
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
            #endif
            action()
        } label: {
            HStack(spacing: 5) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(isActive ? activeColor : textColor)
                }
                Text(text)
                    .font(isMonospaced
                        ? .system(size: 12, weight: .bold, design: .monospaced)
                        : .system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(isActive ? activeColor : textColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(.horizontal, 12)
            .frame(height: height)
            .background(
                isActive
                ? activeColor.opacity(0.18)
                : Color.white.opacity(0.14)
            )
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(
                        LinearGradient(
                            colors: isActive
                                ? [activeColor.opacity(0.6), activeColor.opacity(0.2)]
                                : [.white.opacity(0.4), .white.opacity(0.08)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: isActive ? activeColor.opacity(0.2) : Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(ScaleButtonStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
        .accessibilityAddTraits(.isButton)
    }
}

public struct ScaleButtonStyle: ButtonStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

public struct BookmarksListView: View {
    var viewModel: AudioPlayerViewModel
    @Environment(\.dismiss) var dismiss

    public var body: some View {
        NavigationStack {
            ZStack {
                FluidAuraBackground()

                List {
                    if viewModel.bookmarks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bookmark.slash")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                        Text("No bookmarks yet")
                            .font(.headline)
                        Text("Tap the bookmark icon in the player to save your favorite moments.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(viewModel.bookmarks) { bookmark in
                        Button {
                            viewModel.seek(to: bookmark.timePos)
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "bookmark.fill")
                                    .foregroundStyle(Color.appPrimary)
                                    .font(.body)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bookmark.title ?? "Bookmark")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    if let note = bookmark.note, !note.isEmpty {
                                        Text(note)
                                            .font(.subheadline)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(3)
                                    }
                                    Text(viewModel.formatTime(bookmark.timePos))
                                        .font(.caption.monospaced())
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                Image(systemName: "play.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(Color.appPrimary)
                            }
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            viewModel.deleteBookmark(viewModel.bookmarks[index])
                        }
                    }
                    .listRowBackground(Color.clear)
                }
                }
                .scrollContentBackground(.hidden)
                .navigationTitle("Bookmarks")
                #if os(iOS) || SKIP
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    #if !SKIP
                    if !viewModel.bookmarks.isEmpty {
                        ToolbarItem(placement: .cancellationAction) {
                            ShareLink(
                                item: viewModel.exportBookmarksMarkdown(),
                                subject: Text("Bookmarks Export"),
                                message: Text("Exported Bookmarks & Notes")
                            ) {
                                Label("Export", systemImage: "square.and.arrow.up")
                            }
                        }
                    }
                    #endif
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
