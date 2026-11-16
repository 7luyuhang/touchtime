//
//  HomeDisplayPicker.swift
//  touchtimeWatch
//

import SwiftUI

/// What the app's home shows: the list of cities, the analog clock, or the
/// countdowns.
enum HomeDisplay: String, CaseIterable, Identifiable {
    case list
    case clock
    case countdowns

    /// The view the home shows, as last chosen.
    static let storageKey = "watchHomeDisplay"

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .list: "List"
        case .clock: "Clock"
        case .countdowns: "Countdowns"
        }
    }

    var symbolName: String {
        switch self {
        case .list: "list.bullet"
        case .clock: "clock"
        case .countdowns: "hourglass"
        }
    }
}

/// A full-screen list of the home's views, with the current choice checked.
struct HomeDisplayPicker: View {
    @Binding var selection: HomeDisplay
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(HomeDisplay.allCases) { display in
                row(for: display)
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

    private func row(for display: HomeDisplay) -> some View {
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
