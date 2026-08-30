//
//  HomeCountdownSection.swift
//  touchtime
//
//  Created on 24/08/2026.
//

import SwiftUI
import UIKit

/// Pinned countdowns shown below the home timer: one preview card per
/// pinned countdown, ordered by target date. Day counts follow the
/// scrubbed time passed in as `now`.
struct HomeCountdownSection: View {
    let countdowns: [CountdownItem]
    /// Reference "now" (current time plus the Slide to Adjust offset)
    /// used for the day counts.
    let now: Date
    /// Called with the tapped countdown; Home presents the editor for it.
    let onTap: (CountdownItem) -> Void

    // Same Time Display settings as the countdown sheet rows, so shared
    // text breaks the interval into the units chosen there.
    @AppStorage("countdownShowYears") private var showYears = false
    @AppStorage("countdownShowMonths") private var showMonths = false
    @AppStorage("countdownShowDays") private var showDays = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    private var pinnedCountdowns: [CountdownItem] {
        countdowns
            .filter(\.isPinned)
            .sorted { $0.effectiveTargetDate(at: now) < $1.effectiveTargetDate(at: now) }
    }

    var body: some View {
        ForEach(pinnedCountdowns) { item in
            Section {
                CountdownPreviewCard(
                    title: item.title,
                    targetDate: item.effectiveTargetDate(at: now),
                    emoji: item.emoji,
                    photoData: item.photoData,
                    now: now,
                    isRepeating: item.repeatFrequency != .never
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    onTap(item)
                }
                .contextMenu {
                    shareMenu(for: item)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }

    // MARK: - Share

    @ViewBuilder
    private func shareMenu(for item: CountdownItem) -> some View {
        let lazyImage = LazyCardImage {
            CountdownShare.renderCardImage(
                title: item.title,
                targetDate: item.effectiveTargetDate(at: now),
                emoji: item.emoji,
                photoData: item.photoData,
                isRepeating: item.repeatFrequency != .never,
                now: now,
                showYears: showYears,
                showMonths: showMonths,
                showDays: showDays
            )
        }
        Menu {
            Button {
                UIPasteboard.general.string = CountdownShare.copyText(
                    title: item.title,
                    targetDate: item.effectiveTargetDate(at: now),
                    now: now,
                    showYears: showYears,
                    showMonths: showMonths,
                    showDays: showDays
                )
                if hapticEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                }
            } label: {
                Label(String(localized: "Copy as Text"), systemImage: "quote.opening")
            }
            ShareLink(item: lazyImage, preview: SharePreview(item.title)) {
                Label(String(localized: "Share as Image"), systemImage: "camera.macro")
            }
        } label: {
            Label(String(localized: "Share"), systemImage: "square.and.arrow.up") // Countdown Share
        }
    }
}

// MARK: - Shared countdown share helpers

/// Share helpers used by both the Home cards and the countdown editor:
/// pasteboard text, the relative phrase under the shared card, and the
/// 9:16 card image. The unit flags are the countdown sheet's Time Display
/// settings.
enum CountdownShare {
    /// Whole calendar days from the reference date to the target date;
    /// negative once the event has happened.
    static func dayDifference(from now: Date, to targetDate: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: targetDate)
        ).day ?? 0
    }

    /// Pasteboard text, e.g. "Birthday in 1 year 4 days" /
    /// "Birthday 3 days ago" / "Birthday is today".
    static func copyText(title: String, targetDate: Date, now: Date, showYears: Bool, showMonths: Bool, showDays: Bool) -> String {
        let difference = dayDifference(from: now, to: targetDate)
        if difference == 0 {
            return String(format: String(localized: "%@ is today"), title)
        }
        let interval = intervalText(from: now, to: targetDate, showYears: showYears, showMonths: showMonths, showDays: showDays)
        if difference < 0 {
            return String(format: String(localized: "%1$@ %2$@ ago"), title, interval)
        }
        return String(format: String(localized: "%1$@ in %2$@"), title, interval)
    }

    /// Renders the countdown card into a 9:16 share image, like the city
    /// card share.
    static func renderCardImage(title: String, targetDate: Date, emoji: String?, photoData: Data?, isRepeating: Bool, now: Date, showYears: Bool, showMonths: Bool, showDays: Bool) -> UIImage {
        let difference = dayDifference(from: now, to: targetDate)
        let footerText: String
        if difference == 0 {
            footerText = String(localized: "Today")
        } else {
            let interval = intervalText(from: now, to: targetDate, showYears: showYears, showMonths: showMonths, showDays: showDays)
            footerText = difference < 0
                ? String(format: String(localized: "%@ ago"), interval)
                : String(format: String(localized: "in %@"), interval)
        }

        let snapshotView = CountdownCardSnapshotView(
            title: title,
            targetDate: targetDate,
            emoji: emoji,
            photoData: photoData,
            isRepeating: isRepeating,
            now: now,
            footerText: footerText
        )
        .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: snapshotView)
        renderer.scale = 3

        if let uiImage = renderer.uiImage {
            return uiImage
        }

        // Fallback: create a simple placeholder image
        return UIImage(systemName: "photo") ?? UIImage()
    }

    /// Interval to the target broken into the enabled units, largest
    /// first, mirroring the countdown sheet rows (e.g. "1 year 4 days").
    private static func intervalText(from now: Date, to targetDate: Date, showYears: Bool, showMonths: Bool, showDays: Bool) -> String {
        let calendar = Calendar.current

        var unitSet: Set<Calendar.Component> = []
        if showYears { unitSet.insert(.year) }
        if showMonths { unitSet.insert(.month) }
        if showDays { unitSet.insert(.day) }

        let difference = calendar.dateComponents(
            unitSet,
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: targetDate)
        )

        var parts: [String] = []
        if let years = difference.year, years != 0 {
            let unit = abs(years) == 1 ? String(localized: "year") : String(localized: "years")
            parts.append("\(abs(years)) \(unit)")
        }
        if let months = difference.month, months != 0 {
            let unit = abs(months) == 1 ? String(localized: "month") : String(localized: "months")
            parts.append("\(abs(months)) \(unit)")
        }
        if let days = difference.day, days != 0 {
            let unit = abs(days) == 1 ? String(localized: "day") : String(localized: "days")
            parts.append("\(abs(days)) \(unit)")
        }

        // The target is closer than any enabled unit: fall back to days.
        if parts.isEmpty {
            let dayCount = dayDifference(from: now, to: targetDate)
            let unit = abs(dayCount) == 1 ? String(localized: "day") : String(localized: "days")
            parts.append("\(abs(dayCount)) \(unit)")
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - Countdown Card Snapshot View for Sharing

/// 9:16 share image for a countdown, mirroring the city card share: the
/// pinned card replica centered on a backdrop that echoes its cover — the
/// emoji's dominant colour as a flat fill, or the photo blurred; plain
/// black without a cover. Glass effects don't render in ImageRenderer, so
/// subtle fills stand in for them.
struct CountdownCardSnapshotView: View {
    let title: String
    let targetDate: Date
    let emoji: String?
    let photoData: Data?
    /// True for repeating countdowns; swaps the top-left arrow for a
    /// repeat symbol.
    let isRepeating: Bool
    /// Reference "now" for the day count (scrubbed time on Home).
    let now: Date
    /// Context line under the card, e.g. "in 1 year 4 days".
    let footerText: String

    private var photoImage: UIImage? {
        guard let photoData else { return nil }
        return UIImage(data: photoData)
    }

    private var emojiColor: Color? {
        guard let emoji else { return nil }
        return CountdownPreviewCard.cachedDominantColor(of: emoji)
    }

    private var calendar: Calendar {
        Calendar.current
    }

    private var dayDifference: Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: targetDate)
        ).day ?? 0
    }

    private var hasHappened: Bool {
        dayDifference < 0
    }

    private var bigText: String {
        dayDifference == 0 ? String(localized: "Today") : "\(abs(dayDifference))"
    }

    private var dayUnit: String {
        String(localized: "d")
    }

    /// Same CJK baseline lift as the live card.
    private var dayUnitBaselineOffset: CGFloat {
        dayUnit.unicodeScalars.contains { $0.properties.isIdeographic } ? 1.8 : 0
    }

    private var hasCenterBadge: Bool {
        emoji != nil || photoImage != nil
    }

    var body: some View {
        ZStack {
            // Full-bleed backdrop echoing the card cover
            Color.black
            if let photoImage {
                Image(uiImage: photoImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 360, height: 640)
                    .clipped()
                    .blur(radius: 60, opaque: true)
                    .overlay(Color.black.opacity(0.35))
            } else if let emojiColor {
                // Slightly dimmed so the full-colour card reads on top.
                emojiColor.opacity(0.75)
            }

            VStack(spacing: 10) {
                // Card replica from HomeView, centered vertically
                ZStack {
                    VStack(alignment: .leading, spacing: 4) {
                        // Repeat symbol (repeating) / happened (left arrow) /
                        // happening (right arrow) top-left, countdown date
                        // top-right
                        HStack {
                            Image(systemName: isRepeating ? "repeat" : (hasHappened ? "arrow.left" : "arrow.right"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .blendMode(.plusLighter)

                            Spacer()

                            Text(targetDate, format: .dateTime.year().month().day())
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .blendMode(.plusLighter)
                        }

                        // Event title bottom-left, day count bottom-right
                        HStack(alignment: .lastTextBaseline) {
                            Text(title.isEmpty ? String(localized: "Event Name") : title)
                                .font(.headline)
                                .foregroundStyle(title.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: hasCenterBadge ? 120 : .infinity, alignment: .leading)

                            Spacer()

                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text(bigText)
                                    .font(.system(size: 36))
                                    .fontWeight(.light)
                                    .fontDesign(.rounded)
                                    .monospacedDigit()

                                // Day unit, hidden when the card reads "Today"
                                if dayDifference != 0 {
                                    Text(dayUnit)
                                        .font(.system(size: 20, weight: .regular, design: .rounded))
                                        .baselineOffset(dayUnitBaselineOffset)
                                }
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, -4)
                    .background {
                        if let photoImage {
                            Image(uiImage: photoImage)
                                .resizable()
                                .scaledToFill()
                                .blur(radius: 24, opaque: true)
                                .overlay(Color.black.opacity(0.25))
                        } else if let emojiColor {
                            emojiColor
                        } else {
                            Color(UIColor.secondarySystemBackground)
                        }
                    }
                    // Same clip + hairline border as the city share card
                    .skyBackgroundCardChrome()

                    // Complication-sized emoji or photo in the middle,
                    // glassy like the live card
                    if let photoImage {
                        Image(uiImage: photoImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                            .glassEffect(.clear)
                    } else if let emoji {
                        Text(emoji)
                            .font(.system(size: 36))
                            .frame(width: 64, height: 64)
                            .glassEffect(.clear)
                    }
                }
                .padding(.horizontal, 8)

                Text(footerText)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .padding(.horizontal, 24)
            }
        }
        .frame(width: 360, height: 640) // 9:16 share frame ratio
    }
}
