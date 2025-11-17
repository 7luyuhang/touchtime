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
            return String(localized: "Clear")
        case .mostlyClear:
            return String(localized: "Mostly Clear")
        case .partlyCloudy:
            return String(localized: "Partly Cloudy")
        case .mostlyCloudy:
            return String(localized: "Mostly Cloudy")
        case .cloudy:
            return String(localized: "Cloudy")
        case .foggy:
            return String(localized: "Foggy")
        case .haze:
            return String(localized: "Haze")
        case .smoky:
            return String(localized: "Smoky")
        case .blowingDust:
            return String(localized: "Blowing Dust")
        case .breezy:
            return String(localized: "Breezy")
        case .windy:
            return String(localized: "Windy")
        case .drizzle:
            return String(localized: "Drizzle")
        case .rain:
            return String(localized: "Rain")
        case .heavyRain:
            return String(localized: "Heavy Rain")
        case .sunShowers:
            return String(localized: "Sun Showers")
        case .isolatedThunderstorms:
            return String(localized: "Isolated Thunderstorms")
        case .scatteredThunderstorms:
            return String(localized: "Scattered Thunderstorms")
        case .strongStorms:
            return String(localized: "Strong Storms")
        case .thunderstorms:
            return String(localized: "Thunderstorms")
        case .flurries:
            return String(localized: "Flurries")
        case .snow:
            return String(localized: "Snow")
        case .heavySnow:
            return String(localized: "Heavy Snow")
        case .sunFlurries:
            return String(localized: "Sun Flurries")
        case .blowingSnow:
            return String(localized: "Blowing Snow")
        case .freezingDrizzle:
            return String(localized: "Freezing Drizzle")
        case .freezingRain:
            return String(localized: "Freezing Rain")
        case .sleet:
            return String(localized: "Sleet")
        case .wintryMix:
            return String(localized: "Wintry Mix")
        case .blizzard:
            return String(localized: "Blizzard")
        case .hail:
            return String(localized: "Hail")
        case .hot:
            return String(localized: "Hot")
        case .frigid:
            return String(localized: "Frigid")
        case .hurricane:
            return String(localized: "Hurricane")
        case .tropicalStorm:
            return String(localized: "Tropical Storm")
        @unknown default:
            return String(localized: "Unknown")
        }
    }
}
