//
//  CityDetailDisplayPicker.swift
//  touchtimeWatch
//

import SwiftUI

enum CityDetailDisplay: String, CaseIterable, Identifiable {
    case worldClock
    case analogue
    case solarCurve
    case sunPosition
    case daylight
    case moonPhase
    case weather
    case precipitation
    case wind
    case uvIndex
    case humidity
    case pressure

    /// The view every city's details show, as last chosen.
    static let storageKey = "watchDetailDisplay"

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .worldClock: "World Map"
        case .analogue: "Analogue"
        case .moonPhase: "Moon Phase"
        case .solarCurve: "Solar Curve"
        case .sunPosition: "Sun Position"
        case .daylight: "Daylight"
        case .weather: "Conditions"
        case .precipitation: "Precipitation"
        case .wind: "Wind"
        case .uvIndex: "UV Index"
        case .humidity: "Humidity"
        case .pressure: "Pressure"
        }
    }

    var symbolName: String {
        switch self {
        case .worldClock: "globe"
        case .analogue: "watch.analog"
        case .moonPhase: "moonphase.waxing.gibbous"
        case .solarCurve: "sun.max"
        case .sunPosition: "safari"
        case .daylight: "rays"
        case .weather: "cloud"
        case .precipitation: "umbrella"
        case .wind: "wind"
        case .uvIndex: "beach.umbrella"
        case .humidity: "humidity"
        case .pressure: "gauge.with.dots.needle.bottom.50percent"
        }
    }

    /// Whether the view shows the weather now, whatever time the clocks show.
    var showsNow: Bool {
        self == .weather || self == .precipitation || self == .wind || self == .uvIndex || self == .humidity
            || self == .pressure
    }

    /// The section Choose View and Default View list the view in.
    var category: Category {
        switch self {
        case .worldClock, .analogue: .general
        case .solarCurve, .sunPosition, .daylight, .moonPhase: .astronomy
        case .weather, .precipitation, .wind, .uvIndex, .humidity, .pressure: .weather
        }
    }

    /// The sections Choose View and Default View list the views in, in order.
    enum Category: CaseIterable, Identifiable {
        case general
        case astronomy
        case weather

        var id: Self { self }

        var title: LocalizedStringKey {
            switch self {
            case .general: "General"
            case .astronomy: "Astronomy"
            case .weather: "Weather"
            }
        }

        /// In the order they're declared.
        var displays: [CityDetailDisplay] {
            CityDetailDisplay.allCases.filter { $0.category == self }
        }
    }
}

/// The watch app's Default View setting: the view the app opens on, or the
/// one last chosen.
enum DefaultCityDetailDisplay: RawRepresentable, Hashable {
    case lastUsed
    case display(CityDetailDisplay)

    /// The watch app's Default View setting.
    static let storageKey = "watchDefaultDetailDisplay"

    /// Last Used in place of a view that's no longer there.
    init(rawValue: String) {
        self = CityDetailDisplay(rawValue: rawValue).map(Self.display) ?? .lastUsed
    }

    var rawValue: String {
        switch self {
        case .lastUsed: "lastUsed"
        case .display(let display): display.rawValue
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .lastUsed: "Last Used"
        case .display(let display): display.title
        }
    }
}

/// A full-screen list of detail views, with the current choice checked.
struct CityDetailDisplayPicker: View {
    let cityName: String
    @Binding var selection: CityDetailDisplay
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(CityDetailDisplay.Category.allCases) { category in
                    Section(category.title) {
                        ForEach(category.displays) { display in
                            row(for: display)
                        }
                    }
                }
            }
            .navigationTitle(cityName)
            .toolbarForegroundStyle(.yellow, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func row(for display: CityDetailDisplay) -> some View {
        Button {
            selection = display
            dismiss()
        } label: {
            HStack {
                Label(display.title, systemImage: display.symbolName)
                    .symbolRenderingMode(.monochrome)
                Spacer(minLength: 4)
                if selection == display {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .accessibilityHidden(true)
                }
            }
        }
        .accessibilityAddTraits(selection == display ? .isSelected : [])
    }
}
