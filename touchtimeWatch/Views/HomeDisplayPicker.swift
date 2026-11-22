//
//  HomeDisplayPicker.swift
//  touchtimeWatch
//

import SwiftUI
import WatchKit

/// What the app's home shows: the list of cities, the analog clock, the
/// timer, the stopwatch, or the countdowns.
enum HomeDisplay: String, CaseIterable, Identifiable {
    case list
    case clock
    case timer
    case stopwatch
    case countdowns

    /// The view the home shows, as last chosen.
    static let storageKey = "watchHomeDisplay"

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .list: "List"
        case .clock: "Clock"
        case .timer: "Timer"
        case .stopwatch: "Stopwatch"
        case .countdowns: "Countdowns"
        }
    }

    var symbolName: String {
        switch self {
        case .list: "list.bullet"
        case .clock: "clock"
        case .timer: "timer"
        case .stopwatch: "stopwatch"
        case .countdowns: "hourglass"
        }
    }
}

/// The home's views full screen, each a pill that switches to it.
struct HomeDisplayPicker: View {
    @Binding var selection: HomeDisplay
    @Environment(\.dismiss) private var dismiss
    /// The pills in their places, rather than still to rise into them.
    @State private var showsPills = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    ForEach(Array(HomeDisplay.allCases.enumerated()), id: \.element.id) { index, display in
                        Button(display.title, systemImage: display.symbolName) {
                            selection = display
                            dismiss()
                        }
                        .buttonBorderShape(.capsule)
                        .accessibilityAddTraits(selection == display ? .isSelected : [])
                        // Keeps the pill's first layout, which lands in the same
                        // update, from stretching it out from the left with the rise
                        .animation(nil, value: showsPills)
                        .modifier(RiseIn(progress: showsPills ? 1 : 0))
                        // Held back past the start of the sheet's own
                        // transition, which hides what's on it at first
                        .animation(.smooth(duration: 0.3).delay(0.2 + Double(index) * 0.1), value: showsPills)
                    }
                }
                .scrollTargetLayout()
            }
            // Settling on the pills gives the Digital Crown a click for each,
            // as a list's rows have. Scrolled freely, it turns without one
            .scrollTargetBehavior(.viewAligned)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            showsPills = true
        }
    }
}

/// Brings a pill in as the watch's own lists open: up from the bottom of the
/// screen into its place, coming into focus and into view on the way.
/// `progress` runs from at the bottom (0) to in place (1).
private struct RiseIn: ViewModifier, Animatable {
    /// How blurred a pill is at the bottom.
    nonisolated private static let blurRadius: CGFloat = 12

    var progress: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        // The screen's rather than the scroll view's, which stops short of
        // its bottom edge
        let screenHeight = WKInterfaceDevice.current().screenBounds.height
        content
            .visualEffect { [progress, reduceMotion] content, geometry in
                // From its middle on the screen's bottom edge. Pills below the
                // screen fade in place.
                let rise = reduceMotion ? 0 : max(0, screenHeight - geometry.frame(in: .global).midY)
                return content
                    .offset(y: rise * (1 - progress))
                    .blur(radius: Self.blurRadius * (1 - progress))
                    .opacity(progress)
            }
    }
}
