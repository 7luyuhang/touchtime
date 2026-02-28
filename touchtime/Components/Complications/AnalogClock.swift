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
    let useMaterialBackground: Bool
    let showScale: Bool
    
    @AppStorage("analogClockShowUTCHand") private var analogClockShowUTCHand = false
    
    init(date: Date = Date(), size: CGFloat = 100, timeZone: TimeZone = .current, useMaterialBackground: Bool = false, showScale: Bool = false) {
        self.date = date
        self.size = size
        self.timeZone = timeZone
        self.useMaterialBackground = useMaterialBackground
        self.showScale = showScale
    }
    
    @Environment(\.colorScheme) private var colorScheme
    
    private var displayTime: (hour: Int, minute: Int) {
        time(in: timeZone)
    }
    
    private var utcTime: (hour: Int, minute: Int) {
        time(in: utcTimeZone)
    }
    
    private var utcTimeZone: TimeZone {
        TimeZone(secondsFromGMT: 0) ?? .current
    }
    
    private var shouldShowUTCHand: Bool {
        analogClockShowUTCHand && timeZone.secondsFromGMT(for: date) != utcTimeZone.secondsFromGMT(for: date)
    }
    
    private func time(in zone: TimeZone) -> (hour: Int, minute: Int) {
        var calendar = Calendar.current
        calendar.timeZone = zone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0, components.minute ?? 0)
    }
    
    var body: some View {
        ZStack {
            // 表盘背景
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
            // 刻度标记（4个刻度：12、3、6、9点）
            if showScale {
                ForEach([0, 3, 6, 9], id: \.self) { hour in
                    Capsule()
                        .fill(.white.opacity(0.25))
                        .frame(width: 1.5, height: 8)
                        .offset(y: -size * 0.36)
                        .rotationEffect(.degrees(Double(hour) * 30))
                        .blendMode(.plusLighter)
                }
            }
            
            // UTC 时针
            if shouldShowUTCHand {
                Path { path in
                    let handWidth: CGFloat = 2
                    let handHeight = size * 0.45
                    let handRect = CGRect(
                        x: (size - handWidth) / 2,
                        y: size / 2 - size * 0.20 - handHeight / 2,
                        width: handWidth,
                        height: handHeight
                    )
                    let dotSize: CGFloat = 6
                    let dotRect = CGRect(
                        x: (size - dotSize) / 2,
                        y: handRect.minY - dotSize / 2,
                        width: dotSize,
                        height: dotSize
                    )
                    
                    path.addRoundedRect(
                        in: handRect,
                        cornerSize: CGSize(width: handWidth / 2, height: handWidth / 2)
                    )
                    path.addEllipse(in: dotRect)
                }
                .fill(.red)
                .rotationEffect(.degrees(Double(utcTime.hour % 12) * 30 + Double(utcTime.minute) * 0.5))
            }
            
            // 时针
            Capsule()
                .fill(.white)
                .frame(width: 2.5, height: size * 0.25)
                .offset(y: -size * 0.15)
                .rotationEffect(.degrees(Double(displayTime.hour % 12) * 30 + Double(displayTime.minute) * 0.5))
            
            // 分针
            Capsule()
                .fill(.white)
                .frame(width: 2, height: size * 0.45)
                .offset(y: -size * 0.20)
                .rotationEffect(.degrees(Double(displayTime.minute) * 6))
            
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
            .scaleEffect(4)
    }
    .padding()
}
