//
//  WatchCountdown.swift
//  touchtime
//
//  The countdowns the iPhone app sends to the Apple Watch app over
//  WatchConnectivity.
//

import Foundation

/// A countdown as the watch shows it: its row filled with the background
/// the iPhone's card takes from its cover, and its details with the cover
/// itself. Both are worked out on the iPhone: the watch can't measure an
/// emoji's colour, and the photo is too big to send as it is.
struct WatchCountdown: Codable, Identifiable, Hashable {
    /// What fills the card behind the countdown.
    enum Background: Codable, Hashable {
        /// The cover emoji's dominant colour.
        case color(hue: Double, saturation: Double, brightness: Double)
        /// The cover photo as framed in its badge, shrunk to a JPEG a few
        /// pixels across: blurred over the card, that's all of it that
        /// shows there.
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
    /// Pinned to Home on the iPhone.
    let isPinned: Bool
    /// The cover emoji, which a cover photo takes the place of.
    let emoji: String?
    /// The name of the file the cover photo comes to the watch in, apart
    /// from the countdowns: as framed in its badge and as sharp as the
    /// details show it. Each new cover photo comes in a new file; nil
    /// without one.
    let coverPhotoFileName: String?
    /// Nil when the cover gave none, as for a countdown saved without one.
    let background: Background?

    /// The stored date for one-off countdowns; for repeating ones, the
    /// next occurrence on or after `now`'s calendar day.
    func effectiveTargetDate(at now: Date) -> Date {
        CountdownItem.nextOccurrence(of: targetDate, frequency: repeatFrequency, after: now)
    }
}
