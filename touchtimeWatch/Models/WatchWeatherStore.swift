//
//  WatchWeatherStore.swift
//  touchtimeWatch
//
//  Each city's weather from WeatherKit, now and over the next day.
//

import CoreLocation
import Foundation
import Observation
import WeatherKit

/// A city's weather as it was fetched: its conditions now, and each hour's
/// from the hour under way to a day later.
struct CityWeather {
    struct Conditions: Equatable {
        let temperature: Measurement<UnitTemperature>
        let condition: WeatherCondition
        let isDaylight: Bool
    }

    let current: Conditions
    /// By the start of each hour.
    let hours: [Date: Conditions]
    let fetchDate: Date
}

/// The weather where each city's time zone is, as the iPhone app looks it up,
/// kept while the app runs and fetched again once it's half an hour old.
@Observable
final class WatchWeatherStore {
    private static let maxAge: TimeInterval = 30 * 60

    /// By time zone identifier.
    private(set) var weather: [String: CityWeather]
    /// The time zones whose weather couldn't be fetched, until it's tried again.
    private(set) var unavailableTimeZones: Set<String> = []
    @ObservationIgnored private var fetchingTimeZones: Set<String> = []

    init(weather: [String: CityWeather] = [:]) {
        self.weather = weather
    }

    /// The start of the hour `date` is in. Forecast hours start on UTC's
    /// hours, which are half an hour off the clock's in some cities.
    static func hourStart(of date: Date) -> Date {
        Date(timeIntervalSinceReferenceDate: (date.timeIntervalSinceReferenceDate / 3600).rounded(.down) * 3600)
    }

    /// Fetches `timeZone`'s weather, unless it's recent or already on its way.
    func update(for timeZone: TimeZone) {
        let identifier = timeZone.identifier
        if let cached = weather[identifier], Date.now.timeIntervalSince(cached.fetchDate) < Self.maxAge {
            return
        }
        guard !fetchingTimeZones.contains(identifier) else { return }
        guard let coordinate = TimeZoneCoordinates.getCoordinate(for: identifier) else {
            unavailableTimeZones.insert(identifier)
            return
        }
        fetchingTimeZones.insert(identifier)
        unavailableTimeZones.remove(identifier)

        // Not the view's task, so leaving the view doesn't cancel the fetch.
        Task {
            defer { fetchingTimeZones.remove(identifier) }
            let hourStart = Self.hourStart(of: .now)
            do {
                let (current, forecast) = try await WeatherService.shared.weather(
                    for: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                    including: .current,
                    .hourly(startDate: hourStart, endDate: hourStart.addingTimeInterval(24 * 3600))
                )
                var hours: [Date: CityWeather.Conditions] = [:]
                for hour in forecast {
                    // To the nearest hour, should one start a moment off it.
                    hours[Self.hourStart(of: hour.date.addingTimeInterval(1800))] = CityWeather.Conditions(
                        temperature: hour.temperature,
                        condition: hour.condition,
                        isDaylight: hour.isDaylight
                    )
                }
                weather[identifier] = CityWeather(
                    current: CityWeather.Conditions(
                        temperature: current.temperature,
                        condition: current.condition,
                        isDaylight: current.isDaylight
                    ),
                    hours: hours,
                    fetchDate: .now
                )
            } catch {
                print("Failed to fetch weather for \(identifier): \(error)")
                // Older weather still beats none.
                if weather[identifier] == nil {
                    unavailableTimeZones.insert(identifier)
                }
            }
        }
    }
}
