//
//  RecentTimersSheet.swift
//  touchtimeWatch
//

import SwiftUI

/// The timers started on the iPhone or the watch, as the iPhone's timer
/// sheet lists them under Recents: each its time above its name, or Timer as
/// there without one, with a play symbol beside them, started with a tap and
/// removed with a swipe, from the iPhone's Recents too.
struct RecentTimersSheet: View {
    let start: (WatchRecentTimer) -> Void

    @Environment(WatchCityStore.self) private var cityStore
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .body) private var playCircleSize: CGFloat = 36

    var body: some View {
        NavigationStack {
            Group {
                if cityStore.recentTimers.isEmpty {
                    // Only the title, in a label with no icon: bare text in its
                    // place isn't styled as the title
                    ContentUnavailableView {
                        Label {
                            Text("No Recent")
                        } icon: {
                            EmptyView()
                        }
                    }
                    // Left to fill the screen, the view sets its content at the
                    // top; sized to the title instead, it's centred below the
                    // toolbar
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxHeight: .infinity)
                } else {
                    List(cityStore.recentTimers) { timer in
                        let seconds = timer.durationSeconds
                        Button {
                            start(timer)
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(verbatim: String(format: "%02d:%02d", seconds / 60, seconds % 60))
                                        .accessibilityLabel(Duration.seconds(seconds).formatted(.units(allowed: [.minutes, .seconds], width: .wide)))
                                    Text(timer.name ?? String(localized: "Timer"))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }

                                Spacer()

                                ZStack {
                                    Circle()
                                        .fill(.white.opacity(0.1))
                                    Image(systemName: "play.fill")
                                        .foregroundStyle(.white)
                                }
                                .frame(width: playCircleSize, height: playCircleSize)
                                .accessibilityHidden(true)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Remove", systemImage: "minus.circle.fill", role: .destructive) {
                                cityStore.removeTimer(timer)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Recents")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
        }
    }
}
