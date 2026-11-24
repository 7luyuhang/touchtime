//
//  WatchRecentTimer.swift
//  touchtime
//
//  The recent timers the iPhone app sends to the Apple Watch app over
//  WatchConnectivity, and those started on the watch, which it sends back
//  for them.
//

import Foundation

/// A timer from the iPhone's Recents, which the watch's timer starts as it
/// is, or one started on the watch, for them.
struct WatchRecentTimer: Codable, Identifiable, Hashable {
    /// How many Recents keeps, the most recently started first.
    static let maxCount = 24

    let id: UUID
    /// Nil for a timer never named, which shows as Timer, as on iPhone.
    let name: String?
    let durationSeconds: Int
}
