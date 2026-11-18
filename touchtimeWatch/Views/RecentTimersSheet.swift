//
//  RecentTimersSheet.swift
//  touchtimeWatch
//

import SwiftUI

/// The timers started on the iPhone, as its timer sheet lists them under
/// Recents: each its time above its name, or Timer as there without one,
/// with a play symbol beside them, and started with a tap.
struct RecentTimersSheet: View {
    let start: (WatchRecentTimer) -> Void

    @Environment(WatchCityStore.self) private var cityStore
    @Environment(\.dismiss) private var dismiss
    @ScaledMetric(relativeTo: .body) private var playCircleSize: CGFloat = 36

    var body: some View {
        NavigationStack {
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
