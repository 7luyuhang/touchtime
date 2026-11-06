//
//  WorldClockView.swift
//  touchtimeWatch
//
//  The app's root, laid out like the system World Clock: it opens on a
//  city's details, with the list of cities a tap away, and from the list,
//  the analog clock on a sheet.
//

import SwiftUI

struct WorldClockView: View {
    @Environment(WatchCityStore.self) private var cityStore
    /// The city whose details are showing, or empty for the list. Kept
    /// across launches; the watch's own time zone the first time.
    @AppStorage("selectedCityID") private var selectedCityID = ClockCity.localID
    /// The list's page: every city, or a collection. Kept across launches,
    /// so going back from a city's details lands on the page it was opened from.
    @AppStorage("selectedCollectionID") private var selectedPageID = CityListPage.allCitiesID
    @State private var showsAnalogClock = false
    /// Shows the welcome sheet on launch until Continue is first tapped.
    @AppStorage("showsOnboarding") private var showsOnboarding = true
    /// The time every clock shows in place of now, once moved by the Digital
    /// Crown on a city's details or the analog clock.
    @State private var adjustedDate: Date?

    var body: some View {
        let pages = CityListPage.pages(cities: cityStore.cities, collections: cityStore.collections)
        // Every city's page, once its collection is gone from the iPhone
        let page = pages.first { $0.id == selectedPageID } ?? pages[0]

        NavigationSplitView {
            CityListView(
                pages: pages,
                pageID: pageSelection(among: pages),
                selection: selection(among: page.cities),
                adjustedDate: $adjustedDate
            ) {
                showsAnalogClock = true
            }
            .sheet(isPresented: $showsAnalogClock) {
                AnalogClockHomeView(cities: page.cities, adjustedDate: $adjustedDate)
            }
        } detail: {
            if let city = page.cities.first(where: { $0.id == selectedCityID }) {
                CityDetailView(city: city, mapCities: page.cities, adjustedDate: $adjustedDate)
                    .id(city.id)
            }
        }
        .sheet(isPresented: $showsOnboarding) {
            OnboardingSheet()
        }
    }

    /// The split view reads the selection back through this binding right
    /// after its list button clears it, so the getter reads the stored ID
    /// rather than a city looked up when the body ran. Every page's list
    /// shares it, whichever one the split view reads.
    private func selection(among cities: [ClockCity]) -> Binding<String?> {
        Binding {
            cities.contains { $0.id == selectedCityID } ? selectedCityID : nil
        } set: { id in
            selectedCityID = id ?? ""
        }
    }

    private func pageSelection(among pages: [CityListPage]) -> Binding<String> {
        Binding {
            pages.contains { $0.id == selectedPageID } ? selectedPageID : CityListPage.allCitiesID
        } set: { id in
            selectedPageID = id
        }
    }
}
