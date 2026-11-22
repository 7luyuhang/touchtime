//
//  StopwatchLapsList.swift
//  touchtimeWatch
//

import SwiftUI

/// The stopwatch's laps, on the page to the right of its ring, newest first
/// with a line between them: each lap's number with its time at the
/// trailing edge, as the detail sheets' rows are, the fastest and the
/// slowest marked as the iPhone marks them once there are two to compare.
struct StopwatchLapsList: View {
    let laps: [TimeInterval]
    /// The lap just ended, its number lit up a moment as it joins the list.
    @State private var newLap: Int?

    var body: some View {
        list
            .onChange(of: laps.count) { oldCount, newCount in
                guard newCount > oldCount else { return }
                let lap = newCount - 1
                withAnimation(.easeOut(duration: 0.15)) {
                    newLap = lap
                } completion: {
                    // Unless a newer lap has taken its place
                    guard newLap == lap else { return }
                    withAnimation(.smooth(duration: 0.6)) {
                        newLap = nil
                    }
                }
            }
    }

    /// The laps, or No Laps before the first.
    @ViewBuilder private var list: some View {
        if laps.isEmpty {
            // Only the title, in a label with no icon: bare text in its place
            // isn't styled as the title
            ContentUnavailableView {
                Label {
                    Text("No Laps")
                } icon: {
                    EmptyView()
                }
            }
            // Left to fill the screen, the view sets its content at the top;
            // sized to the title instead, it's centred below the toolbar
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxHeight: .infinity)
        } else {
            let fastest = laps.count < 2 ? nil : laps.indices.min { laps[$0] < laps[$1] }
            let slowest = laps.count < 2 ? nil : laps.indices.max { laps[$0] < laps[$1] }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(laps.indices.reversed(), id: \.self) { index in
                        DetailSheetRow("Lap \(index + 1)", isHighlighted: index == newLap) {
                            if index == fastest {
                                Image(systemName: "circle")
                                    .font(.caption2.weight(.semibold))
                                    .imageScale(.small)
                                    .accessibilityLabel("Fastest Lap")
                            } else if index == slowest {
                                Image(systemName: "circle.fill")
                                    .font(.caption2.weight(.semibold))
                                    .imageScale(.small)
                                    .accessibilityLabel("Slowest Lap")
                            }
                            Text(verbatim: WatchStopwatchStore.figures(for: laps[index]))
                        }

                        if index > 0 {
                            Divider()
                        }
                    }
                }
                .scenePadding(.navigationBar, edges: .horizontal)
            }
        }
    }
}
