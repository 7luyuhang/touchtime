//
//  CityAnalogueView.swift
//  touchtimeWatch
//

import SwiftUI

/// The city's time on a watch face as big as the daylight ring with its hours
/// around it: the hours on a glass ring, fading from the city's hour now, or
/// counting the seconds round it once it's tapped, and inside the ring its
/// Additional Time, or the time while the Digital Crown shows another, over its
/// day. The hands sweep round rather than tick, and as the Digital Crown moves
/// the time an hour at a time, only the hour hand turns, the minute and second
/// hands fading out where they are until it's back at now, which it takes the
/// short way round to.
struct CityAnalogueView: View {
    let date: Date
    let timeZone: TimeZone
    /// Whether the city is Local, whose time shift is always empty.
    let isLocal: Bool
    /// While the Digital Crown shows another time, the hands stop at it.
    let isAdjusting: Bool
    /// Now, while the Digital Crown shows another time.
    var referenceDate: Date? = nil

    @Environment(\.locale) private var locale
    @Environment(\.isLuminanceReduced) private var isLuminanceReduced
    @AppStorage(AdditionalTime.storageKey) private var additionalTime: AdditionalTime = .timeShift
    @AppStorage(WatchTimeFormat.use24HourFormatKey) private var use24HourFormat = WatchTimeFormat.systemUses24HourFormat
    /// Whole turns of the hour hand the hands are ahead of the time, or behind
    /// it, from going the short way back to now from the time the Digital
    /// Crown showed rather than back the way the time went.
    @State private var turnsAhead: Double = 0
    /// The time the Digital Crown showed last.
    @State private var lastAdjustedDate: Date?
    /// Whether the ring counts the seconds round it: a tick for each second
    /// round its outer edge, every fifth one longer, and inside them the
    /// seconds in fives, as bright as each other.
    @State private var showsSeconds = false

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

    /// The hands' time as VoiceOver reads a clock's digits, with AM or PM.
    private var spokenTime: String {
        let time = WatchTimeFormat.time(date, in: timeZone, use24HourFormat: use24HourFormat)
        return [time.digits, time.period].compactMap { $0 }.joined(separator: " ")
    }

    /// How far the city is from the watch's time zone, or from UTC, or while
    /// the Digital Crown shows another time, that time, which the hands show
    /// only to the hour. Local's time shift gives way to its location, as in
    /// the list.
    @ViewBuilder
    private var additionalTimeLabel: some View {
        if isLocal && additionalTime == .timeShift && !isAdjusting {
            Image(systemName: "location.fill")
                .accessibilityHidden(true)
                .transition(.blurReplace)
        } else {
            let text = isAdjusting
                ? WatchTimeFormat.time(date, in: timeZone, use24HourFormat: use24HourFormat).digits
                : additionalTime.text(for: timeZone, at: date)

            // One text for both, so that it rolls from one to the other.
            Text(text)
                // Read first already, as the hands' time.
                .accessibilityHidden(isAdjusting)
                .transition(.blurReplace)
        }
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
                ZStack {
                    glassRing(layout: layout)
                        .accessibilityHidden(true)

                    // Clear of the middle by as much above as below.
                    ZStack {
                        additionalTimeLabel
                            .frame(width: layout.textWidth)
                            .position(x: layout.center.x, y: layout.center.y - layout.innerRadius * 0.47)

                        Text(dayLabel)
                            .textCase(.uppercase)
                            .frame(width: layout.textWidth)
                            .position(x: layout.center.x, y: layout.center.y + layout.innerRadius * 0.47)
                    }
                    .font(.system(.body, design: .rounded, weight: .medium))
                    .contentTransition(.numericText())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    // Any larger and they run into the hands' middle.
                    .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel { label in
                        Text(spokenTime)
                        label
                    }
                }
                // Cut out inside the hands' bars, which the sky shows in.
                .mask {
                    TimelineView(.animation(paused: isAdjusting || isLuminanceReduced)) { context in
                        hands(at: context.date, turns: turns, layout: layout, isCutout: true)
                    }
                }

                // Not while the hands stop at the time the Digital Crown
                // shows, nor once the screen dims with the wrist down.
                TimelineView(.animation(paused: isAdjusting || isLuminanceReduced)) { context in
                    hands(at: context.date, turns: turns, layout: layout)
                }
                .accessibilityHidden(true)
                // Taps on the ring under them reach it.
                .allowsHitTesting(false)
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

    /// The hands as they are at `timelineDate`, their timeline's date, or the
    /// cutout of their bars that the dial under them is masked to.
    private func hands(
        at timelineDate: Date,
        turns: Double,
        layout: AnalogueDialLayout,
        isCutout: Bool = false
    ) -> AnalogueHands {
        AnalogueHands(
            // With the wrist down the hands keep to the minute, but never
            // back from where they stopped.
            now: DialTime(isLuminanceReduced ? max(timelineDate, date) : timelineDate, in: timeZone)
                .turned(by: turns),
            shown: DialTime(date, in: timeZone).turned(by: turns),
            adjustment: isAdjusting ? 1 : 0,
            showsSecondHand: !isLuminanceReduced,
            layout: layout,
            isCutout: isCutout
        )
    }

    /// The hours upright around the glass ring, fading from the city's hour
    /// now, or the seconds in fives inside a tick for each second round its
    /// edge, which tapping the ring brings in and takes away.
    private func glassRing(layout: AnalogueDialLayout) -> some View {
        ZStack {
            ForEach(0..<60, id: \.self) { second in
                let length = showsSeconds ? (second % 5 == 0 ? layout.majorTickLength : layout.tickLength) : 0

                // Turned round the ring's middle rather than in a frame of
                // its own, whose edges would round to whole pixels, leaving
                // some ticks a pixel wider or longer than others.
                RadialBar(start: layout.tickOuterRadius - length, end: layout.tickOuterRadius, width: layout.tickWidth)
                    .fill(.white.opacity(second % 5 == 0 ? 1 : 0.25))
                    .opacity(showsSeconds ? 1 : 0)
                    .blendMode(.plusLighter)
                    .rotationEffect(.degrees(Double(second) * 6))
                    .animation(tickAnimation(second: second), value: showsSeconds)
            }

            ForEach(1...12, id: \.self) { hour in
                let number = showsSeconds ? hour * 5 : hour

                Text(verbatim: String(number))
                    .font(.system(size: layout.hourFontSize, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText(value: Double(number)))
                    .scaleEffect(showsSeconds ? layout.secondNumberScale : 1)
                    .foregroundStyle(.white.opacity(showsSeconds ? 1 : opacity(ofHour: hour)))
                    .blendMode(.plusLighter)
                    .position(layout.point(
                        atHour: hour,
                        radius: showsSeconds ? layout.secondNumberRadius : layout.hourRadius
                    ))
            }
        }
        // The brightness moves along to the next hour.
        .animation(.smooth, value: currentHour)
        .frame(width: layout.diameter, height: layout.diameter)
        .glassEffect(.regular.interactive(), in: layout.ring)
        .contentShape(layout.ring)
        .onTapGesture {
            withAnimation(.smooth) {
                showsSeconds.toggle()
            }
        }
        .sensoryFeedback(.impact(flexibility: .soft), trigger: showsSeconds)
    }

    /// The ticks come in one after another round from the top, and go back
    /// the other way, quicker.
    private func tickAnimation(second: Int) -> Animation {
        showsSeconds
            ? .smooth(duration: 0.35).delay(Double(second) / 60 * 0.4)
            : .smooth(duration: 0.25).delay(Double(59 - second) / 60 * 0.2)
    }

    /// The city's hour now at full brightness, each hour after it round the
    /// dial a step dimmer, down to a quarter for the hour before it.
    private func opacity(ofHour hour: Int) -> Double {
        let hoursAfter = (hour - currentHour + 12) % 12
        return 1 - 0.75 * Double(hoursAfter) / 11
    }
}

/// The face's measurements, in proportion to its diameter like a watch face's.
private struct AnalogueDialLayout {
    let diameter: CGFloat

    var radius: CGFloat { diameter / 2 }
    var center: CGPoint { CGPoint(x: radius, y: radius) }
    /// The glass ring the hours are on.
    var ringWidth: CGFloat { diameter * 0.177 }
    /// Inside the ring, where the day and Additional Time show.
    var innerRadius: CGFloat { radius - ringWidth }
    /// The day's and the Additional Time's, clear of the ring at their heights.
    var textWidth: CGFloat { innerRadius * 1.5 }
    /// Through the middle of the ring.
    var hourRadius: CGFloat { radius - ringWidth / 2 }
    var hourFontSize: CGFloat { ringWidth * 0.62 }
    /// The seconds' size, as the hours shrunk rather than set smaller, so
    /// that the numbers roll from one to the other in the same font.
    var secondNumberScale: CGFloat { 0.36 / 0.62 }
    /// A second's tick reaching in from just inside the ring's outer edge,
    /// every fifth one longer, as wide as the hands' lines.
    var tickOuterRadius: CGFloat { radius - ringWidth * 0.07 }
    var tickLength: CGFloat { ringWidth * 0.16 }
    var majorTickLength: CGFloat { ringWidth * 0.26 }
    var tickWidth: CGFloat { neckWidth }
    /// Halfway between the ring's inner edge and the longer ticks.
    var secondNumberRadius: CGFloat { (innerRadius + tickOuterRadius - majorTickLength) / 2 }

    /// From the middle to the hour and minute hands' bars.
    var neckLength: CGFloat { radius * 0.13 }
    var neckWidth: CGFloat { max(1, radius * 0.018) }
    var hourHandLength: CGFloat { radius * 0.545 }
    /// Over the hours on the ring.
    var minuteHandLength: CGFloat { radius * 0.925 }
    var handWidth: CGFloat { radius * 0.074 }
    /// The white around the bars' material, as wide as their necks.
    var handEdgeWidth: CGFloat { neckWidth }
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

    /// An hour or minute hand's bar, out from its neck to `length`.
    func handBar(length: CGFloat) -> RadialBar {
        RadialBar(start: neckLength, end: length, width: handWidth)
    }

    /// `radius` from the middle, `hour` hours clockwise from 12 at the top.
    func point(atHour hour: Int, radius: CGFloat) -> CGPoint {
        let angle = Double(hour) / 12 * 2 * .pi
        return CGPoint(x: center.x + radius * sin(angle), y: center.y - radius * cos(angle))
    }
}

/// The hands, sweeping round with the time now, or the hour hand stopped at
/// the time the Digital Crown shows. From one to the other, and from hour to
/// hour as the Digital Crown turns, the hour hand goes round through the hours
/// between. The minute and second hands only ever show now, fading out away
/// from it.
private struct AnalogueHands: View, Animatable {
    /// Now, to the frame.
    let now: DialTime
    /// The time the Digital Crown shows.
    var shown: DialTime
    /// From 0, now, to 1, the time the Digital Crown shows.
    var adjustment: Double
    let showsSecondHand: Bool
    let layout: AnalogueDialLayout
    /// Rather than the hands, everywhere but inside the hour and minute hands'
    /// bars, for the dial under them to be masked to so the sky shows in them.
    var isCutout = false

    var animatableData: AnimatablePair<AnimatablePair<Double, Double>, Double> {
        get { AnimatablePair(AnimatablePair(shown.hours, shown.minutes), adjustment) }
        set {
            shown = DialTime(hours: newValue.first.first, minutes: newValue.first.second)
            adjustment = newValue.second
        }
    }

    var body: some View {
        let time = now.moved(toward: shown, by: adjustment)
        let minuteBar = layout.handBar(length: layout.minuteHandLength)
            .rotationEffect(now.minuteAngle)
            .opacity(1 - adjustment)

        if isCutout {
            cutout {
                layout.handBar(length: layout.hourHandLength)
                    .rotationEffect(time.hourAngle)
                minuteBar
            }
        } else {
            hands(at: time, under: minuteBar)
        }
    }

    private func hands(at time: DialTime, under minuteBar: some View) -> some View {
        ZStack {
            AnalogueHand(length: layout.hourHandLength, layout: layout)
                .rotationEffect(time.hourAngle)
                // Under the minute hand's bar, as the dial is.
                .mask { cutout { minuteBar } }
            AnalogueHand(length: layout.minuteHandLength, layout: layout)
                .rotationEffect(now.minuteAngle)
                .opacity(1 - adjustment)
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

    /// Everywhere but inside `bars`, out past the frame so as not to cut off
    /// the glass's edge.
    private func cutout(@ViewBuilder _ bars: () -> some View) -> some View {
        ZStack {
            Rectangle()
                .padding(-layout.radius)
            bars()
                .blendMode(.destinationOut)
        }
        .compositingGroup()
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
/// to a wider bar edged in white, empty inside for the sky to show in.
private struct AnalogueHand: View {
    let length: CGFloat
    let layout: AnalogueDialLayout

    var body: some View {
        let edge = layout.handEdgeWidth

        ZStack {
            // Into the bar's edge, leaving no seam, but short of its middle.
            RadialBar(start: 0, end: layout.neckLength + edge, width: layout.neckWidth)
                .fill(.white)
            layout.handBar(length: length)
                .strokeBorder(.white, lineWidth: edge)
        }
    }
}

/// A bar with round ends on the line up from the middle of its frame, from
/// `start` to `end` along it. Below the middle where `start` is negative.
private struct RadialBar: InsettableShape {
    var start: CGFloat
    var end: CGFloat
    let width: CGFloat
    var insetAmount: CGFloat = 0

    nonisolated var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(start, end) }
        set { (start, end) = (newValue.first, newValue.second) }
    }

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
        CityAnalogueView(date: .now, timeZone: .current, isLocal: true, isAdjusting: false)
            .ignoresSafeArea(edges: .bottom)
            .containerBackground(for: .navigation) {
                CitySkyBackground(date: .now, timeZone: .current)
            }
    }
}
