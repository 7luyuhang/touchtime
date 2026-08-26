//
//  HomeCountdownSection.swift
//  touchtime
//
//  Created on 24/08/2026.
//

import SwiftUI

/// Pinned countdowns shown below the home timer: one preview card per
/// pinned countdown, ordered by target date. Day counts follow the
/// scrubbed time passed in as `now`.
struct HomeCountdownSection: View {
    let countdowns: [CountdownItem]
    /// Reference "now" (current time plus the Slide to Adjust offset)
    /// used for the day counts.
    let now: Date

    private var pinnedCountdowns: [CountdownItem] {
        countdowns
            .filter(\.isPinned)
            .sorted { $0.targetDate < $1.targetDate }
    }

    var body: some View {
        ForEach(pinnedCountdowns) { item in
            Section {
                CountdownPreviewCard(
                    title: item.title,
                    targetDate: item.targetDate,
                    emoji: item.emoji,
                    photoData: item.photoData,
                    now: now
                )
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
    }
}
