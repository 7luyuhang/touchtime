//
//  WorldClockView.swift
//  touchtimeWatch
//
//  The app's root, laid out like the system World Clock: it opens on a
//  city's details, with the list of cities a tap away. Chosen from the
//  list's corner, the analog clock or the countdowns take the list's place.
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
    /// The countdown whose details are showing, or nil for the list.
    /// Selected, as a city is, rather than pushed: going back to the list,
    /// pushed details sink away below a band of black, where selected ones
    /// shrink into their row.
    @State private var selectedCountdownID: WatchCountdown.ID?
    @AppStorage(CityDetailDisplay.storageKey) private var display: CityDetailDisplay = .worldClock
    @AppStorage(DefaultCityDetailDisplay.storageKey) private var defaultDisplay: DefaultCityDetailDisplay = .lastUsed
    /// The list of cities, the analog clock or the countdowns, kept across
    /// launches.
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

        NavigationSplitView {
            Group {
                switch homeDisplay {
                case .list:
                    CityListView(cities: cities, selection: selection(among: cities), adjustedDate: adjustedDate)
                case .clock:
                    AnalogClockHomeView(cities: cities, adjustedDate: $adjustedDate)
                case .countdowns:
                    CountdownListView(selection: countdownSelection)
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
            .toolbarForegroundStyle(.primary, for: .navigationBar)
            .sensoryFeedback(.impact(flexibility: .soft), trigger: currentTimeTaps)
            .sheet(isPresented: $showsHomeDisplayPicker) {
                HomeDisplayPicker(selection: $homeDisplay)
            }
            .sheet(isPresented: $showsSettings) {
                SettingsView()
            }
        } detail: {
            switch homeDisplay {
            case .list:
                if let city = cities.first(where: { $0.id == selectedCityID }) {
                    CityDetailView(city: city, mapCities: cities, adjustedDate: $adjustedDate)
                        .id(city.id)
                }
            case .clock:
                EmptyView()
            case .countdowns:
                if let countdown = cityStore.countdowns.first(where: { $0.id == selectedCountdownID }) {
                    CountdownDetailView(countdown: countdown)
                        .id(countdown.id)
                }
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

    /// Back to now on every clock.
    private func showCurrentTime() {
        withAnimation(.smooth) {
            adjustedDate = nil
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
