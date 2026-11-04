//
//  CitySunTimesSheet.swift
//  touchtimeWatch
//

import SwiftUI

/// The city's first light, sunrise, sunset, and last light on the selected
/// day, titled with the day.
struct CitySunTimesSheet: View {
    let date: Date
    let timeZone: TimeZone
    /// The iPhone app's date style, for the title.
    let dateStyle: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let times = times

        NavigationStack {
            DetailSheetPage {
                DetailSheetRow("First Light") {
                    DetailSheetTime(date: times.firstLight, timeZone: timeZone)
                }
                Divider()
                DetailSheetRow("Sunrise") {
                    DetailSheetTime(date: times.sunrise, timeZone: timeZone)
                }
                Divider()
                DetailSheetRow("Sunset") {
                    DetailSheetTime(date: times.sunset, timeZone: timeZone)
                }
                Divider()
                DetailSheetRow("Last Light") {
                    DetailSheetTime(date: times.lastLight, timeZone: timeZone)
                }
            }
            .navigationTitle(date.formattedDate(style: dateStyle, timeZone: timeZone, relativeTo: .now))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
        }
    }

    /// First and last light are civil dawn and dusk, with the sun 6° below
    /// the horizon. Each time is nil when the sun doesn't cross its height
    /// during the city's day.
    private var times: (firstLight: Date?, sunrise: Date?, sunset: Date?, lastLight: Date?) {
        guard let coordinate = TimeZoneCoordinates.getCoordinate(for: timeZone.identifier) else {
            return (nil, nil, nil, nil)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let day = calendar.dateInterval(of: .day, for: date) else { return (nil, nil, nil, nil) }

        let events = SolarCalculator.events(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            date: date,
            timeZone: timeZone
        )
        let light = crossings(events.civilDawn, events.civilDusk, during: day)
        let sun = crossings(events.sunrise, events.sunset, during: day)
        return (light.morning, sun.morning, sun.evening, light.evening)
    }

    /// The calculator puts crossings that don't happen at noon or the day's
    /// edges. Show a dash instead of presenting those as real times.
    private func crossings(_ morning: Date, _ evening: Date, during day: DateInterval) -> (morning: Date?, evening: Date?) {
        guard morning < evening else { return (nil, nil) }
        return (
            morning > day.start ? morning : nil,
            evening < day.end.addingTimeInterval(-1) ? evening : nil
        )
    }
}
