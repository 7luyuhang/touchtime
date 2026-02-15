//
//  WeatherManager.swift
//  touchtime
//
//  Created on 01/11/2025.
//

import Foundation
import WeatherKit
import CoreLocation
import Combine

@MainActor
class WeatherManager: ObservableObject {
    private let weatherService = WeatherService.shared
    
    @Published var weatherData: [String: CurrentWeather] = [:]
    @Published var dailyWeatherData: [String: DayWeather] = [:]
    @Published var weeklyWeatherData: [String: [DayWeather]] = [:]
    @Published var currentWeather: CurrentWeather?
    @Published var isLoading = false
    @Published var weatherError: Error?
    
    // Cache for weather data
    private var weatherCache: [String: (weather: CurrentWeather, daily: DayWeather?, weekly: [DayWeather], timestamp: Date)] = [:]
    private let cacheExpiration: TimeInterval = 3600 // 1 hour
    
    // Track in-flight fetches to avoid duplicate network requests
    private var inFlightFetches: Set<String> = []
    
    // Get weather for a specific timezone/city
    func getWeather(for timeZoneIdentifier: String) async {
        // Get coordinates for the timezone
        guard let location = getLocation(for: timeZoneIdentifier) else {
            return
        }
        
        // Check cache first
        let cacheKey = timeZoneIdentifier
        if let cached = weatherCache[cacheKey], 
           Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
            // Only update @Published if the data is actually different
            if self.weatherData[timeZoneIdentifier] == nil {
                self.weatherData[timeZoneIdentifier] = cached.weather
            }
            if let daily = cached.daily, self.dailyWeatherData[timeZoneIdentifier] == nil {
                self.dailyWeatherData[timeZoneIdentifier] = daily
            }
            if self.weeklyWeatherData[timeZoneIdentifier] == nil {
                self.weeklyWeatherData[timeZoneIdentifier] = cached.weekly
            }
            if timeZoneIdentifier == TimeZone.current.identifier && self.currentWeather == nil {
                self.currentWeather = cached.weather
            }
            return
        }
        
        // Skip if already fetching this city
        guard !inFlightFetches.contains(timeZoneIdentifier) else { return }
        inFlightFetches.insert(timeZoneIdentifier)
        defer { inFlightFetches.remove(timeZoneIdentifier) }
        
        isLoading = true
        weatherError = nil
        
        do {
            let weather = try await weatherService.weather(for: location)
            self.weatherData[timeZoneIdentifier] = weather.currentWeather
            
            // Get today's daily weather
            if let todayWeather = weather.dailyForecast.first {
                self.dailyWeatherData[timeZoneIdentifier] = todayWeather
            }
            
            // Get weekly forecast (up to 10 days)
            let weeklyForecast = Array(weather.dailyForecast.prefix(10))
            self.weeklyWeatherData[timeZoneIdentifier] = weeklyForecast
            
            // Also set currentWeather if it's the system timezone
            if timeZoneIdentifier == TimeZone.current.identifier {
                self.currentWeather = weather.currentWeather
            }
            
            // Update cache
            let dailyWeather = weather.dailyForecast.first
            weatherCache[cacheKey] = (weather.currentWeather, dailyWeather, weeklyForecast, Date())
            
        } catch {
            self.weatherError = error
            print("Failed to fetch weather for \(timeZoneIdentifier): \(error)")
        }
        
        isLoading = false
    }
    
    // Batch fetch weather for multiple cities - reduces @Published update notifications
    func getWeatherForCities(_ identifiers: [String]) async {
        // Separate cached vs needs-fetch
        var cachedResults: [(id: String, weather: CurrentWeather, daily: DayWeather?, weekly: [DayWeather])] = []
        var toFetch: [(id: String, location: CLLocation)] = []
        
        for id in identifiers {
            if let cached = weatherCache[id],
               Date().timeIntervalSince(cached.timestamp) < cacheExpiration {
                // Already have fresh data in @Published - skip entirely
                if weatherData[id] != nil { continue }
                cachedResults.append((id, cached.weather, cached.daily, cached.weekly))
            } else if !inFlightFetches.contains(id),
                      let location = getLocation(for: id) {
                toFetch.append((id, location))
            }
        }
        
        // Apply cached results in a single synchronous block
        if !cachedResults.isEmpty {
            var newWeatherData = weatherData
            var newDailyData = dailyWeatherData
            var newWeeklyData = weeklyWeatherData
            for item in cachedResults {
                newWeatherData[item.id] = item.weather
                if let daily = item.daily { newDailyData[item.id] = daily }
                newWeeklyData[item.id] = item.weekly
            }
            weatherData = newWeatherData
            dailyWeatherData = newDailyData
            weeklyWeatherData = newWeeklyData
        }
        
        guard !toFetch.isEmpty else { return }
        
        // Mark all as in-flight
        for item in toFetch { inFlightFetches.insert(item.id) }
        defer { for item in toFetch { inFlightFetches.remove(item.id) } }
        
        isLoading = true
        
        // Fetch all in sequence, collect results, then apply at once
        var fetchedResults: [(id: String, current: CurrentWeather, daily: DayWeather?, weekly: [DayWeather])] = []
        
        for item in toFetch {
            do {
                let weather = try await weatherService.weather(for: item.location)
                let daily = weather.dailyForecast.first
                let weekly = Array(weather.dailyForecast.prefix(10))
                weatherCache[item.id] = (weather.currentWeather, daily, weekly, Date())
                fetchedResults.append((item.id, weather.currentWeather, daily, weekly))
            } catch {
                print("Failed to fetch weather for \(item.id): \(error)")
            }
        }
        
        // Apply all fetched results at once to minimize @Published notifications
        if !fetchedResults.isEmpty {
            var newWeatherData = weatherData
            var newDailyData = dailyWeatherData
            var newWeeklyData = weeklyWeatherData
            for item in fetchedResults {
                newWeatherData[item.id] = item.current
                if let daily = item.daily { newDailyData[item.id] = daily }
                newWeeklyData[item.id] = item.weekly
                if item.id == TimeZone.current.identifier {
                    currentWeather = item.current
                }
            }
            weatherData = newWeatherData
            dailyWeatherData = newDailyData
            weeklyWeatherData = newWeeklyData
        }
        
        isLoading = false
    }
    
    // Get location (CLLocation) from timezone identifier
    private func getLocation(for timeZoneIdentifier: String) -> CLLocation? {
        // Get coordinates from timezone
        if let coords = TimeZoneCoordinates.getCoordinate(for: timeZoneIdentifier) {
            return CLLocation(latitude: coords.0, longitude: coords.1)
        }
        
        // For current location, try to get from CoreLocation
        // For now, we'll just return nil if not found in our database
        return nil
    }
    
    // Format temperature for display
    func formatTemperature(_ temperature: Measurement<UnitTemperature>, celsius: Bool = false) -> String {
        let formatter = MeasurementFormatter()
        formatter.numberFormatter.maximumFractionDigits = 0
        
        if celsius {
            formatter.unitOptions = .providedUnit
            return formatter.string(from: temperature.converted(to: .celsius))
        } else {
            formatter.unitOptions = .providedUnit
            return formatter.string(from: temperature.converted(to: .fahrenheit))
        }
    }
}
