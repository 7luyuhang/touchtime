//
//  MoonPhaseWidget.swift
//  touchtimeWidgetExtension
//
//  Small widget: the current moon rendered large in the center, with the
//  same grayscale + plus-lighter treatment as the app's Moon Phase sheet,
//  and the phase name at the bottom.
//

import WidgetKit
import SwiftUI
import MoonKit
import CoreLocation

// MARK: - Timeline

struct MoonPhaseWidgetEntry: TimelineEntry {
    let date: Date
    let imageName: String
    let phaseName: String
}

struct MoonPhaseWidgetProvider: TimelineProvider {
    // The moon's age (and therefore the image and phase name) is the same
    // for every city at a given instant, so the widget simply uses the
    // device time zone. Coordinates only feed MoonKit's internal math.
    private func makeEntry(for date: Date) -> MoonPhaseWidgetEntry {
        let timeZone = TimeZone.current
        let coordinate = TimeZoneCoordinates.getCoordinate(for: timeZone.identifier)
        let location = CLLocation(
            latitude: coordinate?.latitude ?? 51.5074,
            longitude: coordinate?.longitude ?? -0.1278
        )
        
        let moon = Moon(location: location, timeZone: timeZone)
        moon.setDate(date)
        
        // Age wraps at the end of the synodic cycle (~29.5 days) back to new moon
        let imageIndex = Int(moon.ageOfTheMoonInDays.rounded()) % 30
        
        return MoonPhaseWidgetEntry(
            date: date,
            imageName: String(format: "moon_age_%02d", imageIndex),
            phaseName: Self.phaseName(for: moon.currentMoonPhase)
        )
    }
    
    private static func phaseName(for phase: MoonKit.MoonPhase) -> String {
        switch phase {
        case .newMoon:
            return String(localized: "New Moon")
        case .waxingCrescent:
            return String(localized: "Waxing Crescent")
        case .firstQuarter:
            return String(localized: "First Quarter")
        case .waxingGibbous:
            return String(localized: "Waxing Gibbous")
        case .fullMoon:
            return String(localized: "Full Moon")
        case .waningGibbous:
            return String(localized: "Waning Gibbous")
        case .lastQuarter:
            return String(localized: "Last Quarter")
        case .waningCrescent:
            return String(localized: "Waning Crescent")
        case .error:
            return String(localized: "Moon Phase")
        }
    }
    
    func placeholder(in context: Context) -> MoonPhaseWidgetEntry {
        MoonPhaseWidgetEntry(
            date: Date(),
            imageName: "moon_age_15",
            phaseName: String(localized: "Full Moon")
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (MoonPhaseWidgetEntry) -> Void) {
        completion(makeEntry(for: Date()))
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<MoonPhaseWidgetEntry>) -> Void) {
        // The moon's appearance only changes on a daily scale; hourly
        // entries keep the transition to the next image reasonably sharp.
        let now = Date()
        var entries: [MoonPhaseWidgetEntry] = []
        for hourOffset in 0..<24 {
            if let date = Calendar.current.date(byAdding: .hour, value: hourOffset, to: now) {
                entries.append(makeEntry(for: date))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

// MARK: - View

struct MoonPhaseWidgetView: View {
    var entry: MoonPhaseWidgetEntry
    
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.showsWidgetContainerBackground) private var showsContainerBackground
    
    // The moon disc only spans ~86% of the source photo (626px of 730px),
    // the rest is black margin. Scaling by 730/626 (+ a hair for the
    // anti-aliased limb) inside the circular clip crops that margin away,
    // so no black ring shows on transparent Home Screens.
    private static let discCropScale: CGFloat = 1.18
    
    // plusLighter composites against the widget's own black canvas: when the
    // system hides the container background (clear/tinted Home Screen,
    // StandBy), that canvas is gone and the blend would erase the moon, so
    // fall back to normal blending there.
    private var moonBlendMode: BlendMode {
        renderingMode == .fullColor && showsContainerBackground ? .plusLighter : .normal
    }
    
    var body: some View {
        Image(entry.imageName)
            .resizable()
            .widgetAccentedRenderingMode(.desaturated)
            .scaledToFit()
            .scaleEffect(Self.discCropScale)
            .clipShape(Circle())
            .grayscale(1)
            .blendMode(moonBlendMode)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(16)
            .containerBackground(for: .widget) {
                // plusLighter needs a dark canvas: keep the widget black in
                // both color schemes, matching the app's moon sheet.
                Color.black
            }
    }
}

// MARK: - Widget

struct MoonPhaseWidget: Widget {
    let kind: String = "MoonPhaseWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MoonPhaseWidgetProvider()) { entry in
            MoonPhaseWidgetView(entry: entry)
        }
        .configurationDisplayName("Moon Phase")
        .description("Shows the current moon phase.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
