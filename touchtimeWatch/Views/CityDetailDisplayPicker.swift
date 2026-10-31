//
//  CityDetailDisplayPicker.swift
//  touchtimeWatch
//

import SwiftUI

enum CityDetailDisplay: String, CaseIterable, Identifiable {
    case worldClock
    case moonPhase

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .worldClock: "World Clock"
        case .moonPhase: "Moon Phase"
        }
    }

    var symbolName: String {
        switch self {
        case .worldClock: "globe"
        case .moonPhase: "moonphase.waning.gibbous"
        }
    }
}

/// A full-screen list of detail views, with the current choice checked.
struct CityDetailDisplayPicker: View {
    @Binding var selection: CityDetailDisplay
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(CityDetailDisplay.allCases) { display in
                Button {
                    selection = display
                    dismiss()
                } label: {
                    HStack {
                        Label(display.title, systemImage: display.symbolName)
                        Spacer(minLength: 4)
                        if selection == display {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.primary)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .accessibilityAddTraits(selection == display ? .isSelected : [])
            }
            .navigationTitle("View")
            .toolbarForegroundStyle(.primary, for: .navigationBar)
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
