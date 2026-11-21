//
//  WorldClockView.swift
//  touchtimeWatch
//
//  The app's root, laid out like the system World Clock: it opens on a
//  city's details, with the list of cities a tap away. The iPhone's
//  collections each get a page of the list, to the right of every city's.
//  Chosen from the list's corner, the analog clock, the countdowns, the
//  timer or the stopwatch take the list's place.
//

import SwiftUI

struct WorldClockView: View {
    /// Left for longer than the two minutes the watch waits by default
    /// before going back to its face, the app opens on the Default View.
    private static let newVisitInterval: TimeInterval = 2 * 60

    @Environment(WatchCityStore.self) private var cityStore
    @Environment(\.scenePhase) private var scenePhase
    /// The city whose details are showing, or empty for the list. Kept
    /// across launches; the list the first time, under the welcome sheet.
    @AppStorage("selectedCityID") private var selectedCityID = ""
    /// The collection whose page the list is on, or empty for every city's.
    /// Kept across launches.
    @AppStorage("selectedCollectionID") private var selectedCollectionID = ""
    /// The countdown whose details are showing, or nil for the list.
    /// Selected, as a city is, rather than pushed: going back to the list,
    /// pushed details sink away below a band of black, where selected ones
    /// shrink into their row.
    @State private var selectedCountdownID: WatchCountdown.ID?
    @AppStorage(CityDetailDisplay.storageKey) private var display: CityDetailDisplay = .worldClock
    @AppStorage(DefaultCityDetailDisplay.storageKey) private var defaultDisplay: DefaultCityDetailDisplay = .lastUsed
    /// The list of cities, the analog clock, the countdowns, the timer or the
    /// stopwatch, kept across launches.
    @AppStorage(HomeDisplay.storageKey) private var homeDisplay: HomeDisplay = .list
    /// When the app last stopped being active, or nil since it launched.
    @State private var leftDate: Date?
    @State private var showsHomeDisplayPicker = false
    @State private var showsSettings = false
    /// Taps on Current Time, each felt. Not the adjusted date, which a city's
    /// details and the analog clock also clear, with haptics of their own.
    @State private var currentTimeTaps = 0
    /// Shows the welcome sheet on launch until Continue is first tapped.
    @AppStorage("showsOnboarding") private var showsOnboarding = true
    /// The time every clock shows in place of now, once moved by the Digital
    /// Crown on a city's details or the analog clock.
    @State private var adjustedDate: Date?

    var body: some View {
        let cities = [ClockCity.local] + cityStore.cities.map { ClockCity($0) }
        // The cities on the list's page, which a city's details dot on the map
        let pageCities = selectedCollection.map { Self.cities(in: $0) } ?? cities

        NavigationSplitView {
            Group {
                switch homeDisplay {
                case .list:
                    cityList(cities)
                case .clock:
                    AnalogClockHomeView(cities: cities, adjustedDate: $adjustedDate)
                case .countdowns:
                    CountdownListView(selection: countdownSelection)
                case .timer:
                    TimerHomeView()
                case .stopwatch:
                    StopwatchHomeView()
                }
            }
            .toolbar {
                // While adjusting time, a reset button takes Choose View's
                // place, as it takes the back button's on a city's details.
                ToolbarItem(placement: .topBarLeading) {
                    if adjustedDate != nil {
                        Button("Current Time", systemImage: "xmark") {
                            currentTimeTaps += 1
                            showCurrentTime()
                        }
                    } else {
                        Button("Choose View", systemImage: "ellipsis") {
                            showsHomeDisplayPicker = true
                        }
                        .accessibilityValue(Text(homeDisplay.title))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gear") {
                        showsSettings = true
                    }
                }
            }
            // Here rather than on the collections' pages, which this one would override
            .toolbarForegroundStyle(homeDisplay == .list && selectedCollection != nil ? .yellow : Color.primary, for: .navigationBar)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: currentTimeTaps)
            .sheet(isPresented: $showsSettings) {
                SettingsView()
            }
        } detail: {
            switch homeDisplay {
            case .list:
                if let city = pageCities.first(where: { $0.id == selectedCityID }) {
                    CityDetailView(city: city, mapCities: pageCities, adjustedDate: $adjustedDate)
                        .id(city.id)
                }
            case .clock, .timer, .stopwatch:
                EmptyView()
            case .countdowns:
                if let countdown = cityStore.countdowns.first(where: { $0.id == selectedCountdownID }) {
                    CountdownDetailView(countdown: countdown)
                        .id(countdown.id)
                }
            }
        }
        // On the split view rather than its sidebar, where the sheet would
        // close without its animation as a list takes the analog clock's place
        .sheet(isPresented: $showsHomeDisplayPicker) {
            HomeDisplayPicker(selection: $homeDisplay)
        }
        .sheet(isPresented: $showsOnboarding) {
            OnboardingSheet()
        }
        .onChange(of: scenePhase, initial: true) { oldPhase, phase in
            if oldPhase == .active, phase != .active {
                leftDate = .now
            } else if isNewVisit {
                showDefaultDisplay()
            }
        }
        // Right away too, so the details show the new choice.
        .onChange(of: defaultDisplay) {
            showDefaultDisplay()
        }
    }

    /// Whether the app is opening anew, rather than coming back as the wrist
    /// is raised again soon after it was left.
    private var isNewVisit: Bool {
        leftDate.map { Date.now.timeIntervalSince($0) >= Self.newVisitInterval } ?? true
    }

    /// Every city's details on the Default View, unless it's Last Used.
    private func showDefaultDisplay() {
        if case .display(let display) = defaultDisplay {
            self.display = display
        }
    }

    /// Back to now on every clock.
    private func showCurrentTime() {
        withAnimation(.smooth) {
            adjustedDate = nil
        }
    }

    /// Every city's list, then a page to its right for each of the iPhone's
    /// collections, titled with the collection's name.
    @ViewBuilder
    private func cityList(_ cities: [ClockCity]) -> some View {
        let allCitiesList = CityListView(cities: cities, selection: selection(among: cities, in: nil), adjustedDate: adjustedDate)
        if cityStore.collections.isEmpty {
            allCitiesList
        } else {
            TabView(selection: collectionSelection) {
                allCitiesList
                    .tag(WatchCollection.ID?.none)
                ForEach(cityStore.collections) { collection in
                    let collectionCities = Self.cities(in: collection)
                    CityListView(
                        cities: collectionCities,
                        selection: selection(among: collectionCities, in: collection.id),
                        adjustedDate: adjustedDate
                    )
                    .tag(Optional(collection.id))
                }
            }
            .tabViewStyle(.page)
            .navigationTitle(selectedCollection?.name ?? "")
        }
    }

    /// The split view reads the selection back through this binding right
    /// after its list button clears it, so the getter reads the stored ID
    /// rather than a city looked up when the body ran. Only the page showing
    /// has the selection, so the details shrink back into its row, not into
    /// the same city's row on another page.
    private func selection(among cities: [ClockCity], in collectionID: WatchCollection.ID?) -> Binding<String?> {
        Binding {
            selectedCollection?.id == collectionID && cities.contains { $0.id == selectedCityID } ? selectedCityID : nil
        } set: { id in
            selectedCityID = id ?? ""
        }
    }

    private var collectionSelection: Binding<WatchCollection.ID?> {
        Binding {
            selectedCollection?.id
        } set: { id in
            selectedCollectionID = id?.uuidString ?? ""
        }
    }

    /// Nil for every city's page, which the list goes back to once the
    /// collection is gone from the iPhone.
    private var selectedCollection: WatchCollection? {
        cityStore.collections.first { $0.id.uuidString == selectedCollectionID }
    }

    /// Local, then `collection`'s cities, as every city's page starts with
    /// Local too.
    private static func cities(in collection: WatchCollection) -> [ClockCity] {
        [ClockCity.local] + collection.cities.map { ClockCity($0) }
    }

    /// Read back as the cities' selection is; nil, so the list shows, once
    /// the countdown is gone from the iPhone.
    private var countdownSelection: Binding<WatchCountdown.ID?> {
        Binding {
            cityStore.countdowns.contains { $0.id == selectedCountdownID } ? selectedCountdownID : nil
        } set: { id in
            selectedCountdownID = id
        }
    }
}
