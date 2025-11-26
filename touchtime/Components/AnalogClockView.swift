//
//  AnalogClock.swift
//  touchtime
//
//  Created on 28/10/2025.
//
//  Testing

import SwiftUI

struct AnalogClockView: View {
    let date: Date
    let size: CGFloat
    let timeZone: TimeZone
    
    init(date: Date = Date(), size: CGFloat = 100, timeZone: TimeZone = .current) {
        self.date = date
        self.size = size
        self.timeZone = timeZone
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var time: (hour: Int, minute: Int) {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0, components.minute ?? 0)
    }
    
    var body: some View {
        ZStack {
            // 表盘背景
            Circle()
                .fill(Color.black.opacity(0.25))
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.05))
                        .glassEffect(.clear)
                )
            
            
//             时刻标记
//            ForEach(0..<12) { hour in
//                Capsule()
//                    .fill(hour % 3 == 0 ? .white : .white.opacity(0.5))
//                    .frame(width: hour % 3 == 0 ? 2 : 1, height: hour % 3 == 0 ? 6 : 6)
//                    .offset(y: -size * 0.4)
//                    .rotationEffect(.degrees(Double(hour) * 30))
//                    .blendMode(.plusLighter)
//            }
            
            // 时针
            Capsule()
                .fill(.white)
                .frame(width: 2.5, height: size * 0.25)
                .offset(y: -size * 0.15)
                .rotationEffect(.degrees(Double(time.hour % 12) * 30 + Double(time.minute) * 0.5))
            
            // 分针
            Capsule()
                .fill(.white)
                .frame(width: 2, height: size * 0.5)
                .offset(y: -size * 0.2)
                .rotationEffect(.degrees(Double(time.minute) * 6))
            
            
            // 中心点
            Circle()
                .fill(.white)
                .frame(width: 6, height: 6)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    HStack {
        AnalogClockView(size: 64)
//            .scaleEffect(4)
    }
    .padding()
}
