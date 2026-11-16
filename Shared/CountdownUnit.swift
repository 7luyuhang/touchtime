//
//  CountdownUnit.swift
//  touchtime
//
//  Created on 15/11/2026.
//

import Foundation

/// The units a countdown's card counts in, from the largest. The card
/// counts in the largest one switched on in the countdown sheet's Time
/// Display.
enum CountdownUnit: String {
    case years
    case months
    case days

    /// The largest unit switched on in Time Display, which always keeps one
    /// on: days, when neither years nor months is.
    init(showYears: Bool, showMonths: Bool) {
        if showYears {
            self = .years
        } else if showMonths {
            self = .months
        } else {
            self = .days
        }
    }

    /// The count from `date` to `targetDate`, both taken at the start of
    /// their day, in whole units of this size, or of the next smaller one
    /// while there isn't a whole one: with years, 2 years, then 5 months,
    /// then 12 days.
    func count(from date: Date, to targetDate: Date) -> CountdownCount {
        let calendar = Calendar.current
        let value = calendar.dateComponents(
            [component],
            from: calendar.startOfDay(for: date),
            to: calendar.startOfDay(for: targetDate)
        ).value(for: component) ?? 0
        if value == 0, let smaller {
            return smaller.count(from: date, to: targetDate)
        }
        return CountdownCount(value: value, unit: self)
    }

    private var component: Calendar.Component {
        switch self {
        case .years: .year
        case .months: .month
        case .days: .day
        }
    }

    private var smaller: CountdownUnit? {
        switch self {
        case .years: .months
        case .months: .days
        case .days: nil
        }
    }
}

/// How far off a countdown's event is, as its card shows it.
struct CountdownCount: Equatable {
    /// Negative once the event has happened; 0 only on the day itself.
    let value: Int
    let unit: CountdownUnit
}
