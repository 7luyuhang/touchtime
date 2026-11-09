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
    /// Left for longer than the two minutes the watch waits by default
    /// before going back to its face, the app opens on the Default View.
    private static let newVisitInterval: TimeInterval = 2 * 60

    @Environment(WatchCityStore.self) private var cityStore
    @Environment(\.scenePhase) private var scenePhase
    /// The city whose details are showing, or empty for the list. Kept
    /// across launches; the watch's own time zone the first time.
    @AppStorage("selectedCityID") private var selectedCityID = ClockCity.localID
    @AppStorage(CityDetailDisplay.storageKey) private var display: CityDetailDisplay = .worldClock
    @AppStorage(DefaultCityDetailDisplay.storageKey) private var defaultDisplay: DefaultCityDetailDisplay = .lastUsed
    /// When the app last stopped being active, or nil since it launched.
    @State private var leftDate: Date?
    @State private var showsAnalogClock = false
    /// Shows the welcome sheet on launch until Continue is first tapped.
    @AppStorage("showsOnboarding") private var showsOnboarding = true
    /// The time every clock shows in place of now, once moved by the Digital
    /// Crown on a city's details or the analog clock.
    @State private var adjustedDate: Date?

    var body: some View {
        let cities = [ClockCity.local] + cityStore.cities.map { ClockCity($0) }

        NavigationSplitView {
            CityListView(cities: cities, selection: selection(among: cities), adjustedDate: $adjustedDate) {
                showsAnalogClock = true
            }
            .sheet(isPresented: $showsAnalogClock) {
                AnalogClockHomeView(cities: cities, adjustedDate: $adjustedDate)
            }
        } detail: {
            if let city = cities.first(where: { $0.id == selectedCityID }) {
                CityDetailView(city: city, mapCities: cities, adjustedDate: $adjustedDate)
                    .id(city.id)
            }
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
