//
//  SecondsDial.swift
//  touchtimeWatch
//

import SwiftUI

/// The analogue face's ring as it counts the seconds round it once tapped,
/// outlined rather than glass: a tick for each one round its outer edge,
/// every fifth one longer, and inside them the fives, in two figures, from
/// 00 at the top rather than 60. The timer's and the stopwatch's.
struct SecondsDial: View {
    /// The ring's edges, and the timer's boxes' unless focused.
    static let lineColor = Color.white.opacity(0.2)

    let layout: AnalogueDialLayout
    /// How many ticks are lit, from the top.
    var litTicks = 0
    /// The tick a dot stands in for.
    var hiddenTick: Int?

    var body: some View {
        ZStack {
            layout.ring
                .stroke(Self.lineColor, lineWidth: 1)

            ForEach(0..<60, id: \.self) { tick in
                let isLit = tick < litTicks
                RadialBar(
                    start: layout.tickOuterRadius - (tick % 5 == 0 ? layout.majorTickLength : layout.tickLength),
                    end: layout.tickOuterRadius,
                    width: layout.tickWidth
                )
                // The shorter ticks as bright on black as the face's are on
                // its glass
                .fill(isLit ? Color.orange : .white.opacity(tick % 5 == 0 ? 1 : 0.375))
                .opacity(tick == hiddenTick ? 0 : 1)
                .rotationEffect(.degrees(Double(tick) * 6))
                .animation(tickAnimation(tick: tick, isLit: isLit), value: isLit)
            }

            ForEach(1...12, id: \.self) { hour in
                Text(verbatim: String(format: "%02d", hour * 5 % 60))
                    // Shrunk as the face's seconds are, rather than set
                    // smaller, so they look the same
                    .font(.system(size: layout.hourFontSize, weight: .semibold, design: .rounded))
                    .scaleEffect(layout.secondNumberScale)
                    .foregroundStyle(.white)
                    .position(layout.point(atHour: hour, radius: layout.secondNumberRadius))
            }
        }
        .frame(width: layout.diameter, height: layout.diameter)
    }

    /// The ticks light one after another round from the top, and go out the
    /// other way, quicker, as the face's seconds come in and go.
    private func tickAnimation(tick: Int, isLit: Bool) -> Animation {
        isLit
            ? .smooth(duration: 0.35).delay(Double(tick) / 60 * 0.4)
            : .smooth(duration: 0.25).delay(Double(59 - tick) / 60 * 0.2)
    }
}
