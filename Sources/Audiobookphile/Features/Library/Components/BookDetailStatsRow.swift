import SwiftUI

public struct BookDetailStatsRow: View {
    public let detailed: Book
    public let viewModel: BookDetailViewModel
    public var onSeriesTap: ((String) -> Void)?

    public init(detailed: Book, viewModel: BookDetailViewModel, onSeriesTap: ((String) -> Void)? = nil) {
        self.detailed = detailed
        self.viewModel = viewModel
        self.onSeriesTap = onSeriesTap
    }

    public var body: some View {
        HStack(spacing: 10) {
            statBadge(icon: "clock.fill", value: viewModel.formatDuration(detailed.duration), label: "Duration")
            if let year = detailed.media.metadata.publishedYear, !year.isEmpty {
                statBadge(icon: "calendar", value: year, label: "Published")
            }
            if !detailed.chapters.isEmpty {
                statBadge(icon: "list.bullet", value: "\(detailed.chapters.count)", label: "Chapters")
            }
            if let series = detailed.seriesName, !series.isEmpty {
                Button {
                    onSeriesTap?(series)
                } label: {
                    statBadge(icon: "books.vertical.fill", value: series, label: "Series")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View series \(series)")
            }
        }
    }

    private func statBadge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DesignTokens.Color.foreground)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(label.uppercased())
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(DesignTokens.Color.foreground.opacity(0.55))
                .tracking(0.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 6)
        .glassCard(cornerRadius: 14)
    }
}
