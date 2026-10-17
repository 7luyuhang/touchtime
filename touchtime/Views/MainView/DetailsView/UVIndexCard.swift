//
//  UVIndexCard.swift
//  touchtime
//
//  Created on 15/10/2026.
//

import SwiftUI
import WeatherKit

/// UV index and its category over the rest of the day's outlook (left)
/// + UV index complication (right)
struct UVIndexCard: View {
    let uvIndex: UVIndex
    let dailyWeather: DayWeather?
    let hourlyWeather: [HourWeather]
    let currentDate: Date
    let timeZoneIdentifier: String
    let dateFormat: DetailsDateFormat

    var body: some View {
        let complicationSize: CGFloat = 64
        // e.g. "4 · Moderate"
        let indexText = "\(uvIndex.value) · \(categoryName(uvIndex.category))"
        let summary = restOfDaySummary

        HStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    Text("UV Index")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                        .lineLimit(1)

                    Spacer()

                    Text(indexText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .animation(.spring(), value: indexText)
                }

                Divider()
                    .overlay(.white.opacity(0.10))
                    .blendMode(.plusLighter)

                Text(summary)
                    .font(.body)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentTransition(.numericText())
                    .animation(.spring(), value: summary)
            }

            Color.clear
                .frame(width: complicationSize, height: complicationSize)
        }
        .detailsSheetCard()
        // Over the card rather than in it: the card's plusLighter blend would
        // add the glass's copy of the sky back onto the sky and wash it out
        .overlay(alignment: .trailing) {
            UVIndexIndicator(
                timeZone: TimeZone(identifier: timeZoneIdentifier) ?? .current,
                size: complicationSize
            )
            .overlay(
                Circle()
                    .stroke(.white.opacity(0.1), lineWidth: 1)
                    .blendMode(.plusLighter)
            )
            .padding(.trailing, 16)
        }
    }

    private func categoryName(_ category: UVIndex.ExposureCategory) -> String {
        switch category {
        case .low:
            return String(localized: "Low")
        case .moderate:
            return String(localized: "Moderate")
        case .high:
            return String(localized: "High")
        case .veryHigh:
            return String(localized: "Very High")
        case .extreme:
            return String(localized: "Extreme")
        }
    }

    // UV outlook for the rest of the city's day, e.g. "Use sun protection
    // 10:00–16:00". Sun protection is advised from Moderate (UV index 3) up.
    private var restOfDaySummary: String {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: currentDate)) ?? currentDate
        let currentCategory = uvIndex.category

        // The current hour goes by the current reading, so the text agrees
        // with the index shown above it
        let protectionHours = hourlyWeather.filter { hour in
            let hourEnd = hour.date.addingTimeInterval(3600)
            guard hourEnd > currentDate && hour.date < startOfTomorrow else { return false }
            let category = hour.date <= currentDate ? currentCategory : hour.uvIndex.category
            return category > .low
        }

        guard let firstHour = protectionHours.first, let lastHour = protectionHours.last else {
            let isLowAllDay = dailyWeather?.uvIndex.category == .low
            return isLowAllDay ? String(localized: "Low levels all day") : String(localized: "Low for the rest of the day")
        }

        let endTime = dateFormat.time(lastHour.date.addingTimeInterval(3600))
        if firstHour.date <= currentDate {
            return String(format: String(localized: "Use sun protection until %@"), endTime)
        }
        return String(format: String(localized: "Use sun protection %@–%@"), dateFormat.time(firstHour.date), endTime)
    }
}
