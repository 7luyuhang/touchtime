//
//  HomeTimerSection.swift
//  touchtime
//
//  Created on 28/03/2026.
//

import SwiftUI

struct HomeTimerSection: View {
    let configuredSeconds: Int
    let endDateEpoch: Double
    let isPaused: Bool
    let pausedRemainingSeconds: Int
    let onTap: () -> Void
    let onReset: () -> Void
    let onDelete: () -> Void

    private var configuredDisplay: String {
        formattedConfiguredDuration(seconds: configuredSeconds)
    }

    private var endDate: Date? {
        guard endDateEpoch > 0 else { return nil }
        return Date(timeIntervalSince1970: endDateEpoch)
    }

    private func remainingSeconds(at date: Date) -> Int {
        if isPaused {
            return max(0, min(pausedRemainingSeconds, 59 * 60 + 59))
        }

        guard let endDate else { return 0 }
        let remaining = Int(ceil(endDate.timeIntervalSince(date)))
        return max(remaining, 0)
    }

    private func formattedTimer(seconds: Int) -> String {
        let clampedSeconds = max(0, min(seconds, 59 * 60 + 59))
        let minutes = clampedSeconds / 60
        let remainingSeconds = clampedSeconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private func formattedConfiguredDuration(seconds: Int) -> String {
        let clampedSeconds = max(0, min(seconds, 59 * 60 + 59))
        let minutes = clampedSeconds / 60
        let remainingSeconds = clampedSeconds % 60

        if minutes > 0 && remainingSeconds > 0 {
            return "\(minutes) min \(remainingSeconds) sec"
        }
        if minutes > 0 {
            return "\(minutes) min"
        }
        return "\(remainingSeconds) sec"
    }

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: "timer")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)

                    Spacer()

                    Text(configuredDisplay)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                        .monospacedDigit()
                }

                HStack(alignment: .lastTextBaseline) {
                    Text("Timer")
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)

                    Spacer()

                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = remainingSeconds(at: context.date)
                        Text(formattedTimer(seconds: remaining))
                            .font(.system(size: 36))
                            .fontWeight(.light)
                            .fontDesign(.rounded)
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                            .animation(.smooth(duration: 0.20), value: remaining)
                            .clipped()
                    }
                }
                .padding(.bottom, -4)
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "xmark.circle")
                }
                Button(action: onReset) {
                    Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
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
            .id("home-timer")
        }
    }
}
