//
//  CityAnalogueView.swift
//  touchtimeWatch
//

import SwiftUI

/// The city's time on a watch face as big as the daylight ring with its hours
/// around it: the hours on a glass ring, the city's hour now brighter, and
/// inside the ring the city's time over its day. The hands sweep round rather
/// than tick, and as the Digital Crown moves the time an hour at a time, only
/// the hour hand turns, the second hand fading out until the hands are back at
/// now, which they take the short way round to.
struct CityAnalogueView: View {
    let date: Date
    let timeZone: TimeZone
    /// While the Digital Crown shows another time, the hands stop at it.
    let isAdjusting: Bool
    /// Now, while the Digital Crown shows another time.
    var referenceDate: Date? = nil

    @Environment(\.locale) private var locale
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    /// Whole turns of the hour hand the hands are ahead of the time, or behind
    /// it, from going the short way back to now from the time the Digital
    /// Crown showed rather than back the way the time went.
    @State private var turnsAhead: Double = 0
    /// The time the Digital Crown showed last.
    @State private var lastAdjustedDate: Date?

    /// The city's hour now, 1 to 12, which stays now while the Digital Crown
    /// shows another time, as on the daylight ring's hours.
    private var currentHour: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hour = calendar.component(.hour, from: referenceDate ?? date) % 12
        return hour == 0 ? 12 : hour
    }

    /// The day of the week and of the month, as a watch face's date shows them.
    private var dayLabel: String {
        date.formatted(Date.FormatStyle(locale: locale, timeZone: timeZone).weekday(.abbreviated).day())
    }

    /// On the way back to now, the turns ahead with those from now round to
    /// the time the Digital Crown showed last, so that the hour hand goes no
    /// more than half way round.
    private var handTurnsAhead: Double {
        guard !isAdjusting, let lastAdjustedDate else { return turnsAhead }
        return turnsAhead + DialTime(lastAdjustedDate, in: timeZone).turns(from: DialTime(date, in: timeZone))
    }

    var body: some View {
        GeometryReader { geometry in
            // As big as the border around the daylight ring's hours.
            let layout = AnalogueDialLayout(diameter: max(0, min(geometry.size.width - 16, geometry.size.height)))
            let turns = handTurnsAhead

            ZStack {
                hours(layout: layout)
                    .accessibilityHidden(true)

                // Clear of the middle by as much above as below, the taller
                // time set further out.
                ZStack {
                    ClockTimeText(date: date, timeZone: timeZone, size: .title)
                        .frame(width: layout.textWidth)
                        .position(x: layout.center.x, y: layout.center.y - layout.innerRadius * 0.5)

                    Text(dayLabel)
                        .font(.system(.body, design: .rounded, weight: .medium))
                        .textCase(.uppercase)
                        .contentTransition(.numericText())
                        .frame(width: layout.textWidth)
                        .position(x: layout.center.x, y: layout.center.y + layout.innerRadius * 0.47)
                }
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                // Any larger and they run into the hands' middle.
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .accessibilityElement(children: .combine)

                // Not while the hands stop at the time the Digital Crown
                // shows, nor once the screen dims with the wrist down.
                TimelineView(.animation(paused: isAdjusting || isLuminanceReduced)) { context in
                    AnalogueHands(
                        // With the wrist down the hands keep to the minute,
                        // but never back from where they stopped.
                        now: DialTime(isLuminanceReduced ? max(context.date, date) : context.date, in: timeZone)
                            .turned(by: turns),
                        shown: DialTime(date, in: timeZone).turned(by: turns),
                        adjustment: isAdjusting ? 1 : 0,
                        showsSecondHand: !isLuminanceReduced,
                        layout: layout
                    )
                }
                .accessibilityHidden(true)
            }
            .frame(width: layout.diameter, height: layout.diameter)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        // The circle's narrow top fits between the toolbar controls, as the
        // daylight ring's does.
        .padding(.top, -20)
        .padding(.bottom, 8)
        .onChange(of: date, initial: true) {
            if isAdjusting {
                lastAdjustedDate = date
            }
        }
        // Kept, so that the hands count on from the turn they went back to.
        .onChange(of: isAdjusting) {
            if !isAdjusting {
                turnsAhead = handTurnsAhead
                lastAdjustedDate = nil
            }
        }
    }

    /// Upright around the glass ring, the city's hour now brighter.
    private func hours(layout: AnalogueDialLayout) -> some View {
        ZStack {
            ForEach(1...12, id: \.self) { hour in
                Text(verbatim: String(hour))
                    .font(.system(size: layout.hourFontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(hour == currentHour ? 1 : 0.4))
                    .position(layout.point(atHour: hour, radius: layout.hourRadius))
            }
        }
        // The brightness moves along to the next hour.
        .animation(.smooth, value: currentHour)
        .frame(width: layout.diameter, height: layout.diameter)
        .glassEffect(.regular, in: layout.ring)
    }
}

/// The face's measurements, in proportion to its diameter like a watch face's.
private struct AnalogueDialLayout {
    let diameter: CGFloat

    var radius: CGFloat { diameter / 2 }
    var center: CGPoint { CGPoint(x: radius, y: radius) }
    /// The glass ring the hours are on.
    var ringWidth: CGFloat { diameter * 0.177 }
    /// Inside the ring, where the day and time show.
    var innerRadius: CGFloat { radius - ringWidth }
    /// The day's and the time's, clear of the ring at their heights.
    var textWidth: CGFloat { innerRadius * 1.5 }
    /// Through the middle of the ring.
    var hourRadius: CGFloat { radius - ringWidth / 2 }
    var hourFontSize: CGFloat { ringWidth * 0.69 }

    /// From the middle to the hour and minute hands' bars.
    var neckLength: CGFloat { radius * 0.13 }
    var neckWidth: CGFloat { max(1, radius * 0.018) }
    var hourHandLength: CGFloat { radius * 0.545 }
    /// Over the hours on the ring.
    var minuteHandLength: CGFloat { radius * 0.925 }
    var handWidth: CGFloat { radius * 0.074 }
    /// The white around the bars' material.
    var handEdgeWidth: CGFloat { max(1, radius * 0.012) }
    /// Almost to the dial's edge.
    var secondHandLength: CGFloat { radius * 0.98 }
    /// Back past the middle.
    var secondHandTail: CGFloat { radius * 0.142 }
    var secondHandWidth: CGFloat { max(1.5, radius * 0.011) }
    /// Where the hour and minute hands turn, under the second hand's.
    var capDiameter: CGFloat { radius * 0.074 }
    var secondCapDiameter: CGFloat { radius * 0.054 }
    var pinDiameter: CGFloat { radius * 0.019 }

    /// The glass ring, in a frame as wide as the dial.
    var ring: some Shape {
        Circle()
            .inset(by: ringWidth / 2)
            .stroke(style: StrokeStyle(lineWidth: ringWidth))
    }

    /// `radius` from the middle, `hour` hours clockwise from 12 at the top.
    func point(atHour hour: Int, radius: CGFloat) -> CGPoint {
        let angle = Double(hour) / 12 * 2 * .pi
        return CGPoint(x: center.x + radius * sin(angle), y: center.y - radius * cos(angle))
    }
}

/// The hands, sweeping round with the time now, or stopped at the time the
/// Digital Crown shows. From one to the other, and from hour to hour as the
/// Digital Crown turns, the hour hand goes round through the hours between,
/// and the minute hand only the short way to its minute. The second hand,
/// which only ever shows now, fades out away from it.
private struct AnalogueHands: View, Animatable {
    /// Now, to the frame.
    let now: DialTime
    /// The time the Digital Crown shows.
    var shown: DialTime
    /// From 0, now, to 1, the time the Digital Crown shows.
    var adjustment: Double
    let showsSecondHand: Bool
    let layout: AnalogueDialLayout

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, Double> {
        get { AnimatablePair(AnimatablePair(shown.hours, shown.minutes), adjustment) }
        set {
            shown = DialTime(hours: newValue.first.first, minutes: newValue.first.second)
            adjustment = newValue.second
        }
    }

    var body: some View {
        let time = now.moved(toward: shown, by: adjustment)

        ZStack {
            AnalogueHand(length: layout.hourHandLength, layout: layout)
                .rotationEffect(time.hourAngle)
            AnalogueHand(length: layout.minuteHandLength, layout: layout)
                .rotationEffect(time.minuteAngle)
            Circle()
                .fill(.white)
                .frame(width: layout.capDiameter, height: layout.capDiameter)

            ZStack {
                RadialBar(start: -layout.secondHandTail, end: layout.secondHandLength, width: layout.secondHandWidth)
                    .fill(.red)
                Circle()
                    .fill(.red)
                    .frame(width: layout.secondCapDiameter, height: layout.secondCapDiameter)
            }
            .rotationEffect(now.secondAngle)
            .opacity(showsSecondHand ? 1 - adjustment : 0)

            Circle()
                .fill(.black)
                .frame(width: layout.pinDiameter, height: layout.pinDiameter)
        }
        .frame(width: layout.diameter, height: layout.diameter)
    }
}

/// A time on the city's clock as the whole hour nearest it, counted from the
/// reference date, and the minutes either side of that hour. Moved toward
/// another time, each moves on its own: whole hours apart, only the hour hand
/// turns, and the minute hand never goes more than half way round.
private struct DialTime {
    var hours: Double
    var minutes: Double

    /// Within a turn, as a CGFloat on 32-bit watches can't hold a count of
    /// every turn since the reference date.
    var hourAngle: Angle {
        .degrees((hours.truncatingRemainder(dividingBy: 12) + minutes / 60) * 30)
    }

    var minuteAngle: Angle {
        .degrees(minutes * 6)
    }

    var secondAngle: Angle {
        .degrees((minutes * 60).truncatingRemainder(dividingBy: 60) * 6)
    }

    /// The whole turns of the hour hand from `other` round to this time, to
    /// the nearest turn.
    func turns(from other: DialTime) -> Double {
        ((hours - other.hours + (minutes - other.minutes) / 60) / 12).rounded()
    }

    /// The same place on the dial, `turns` whole turns of the hour hand on.
    func turned(by turns: Double) -> DialTime {
        DialTime(hours: hours + turns * 12, minutes: minutes)
    }

    /// `amount` of the way from this time to `other`.
    func moved(toward other: DialTime, by amount: Double) -> DialTime {
        DialTime(
            hours: hours + (other.hours - hours) * amount,
            minutes: minutes + (other.minutes - minutes) * amount
        )
    }
}

extension DialTime {
    init(_ date: Date, in timeZone: TimeZone) {
        let seconds = date.timeIntervalSinceReferenceDate + Double(timeZone.secondsFromGMT(for: date))
        hours = (seconds / 3600).rounded()
        minutes = (seconds - hours * 3600) / 60
    }
}

/// An hour or minute hand pointing up from the dial's middle: a white neck out
/// to a wider bar edged in white, darkening what shows through it.
private struct AnalogueHand: View {
    let length: CGFloat
    let layout: AnalogueDialLayout

    var body: some View {
        let edge = layout.handEdgeWidth
        let bar = RadialBar(start: layout.neckLength, end: length, width: layout.handWidth)

        ZStack {
            // Into the bar's edge, leaving no seam, but short of its middle,
            // which it would show through.
            RadialBar(start: 0, end: layout.neckLength + edge, width: layout.neckWidth)
                .fill(.white)
            bar
                .fill(.black.opacity(0.1))
                .blendMode(.plusDarker)
            bar
                .strokeBorder(.white, lineWidth: edge)
        }
    }
}

/// A bar with round ends on the line up from the middle of its frame, from
/// `start` to `end` along it. Below the middle where `start` is negative.
private struct RadialBar: InsettableShape {
    let start: CGFloat
    let end: CGFloat
    let width: CGFloat
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        Capsule(style: .circular).path(in: CGRect(
            x: rect.midX - width / 2,
            y: rect.midY - end,
            width: width,
            height: end - start
        ).insetBy(dx: insetAmount, dy: insetAmount))
    }

    func inset(by amount: CGFloat) -> RadialBar {
        var bar = self
        bar.insetAmount += amount
        return bar
    }
}

#Preview {
    NavigationStack {
        CityAnalogueView(date: .now, timeZone: .current, isAdjusting: false)
            .ignoresSafeArea(edges: .bottom)
            .containerBackground(for: .navigation) {
                CitySkyBackground(date: .now, timeZone: .current)
            }
    }
}
