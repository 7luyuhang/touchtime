//
//  WeatherConditionView.swift
//  touchtime
//
//  Created on 14/12/2025.
//

import SwiftUI
import WeatherKit

struct WeatherConditionView: View {
    let timeZone: TimeZone
    let size: CGFloat
    let useMaterialBackground: Bool
    
    @EnvironmentObject private var weatherManager: WeatherManager
    
    init(timeZone: TimeZone = .current, size: CGFloat = 100, useMaterialBackground: Bool = false) {
        self.timeZone = timeZone
        self.size = size
        self.useMaterialBackground = useMaterialBackground
    }
    
    private var weatherCondition: WeatherCondition? {
        weatherManager.weatherData[timeZone.identifier]?.condition
    }
    
    private var iconName: String {
        weatherCondition?.icon ?? "cloud.fill"
    }
    
    var body: some View {
        ZStack {
            // Background
            if useMaterialBackground {
                Circle()
                    .fill(.black.opacity(0.05))
                    .blendMode(.plusDarker)
            } else {
                Circle()
                    .fill(.clear)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.10))
                            .glassEffect(.clear)
                    )
            }
            
            // Weather Condition Icon
            Image(systemName: iconName)
                .font(.system(size: size * 0.325, weight: .regular))
                .foregroundStyle(.white)
                .symbolRenderingMode(.hierarchical)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: size, height: size)
        .task {
            await weatherManager.getWeather(for: timeZone.identifier)
        }
    }
}

#Preview {
    ZStack {
        Color.black
            .ignoresSafeArea()
        
        HStack(spacing: 40) {
            WeatherConditionView(
                timeZone: .current,
                size: 64
            )
            .environmentObject(WeatherManager())
            
            AnalogClockView(
                date: Date(),
                size: 64,
                timeZone: .current
            )
        }
    }
}

