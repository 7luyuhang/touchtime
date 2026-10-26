//
//  HomeRows.swift
//  touchtime
//

import SwiftUI
import WeatherKit

private struct HomeSkyListRowBackground: View {
    let date: Date
    let timeZoneIdentifier: String
    let weatherCondition: WeatherCondition?
    /// Displayed time minus now, which the stars turn with.
    let timeOffset: TimeInterval

    var body: some View {
        SkyBackgroundView(
            date: date,
            timeZoneIdentifier: timeZoneIdentifier,
            weatherCondition: weatherCondition,
            showRainEffect: true,
            appliesCardChrome: false,
            starsMotion: StarsView.Motion(timeOffset: timeOffset, timeZoneIdentifier: timeZoneIdentifier)
        )
        .skyBackgroundCardChrome()
    }
}

// MARK: - Shared row time formatting
// Pure helpers used by the extracted row views so that each row can compute its
// own time/date strings from the bindings it observes (enabling localized
// invalidation without depending on HomeView instance methods).
enum RowTimeFormat {
    private static let timeFormatterCache: NSCache<NSString, DateFormatter> = {
        let cache = NSCache<NSString, DateFormatter>()
        cache.countLimit = 50
        return cache
    }()

    static func timeFormatter(for timeZone: TimeZone, use24Hour: Bool) -> DateFormatter {
        let key = "\(timeZone.identifier)_\(use24Hour)" as NSString
        if let cached = timeFormatterCache.object(forKey: key) {
            return cached
        }
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = use24Hour ? "HH:mm" : "h:mm"
        timeFormatterCache.setObject(formatter, forKey: key)
        return formatter
    }

    static func time(date: Date, offset: TimeInterval, timeZone: TimeZone, use24Hour: Bool) -> String {
        timeFormatter(for: timeZone, use24Hour: use24Hour).string(from: date.addingTimeInterval(offset))
    }

    static func minuteQuantized(date: Date, offset: TimeInterval) -> Date {
        let interval = date.addingTimeInterval(offset).timeIntervalSinceReferenceDate
        return Date(timeIntervalSinceReferenceDate: (interval / 60).rounded(.down) * 60)
    }

    static func minuteQuantized(offset: TimeInterval) -> TimeInterval {
        (offset / 60).rounded(.down) * 60
    }

    static func cityDate(timeZoneIdentifier: String, displayDate: Date, referenceDate: Date, dateStyle: String) -> String {
        guard let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return ""
        }
        return displayDate.formattedDate(
            style: dateStyle,
            timeZone: targetTimeZone,
            relativeTo: referenceDate
        )
    }

    struct WeekdayDisplay {
        let previous: String
        let current: String
        let next: String
    }

    static func weekdayDisplay(for timeZoneIdentifier: String, baseDate: Date, offset: TimeInterval) -> WeekdayDisplay? {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return nil
        }
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let displayDate = baseDate.addingTimeInterval(offset)
        let previousDate = calendar.date(byAdding: .day, value: -1, to: displayDate) ?? displayDate.addingTimeInterval(-86_400)
        let nextDate = calendar.date(byAdding: .day, value: 1, to: displayDate) ?? displayDate.addingTimeInterval(86_400)
        let previous = weekdaySymbol(for: calendar.component(.weekday, from: previousDate))
        let current = weekdaySymbol(for: calendar.component(.weekday, from: displayDate))
        let next = weekdaySymbol(for: calendar.component(.weekday, from: nextDate))
        return WeekdayDisplay(previous: previous, current: current, next: next)
    }

    static func weekdaySymbol(for weekday: Int) -> String {
        switch weekday {
        case 1: return String(localized: "Sun")
        case 2: return String(localized: "Mon")
        case 3: return String(localized: "Tue")
        case 4: return String(localized: "Wed")
        case 5: return String(localized: "Thu")
        case 6: return String(localized: "Fri")
        case 7: return String(localized: "Sat")
        default: return ""
        }
    }

    static func weekdayInlineText(for weekday: WeekdayDisplay) -> String {
        "\(weekday.previous) [\(weekday.current)] \(weekday.next)"
    }

    static func additionalText(for clock: WorldClock, display: String, baseDate: Date, offset: TimeInterval) -> String {
        switch display {
        case "Time Difference":
            return clock.timeDifference
        case "UTC":
            return clock.utcOffset
        case "Weekday":
            guard let weekday = weekdayDisplay(for: clock.timeZoneIdentifier, baseDate: baseDate, offset: offset) else {
                return ""
            }
            return weekdayInlineText(for: weekday)
        default:
            return ""
        }
    }
}

// MARK: - Extracted row views (localized invalidation)
// Each of these reads `currentDate`/`timeOffset` through bindings so that, while
// scrubbing time, only the visible rows recompute instead of the whole HomeView
// body. HomeView no longer reads the per-frame time values directly.

/// Sky background for a single list row, computed from the time bindings.
/// `HomeSkyListRowBackground` only receives plain values, so its subtree is
/// pruned on frames where the quantized date and weather did not change.
struct RowSkyBackground: View {
    let timeZoneIdentifier: String
    @Binding var currentDate: Date
    @Binding var timeOffset: TimeInterval
    @ObservedObject var weatherManager: WeatherManager
    @AppStorage("showWeather") private var showWeather = false

    var body: some View {
        HomeSkyListRowBackground(
            date: RowTimeFormat.minuteQuantized(date: currentDate, offset: timeOffset),
            timeZoneIdentifier: timeZoneIdentifier,
            weatherCondition: showWeather ? weatherManager.weatherData[timeZoneIdentifier]?.condition : nil,
            timeOffset: RowTimeFormat.minuteQuantized(offset: timeOffset)
        )
    }
}

/// The local time zone's sky color across the top of the screen, fading out
/// downward.
struct LocalSkyGlowBackground: View {
    @Binding var currentDate: Date
    @Binding var timeOffset: TimeInterval
    @ObservedObject var weatherManager: WeatherManager
    @AppStorage("showWeather") private var showWeather = false

    // Smoothstep opacity ramp: a linear one shows hard bands where the fade
    // starts and ends
    private static let fadeStops: [Gradient.Stop] = (0...8).map { step in
        let location = Double(step) / 8
        return .init(color: .black.opacity(location * location * (3 - 2 * location)), location: location)
    }

    var body: some View {
        let sky = SkyColorGradient(
            date: RowTimeFormat.minuteQuantized(date: currentDate, offset: timeOffset),
            timeZoneIdentifier: TimeZone.current.identifier,
            weatherCondition: showWeather ? weatherManager.weatherData[TimeZone.current.identifier]?.condition : nil
        )

        Rectangle()
            .fill(sky.linearGradient())
            .animation(.easeInOut(duration: 0.5), value: sky.animationValue)
            .frame(height: 400)
            .mask {
                LinearGradient(stops: Self.fadeStops, startPoint: .bottom, endPoint: .top)
            }
            .opacity(0.25)
    }
}

/// Local time zone row content.
///
/// Thin wrapper: it is the only layer that reads the per-frame time bindings.
/// It quantizes them to the minute and hands plain values to
/// `LocalTimeRowBody`, so SwiftUI can prune the whole row subtree (via
/// `.equatable()`) on frames where the displayed minute did not change.
struct LocalTimeRowContent: View {
    @Binding var currentDate: Date
    @Binding var timeOffset: TimeInterval
    let complicationOptions: ComplicationDisplayOptions
    @ObservedObject var weatherManager: WeatherManager

    var body: some View {
        LocalTimeRowBody(
            displayDate: RowTimeFormat.minuteQuantized(date: currentDate, offset: timeOffset),
            referenceDate: RowTimeFormat.minuteQuantized(date: currentDate, offset: 0),
            complicationOptions: complicationOptions,
            weatherManager: weatherManager
        )
        .equatable()
    }
}

fileprivate struct LocalTimeRowBody: View, Equatable {
    let displayDate: Date
    let referenceDate: Date
    let complicationOptions: ComplicationDisplayOptions
    @ObservedObject var weatherManager: WeatherManager

    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showWeather") private var showWeather = false
    @AppStorage("useCelsius") private var useCelsius = true
    @AppStorage("dateStyle") private var dateStyle = "Relative"
    @AppStorage("hasLifetimeAccess") private var hasLifetimeAccess = false
    @AppStorage("availableTimeEnabled") private var availableTimeEnabled = false
    @AppStorage("availableStartTime") private var availableStartTime = "09:00"
    @AppStorage("availableEndTime") private var availableEndTime = "17:00"
    @AppStorage("availableWeekdays") private var availableWeekdays = "2,3,4,5,6"

    // Dynamic properties (@AppStorage / @ObservedObject) invalidate the view
    // through their own dependency channel, so == only needs to cover the
    // plain inputs coming from the wrapper.
    static func == (lhs: LocalTimeRowBody, rhs: LocalTimeRowBody) -> Bool {
        lhs.displayDate == rhs.displayDate
            && lhs.referenceDate == rhs.referenceDate
            && lhs.complicationOptions == rhs.complicationOptions
    }

    private var hasVisibleComplication: Bool { complicationOptions.hasVisibleComplication }
    private var showsAvailableTime: Bool {
        hasLifetimeAccess && availableTimeEnabled && !availableWeekdays.isEmpty
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 4) {
                // Top row: "Local" label and Date
                HStack {
                    Image(systemName: "location.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)

                    Spacer()

                    // Weather display for local time
                    if showWeather {
                        WeatherView(
                            weather: weatherManager.weatherData[TimeZone.current.identifier],
                            useCelsius: useCelsius
                        )
                        .contentTransition(.numericText())
                    }

                    Text(displayDate.formattedDate(
                        style: dateStyle,
                        timeZone: TimeZone.current,
                        relativeTo: referenceDate
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .contentTransition(.numericText())
                    .clipped()
                }

                // Bottom row: Location and Time (baseline aligned)
                HStack(alignment: .lastTextBaseline) {
                    Text(String(localized: "Local"))
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: hasVisibleComplication ? 120 : .infinity, alignment: .leading)
                        .contentTransition(.numericText())

                    Spacer()

                    PulsingTimeText(timeText: RowTimeFormat.time(date: displayDate, offset: 0, timeZone: .current, use24Hour: use24HourFormat))
                        .font(.system(size: 36))
                        .fontWeight(.light)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .clipped()
                }
                .padding(.bottom, -4)

                // Available Time Display with Progress Indicator
                if showsAvailableTime {
                    AvailableTimeIndicator(
                        currentDate: displayDate,
                        timeOffset: 0,
                        availableStartTime: availableStartTime,
                        availableEndTime: availableEndTime,
                        use24HourFormat: use24HourFormat,
                        availableWeekdays: availableWeekdays
                    )
                }
            }
            .frame(minHeight: 64) // For Complication Overlays

            // Complication Overlays
            ComplicationOverlayView(
                date: displayDate,
                timeZone: TimeZone.current,
                options: complicationOptions,
                bottomPadding: showsAvailableTime ? 18 : 0
            )
            .environmentObject(weatherManager)
        }
        .animation(nil, value: complicationOptions)
        .contentShape(Rectangle())
    }
}

/// World clock (city) row content.
///
/// Thin wrapper: reads the per-frame time bindings, quantizes to the minute,
/// and hands plain values to `CityRowBody` so unchanged rows are pruned.
struct CityRowContent: View {
    let clock: WorldClock
    @Binding var currentDate: Date
    @Binding var timeOffset: TimeInterval
    let complicationOptions: ComplicationDisplayOptions
    @ObservedObject var weatherManager: WeatherManager

    var body: some View {
        CityRowBody(
            clock: clock,
            displayDate: RowTimeFormat.minuteQuantized(date: currentDate, offset: timeOffset),
            referenceDate: RowTimeFormat.minuteQuantized(date: currentDate, offset: 0),
            complicationOptions: complicationOptions,
            weatherManager: weatherManager
        )
        .equatable()
    }
}

fileprivate struct CityRowBody: View, Equatable {
    let clock: WorldClock
    let displayDate: Date
    let referenceDate: Date
    let complicationOptions: ComplicationDisplayOptions
    @ObservedObject var weatherManager: WeatherManager

    @AppStorage("dateStyle") private var dateStyle = "Relative"
    @AppStorage("additionalTimeDisplay") private var additionalTimeDisplay = "None"
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showWeather") private var showWeather = false
    @AppStorage("useCelsius") private var useCelsius = true

    // Dynamic properties (@AppStorage / @ObservedObject) invalidate the view
    // through their own dependency channel, so == only needs to cover the
    // plain inputs coming from the wrapper.
    static func == (lhs: CityRowBody, rhs: CityRowBody) -> Bool {
        lhs.clock == rhs.clock
            && lhs.displayDate == rhs.displayDate
            && lhs.referenceDate == rhs.referenceDate
            && lhs.complicationOptions == rhs.complicationOptions
    }

    private var hasVisibleComplication: Bool { complicationOptions.hasVisibleComplication }

    private var cityDateText: String {
        RowTimeFormat.cityDate(
            timeZoneIdentifier: clock.timeZoneIdentifier,
            displayDate: displayDate,
            referenceDate: referenceDate,
            dateStyle: dateStyle
        )
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 4) {
                // Top row: Additional time display and Date
                if additionalTimeDisplay != "None" {
                    HStack {
                        additionalTimeView

                        Spacer()

                        // Weather display for world clock
                        if showWeather {
                            WeatherView(
                                weather: weatherManager.weatherData[clock.timeZoneIdentifier],
                                useCelsius: useCelsius
                            )
                            .contentTransition(.numericText())
                        }

                        Text(cityDateText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .blendMode(.plusLighter)
                            .contentTransition(.numericText())
                            .clipped()
                    }
                } else {
                    HStack {
                        Spacer()

                        // Weather display for world clock (when time difference is hidden)
                        if showWeather {
                            WeatherView(
                                weather: weatherManager.weatherData[clock.timeZoneIdentifier],
                                useCelsius: useCelsius
                            )
                            .contentTransition(.numericText())
                        }

                        Text(cityDateText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText())
                            .clipped()
                    }
                }

                // Bottom row: City name and Time (baseline aligned)
                HStack(alignment: .lastTextBaseline) {
                    Text(clock.localizedCityName)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: hasVisibleComplication ? 120 : .infinity, alignment: .leading)
                        .contentTransition(.numericText())

                    Spacer()

                    PulsingTimeText(timeText: RowTimeFormat.time(
                        date: displayDate,
                        offset: 0,
                        timeZone: TimeZone(identifier: clock.timeZoneIdentifier) ?? .current,
                        use24Hour: use24HourFormat
                    ))
                    .font(.system(size: 36))
                    .fontWeight(.light)
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .clipped()
                }
                .padding(.bottom, -4)
            }
            .frame(minHeight: 64) // For Complication Overlays

            // Complication Overlays
            ComplicationOverlayView(
                date: displayDate,
                timeZone: TimeZone(identifier: clock.timeZoneIdentifier) ?? TimeZone.current,
                options: complicationOptions,
                bottomPadding: 0
            )
            .environmentObject(weatherManager)
        }
        .animation(nil, value: complicationOptions)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var additionalTimeView: some View {
        if additionalTimeDisplay == "Weekday" {
            if let weekday = RowTimeFormat.weekdayDisplay(
                for: clock.timeZoneIdentifier,
                baseDate: displayDate,
                offset: 0
            ) {
                HStack(spacing: 5) {
                    Text(weekday.previous)
                        .font(.caption.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .blendMode(.plusLighter)
                        .contentTransition(.numericText())

                    Text(weekday.current)
                        .font(.caption.weight(.bold))
                        .fontDesign(.rounded)
                        .foregroundStyle(Color.white)
                        .frame(width: 20, height: 16)
                        .glassEffect(.clear, in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                        .contentTransition(.numericText())

                    Text(weekday.next)
                        .font(.caption.weight(.semibold))
                        .fontDesign(.rounded)
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .blendMode(.plusLighter)
                        .contentTransition(.numericText())
                }
            }
        } else {
            let text = RowTimeFormat.additionalText(
                for: clock,
                display: additionalTimeDisplay,
                baseDate: displayDate,
                offset: 0
            )
            if !text.isEmpty || additionalTimeDisplay == "UTC" {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
            }
        }
    }
}
