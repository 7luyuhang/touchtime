//
//  MoonPhaseWidget.swift
//  touchtimeWidgetExtension
//
//  Small widget: the current moon rendered large in the center, with the
//  same grayscale + plus-lighter treatment as the app's Moon Phase sheet,
//  and an optional phase name at the bottom (edit-widget toggle).
//

import WidgetKit
import SwiftUI
import AppIntents
import MoonKit
import CoreLocation

// MARK: - Intent

struct MoonPhaseWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Moon Phase"
    static let description = IntentDescription("Shows the current moon phase.")

    @Parameter(title: "Show Moon Phase Name", default: false)
    var showPhaseName: Bool
}

// MARK: - Timeline

struct MoonPhaseWidgetEntry: TimelineEntry {
    let date: Date
    let imageName: String
    let phaseName: String
    let showPhaseName: Bool
}

struct MoonPhaseWidgetProvider: AppIntentTimelineProvider {
    // The moon's age (and therefore the image and phase name) is the same
    // for every city at a given instant, so the widget simply uses the
    // device time zone. Coordinates only feed MoonKit's internal math.
    //
    // One Moon instance is reused for the whole batch: MoonKit recomputes
    // moonrise/moonset for every new instance and every day change, which
    // is by far the most expensive part. Creating a fresh instance per
    // entry could push the timeline past WidgetKit's budget on slow
    // devices, and a killed extension is a widget that never updates.
    private func makeEntries(for dates: [Date], showPhaseName: Bool) -> [MoonPhaseWidgetEntry] {
        let timeZone = TimeZone.current
        let coordinate = TimeZoneCoordinates.getCoordinate(for: timeZone.identifier)
        let location = CLLocation(
            latitude: coordinate?.latitude ?? 51.5074,
            longitude: coordinate?.longitude ?? -0.1278
        )
        
        let moon = Moon(location: location, timeZone: timeZone)
        
        return dates.map { date in
            moon.setDate(date)
            
            // Age wraps at the end of the synodic cycle (~29.5 days) back to new moon
            let imageIndex = Int(moon.ageOfTheMoonInDays.rounded()) % 30
            
            return MoonPhaseWidgetEntry(
                date: date,
                imageName: String(format: "moon_age_%02d", imageIndex),
                phaseName: Self.phaseName(for: moon.currentMoonPhase),
                showPhaseName: showPhaseName
            )
        }
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
            phaseName: String(localized: "Full Moon"),
            showPhaseName: false
        )
    }
    
    func snapshot(for configuration: MoonPhaseWidgetIntent, in context: Context) async -> MoonPhaseWidgetEntry {
        makeEntries(for: [Date()], showPhaseName: configuration.showPhaseName).first
            ?? placeholder(in: context)
    }
    
    func timeline(for configuration: MoonPhaseWidgetIntent, in context: Context) async -> Timeline<MoonPhaseWidgetEntry> {
        // The moon's appearance only changes on a daily scale; hourly
        // entries keep the transition to the next image reasonably sharp.
        let now = Date()
        let dates = (0..<24).compactMap {
            Calendar.current.date(byAdding: .hour, value: $0, to: now)
        }
        let entries = makeEntries(for: dates, showPhaseName: configuration.showPhaseName)
        return Timeline(entries: entries, policy: .atEnd)
    }
}

// MARK: - View

struct MoonPhaseWidgetView: View {
    var entry: MoonPhaseWidgetEntry
    
    // The moon disc only spans ~86% of the source photo (626px of 730px),
    // the rest is black margin. Scaling by 730/626 (+ a hair for the
    // anti-aliased limb) inside the circular clip crops that margin away,
    // so no black ring shows on transparent Home Screens.
    private static let discCropScale: CGFloat = 1.18
    
    // No blend mode here on purpose: WidgetKit composites the content and
    // the container background in separate layers (that's how the system
    // strips the background for StandBy/tinted/clear contexts), so a
    // plusLighter moon can end up blending against nothing and vanish.
    // Over this widget's pure-black canvas plusLighter is identical to
    // normal blending anyway, so normal is the safe choice everywhere.
    var body: some View {
        VStack(spacing: 8) {
            Image(entry.imageName)
                .resizable()
                .widgetAccentedRenderingMode(.desaturated)
                .scaledToFit()
                .scaleEffect(Self.discCropScale)
                .clipShape(Circle())
                .grayscale(1)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            if entry.showPhaseName {
                Text(entry.phaseName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
        }
        .padding(16)
        .containerBackground(for: .widget) {
            // Keep the widget black in both color schemes, matching the
            // night-sky look of the app's moon sheet.
            Color.black
        }
    }
}

// MARK: - Widget

struct MoonPhaseWidget: Widget {
    let kind: String = "MoonPhaseWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: MoonPhaseWidgetIntent.self,
            provider: MoonPhaseWidgetProvider()
        ) { entry in
            MoonPhaseWidgetView(entry: entry)
        }
        .configurationDisplayName("Moon Phase")
        .description("Shows the current moon phase.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
