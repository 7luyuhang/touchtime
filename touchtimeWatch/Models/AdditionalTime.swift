//
//  AdditionalTime.swift
//  touchtimeWatch
//

import SwiftUI

/// What shows beside each city's time: how far it is from the watch's time
/// zone, or from UTC.
enum AdditionalTime: String, CaseIterable, Identifiable {
    case timeShift
    case utc

    /// The watch app's Additional Time setting.
    static let storageKey = "additionalTimeDisplay"

    var id: Self { self }

    var title: LocalizedStringKey {
        switch self {
        case .timeShift: "Time Shift"
        case .utc: "UTC"
        }
    }

    /// `timeZone`'s whole hours from the watch's time zone, like "+8h", or
    /// from UTC, like "UTC +8", at `date`.
    func text(for timeZone: TimeZone, at date: Date) -> String {
        switch self {
        case .timeShift: WorldClock.timeDifference(to: timeZone, at: date)
        case .utc: WorldClock.utcOffset(of: timeZone, at: date)
        }
    }
}
