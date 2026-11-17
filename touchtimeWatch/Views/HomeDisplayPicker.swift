//
//  HomeDisplayPicker.swift
//  touchtimeWatch
//

import SwiftUI

/// What the app's home shows: the list of cities, the analog clock, the
/// countdowns, or the timer.
enum HomeDisplay: String, CaseIterable, Identifiable {
    case list
    case clock
    case countdowns
    case timer

    /// The view the home shows, as last chosen.
    static let storageKey = "watchHomeDisplay"

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .list: "List"
        case .clock: "Clock"
        case .countdowns: "Countdowns"
        case .timer: "Timer"
        }
    }

    var symbolName: String {
        switch self {
        case .list: "list.bullet"
        case .clock: "clock"
        case .countdowns: "hourglass"
        case .timer: "timer"
        }
    }
}

/// The home's views full screen, each a pill that switches to it.
struct HomeDisplayPicker: View {
    @Binding var selection: HomeDisplay
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    ForEach(HomeDisplay.allCases) { display in
                        Button(display.title, systemImage: display.symbolName) {
                            selection = display
                            dismiss()
                        }
                        .buttonBorderShape(.capsule)
                        .accessibilityAddTraits(selection == display ? .isSelected : [])
                    }
                }
            }
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
