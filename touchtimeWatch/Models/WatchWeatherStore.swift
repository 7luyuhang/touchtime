//
//  WatchWeatherStore.swift
//  touchtimeWatch
//
//  Each city's weather from WeatherKit: now, over the next day, and over the
//  days ahead.
//

import CoreLocation
import Foundation
import Observation
import WeatherKit

/// A city's weather as it was fetched: its conditions and wind now, each
/// hour's conditions from the hour under way to a day later, and each day's
/// from today.
struct CityWeather {
    struct Conditions: Equatable {
        let temperature: Measurement<UnitTemperature>
        let condition: WeatherCondition
        let isDaylight: Bool
    }

    struct Wind: Equatable {
        /// Where the wind comes from, in degrees clockwise from north.
        let direction: Double
        let speed: Measurement<UnitSpeed>
        /// Nil when the forecast has none.
        let gust: Measurement<UnitSpeed>?
    }

    struct Day: Equatable {
        /// The city's midnight at the start of the day.
        let date: Date
        let highTemperature: Measurement<UnitTemperature>
        let lowTemperature: Measurement<UnitTemperature>
        let condition: WeatherCondition
    }

    let current: Conditions
    let wind: Wind
    /// By the start of each hour.
    let hours: [Date: Conditions]
    /// From today, in order.
    let days: [Day]
    let fetchDate: Date
}

/// The weather where each city's time zone is, as the iPhone app looks it up,
/// kept while the app runs and fetched again once it's half an hour old. And
/// for Wind's live compass, the wind where the watch is, fetched again sooner.
@Observable
final class WatchWeatherStore {
    /// The wind where the watch was, as it was fetched.
    struct LiveWind {
        let wind: CityWeather.Wind
        let location: CLLocation
        let fetchDate: Date
    }

    private static let maxAge: TimeInterval = 30 * 60
    private static let liveWindMaxAge: TimeInterval = 10 * 60
    /// How far the watch goes before the wind where it was no longer stands
    /// for the wind where it is.
    private static let liveWindRange: CLLocationDistance = 5000

    /// By time zone identifier.
    private(set) var weather: [String: CityWeather]
    /// The time zones whose weather couldn't be fetched, until it's tried again.
    private(set) var unavailableTimeZones: Set<String> = []
    /// The wind where the watch was when it was last fetched.
    private(set) var liveWind: LiveWind?
    @ObservationIgnored private var fetchingTimeZones: Set<String> = []
    @ObservationIgnored private var isFetchingLiveWind = false

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
                let (current, forecast, dailyForecast) = try await WeatherService.shared.weather(
                    for: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                    including: .current,
                    .hourly(startDate: hourStart, endDate: hourStart.addingTimeInterval(24 * 3600)),
                    .daily
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
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = timeZone
                let days = dailyForecast.map { day in
                    CityWeather.Day(
                        // The city's day most of the forecast's falls in,
                        // should their midnights differ.
                        date: calendar.startOfDay(for: day.date.addingTimeInterval(12 * 3600)),
                        highTemperature: day.highTemperature,
                        lowTemperature: day.lowTemperature,
                        condition: day.condition
                    )
                }
                weather[identifier] = CityWeather(
                    current: CityWeather.Conditions(
                        temperature: current.temperature,
                        condition: current.condition,
                        isDaylight: current.isDaylight
                    ),
                    wind: CityWeather.Wind(current.wind),
                    hours: hours,
                    days: days,
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

    /// Fetches the wind at `location`, where the watch is, unless it was
    /// fetched near there recently, or is already on its way.
    func updateLiveWind(at location: CLLocation) {
        if let liveWind,
           Date.now.timeIntervalSince(liveWind.fetchDate) < Self.liveWindMaxAge,
           liveWind.location.distance(from: location) < Self.liveWindRange {
            return
        }
        guard !isFetchingLiveWind else { return }
        isFetchingLiveWind = true

        Task {
            defer { isFetchingLiveWind = false }
            do {
                let current = try await WeatherService.shared.weather(for: location, including: .current)
                liveWind = LiveWind(wind: CityWeather.Wind(current.wind), location: location, fetchDate: .now)
            } catch {
                // The city's wind stands in.
                print("Failed to fetch the wind where the watch is: \(error)")
            }
        }
    }
}

private extension CityWeather.Wind {
    init(_ wind: WeatherKit.Wind) {
        self.init(
            direction: wind.direction.converted(to: .degrees).value,
            speed: wind.speed,
            gust: wind.gust
        )
    }
}
