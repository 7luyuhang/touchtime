//
//  HomeStopwatchSection.swift
//  touchtime
//
//  Created on 04/10/2026.
//

import SwiftUI

/// The stopwatch on Home, shown while a session is going (running, or
/// stopped partway). Tapping the card starts or stops it; Reset files the
/// session under the Stopwatch records, which also takes the card away.
struct HomeStopwatchSection: View {
    let stopwatch: StopwatchSnapshot
    let onTap: () -> Void
    let onReset: () -> Void

    private let complicationButtonSize: CGFloat = 64

    private var centerButtonSymbol: String {
        stopwatch.isRunning ? "pause.fill" : "play.fill"
    }

    /// "1 Lap" or "3 Laps"; also worded this way on the stopwatch's Live Activity.
    static func lapCountText(lapCount: Int) -> String {
        if lapCount == 1 {
            return String(localized: "1 Lap")
        }
        return String.localizedStringWithFormat(String(localized: "%d Laps"), lapCount)
    }

    /// While running, the shown second changes on these ticks: one second
    /// apart from when the elapsed time was zero, each a moment late so
    /// float rounding can't floor it back to the previous second.
    private var secondTicksStart: Date {
        Date(timeIntervalSince1970: stopwatch.startEpoch - stopwatch.accumulatedSeconds + 0.01)
    }

    /// "MM:SS", growing to "H:MM:SS" once the first hour is reached.
    private func formattedElapsed(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds / 60) % 60
        let remainingSeconds = seconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, remainingSeconds)
        }
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    var body: some View {
        Section {
            ZStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "stopwatch")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .blendMode(.plusLighter)

                        Spacer()

                        if !stopwatch.laps.isEmpty {
                            Text(Self.lapCountText(lapCount: stopwatch.laps.count))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .blendMode(.plusLighter)
                                .monospacedDigit()
                        }
                    }

                    HStack(alignment: .lastTextBaseline) {
                        Text(String(localized: "Stopwatch"))
                            .font(.headline)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: 120, alignment: .leading)

                        Spacer()

                        TimelineView(.periodic(from: secondTicksStart, by: 1)) { context in
                            let elapsedSeconds = Int(stopwatch.elapsed(at: context.date))
                            Text(formattedElapsed(seconds: elapsedSeconds))
                                .font(.system(size: 36))
                                .fontWeight(.light)
                                .fontDesign(.rounded)
                                .monospacedDigit()
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                                .contentTransition(.numericText())
                                .animation(.smooth(duration: 0.20), value: elapsedSeconds)
                                // Past an hour the digits shrink rather than run under the center button
                                .frame(maxWidth: 120, alignment: .trailing)
                                .clipped()
                        }
                    }
                    .padding(.bottom, -4)
                }
                .frame(minHeight: 64)

                Button(action: {}) {
                    Image(systemName: centerButtonSymbol)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace, options: .speed(2.0)))
                        .animation(.spring(), value: centerButtonSymbol)
                        .frame(width: complicationButtonSize, height: complicationButtonSize)
                }
                .glassEffect(.clear)
                .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(action: onReset) {
                    Image(systemName: "xmark.circle")
                }
                .tint(.red)
            }
            .contextMenu {
                Button(action: onReset) {
                    Label(String(localized: "Reset"), systemImage: "arrow.counterclockwise")
                }
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.black.opacity(0.10))
                    .glassEffect(
                        .clear,
                        in: RoundedRectangle(cornerRadius: 26, style: .continuous)
                    )
            )
            .id("home-stopwatch")
        }
    }
}
