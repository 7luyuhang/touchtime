//
//  StopwatchLapsList.swift
//  touchtimeWatch
//

import SwiftUI

/// The stopwatch's laps, on the page to the right of its ring, newest first:
/// each lap's time above its number, as the recent timers' times are above
/// their names, with the fastest and the slowest marked as the iPhone marks
/// them once there are two to compare.
struct StopwatchLapsList: View {
    let laps: [TimeInterval]

    var body: some View {
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

            List(laps.indices.reversed(), id: \.self) { index in
                HStack {
                    VStack(alignment: .leading) {
                        Text(verbatim: WatchStopwatchStore.figures(for: laps[index]))
                            .monospacedDigit()
                        Text("Lap \(index + 1)")
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if index == fastest {
                        Image(systemName: "circle")
                            .font(.caption2)
                            .accessibilityLabel("Fastest Lap")
                    } else if index == slowest {
                        Image(systemName: "circle.fill")
                            .font(.caption2)
                            .accessibilityLabel("Slowest Lap")
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}
