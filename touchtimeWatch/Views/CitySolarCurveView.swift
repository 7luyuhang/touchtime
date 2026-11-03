//
//  CitySolarCurveView.swift
//  touchtimeWatch
//

import SwiftUI

/// The day's solar path, with the selected instant marked on the curve and
/// `footer` along the bottom of the screen.
struct CitySolarCurveView<Footer: View>: View {
    let date: Date
    let timeZone: TimeZone
    @ViewBuilder let footer: Footer

    /// The room under the curve, with `footer` at its bottom. The curve's
    /// height is what's left, so this also sets how tall the curve draws.
    @ScaledMetric(relativeTo: .body) private var footerRoom: CGFloat = 76

    var body: some View {
        GeometryReader { geometry in
            let chartHeight = max(40, geometry.size.height - footerRoom)
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
                // VoiceOver reads the sunrise and sunset where the curve
                // crosses the horizon
                .accessibilityRepresentation {
                    let events = sunTimes
                    VStack {
                        eventRow("Sunrise", systemImage: "sunrise.fill", date: events.sunrise)
                        eventRow("Sunset", systemImage: "sunset.fill", date: events.sunset)
                    }
                }

                footer
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: footerRoom, alignment: .bottom)
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

    private func eventRow(_ title: LocalizedStringKey, systemImage: String, date: Date?) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .labelStyle(.titleAndIcon)
            Spacer(minLength: 8)
            if let date {
                ClockTimeText(date: date, timeZone: timeZone, size: .medium)
            } else {
                Text(verbatim: "-")
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
                    .overlay {
                        if sky.starOpacity > 0 {
                            StarsView(starCount: 25)
                                .opacity(sky.starOpacity)
                                .blendMode(.plusLighter)
                                .animation(.easeInOut(duration: 0.5), value: sky.starOpacity)
                        }
                    }
                    .clipped()

                ZStack {
                    reflection

                    LinearGradient(
                        colors: [.black.opacity(0.25), .black.opacity(1.0)],
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
    let date = Date.now
    NavigationStack {
        CitySolarCurveView(date: date, timeZone: .current) {
            Text(date.formattedDate(style: "Relative", timeZone: .current, relativeTo: date))
                .foregroundStyle(.secondary)
                .padding(.bottom, 14)
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle("Local")
    }
}
