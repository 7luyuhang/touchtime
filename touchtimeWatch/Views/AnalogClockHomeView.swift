//
//  AnalogClockHomeView.swift
//  touchtimeWatch
//
//  The iPhone app's analog clock, one city at a time, on a sheet over the
//  list. Tapping a dot moves on to its city. Turning the Digital Crown moves
//  the time an hour at a time, as on a city's details.
//

import SwiftUI

struct AnalogClockHomeView: View {
    let cities: [ClockCity]
    /// The time every clock shows in place of now, or nil for now.
    @Binding var adjustedDate: Date?

    @Environment(WatchCityStore.self) private var cityStore
    @Environment(\.dismiss) private var dismiss
    /// The city on the clock, kept across launches.
    @AppStorage("analogClockCityID") private var cityID = ClockCity.localID
    /// How many hours the Digital Crown has moved.
    @State private var crownSteps: Double = 0
    /// The time the Digital Crown's steps count from: the clocks' time when
    /// it last rested at zero, or nil for now.
    @State private var crownStart: Date?
    /// Freeze "now" on the first step so minute ticks cannot shift the adjustment.
    @State private var crownReferenceDate: Date?
    @FocusState private var isCrownFocused: Bool

    /// A year in either direction, as on a city's details.
    private static let crownRange: Double = 24 * 365

    /// The city on the clock, or the first once it's gone from the list.
    private var cityIndex: Int {
        cities.firstIndex { $0.id == cityID } ?? 0
    }

    var body: some View {
        let city = cities[cityIndex]

        NavigationStack {
            TimelineView(.everyMinute) { context in
                let date = adjustedDate ?? context.date

                GeometryReader { geometry in
                    AnalogClockDial(
                        city: city,
                        cities: cities,
                        date: date,
                        now: context.date,
                        dateStyle: cityStore.dateStyle,
                        layout: AnalogClockDialLayout(
                            diameter: max(0, min(geometry.size.width - 16, geometry.size.height - 12))
                        ),
                        onDotTap: { cityID = $0.id }
                    )
                    .frame(width: geometry.size.width, height: geometry.size.height)
                }
                // The circle's narrow top fits between the toolbar controls.
                .padding(.top, -24)
                .ignoresSafeArea(edges: .bottom)
                .containerBackground(for: .navigation) {
                    CitySkyBackground(date: date, timeZone: city.timeZone)
                }
                .animation(.smooth, value: adjustedDate)
            }
            .accessibilityElement(children: .combine)
            .accessibilityAction {
                showNextCity()
            }
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment:
                    crownSteps += 1
                case .decrement:
                    crownSteps -= 1
                @unknown default:
                    break
                }
            }
            .focusable()
            .focused($isCrownFocused)
            .digitalCrownRotation(
                $crownSteps,
                from: -Self.crownRange,
                through: Self.crownRange,
                by: 1,
                sensitivity: .medium,
                isContinuous: false,
                isHapticFeedbackEnabled: true
            )
            .toolbar {
                // In place of the sheet's own close button. While adjusting
                // time, a reset button takes the list button's place, as it
                // takes the back button's on a city's details.
                ToolbarItem(placement: .cancellationAction) {
                    if adjustedDate != nil {
                        Button("Current Time", systemImage: "xmark", action: showCurrentTime)
                    } else {
                        Button("Cities", systemImage: "list.bullet") {
                            dismiss()
                        }
                    }
                }
            }
            .toolbarForegroundStyle(.primary, for: .navigationBar)
            .onChange(of: Int(crownSteps.rounded())) { _, steps in
                if steps == 0 {
                    adjustedDate = crownStart
                    crownReferenceDate = nil
                } else {
                    let referenceDate = crownReferenceDate ?? crownStart ?? .now
                    crownReferenceDate = referenceDate
                    adjustedDate = crownDate(steps, from: referenceDate, in: city.timeZone)
                }
            }
            .onAppear {
                crownStart = adjustedDate
                isCrownFocused = true
            }
        }
    }

    private func showNextCity() {
        cityID = cities[(cityIndex + 1) % cities.count].id
    }

    /// Back to now on every clock, with the Digital Crown at rest.
    private func showCurrentTime() {
        withAnimation(.smooth) {
            crownStart = nil
            crownReferenceDate = nil
            crownSteps = 0
            adjustedDate = nil
        }
    }

    /// `steps` whole hours on from `date`, on the city's clock.
    private func crownDate(_ steps: Int, from date: Date, in timeZone: TimeZone) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let hourStart = calendar.dateInterval(of: .hour, for: date)?.start ?? date
        // Turning back, the start of the hour under way is the first stop.
        let hours = steps < 0 && hourStart < date ? steps + 1 : steps
        return hourStart.addingTimeInterval(TimeInterval(hours) * 3600)
    }
}

/// The dial's measurements, laid out like the sun dial's: the hours' band
/// keeps its width on every watch, and the cities' track scales with the
/// diameter.
private struct AnalogClockDialLayout {
    static let hourBandWidth: CGFloat = 16
    static let lineWidth: CGFloat = 1

    let diameter: CGFloat

    var center: CGPoint { CGPoint(x: diameter / 2, y: diameter / 2) }
    /// The dial's edge, inset to keep its line inside.
    var edgeRadius: CGFloat { (diameter - Self.lineWidth) / 2 }
    /// Through the middle of the hours' band.
    var hourRadius: CGFloat { (diameter - Self.hourBandWidth) / 2 }
    /// Between neighboring hours, center to center.
    var hourSpacing: CGFloat { 2 * hourRadius * sin(.pi / 24) }
    /// The city on the clock's dot, just clear of the lines either side.
    var selectedDotDiameter: CGFloat { diameter * 0.085 }
    /// Every other city's dot.
    var dotDiameter: CGFloat { selectedDotDiameter * 0.3 }
    /// The track the cities' times travel, inside the hours' band.
    var trackOuterRadius: CGFloat { diameter / 2 - Self.hourBandWidth }
    var trackInnerRadius: CGFloat { trackOuterRadius - selectedDotDiameter - Self.lineWidth }
    var orbitRadius: CGFloat { (trackOuterRadius + trackInnerRadius) / 2 }
    /// Inside the track, where the time, the city and its day show.
    var innerDiameter: CGFloat { trackInnerRadius * 2 }

    /// `radius` from the center, `hour` hours clockwise from midnight at the top.
    func point(atHour hour: Double, radius: CGFloat) -> CGPoint {
        let angle = hour / 24 * 2 * .pi
        return CGPoint(x: center.x + radius * sin(angle), y: center.y - radius * cos(angle))
    }
}

/// A city's 24-hour dial, midnight at the top: the hours around the outside,
/// the city's hour now on a pill, and inside them the track where every
/// city's time shows as a dot, crossed at the city's sunrise and sunset and
/// lit between them, around the city's time, name and day.
private struct AnalogClockDial: View {
    /// The rings', lightening the sky behind them, as on the sun dial.
    private static let lineColor = Color.white.opacity(0.1)
    /// How far from a dot a tap still picks it, as the dots are much smaller
    /// than a fingertip.
    private static let dotReach: CGFloat = 22

    let city: ClockCity
    let cities: [ClockCity]
    let date: Date
    let now: Date
    let dateStyle: String
    let layout: AnalogClockDialLayout
    /// Called with the city to show for a tap on a dot.
    let onDotTap: (ClockCity) -> Void

    /// The time in UTC around the dial, counting whole turns so the dots
    /// always move the shorter way around, past midnight included.
    @State private var displayedAngle: Double?
    /// The current hour's pill around the dial, in degrees, counting whole
    /// turns in the same way.
    @State private var pillAngle: Double?

    /// Across the dial's bottom half, an hour turns over to read left to right
    /// rather than upside down.
    private static func isTurnedOver(_ hour: Int) -> Bool {
        hour > 6 && hour < 18
    }

    /// The city's hour now, which stays now while the Digital Crown shows
    /// another time, as on the daylight ring's hours.
    private var currentHour: Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = city.timeZone
        return calendar.component(.hour, from: now)
    }

    /// The time in UTC, in degrees clockwise from midnight.
    private var utcAngle: Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 86400) / 240
    }

    /// Where `dotCity`'s time shows, in degrees clockwise from midnight, with
    /// the time in UTC at `utcAngle`.
    private func angle(of dotCity: ClockCity, at utcAngle: Double) -> Double {
        utcAngle + Double(dotCity.timeZone.secondsFromGMT(for: date)) / 240
    }

    /// The cities whose times show as dots: the first in the list at each
    /// time, as cities at one time share a dot.
    private var dotCities: [ClockCity] {
        var offsets = Set<Int>()
        return cities.filter { offsets.insert($0.timeZone.secondsFromGMT(for: date)).inserted }
    }

    /// The city to show for a tap at `location`: the nearest dot's, if the
    /// tap is within reach of it. A dot stands for every city at its time:
    /// the first of them, or with the clock already on one, the next.
    private func city(tappedAt location: CGPoint) -> ClockCity? {
        let utcAngle = utcAngle
        func distance(to dotCity: ClockCity) -> CGFloat {
            let dot = layout.point(atHour: angle(of: dotCity, at: utcAngle) / 15, radius: layout.orbitRadius)
            return hypot(dot.x - location.x, dot.y - location.y)
        }
        guard let dotCity = dotCities.min(by: { distance(to: $0) < distance(to: $1) }),
              distance(to: dotCity) <= Self.dotReach else { return nil }

        let offset = dotCity.timeZone.secondsFromGMT(for: date)
        let citiesAtDot = cities.filter { $0.timeZone.secondsFromGMT(for: date) == offset }
        guard let index = citiesAtDot.firstIndex(where: { $0.id == city.id }) else { return dotCity }
        return citiesAtDot[(index + 1) % citiesAtDot.count]
    }

    /// The city's day around the dial, in degrees clockwise from midnight:
    /// from sunrise to sunset, all the way around while the sun stays up, and
    /// none of it, at noon, while the sun stays down.
    private var daylight: (sunrise: Double, sunset: Double) {
        guard let coordinate = TimeZoneCoordinates.getCoordinate(for: city.timeZone.identifier) else { return (0, 360) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = city.timeZone
        guard let day = calendar.dateInterval(of: .day, for: date) else { return (0, 360) }

        let events = SolarCalculator.events(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            date: date,
            timeZone: city.timeZone
        )
        // On the clock, as the dots' times are
        func clockAngle(of event: Date) -> Double {
            let seconds = event.timeIntervalSinceReferenceDate + Double(city.timeZone.secondsFromGMT(for: event))
            return seconds.truncatingRemainder(dividingBy: 86400) / 240
        }
        // Polar night puts both at noon; polar day pins them to the day's ends
        guard events.sunrise < events.sunset else {
            let noon = clockAngle(of: events.solarNoon)
            return (noon, noon)
        }
        if events.sunrise <= day.start && events.sunset >= day.end.addingTimeInterval(-1) {
            return (0, 360)
        }
        let sunrise = clockAngle(of: events.sunrise)
        return (sunrise, sunrise + events.sunset.timeIntervalSince(events.sunrise) / 240)
    }

    var body: some View {
        let utcAngle = utcAngle
        let daylight = daylight
        let dateLabel = date.formattedDate(
            style: dateStyle, timeZone: city.timeZone, relativeTo: now, allowsWeekday: false
        )

        ZStack {
            TrackDay(layout: layout, sunrise: daylight.sunrise, sunset: daylight.sunset)
                .fill(.white.opacity(0.1))
                .blendMode(.plusLighter)

            DialLines(layout: layout, sunrise: daylight.sunrise, sunset: daylight.sunset)
                .stroke(Self.lineColor, lineWidth: AnalogClockDialLayout.lineWidth)
                .blendMode(.plusLighter)

            // Like the daylight ring's current hour, the city's hour now on a
            // pill, with the hours it covers cut out of it like the sun
            // dial's N, so it can move along them to another city's hour.
            let pill = DialHourPill(layout: layout, angle: pillAngle ?? Double(currentHour) * 15)
            ZStack {
                // Clear of the pill, so as not to fill its cutouts back in
                ZStack {
                    hours
                    pill.blendMode(.destinationOut)
                }
                .compositingGroup()

                ZStack {
                    pill
                    hours.blendMode(.destinationOut)
                }
                .compositingGroup()
            }
            .foregroundStyle(.white)
            .animation(.smooth, value: pillAngle)
            .accessibilityHidden(true)

            ForEach(dotCities) { dotCity in
                let isSelected = dotCity.timeZone.secondsFromGMT(for: date) == city.timeZone.secondsFromGMT(for: date)
                let dot = TrackDot(
                    layout: layout,
                    angle: angle(of: dotCity, at: displayedAngle ?? utcAngle),
                    diameter: isSelected ? layout.selectedDotDiameter : layout.dotDiameter,
                    nightFill: isSelected ? 0 : 1,
                    sunrise: daylight.sunrise,
                    sunset: daylight.sunset
                )

                dot
                    .fill(.white, style: FillStyle(eoFill: true))
                    .opacity(isSelected ? 1 : dotCity.isLocal ? 0 : 0.5)
                    .blendMode(.plusLighter)

                // Local's in yellow, unless it's the sun: unblended, as
                // lightening the sky washes the yellow out, and over the
                // white rather than in its place, as switching blend modes
                // blinks
                if dotCity.isLocal {
                    dot
                        .fill(.yellow, style: FillStyle(eoFill: true))
                        .opacity(isSelected ? 0 : 1)
                }
            }
            .animation(.smooth, value: displayedAngle)
            .accessibilityHidden(true)

            VStack(spacing: 0) {
                ZStack {
                    VStack(spacing: 0) {
                        ClockTimeText(date: date, timeZone: city.timeZone, size: .medium)

                        Text(city.name)
                            .font(.headline)
                    }
                    .transition(.blurReplace)
                    .id(city.id)
                }

                // Blended outside its transition, whose blur would otherwise
                // keep it from lightening the sky until the blur ends
                ZStack {
                    Text(dateLabel)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                        .transition(.blurReplace)
                        .id(city.id)
                }
                .blendMode(.plusLighter)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: layout.innerDiameter * 0.8)
            .frame(width: layout.innerDiameter, height: layout.innerDiameter)
        }
        .frame(width: layout.diameter, height: layout.diameter)
        .contentShape(.circle)
        .onTapGesture(coordinateSpace: .local) { location in
            if let tappedCity = city(tappedAt: location) {
                onDotTap(tappedCity)
            }
        }
        // The stored city changes outside any transaction of the tap's
        .animation(.smooth, value: city.id)
        .onChange(of: utcAngle, initial: true) { oldAngle, newAngle in
            // At most half a turn either way
            let turn = (newAngle - oldAngle + 540).truncatingRemainder(dividingBy: 360) - 180
            displayedAngle = (displayedAngle ?? oldAngle) + turn
        }
        .onChange(of: currentHour, initial: true) { oldHour, newHour in
            let turn = Double((newHour - oldHour + 36) % 24 - 12) * 15
            pillAngle = (pillAngle ?? Double(oldHour) * 15) + turn
        }
    }

    /// Turned along the dial, and over across its bottom half, like the
    /// daylight ring's hours.
    private var hours: some View {
        ZStack {
            ForEach(0..<24, id: \.self) { hour in
                Text(verbatim: String(hour == 0 ? 24 : hour))
                    .rotationEffect(.degrees(Double(hour) * 15 - (Self.isTurnedOver(hour) ? 180 : 0)))
                    .position(layout.point(atHour: Double(hour), radius: layout.hourRadius))
            }
        }
        .font(.system(size: 11, weight: .semibold, design: .rounded))
    }
}

/// The current hour's pill, bent along the hours' band like the daylight
/// ring's, at `angle` around the dial, so it moves along the band rather
/// than across the dial. It reaches halfway to the neighboring hours, as
/// every hour is marked.
private struct DialHourPill: Shape {
    let layout: AnalogClockDialLayout
    /// In degrees clockwise from midnight.
    var angle: Double

    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let thickness = AnalogClockDialLayout.hourBandWidth
        // The round ends reach half the thickness past each end of the arc.
        let sweep = (layout.hourSpacing - thickness) / layout.hourRadius
        var arc = Path()
        arc.addRelativeArc(
            center: layout.center,
            radius: layout.hourRadius,
            startAngle: .radians((angle - 90) * .pi / 180 - sweep / 2),
            delta: .radians(sweep)
        )
        return arc.strokedPath(StrokeStyle(lineWidth: thickness, lineCap: .round))
    }
}

/// The dial's rings, and across the track between two of them, the lines of
/// sunrise and sunset, on days the sun rises and sets.
private struct DialLines: Shape {
    let layout: AnalogClockDialLayout
    /// In degrees clockwise from midnight.
    var sunrise: Double
    var sunset: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(sunrise, sunset) }
        set { (sunrise, sunset) = (newValue.first, newValue.second) }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for radius in [layout.edgeRadius, layout.trackOuterRadius, layout.trackInnerRadius] {
            path.addEllipse(in: CGRect(
                x: layout.center.x - radius,
                y: layout.center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))
        }
        if sunset > sunrise, sunset < sunrise + 360 {
            for angle in [sunrise, sunset] {
                path.move(to: layout.point(atHour: angle / 15, radius: layout.trackInnerRadius))
                path.addLine(to: layout.point(atHour: angle / 15, radius: layout.trackOuterRadius))
            }
        }
        return path
    }
}

/// The track from sunrise to sunset: all the way around while the sun stays
/// up, and none of it while the sun stays down.
private struct TrackDay: Shape {
    let layout: AnalogClockDialLayout
    /// In degrees clockwise from midnight.
    var sunrise: Double
    var sunset: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(sunrise, sunset) }
        set { (sunrise, sunset) = (newValue.first, newValue.second) }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRelativeArc(
            center: layout.center,
            radius: layout.trackOuterRadius,
            startAngle: .degrees(sunrise - 90),
            delta: .degrees(sunset - sunrise)
        )
        path.addRelativeArc(
            center: layout.center,
            radius: layout.trackInnerRadius,
            startAngle: .degrees(sunset - 90),
            delta: .degrees(sunrise - sunset)
        )
        path.closeSubpath()
        return path
    }
}

/// A city's dot on the track. The city on the clock's is the sun: solid
/// through the day and an outline through the night, like the daylight
/// ring's, and cut across where it crosses sunrise or sunset, as on the
/// Sunrise/Sunset complication.
private struct TrackDot: Shape {
    private static let outlineWidth: CGFloat = 1.5

    let layout: AnalogClockDialLayout
    /// In degrees clockwise from midnight, like sunrise and sunset.
    var angle: Double
    var diameter: CGFloat
    /// Through the night, 1 is solid and 0 an outline.
    var nightFill: CGFloat
    var sunrise: Double
    var sunset: Double

    var animatableData: AnimatablePair<AnimatablePair<Double, CGFloat>, AnimatablePair<CGFloat, AnimatablePair<Double, Double>>> {
        get {
            AnimatablePair(
                AnimatablePair(angle, diameter),
                AnimatablePair(nightFill, AnimatablePair(sunrise, sunset))
            )
        }
        set {
            (angle, diameter) = (newValue.first.first, newValue.first.second)
            nightFill = newValue.second.first
            (sunrise, sunset) = (newValue.second.second.first, newValue.second.second.second)
        }
    }

    func path(in rect: CGRect) -> Path {
        let center = layout.point(atHour: angle / 15, radius: layout.orbitRadius)
        let dot = CGRect(x: center.x - diameter / 2, y: center.y - diameter / 2, width: diameter, height: diameter)
        let night = SunDisc(fill: nightFill, lineWidth: Self.outlineWidth).path(in: dot)
        guard nightFill < 1 else { return night }

        // Solid on the day's side of the sunrise and sunset lines
        var day = Path()
        day.move(to: layout.center)
        day.addRelativeArc(
            center: layout.center,
            radius: layout.diameter,
            startAngle: .degrees(sunrise - 90),
            delta: .degrees(sunset - sunrise)
        )
        day.closeSubpath()
        return Path(ellipseIn: dot).intersection(day).union(night, eoFill: true)
    }
}
