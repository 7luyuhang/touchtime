//
//  CityDetailDisplayPicker.swift
//  touchtimeWatch
//

import SwiftUI

enum CityDetailDisplay: String, CaseIterable, Identifiable {
    case worldClock
    case solarCurve
    case sunPosition
    case daylight
    case moonPhase
    case weather
    case wind
    case uvIndex

    /// The view every city's details show, as last chosen.
    static let storageKey = "watchDetailDisplay"

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .worldClock: "World Clock"
        case .moonPhase: "Moon Phase"
        case .solarCurve: "Solar Curve"
        case .sunPosition: "Sun Position"
        case .daylight: "Daylight"
        case .weather: "Conditions"
        case .wind: "Wind"
        case .uvIndex: "UV Index"
        }
    }

    var symbolName: String {
        switch self {
        case .worldClock: "globe"
        case .moonPhase: "moonphase.waxing.gibbous"
        case .solarCurve: "sun.max"
        case .sunPosition: "safari"
        case .daylight: "rays"
        case .weather: "cloud"
        case .wind: "wind"
        case .uvIndex: "beach.umbrella"
        }
    }

    /// Whether the view shows the weather now, whatever time the clocks show.
    var showsNow: Bool {
        self == .weather || self == .wind || self == .uvIndex
    }
}

/// The watch app's Default View setting: the view the app opens on, or the
/// one last chosen.
enum DefaultCityDetailDisplay: RawRepresentable, CaseIterable, Identifiable, Hashable {
    case lastUsed
    case display(CityDetailDisplay)

    /// The watch app's Default View setting.
    static let storageKey = "watchDefaultDetailDisplay"

    /// Last Used, then every view in the order Choose View lists them.
    static let allCases: [Self] = [.lastUsed] + CityDetailDisplay.allCases.map(Self.display)

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

    var id: Self { self }

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
                Section("General") {
                    row(for: .worldClock)
                }

                Section("Astronomy") {
                    row(for: .solarCurve)
                    row(for: .sunPosition)
                    row(for: .daylight)
                    row(for: .moonPhase)
                }

                Section("Weather") {
                    row(for: .weather)
                    row(for: .wind)
                    row(for: .uvIndex)
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
