//
//  CitySolarCurveView.swift
//  touchtimeWatch
//

import SwiftUI

/// The day's solar path, with the selected instant marked on the curve.
struct CitySolarCurveView: View {
    let date: Date
    let timeZone: TimeZone

    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .body) private var informationHeight: CGFloat = 76

    var body: some View {
        GeometryReader { geometry in
            let chartHeight = max(40, geometry.size.height - informationHeight)
            let topInset = geometry.safeAreaInsets.top
            let screenHeight = geometry.size.height + topInset
            let horizon = screenHeight / 2

            VStack(spacing: 0) {
                SolarCurve(
                    date: date,
                    timeZone: timeZone,
                    size: geometry.size.width,
                    height: chartHeight,
                    showBackground: false,
                    showSun: true,
                    sunDiameter: 16
                )
                // Convert the screen's midpoint to this content area's
                // coordinates, below the navigation bar.
                .offset(y: horizon - topInset - chartHeight / 2)
                .accessibilityHidden(true)

                information
                    .frame(height: informationHeight, alignment: .top)
            }
            .background(alignment: .top) {
                // Extend the upper sky behind the toolbar while keeping its
                // horizon exactly level with the shared curve's horizon.
                SolarCurveSkyBackground(
                    date: date,
                    timeZone: timeZone,
                    horizon: horizon
                )
                .frame(height: screenHeight)
                .offset(y: -topInset)
            }
        }
        // Fill the display width instead of leaving the navigation
        // content area's narrow black gutters beside the sky and curve.
        .ignoresSafeArea(edges: .horizontal)
    }

    private var information: some View {
        let events = sunTimes

        return VStack(spacing: 3) {
            eventRow("Sunrise", date: events.sunrise)
            eventRow("Sunset", date: events.sunset)

            Text(date.formatted(Date.FormatStyle(
                date: .abbreviated,
                time: .omitted,
                locale: locale,
                timeZone: timeZone
            )))
            .foregroundStyle(.secondary)
            .contentTransition(.numericText())
            .padding(.top, 3)
        }
        .font(.body)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .scenePadding(.navigationBar, edges: .horizontal)
    }

    private func eventRow(_ title: LocalizedStringKey, date: Date?) -> some View {
        HStack {
            Text(title)
            Spacer(minLength: 8)
            if let date {
                ClockTimeText(date: date, timeZone: timeZone, size: .medium)
            } else {
                Text("—")
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var sunTimes: (sunrise: Date?, sunset: Date?) {
        guard let coordinate = TimeZoneCoordinates.getCoordinate(for: timeZone.identifier) else {
            return (nil, nil)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let day = calendar.dateInterval(of: .day, for: date) else { return (nil, nil) }

        let events = SolarCalculator.events(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            date: date,
            timeZone: timeZone
        )
        // The calculator clamps missing polar events to noon or the day's
        // edges. Show a dash instead of presenting those as real crossings.
        guard events.sunrise < events.sunset else { return (nil, nil) }
        return (
            events.sunrise > day.start ? events.sunrise : nil,
            events.sunset < day.end.addingTimeInterval(-1) ? events.sunset : nil
        )
    }
}

/// Sky above the horizon, reflected and darkened beneath it.
private struct SolarCurveSkyBackground: View {
    let date: Date
    let timeZone: TimeZone
    let horizon: CGFloat

    var body: some View {
        let sky = SkyColorGradient(date: date, timeZoneIdentifier: timeZone.identifier)
        let colors = sky.colorsOverBlack(opacity: 0.75)
        let reflection = LinearGradient(colors: colors.reversed(), startPoint: .top, endPoint: .bottom)

        GeometryReader { geometry in
            let upperHeight = min(max(horizon, 0), geometry.size.height)

            VStack(spacing: 0) {
                LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
                    .frame(height: upperHeight)

                ZStack {
                    reflection

                    LinearGradient(
                        colors: [.black.opacity(0.15), .black.opacity(0.85)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .frame(height: max(0, geometry.size.height - upperHeight))
                .clipped()
            }
        }
        .animation(.easeInOut(duration: 0.5), value: sky.animationValue)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    NavigationStack {
        CitySolarCurveView(date: .now, timeZone: .current)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle("Local")
    }
}
