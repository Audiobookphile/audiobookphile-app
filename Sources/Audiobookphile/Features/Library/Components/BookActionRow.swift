//
//  BookActionRow.swift
//  Audiobookphile
//

import SwiftUI

public struct BookActionRow: View {
    public let detailed: Book
    @Bindable public var viewModel: BookDetailViewModel
    @Environment(\.dismiss) var dismiss
    public var downloadService = DownloadService.shared

    public init(detailed: Book, viewModel: BookDetailViewModel) {
        self.detailed = detailed
        self.viewModel = viewModel
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Main Play / Continue Button
            Button {
                viewModel.playBook(detailed, dismiss: dismiss)
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isStartingPlayback {
                        ProgressView().tint(DesignTokens.Color.foreground)
                        Text("Starting...")
                            .fontWeight(.bold)
                    } else {
                        Image(systemName: hasProgress(detailed) ? "play.circle.fill" : "play.fill")
                            .font(.title3)
                        Text(hasProgress(detailed) ? "Continue (\(detailed.userMediaProgress?.progressPercentage ?? 0)%)" : "Play")
                            .fontWeight(.bold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundStyle(detailed.isMissing == true || viewModel.isStartingPlayback ? DesignTokens.Color.foreground : DesignTokens.Color.background)
                .background(
                    (detailed.isMissing == true || viewModel.isStartingPlayback) ?
                    LinearGradient(colors: [.gray.opacity(0.3), .gray.opacity(0.2)], startPoint: .leading, endPoint: .trailing) :
                    LinearGradient(colors: [.appPrimary, .appSecondary], startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: (detailed.isMissing == true || viewModel.isStartingPlayback) ? .clear : .appPrimary.opacity(0.3), radius: 10)
            }
            .accessibilityIdentifier("abp_play_book_button")
            .disabled(detailed.isMissing == true || viewModel.isStartingPlayback)

            // Dynamic Download Button
            if detailed.isMissing == true {
                Button {
                    // Disabled
                } label: {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title3)
                        .foregroundStyle(DesignTokens.Color.foreground.opacity(0.5))
                        .padding()
                        .background(DesignTokens.Color.surface.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(true)
            } else if let download = downloadService.downloads.first(where: { $0.libraryItemId == detailed.id }) {
                switch download.status {
                case .pending:
                    Button {
                        #if os(iOS) && !SKIP
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        downloadService.cancelDownload(bookId: detailed.id)
                    } label: {
                        HStack(spacing: 8) {
                            CircularDownloadProgressBadge(status: .pending)
                            Text("Pending...")
                                .font(.caption.bold())
                                .foregroundStyle(DesignTokens.Color.warning)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(DesignTokens.Color.surface.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                case .downloading:
                    Button {
                        #if os(iOS) && !SKIP
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        downloadService.cancelDownload(bookId: detailed.id)
                    } label: {
                        CircularDownloadProgressBadge(progress: download.progress, status: .downloading)
                            .frame(width: 32, height: 32)
                            .padding(8)
                            .background(DesignTokens.Color.surface.opacity(0.1))
                            .clipShape(Circle())
                    }

                case .completed:
                    Button {
                        #if os(iOS) && !SKIP
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        #endif
                        viewModel.showRemoveDownloadConfirmation = true
                    } label: {
                        CircularDownloadProgressBadge(status: .completed)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(DesignTokens.Color.surface.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                case .failed:
                    Button {
                        #if os(iOS) && !SKIP
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        Task {
                            await downloadService.downloadBook(detailed)
                        }
                    } label: {
                        CircularDownloadProgressBadge(status: .failed)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(DesignTokens.Color.surface.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                case .paused:
                    Button {
                        #if os(iOS) && !SKIP
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        #endif
                        Task {
                            await downloadService.downloadBook(detailed)
                        }
                    } label: {
                        CircularDownloadProgressBadge(status: .paused)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(DesignTokens.Color.surface.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            } else {
                Button {
                    #if os(iOS) && !SKIP
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    #endif
                    Task {
                        await downloadService.downloadBook(detailed)
                    }
                } label: {
                    Image(systemName: "arrow.down.circle")
                        .font(.title3)
                        .foregroundStyle(DesignTokens.Color.foreground)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(DesignTokens.Color.surface.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }

            // Podcast RSS Feed Button
            Button {
                #if os(iOS) && !SKIP
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                viewModel.copyRssFeed(for: detailed)
            } label: {
                Image(systemName: viewModel.hasCopiedRssFeed ? "checkmark" : "dot.radiowaves.up.forward")
                    .font(.title3)
                    .foregroundStyle(viewModel.hasCopiedRssFeed ? DesignTokens.Color.success : DesignTokens.Color.foreground)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(DesignTokens.Color.surface.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Podcast RSS Feed")
            .accessibilityHint("Copies private podcast feed link to clipboard")

            // Playback Queue Menu (Play Next & Add to Queue)
            Menu {
                Button {
                    #if os(iOS) && !SKIP
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    viewModel.playNext(detailed)
                } label: {
                    Label("Play Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                }

                Button {
                    #if os(iOS) && !SKIP
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    viewModel.addToQueue(detailed)
                } label: {
                    Label("Add to Queue", systemImage: "text.badge.plus")
                }
            } label: {
                Image(systemName: viewModel.hasAddedToQueue ? "checkmark" : "text.badge.plus")
                    .font(.title3)
                    .foregroundStyle(viewModel.hasAddedToQueue ? DesignTokens.Color.success : DesignTokens.Color.foreground)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(DesignTokens.Color.surface.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel("Queue Options")
            .accessibilityHint("Add to playback queue or play next")

            // Mark as Finished / Not Finished Button
            Button {
                #if os(iOS) && !SKIP
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                #endif
                viewModel.toggleFinished()
            } label: {
                Image(systemName: detailed.userMediaProgress?.isFinished == true ? "checkmark.circle.fill" : "checkmark.circle")
                    .font(.title3)
                    .foregroundStyle(detailed.userMediaProgress?.isFinished == true ? DesignTokens.Color.success : DesignTokens.Color.foreground)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(DesignTokens.Color.surface.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .accessibilityLabel(detailed.userMediaProgress?.isFinished == true ? "Mark as Not Finished" : "Mark as Finished")
            .accessibilityHint("Toggles completed listening status")
        }
    }
    
    private func hasProgress(_ detailed: Book) -> Bool {
        if let progress = detailed.userMediaProgress, !progress.isFinished, progress.progress > 0 {
            return true
        }
        return false
    }
}
