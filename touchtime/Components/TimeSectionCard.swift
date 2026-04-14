//
//  TimePreviewCard.swift
//  MainSettings Preview, OnboardingView
//
//  Created on 12/04/2026.
//

import SwiftUI
import WeatherKit

struct TimePreviewCard<OverlayContent: View>: View {
    private struct WeekdayDisplay {
        let previous: String
        let current: String
        let next: String
    }

    let date: Date
    let timeZoneIdentifier: String
    let weatherCondition: WeatherCondition?
    let showSkyDot: Bool
    let additionalTimeDisplay: String
    let additionalTimeText: String
    let showWeather: Bool
    let weather: CurrentWeather?
    let useCelsius: Bool
    let dateText: String
    let cityText: String
    let timeText: String
    @ViewBuilder let overlayContent: () -> OverlayContent

    private var resolvedTimeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    private var weekdayDisplay: WeekdayDisplay {
        var calendar = Calendar.current
        calendar.timeZone = resolvedTimeZone

        let previousDate = calendar.date(byAdding: .day, value: -1, to: date) ?? date.addingTimeInterval(-86_400)
        let nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86_400)

        return WeekdayDisplay(
            previous: weekdaySymbol(for: calendar.component(.weekday, from: previousDate)),
            current: weekdaySymbol(for: calendar.component(.weekday, from: date)),
            next: weekdaySymbol(for: calendar.component(.weekday, from: nextDate))
        )
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if showSkyDot && additionalTimeDisplay == "None" {
                        SkyDotView(
                            date: date,
                            timeZoneIdentifier: timeZoneIdentifier,
                            weatherCondition: weatherCondition
                        )
                        .overlay(
                            Capsule(style: .continuous)
                                .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
                                .blendMode(.plusLighter)
                        )
                        .transition(.blurReplace)
                    }

                    if additionalTimeDisplay != "None" {
                        additionalTimeView
                    }

                    Spacer()

                    if showWeather {
                        WeatherView(
                            weather: weather,
                            useCelsius: useCelsius
                        )
                        .transition(.blurReplace)
                    }

                    Text(dateText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                        .contentTransition(.numericText())
                }
                .animation(.spring(), value: showSkyDot)
                .animation(.spring(), value: showWeather)

                HStack(alignment: .lastTextBaseline) {
                    Text(cityText)
                        .font(.headline)

                    Spacer()

                    Text(timeText)
                        .font(.system(size: 36))
                        .fontWeight(.light)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .padding()
            .padding(.bottom, -4)

            overlayContent()
        }
        .background(
            showSkyDot ?
            ZStack {
                Color.black
                SkyBackgroundView(
                    date: date,
                    timeZoneIdentifier: timeZoneIdentifier,
                    weatherCondition: weatherCondition
                )
            } : nil
        )
        .clipShape(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
        .glassEffect(
            .clear.interactive(),
            in: RoundedRectangle(cornerRadius: 26, style: .continuous)
        )
    }

    @ViewBuilder
    private var additionalTimeView: some View {
        if additionalTimeDisplay == "Weekday" {
            HStack(spacing: 5) {
                Text(weekdayDisplay.previous)
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

                Text(weekdayDisplay.current)
                    .font(.caption.weight(.bold))
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.white)
                    .frame(width: 20, height: 16)
                    .background(.black.opacity(0.20), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                    .contentTransition(.numericText())

                Text(weekdayDisplay.next)
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
        } else {
            Text(additionalTimeText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)
        }
    }

    private func weekdaySymbol(for weekday: Int) -> String {
        switch weekday {
        case 1:
            return String(localized: "Sun")
        case 2:
            return String(localized: "Mon")
        case 3:
            return String(localized: "Tue")
        case 4:
            return String(localized: "Wed")
        case 5:
            return String(localized: "Thu")
        case 6:
            return String(localized: "Fri")
        case 7:
            return String(localized: "Sat")
        default:
            return ""
        }
    }
}
