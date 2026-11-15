//
//  WatchCountdown.swift
//  touchtime
//
//  The countdowns the iPhone app sends to the Apple Watch app over
//  WatchConnectivity.
//

import Foundation

/// A countdown as the watch shows it. The watch shows no cover, only the
/// background the iPhone's card takes from it, worked out on the iPhone:
/// the watch can't measure an emoji's colour, and the photo is too big to
/// send as it is.
struct WatchCountdown: Codable, Identifiable, Hashable {
    /// What fills the card behind the countdown.
    enum Background: Codable, Hashable {
        /// The cover emoji's dominant colour.
        case color(hue: Double, saturation: Double, brightness: Double)
        /// The cover photo as framed in its badge, shrunk to a JPEG a few
        /// pixels across: blurred over the card, that's all of it that
        /// shows.
        case photo(Data)
    }

    let id: UUID
    let title: String
    /// As set on the iPhone; see `effectiveTargetDate(at:)` for repeating
    /// countdowns.
    let targetDate: Date
    let repeatFrequency: CountdownItem.RepeatFrequency
    /// When counting was paused, or nil while it counts.
    let pausedAt: Date?
    /// Nil when the cover gave none, as for a countdown saved without one.
    let background: Background?

    /// The stored date for one-off countdowns; for repeating ones, the
    /// next occurrence on or after `now`'s calendar day.
    func effectiveTargetDate(at now: Date) -> Date {
        CountdownItem.nextOccurrence(of: targetDate, frequency: repeatFrequency, after: now)
    }
}
