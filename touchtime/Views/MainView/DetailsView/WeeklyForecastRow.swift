//
//  WeeklyForecastRow.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import SwiftUI
import WeatherKit

/// Shared sizing keeps the daily and hourly forecast cards interchangeable.
enum ForecastCardMetrics {
    static let width: CGFloat = 64
    static let contentHeight: CGFloat = 100
}

/// The coming days' highs, lows and conditions, scrolling sideways.
struct WeeklyForecastRow: View {
    let days: [DayWeather]
    let timeZoneIdentifier: String
    let currentDate: Date
    @Binding var isHourlyForecastShown: Bool

    @AppStorage("useCelsius") private var useCelsius = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    let showsHourlyDisclosure = isToday(day.date)

                    if showsHourlyDisclosure {
                        Button {
                            if hapticEnabled {
                                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                            }
                            withAnimation(.snappy(duration: 0.5)) {
                                isHourlyForecastShown = true
                            }
                        } label: {
                            dayCard(day, isToday: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Today"))
                    } else {
                        dayCard(day, isToday: false)
                    }
                }
            }
        }
        .horizontalScrollEdgeFade()
        // The fade mask composites the row offscreen, so the cards'
        // plusLighter blend is reapplied to the whole row
        .blendMode(.plusLighter)
    }

    private func dayCard(_ day: DayWeather, isToday: Bool) -> some View {
        VStack(spacing: 5) {
            // High temperature
            let highTemp = useCelsius ?
            day.highTemperature.converted(to: .celsius) :
            day.highTemperature.converted(to: .fahrenheit)
            Text("\(Int(highTemp.value))°")
                .font(.subheadline.weight(.medium))
                .monospacedDigit()

            // Low temperature
            let lowTemp = useCelsius ?
            day.lowTemperature.converted(to: .celsius) :
            day.lowTemperature.converted(to: .fahrenheit)
            Text("\(Int(lowTemp.value))°")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)
                .monospacedDigit()

            // Weather icon
            Image(systemName: day.condition.icon)
                .symbolRenderingMode(.multicolor)
                .font(.title3)
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)
                .frame(height: 28)

            // Day of week. Only today's card is an hourly disclosure control.
            HStack(spacing: 3) {
                Text(dayOfWeek(day.date))

                if isToday {
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(isToday ? Color.primary : Color.secondary)
            .blendMode(.plusLighter)
            .padding(.top, 5)
        }
        .frame(
            width: ForecastCardMetrics.width,
            height: ForecastCardMetrics.contentHeight
        )
        .padding(.vertical, 12)
        .detailsSheetCardChrome()
        .contentShape(Rectangle())
    }

    private func isToday(_ date: Date) -> Bool {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        return calendar.isDate(date, inSameDayAs: currentDate)
    }

    private func dayOfWeek(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.locale = Locale.current

        // Use very short weekday format (M, T, W, etc.)
        formatter.dateFormat = "EEEEE"
        return formatter.string(from: date)
    }
}
