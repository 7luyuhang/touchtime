//
//  StopwatchRecordStore.swift
//  touchtime
//
//  Storage for finished stopwatch sessions.
//

import Foundation

/// A finished stopwatch session: the time on the stopwatch and its laps at
/// the moment it was reset. Listed in the Stopwatch sheet.
struct StopwatchRecord: Identifiable, Codable, Equatable {
    let id: UUID
    /// When the stopwatch was reset, ending the session.
    let recordedAt: Date
    /// Total time on the stopwatch when it was reset.
    let totalSeconds: TimeInterval
    /// Duration of each completed lap, in recorded order.
    let laps: [TimeInterval]
}

/// Persists finished stopwatch sessions in UserDefaults, newest first.
enum StopwatchRecordStore {
    private static let storageKey = "stopwatchRecords"
    private static let maxCount = 100

    static func load() -> [StopwatchRecord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let records = try? JSONDecoder().decode([StopwatchRecord].self, from: data) else {
            return []
        }
        return records.sorted { $0.recordedAt > $1.recordedAt }
    }

    static func save(_ records: [StopwatchRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    /// Keeps the session that is being reset at the front of the list,
    /// capping the history size. A stopwatch that never ran leaves nothing
    /// behind. Returns the updated list.
    @discardableResult
    static func remember(totalSeconds: TimeInterval, laps: [TimeInterval], at date: Date = Date()) -> [StopwatchRecord] {
        guard totalSeconds > 0 || !laps.isEmpty else { return load() }

        var records = load()
        records.insert(
            StopwatchRecord(id: UUID(), recordedAt: date, totalSeconds: totalSeconds, laps: laps),
            at: 0
        )
        if records.count > maxCount {
            records = Array(records.prefix(maxCount))
        }
        save(records)
        return records
    }
}
