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

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .worldClock: "World Clock"
        case .moonPhase: "Moon Phase"
        case .solarCurve: "Solar Curve"
        case .sunPosition: "Sun Position"
        case .daylight: "Daylight"
        case .weather: "Weather"
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
                Section("Viewing") {
                    ForEach(CityDetailDisplay.allCases) { display in
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
}
