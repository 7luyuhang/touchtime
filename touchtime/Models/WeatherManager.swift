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
    @Published var currentWeather: CurrentWeather?
    @Published var isLoading = false
    @Published var weatherError: Error?
    
    // Cache for weather data
    private var weatherCache: [String: (weather: CurrentWeather, timestamp: Date)] = [:]
    private let cacheExpiration: TimeInterval = 3600 // 1 hour
    
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
            self.weatherData[timeZoneIdentifier] = cached.weather
            // Also set currentWeather if it's the system timezone
            if timeZoneIdentifier == TimeZone.current.identifier {
                self.currentWeather = cached.weather
            }
            return
        }
        
        isLoading = true
        weatherError = nil
        
        do {
            let weather = try await weatherService.weather(for: location)
            self.weatherData[timeZoneIdentifier] = weather.currentWeather
            
            // Also set currentWeather if it's the system timezone
            if timeZoneIdentifier == TimeZone.current.identifier {
                self.currentWeather = weather.currentWeather
            }
            
            // Update cache
            weatherCache[cacheKey] = (weather.currentWeather, Date())
            
        } catch {
            self.weatherError = error
            print("Failed to fetch weather for \(timeZoneIdentifier): \(error)")
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
