//
//  DSTClockDial.swift
//  touchtime
//
//  Created on 17/10/2026.
//

import SwiftUI

/// A 12-hour clock with hour, minute and second hands, and the time in digits
/// in its lower half. Given an `hourHandShift`, it also sweeps the range the
/// hour hand jumped over, drawn like the timer's set range.
struct DSTClockDial: View {
    let date: Date
    /// The clock's offset from UTC, in seconds
    let secondsFromGMT: Int
    let use24HourFormat: Bool
    /// How far the clock was moved, in seconds: negative when it went back
    var hourHandShift: Int = 0

    /// Seconds since midnight on this clock, with the fraction, so the second
    /// hand sweeps rather than ticks
    private var secondsIntoDay: Double {
        let seconds = (date.timeIntervalSince1970 + Double(secondsFromGMT)).truncatingRemainder(dividingBy: 86_400)
        return seconds < 0 ? seconds + 86_400 : seconds
    }

    // Degrees clockwise from 12
    private var hourAngle: Double { secondsIntoDay.truncatingRemainder(dividingBy: 43_200) / 120 }
    private var minuteAngle: Double { secondsIntoDay.truncatingRemainder(dividingBy: 3_600) / 10 }
    private var secondAngle: Double { secondsIntoDay.truncatingRemainder(dividingBy: 60) * 6 }

    /// e.g. "13:38", or "1:38" on a 12-hour clock
    private var timeText: String {
        let hour = Int(secondsIntoDay / 3_600)
        let minute = Int(secondsIntoDay / 60) % 60
        guard !use24HourFormat else { return String(format: "%02d:%02d", hour, minute) }
        return String(format: "%d:%02d", hour % 12 == 0 ? 12 : hour % 12, minute)
    }

    var body: some View {
        GeometryReader { proxy in
            dial(size: min(proxy.size.width, proxy.size.height))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(timeText)
    }

    private func dial(size: CGFloat) -> some View {
        ZStack {
            DialFace(size: size)

            if hourHandShift != 0 {
                let angleBeforeShift = hourAngle - Double(hourHandShift) / 120
                HourHandSweep(
                    startAngle: min(angleBeforeShift, hourAngle),
                    endAngle: max(angleBeforeShift, hourAngle),
                    size: size
                )
            }

            Text(timeText)
                .font(.footnote.weight(.semibold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)
                .contentTransition(.numericText())
                .animation(.spring(), value: timeText)
                .offset(y: size * 0.175)

            hand(angle: hourAngle, width: size * 0.02, length: size * 0.25)
            hand(angle: minuteAngle, width: size * 0.02, length: size * 0.35)

            Circle()
                .fill(.white)
                .frame(width: size * 0.055, height: size * 0.055)

            secondHand(size: size)
        }
        .frame(width: size, height: size)
    }

    private func hand(angle: Double, width: CGFloat, length: CGFloat) -> some View {
        Capsule()
            .fill(.white)
            .frame(width: width, height: length)
            .offset(y: -length / 2)
            .rotationEffect(.degrees(angle))
    }

    private func secondHand(size: CGFloat) -> some View {
        let length = size * 0.445
        let tailLength = size * 0.08
        // `.orange` (#FF9230 in dark mode) as plain RGB: the system color blends
        // with the white hands and hub it passes over, making them show through
        let color = Color(red: 1, green: 146 / 255, blue: 48 / 255)

        return ZStack {
            Capsule()
                .fill(color)
                .frame(width: 1.5, height: length + tailLength)
                .offset(y: -(length - tailLength) / 2)

            Circle()
                .fill(color)
                .frame(width: size * 0.035, height: size * 0.035)
        }
        .rotationEffect(.degrees(secondAngle))
    }
}

/// The glass face and its hour numbers, which never change with the time.
private struct DialFace: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.10))
                .glassEffect(.clear, in: Circle())

            ForEach(1..<13, id: \.self) { hour in
                let radians = (Double(hour) * 30 - 90) * .pi / 180

                Text("\(hour)")
                    .font(.system(size: size * 0.115, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .offset(x: size * 0.375 * cos(radians), y: size * 0.375 * sin(radians))
            }
        }
        .frame(width: size, height: size)
    }
}

/// A range on the dial: the sector fading out from the center, the arc along
/// the rim and the two edge lines.
private struct HourHandSweep: View {
    // Degrees clockwise from 12; `endAngle` is the larger
    let startAngle: Double
    let endAngle: Double
    let size: CGFloat

    private var center: CGPoint { CGPoint(x: size / 2, y: size / 2) }
    private var radius: CGFloat { size / 2 }

    private func addRimArc(to path: inout Path) {
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(startAngle - 90),
            endAngle: .degrees(endAngle - 90),
            clockwise: false
        )
    }

    var body: some View {
        ZStack {
            Path { path in
                path.move(to: center)
                addRimArc(to: &path)
                path.closeSubpath()
            }
            .fill(
                RadialGradient(
                    colors: [.white.opacity(0.10), .white.opacity(0)],
                    center: .center,
                    startRadius: 0,
                    endRadius: radius
                )
            )
            .blendMode(.plusLighter)

            Path { path in
                addRimArc(to: &path)
            }
            .stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))

            edgeLine(at: startAngle)
            edgeLine(at: endAngle)
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
    }

    private func edgeLine(at angle: Double) -> some View {
        let length = radius * 0.7
        let radians = (angle - 90) * .pi / 180
        let end = UnitPoint(
            x: 0.5 + (length / size) * CGFloat(cos(radians)),
            y: 0.5 + (length / size) * CGFloat(sin(radians))
        )

        return Path { path in
            path.move(to: center)
            path.addLine(to: CGPoint(x: end.x * size, y: end.y * size))
        }
        .stroke(
            LinearGradient(
                colors: [.white.opacity(0.25), .white.opacity(0)],
                startPoint: .center,
                endPoint: end
            ),
            style: StrokeStyle(lineWidth: 1.25, lineCap: .round)
        )
        .blendMode(.plusLighter)
    }
}

#Preview {
    HStack(spacing: 24) {
        DSTClockDial(date: .now, secondsFromGMT: 3_600, use24HourFormat: true)
        DSTClockDial(date: .now, secondsFromGMT: 0, use24HourFormat: true, hourHandShift: -3_600)
    }
    .frame(height: 160)
    .padding()
    .preferredColorScheme(.dark)
}
