//
//  CityListView.swift
//  touchtimeWatch
//

import SwiftUI

/// Every clock at a glance, each row tinted with the sky over its city.
struct CityListView: View {
    let cities: [ClockCity]
    @Binding var selection: String?
    /// The time every clock shows in place of now, or nil for now.
    let adjustedDate: Date?

    @Environment(WatchCityStore.self) private var cityStore

    var body: some View {
        TimelineView(.everyMinute) { context in
            let date = adjustedDate ?? context.date

            List(selection: $selection) {
                ForEach(cities) { city in
                    NavigationLink(value: city.id) {
                        CityCard(city: city, date: date, now: context.date, dateStyle: cityStore.dateStyle)
                            // Less below, as the time's digits leave the space
                            // under their baseline empty
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                    }
                    .listRowBackground(CityRowBackground(date: date, timeZone: city.timeZone))
                }
            }
            .animation(.smooth, value: adjustedDate)
        }
    }
}

/// A row's sky, in the rounded shape the list gives its rows.
private struct CityRowBackground: View {
    let date: Date
    let timeZone: TimeZone

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        // As thick with stars as the iPhone app's rows, which are twice as big
        CitySkyBackground(date: date, timeZone: timeZone, starCount: 12)
            .clipShape(shape)
            .overlay {
                shape
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    .blendMode(.plusLighter)
            }
    }
}
