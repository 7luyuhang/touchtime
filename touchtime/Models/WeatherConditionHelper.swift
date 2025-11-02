//
//  WeatherConditionHelper.swift
//  touchtime
//
//  Created on 2/11/2025.
//

import SwiftUI
import WeatherKit

extension WeatherCondition {
    
    // Get SF Symbol icon for weather condition
    var icon: String {
        switch self {
        // Clear conditions
        case .clear:
            return "sun.max.fill"
        case .mostlyClear:
            return "sun.max.fill"
            
        // Cloudy conditions
        case .partlyCloudy:
            return "cloud.sun.fill"
        case .mostlyCloudy:
            return "cloud.sun.fill"
        case .cloudy:
            return "cloud.fill"
            
        // Visibility conditions
        case .foggy:
            return "cloud.fog.fill"
        case .haze:
            return "sun.haze.fill"
        case .smoky:
            return "smoke.fill"
        case .blowingDust:
            return "sun.dust.fill"
            
        // Wind conditions
        case .breezy:
            return "wind"
        case .windy:
            return "wind"
            
        // Rain conditions
        case .drizzle:
            return "cloud.drizzle.fill"
        case .rain:
            return "cloud.rain.fill"
        case .heavyRain:
            return "cloud.heavyrain.fill"
        case .sunShowers:
            return "cloud.sun.rain.fill"
            
        // Thunderstorm conditions
        case .isolatedThunderstorms:
            return "cloud.bolt.rain.fill"
        case .scatteredThunderstorms:
            return "cloud.bolt.rain.fill"
        case .strongStorms:
            return "cloud.bolt.fill"
        case .thunderstorms:
            return "cloud.bolt.rain.fill"
            
        // Winter conditions
        case .flurries:
            return "cloud.snow.fill"
        case .snow:
            return "cloud.snow.fill"
        case .heavySnow:
            return "cloud.snow.fill"
        case .sunFlurries:
            return "sun.snow.fill"
        case .blowingSnow:
            return "wind.snow"
        case .freezingDrizzle:
            return "cloud.sleet.fill"
        case .freezingRain:
            return "cloud.sleet.fill"
        case .sleet:
            return "cloud.sleet.fill"
        case .wintryMix:
            return "cloud.sleet.fill"
        case .blizzard:
            return "snow"
            
        // Hazardous conditions
        case .hail:
            return "cloud.hail.fill"
        case .hot:
            return "thermometer.sun.fill"
        case .frigid:
            return "thermometer.snowflake"
            
        // Tropical conditions
        case .hurricane:
            return "hurricane"
        case .tropicalStorm:
            return "tropicalstorm"
            
        @unknown default:
            return "cloud.fill"
        }
    }
    
    // Format weather condition name for display
    var displayName: String {
        switch self {
        case .clear:
            return "Clear"
        case .mostlyClear:
            return "Mostly Clear"
        case .partlyCloudy:
            return "Partly Cloudy"
        case .mostlyCloudy:
            return "Mostly Cloudy"
        case .cloudy:
            return "Cloudy"
        case .foggy:
            return "Foggy"
        case .haze:
            return "Haze"
        case .smoky:
            return "Smoky"
        case .blowingDust:
            return "Blowing Dust"
        case .breezy:
            return "Breezy"
        case .windy:
            return "Windy"
        case .drizzle:
            return "Drizzle"
        case .rain:
            return "Rain"
        case .heavyRain:
            return "Heavy Rain"
        case .sunShowers:
            return "Sun Showers"
        case .isolatedThunderstorms:
            return "Isolated Thunderstorms"
        case .scatteredThunderstorms:
            return "Scattered Thunderstorms"
        case .strongStorms:
            return "Strong Storms"
        case .thunderstorms:
            return "Thunderstorms"
        case .flurries:
            return "Flurries"
        case .snow:
            return "Snow"
        case .heavySnow:
            return "Heavy Snow"
        case .sunFlurries:
            return "Sun Flurries"
        case .blowingSnow:
            return "Blowing Snow"
        case .freezingDrizzle:
            return "Freezing Drizzle"
        case .freezingRain:
            return "Freezing Rain"
        case .sleet:
            return "Sleet"
        case .wintryMix:
            return "Wintry Mix"
        case .blizzard:
            return "Blizzard"
        case .hail:
            return "Hail"
        case .hot:
            return "Hot"
        case .frigid:
            return "Frigid"
        case .hurricane:
            return "Hurricane"
        case .tropicalStorm:
            return "Tropical Storm"
        @unknown default:
            return "Unknown"
        }
    }
}
