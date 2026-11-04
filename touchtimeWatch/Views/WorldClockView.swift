//
//  WorldClockView.swift
//  touchtimeWatch
//
//  The app's root, laid out like the system World Clock: it opens on a
//  city's details, with the list of cities, or the analog clock, a tap away.
//

import SwiftUI

struct WorldClockView: View {
    @Environment(WatchCityStore.self) private var cityStore
    /// The city whose details are showing, or empty for the list. Kept
    /// across launches; the watch's own time zone the first time.
    @AppStorage("selectedCityID") private var selectedCityID = ClockCity.localID
    /// Whether the cities show one at a time on an analog clock, in place of
    /// the list.
    @AppStorage("showsAnalogClock") private var showsAnalogClock = false
    /// The time every clock shows in place of now, once moved by the list's
    /// Scroll Time bar or the Digital Crown on a city's details or the
    /// analog clock.
    @State private var adjustedDate: Date?

    var body: some View {
        let cities = [ClockCity.local] + cityStore.cities.map { ClockCity($0) }

        NavigationSplitView {
            Group {
                if showsAnalogClock {
                    AnalogClockHomeView(cities: cities, adjustedDate: $adjustedDate) {
                        showsAnalogClock = false
                    }
                } else {
                    CityListView(cities: cities, selection: selection(among: cities), adjustedDate: $adjustedDate)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Analog Clock", systemImage: "clock") {
                                    showsAnalogClock = true
                                }
                            }
                        }
                }
            }
            .toolbarForegroundStyle(.primary, for: .navigationBar)
        } detail: {
            if let city = cities.first(where: { $0.id == selectedCityID }) {
                CityDetailView(city: city, mapCities: cities, adjustedDate: $adjustedDate)
                    .id(city.id)
            }
        }
    }

    /// The split view reads the selection back through this binding right
    /// after its list button clears it, so the getter reads the stored ID
    /// rather than a city looked up when the body ran.
    private func selection(among cities: [ClockCity]) -> Binding<String?> {
        Binding {
            cities.contains { $0.id == selectedCityID } ? selectedCityID : nil
        } set: { id in
            selectedCityID = id ?? ""
        }
    }
}
