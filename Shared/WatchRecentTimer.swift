//
//  WatchRecentTimer.swift
//  touchtime
//
//  The recent timers the iPhone app sends to the Apple Watch app over
//  WatchConnectivity.
//

import Foundation

/// A timer from the iPhone's Recents, which the watch's timer starts as it
/// is.
struct WatchRecentTimer: Codable, Identifiable, Hashable {
    let id: UUID
    /// Nil for a timer never named, which shows as Timer, as on iPhone.
    let name: String?
    let durationSeconds: Int
}
