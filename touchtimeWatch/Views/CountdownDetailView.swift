//
//  CountdownDetailView.swift
//  touchtimeWatch
//

import SwiftUI
import UIKit

/// A countdown laid out like a city's World Time: its cover in glass, as in
/// the middle of its card on iPhone, where the map is, its count where the
/// time is, and its title along the bottom, with the arrow back or ahead,
/// or the repeat or pause symbol, after it, and its date at the top, over
/// the background its row is filled with.
struct CountdownDetailView: View {
    let countdown: WatchCountdown

    @Environment(WatchCityStore.self) private var cityStore
    /// The unit a tap on the count switched it to, or nil for the one its
    /// card on iPhone counts in. Not kept: the details open in that one again.
    @State private var unit: CountdownUnit?

    var body: some View {
        // Each minute, so the count turns over at midnight, and a
        // repeating countdown's date moves on once it passes
        TimelineView(.everyMinute) { context in
            let targetDate = countdown.effectiveTargetDate(at: context.date)

            VStack(spacing: 0) {
                CountdownCover(countdown: countdown)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.bottom, 4)

                CountdownDays(countdown: countdown, now: context.date, size: .large, unit: unit ?? cityStore.countdownUnit)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    // The digits can shrink to fit, so the stack would
                    // otherwise squeeze them to make room for the cover
                    .fixedSize(horizontal: false, vertical: true)
                    .scenePadding(.navigationBar, edges: .horizontal)
                    .contentShape(.rect)
                    .onTapGesture {
                        switchUnit(at: context.date)
                    }
                    .sensoryFeedback(.impact(flexibility: .soft), trigger: unit)

                HStack(alignment: .firstTextBaseline) {
                    MarqueeText(countdown.title, alignment: .leading)
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)

                    CountdownStatusSymbol(countdown: countdown, now: context.date)
                }
                .fixedSize(horizontal: false, vertical: true)
                .scenePadding(.navigationBar, edges: .horizontal)
                .padding(.bottom, 14)
            }
            // As in World Time, the count and title sit low enough to
            // leave the cover room above them
            .ignoresSafeArea(edges: .bottom)
            .accessibilityElement(children: .combine)
            .accessibilityAction {
                switchUnit(at: context.date)
            }
            .navigationTitle(Text(targetDate, format: .dateTime.year().month().day()))
        }
        .containerBackground(for: .navigation) {
            if let background = countdown.background {
                CountdownBackground(background: background)
            }
        }
        .toolbarForegroundStyle(.primary, for: .navigationBar)
    }

    /// From years to months to days and round again, past a unit without a
    /// whole one to go, or gone: less than a month off, there's only days.
    private func switchUnit(at now: Date) {
        let shownUnit = CountdownDays.count(of: countdown, in: unit ?? cityStore.countdownUnit, now: now).unit
        let nextUnit: CountdownUnit = switch shownUnit {
        case .years: .months
        case .months: .days
        case .days: .years
        }
        guard CountdownDays.count(of: countdown, in: nextUnit, now: now).unit != shownUnit else { return }
        withAnimation(.smooth) {
            unit = nextUnit
        }
    }
}

/// A countdown's cover photo, or its emoji, in a glass circle. Every
/// countdown has one on the iPhone; as in the Countdown widget, an
/// hourglass stands in for one the watch hasn't been sent: before the
/// iPhone first sends covers, or for a photo too big to send with no emoji
/// under it.
private struct CountdownCover: View {
    let countdown: WatchCountdown

    private static let diameter: CGFloat = 88

    var body: some View {
        ZStack {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Self.diameter, height: Self.diameter)
                    .clipShape(.circle)
            } else if let emoji = countdown.emoji {
                Text(emoji)
                    .font(.system(size: 50))
            } else {
                Image(systemName: "hourglass")
                    .font(.system(size: 35, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .glassEffect(.clear.interactive(), in: .circle)
        .accessibilityHidden(true)
    }

    /// The cover photo, or the few pixels of it behind the row when it was
    /// too much to send.
    private var photo: UIImage? {
        if let coverPhoto = countdown.coverPhoto {
            return UIImage(data: coverPhoto)
        }
        if case .photo(let thumbnail) = countdown.background {
            return UIImage(data: thumbnail)
        }
        return nil
    }
}
