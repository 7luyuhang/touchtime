//
//  CountdownListView.swift
//  touchtimeWatch
//

import SwiftUI

/// The iPhone app's countdowns, in the list of cities' place once chosen.
/// Each row is laid out like a city's, and filled like the countdown's card
/// on iPhone: with its cover emoji's colour, or its photo blurred. It opens
/// the countdown's details, where the cover itself shows.
struct CountdownListView: View {
    @Binding var selection: WatchCountdown.ID?

    @Environment(WatchCityStore.self) private var cityStore

    var body: some View {
        if cityStore.countdowns.isEmpty {
            emptyState("No Countdowns")
        } else {
            // Each minute, so the counts turn over at midnight
            TimelineView(.everyMinute) { context in
                List(cityStore.countdowns, selection: $selection) { countdown in
                    NavigationLink(value: countdown.id) {
                        CountdownCard(countdown: countdown, now: context.date, unit: cityStore.countdownUnit)
                            // As a city's row, less below, as the digits leave
                            // the space under their baseline empty
                            .padding(.top, 12)
                            .padding(.bottom, 4)
                    }
                    .listRowBackground(countdown.background.map { CountdownRowBackground(background: $0) })
                }
            }
        }
    }

    /// Only `title`, in a label with no icon: bare text in its place isn't
    /// styled as the title.
    private func emptyState(_ title: LocalizedStringKey) -> some View {
        ContentUnavailableView {
            Label {
                Text(title)
            } icon: {
                EmptyView()
            }
        }
        // Left to fill the screen, the view sets its content at the top;
        // sized to the title instead, it's centred below the toolbar
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxHeight: .infinity)
    }
}

/// A countdown's row filled as its card is on iPhone, in the rounded shape
/// the list gives its rows.
private struct CountdownRowBackground: View {
    let background: WatchCountdown.Background

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        CountdownBackground(background: background)
            .clipShape(shape)
            .overlay {
                shape
                    .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    .blendMode(.plusLighter)
            }
    }
}
