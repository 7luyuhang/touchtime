//
//  HourNumbersView.swift
//  touchtime
//
//  Created on 28/11/2025.
//

import SwiftUI

struct HourNumbersView: View {
    let size: CGFloat
    let isFolded: Bool

    private var numberFont: Font {
        isFolded ? .body.weight(.semibold) : .title3.weight(.medium)
    }
    
    var body: some View {
        Group {
            // Hour numbers - Right side (1-12 for hours 0-12)
            ForEach(1..<13, id: \.self) { hour in
                let angle = Double(hour) * 15.0 - 90 // 15 degrees per hour, starting from top
                let radius = size / 2 - 36
                let x = radius * cos(angle * .pi / 180)
                let y = radius * sin(angle * .pi / 180)
                
                Text("\(hour)")
                    .font(numberFont)
                    .fontDesign(.rounded)
                    .foregroundColor(.white)
                    .position(x: size / 2 + x, y: size / 2 + y)
            }
            
            // Hour numbers - Left side (1-12 for hours 12-24)
            ForEach(1..<13, id: \.self) { hour in
                let displayHour = hour
                let angle = Double(hour + 12) * 15.0 - 90 // Continue from 12, 15 degrees per hour
                let radius = size / 2 - 36
                let x = radius * cos(angle * .pi / 180)
                let y = radius * sin(angle * .pi / 180)
                
                Text("\(displayHour)")
                    .font(numberFont)
                    .fontDesign(.rounded)
                    .foregroundColor(.white)
                    .position(x: size / 2 + x, y: size / 2 + y)
            }
        }
    }
}
