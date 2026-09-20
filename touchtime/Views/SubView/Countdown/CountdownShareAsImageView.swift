//
//  CountdownShareAsImageView.swift
//  touchtime
//
//  Created on 08/09/2026.
//

import SwiftUI
import UIKit

/// Share-as-image screen for a countdown: `ShareAsImageView` around the
/// countdown share card, its footer broken into the units picked in the
/// countdown sheet's Time Display settings.
struct CountdownShareAsImageView: View {
    // Time Display settings from the countdown sheet, as the menu shares use.
    @AppStorage("countdownShowYears") private var showYears = false
    @AppStorage("countdownShowMonths") private var showMonths = false
    @AppStorage("countdownShowDays") private var showDays = true

    let title: String
    let targetDate: Date
    let emoji: String?
    let photoData: Data?
    /// How the photo is framed in the badge; nil shows it centred.
    let photoCrop: CountdownItem.PhotoCrop?
    /// True for repeating countdowns; swaps the card's arrow for a
    /// repeat symbol.
    let isRepeating: Bool
    /// Reference "now" for the day count and the footer line.
    var now: Date = Date()

    var body: some View {
        ShareAsImageView(title: title) { aspectRatio, frameCornerRadius in
            CountdownCardSnapshotView(
                title: title,
                targetDate: targetDate,
                emoji: emoji,
                photoData: photoData,
                photoCrop: photoCrop,
                isRepeating: isRepeating,
                now: now,
                footerText: CountdownShare.footerText(
                    from: now,
                    to: targetDate,
                    showYears: showYears,
                    showMonths: showMonths,
                    showDays: showDays
                ),
                aspectRatio: aspectRatio,
                frameCornerRadius: frameCornerRadius
            )
            .environment(\.colorScheme, .dark)
        } render: { aspectRatio in
            CountdownShare.renderCardImage(
                title: title,
                targetDate: targetDate,
                emoji: emoji,
                photoData: photoData,
                photoCrop: photoCrop,
                isRepeating: isRepeating,
                now: now,
                showYears: showYears,
                showMonths: showMonths,
                showDays: showDays,
                aspectRatio: aspectRatio
            )
        }
    }
}
