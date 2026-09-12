//
//  CountdownWidget.swift
//  touchtimeWidgetExtension
//
//  Small widget, laid out like City Time: event name on top, the
//  countdown's cover (emoji or photo) in the centre circle (80x80), the
//  days to the event at the bottom. Every countdown has a cover, and the
//  background follows it the way the app's countdown card does — the
//  emoji's dominant colour, or the photo blurred. In the Clear and Tinted
//  Home Screen modes the cover is desaturated with the rest of the widget
//  unless the edit-widget toggle keeps it in full colour.
//

import WidgetKit
import SwiftUI

// MARK: - Timeline

struct CountdownWidgetEntry: TimelineEntry {
    /// One countdown as it reads at the entry's date.
    struct Countdown {
        let title: String
        /// Rolled forward to the next occurrence for repeating countdowns.
        let targetDate: Date
        let emoji: String?
        let photoData: Data?
        /// How the photo is framed in the badge; nil shows it centred.
        let photoCrop: CountdownItem.PhotoCrop?
    }

    let date: Date
    /// Nil when the app has no countdowns yet: the widget shows its empty state.
    let countdown: Countdown?
    /// Edit-widget toggle: keep the cover in colour in the Clear and Tinted
    /// Home Screen modes instead of desaturating it with the rest of the widget.
    let showCoverInFullColor: Bool
}

struct CountdownWidgetProvider: AppIntentTimelineProvider {
    // Only honour the configured countdown if it still exists in the app's
    // saved list; otherwise (deleted in the app, or never picked) fall back
    // to the first countdown in widget order.
    private func resolveCountdown(for configuration: CountdownWidgetIntent, now: Date) -> CountdownItem? {
        let saved = SharedWidgetStore.loadCountdowns()
        if let selected = configuration.countdown,
           let match = saved.first(where: { $0.id.uuidString == selected.id }) {
            return match
        }
        return CountdownEntity.widgetOrder(saved, now: now).first
    }

    private func makeEntry(
        for item: CountdownItem?,
        date: Date,
        showCoverInFullColor: Bool
    ) -> CountdownWidgetEntry {
        let countdown = item.map {
            CountdownWidgetEntry.Countdown(
                title: $0.title,
                targetDate: $0.effectiveTargetDate(at: date),
                emoji: $0.emoji,
                photoData: $0.photoData,
                photoCrop: $0.photoCrop
            )
        }
        return CountdownWidgetEntry(
            date: date,
            countdown: countdown,
            showCoverInFullColor: showCoverInFullColor
        )
    }

    /// Gallery sample: a countdown to the next New Year's Day.
    private func sampleEntry(date: Date) -> CountdownWidgetEntry {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let newYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) ?? date
        return CountdownWidgetEntry(
            date: date,
            countdown: CountdownWidgetEntry.Countdown(
                title: String(localized: "New Year"),
                targetDate: newYear,
                emoji: "🎆",
                photoData: nil,
                photoCrop: nil
            ),
            showCoverInFullColor: false
        )
    }

    func placeholder(in context: Context) -> CountdownWidgetEntry {
        sampleEntry(date: Date())
    }

    func snapshot(for configuration: CountdownWidgetIntent, in context: Context) async -> CountdownWidgetEntry {
        let now = Date()
        let item = resolveCountdown(for: configuration, now: now)
        // No countdowns yet: the gallery shows the sample, the Home Screen
        // the empty state.
        if item == nil, context.isPreview {
            return sampleEntry(date: now)
        }
        return makeEntry(for: item, date: now, showCoverInFullColor: configuration.showCoverInFullColor)
    }

    func timeline(for configuration: CountdownWidgetIntent, in context: Context) async -> Timeline<CountdownWidgetEntry> {
        let now = Date()
        let item = resolveCountdown(for: configuration, now: now)

        // Only the day count changes: one entry now, then one at each of
        // the next seven midnights. The app reloads the timeline whenever
        // a countdown is edited.
        let calendar = Calendar.current
        var dates = [now]
        var day = calendar.startOfDay(for: now)
        for _ in 0..<7 {
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            dates.append(next)
            day = next
        }

        let entries = dates.map {
            makeEntry(for: item, date: $0, showCoverInFullColor: configuration.showCoverInFullColor)
        }
        return Timeline(entries: entries, policy: .atEnd)
    }
}

// MARK: - View

struct CountdownWidgetView: View {
    var entry: CountdownWidgetEntry

    @Environment(\.redactionReasons) private var redactionReasons
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.displayScale) private var displayScale

    // Same size as the City Time complication
    private static let badgeSize: CGFloat = 80
    private static let emojiPointSize: CGFloat = 40
    /// Background while loading and in the empty state: a neutral grey
    /// rather than any cover's colour.
    private static let neutralBackground = Color(white: 0.50)

    private var countdown: CountdownWidgetEntry.Countdown? {
        entry.countdown
    }

    /// Decoded cover photo, cut to its framing; nil for emoji covers.
    private var photoImage: UIImage? {
        guard let countdown, let photoData = countdown.photoData,
              let image = UIImage(data: photoData) else { return nil }
        return countdown.photoCrop?.croppedImage(from: image) ?? image
    }

    /// Dominant colour of the cover emoji, the same one the app's card uses.
    private var emojiColor: EmojiDominantColor? {
        countdown?.emoji.flatMap { EmojiDominantColor.cached(for: $0) }
    }

    /// How the cover is handed to the system in the Clear and Tinted Home
    /// Screen modes: desaturated with the rest of the widget, or kept in
    /// colour when the edit-widget toggle is on. Ignored in full-colour mode.
    private var coverRenderingMode: WidgetAccentedRenderingMode {
        entry.showCoverInFullColor ? .fullColor : .desaturated
    }

    /// Whole calendar days from the entry's date to the event; negative
    /// once the event has happened.
    private var dayDifference: Int {
        guard let countdown else { return 0 }
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: entry.date),
            to: calendar.startOfDay(for: countdown.targetDate)
        ).day ?? 0
    }

    /// "in 3 days" / "1 day ago" / "Today", phrased like the app's shared
    /// countdown footer; a hint to add one in the empty state.
    private var countdownString: String {
        guard countdown != nil else { return String(localized: "Tap to add") }
        let days = dayDifference
        if days == 0 {
            return String(localized: "Today")
        }
        let unit = abs(days) == 1 ? String(localized: "day") : String(localized: "days")
        let interval = "\(abs(days)) \(unit)"
        return days < 0
            ? String(format: String(localized: "%@ ago"), interval)
            : String(format: String(localized: "in %@"), interval)
    }

    var body: some View {
        ZStack {
            Group {
                if redactionReasons.contains(.placeholder) {
                    // Loading/placeholder state
                    Circle()
                        .fill(.white.opacity(0.10))
                } else {
                    badge
                        .overlay {
                            Circle()
                                .strokeBorder(.white.opacity(0.10), lineWidth: 1.50)
                                .blendMode(.plusLighter)
                        }
                }
            }
            .frame(width: Self.badgeSize, height: Self.badgeSize)

            VStack {
                Text(countdown?.title ?? String(localized: "No Countdowns"))
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 8)

                Spacer(minLength: 0)

                Text(countdownString)
                    .font(.system(size: 15, weight: .medium))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .foregroundStyle(.white)
        .padding(14)
        .containerBackground(for: .widget) {
            background
        }
    }

    /// The centre circle: the cover photo or emoji, or an hourglass in the
    /// empty state.
    @ViewBuilder
    private var badge: some View {
        if let photoImage {
            Image(uiImage: photoImage)
                .resizable()
                .widgetAccentedRenderingMode(coverRenderingMode)
                .scaledToFill()
                .frame(width: Self.badgeSize, height: Self.badgeSize)
                .clipShape(Circle())
        } else {
            ZStack {
                // Fills the badge frame so the hairline overlay hugs the circle
                Circle()
                    .fill(.clear)

                if let emoji = countdown?.emoji {
                    if renderingMode == .accented,
                       let glyph = Self.rasterise(emoji: emoji, scale: displayScale) {
                        // In the Clear and Tinted Home Screen modes text is
                        // flattened to a solid silhouette (a disco ball becomes
                        // a white disc), so hand the emoji over as an image and
                        // let the system treat it like the cover photo:
                        // desaturated, or in full colour with the toggle on.
                        Image(uiImage: glyph)
                            .widgetAccentedRenderingMode(coverRenderingMode)
                    } else {
                        Text(emoji)
                            .font(.system(size: Self.emojiPointSize))
                    }
                } else {
                    // Empty state (and a countdown saved without a cover by
                    // an app version that still allowed that)
                    Image(systemName: "hourglass")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundStyle(.white.opacity(0.50))
                }
            }
        }
    }

    /// The emoji drawn with the same system font `Text` uses, at the
    /// screen's scale so it stays crisp.
    private static func rasterise(emoji: String, scale: CGFloat) -> UIImage? {
        let attributes: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: emojiPointSize)]
        let string = emoji as NSString
        let size = string.size(withAttributes: attributes)
        guard size.width > 0, size.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            string.draw(at: .zero, withAttributes: attributes)
        }
    }

    /// Background driven by the cover, as on the app's countdown card.
    @ViewBuilder
    private var background: some View {
        if redactionReasons.contains(.placeholder) {
            Self.neutralBackground
        } else if let photoImage {
            // Blurred copy of the cover photo, darkened a touch for text contrast
            GeometryReader { geometry in
                Image(uiImage: photoImage)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 24, opaque: true)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .overlay(Color.black.opacity(0.25))
            }
        } else if let emojiColor {
            emojiColor.color
        } else {
            // Empty state
            Self.neutralBackground
        }
    }
}

// MARK: - Widget

struct CountdownWidget: Widget {
    let kind: String = SharedWidgetStore.countdownWidgetKind

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: CountdownWidgetIntent.self,
            provider: CountdownWidgetProvider()
        ) { entry in
            CountdownWidgetView(entry: entry)
        }
        .configurationDisplayName("Countdown")
        .description("Shows the days to an event with its cover in the center.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
