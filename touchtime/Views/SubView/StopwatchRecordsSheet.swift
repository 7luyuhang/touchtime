//
//  StopwatchRecordsSheet.swift
//  touchtime
//
//  Created on 22/09/2026.
//

import SwiftUI
import UIKit

/// Finished stopwatch sessions, newest first, opened from the Tools menu.
/// Each row shows when the stopwatch was reset and the time it had reached;
/// a session with laps also lists their count, and tapping it swaps the list
/// for its laps in place. (Not a push: a pushed page gets an opaque backing
/// that breaks the sheet's glass.)
struct StopwatchRecordsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var records: [StopwatchRecord] = StopwatchRecordStore.load()
    /// The session whose laps are showing instead of the records.
    @State private var openedRecord: StopwatchRecord? = nil

    @AppStorage("dateStyle") private var dateStyle = "Relative"
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    private var isShowingLaps: Bool {
        openedRecord != nil
    }

    var body: some View {
        NavigationStack {
            Group {
                if let openedRecord {
                    StopwatchLapListView(laps: openedRecord.laps)
                        .transition(.blurReplace())
                } else {
                    recordsPage
                        .transition(.blurReplace())
                }
            }
            .animation(.smooth(duration: 0.30), value: openedRecord)
            .navigationTitle(isShowingLaps ? String(localized: "Laps") : String(localized: "Stopwatch"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isShowingLaps {
                        // Back to the records
                        Button {
                            triggerHaptic()
                            openedRecord = nil
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                    } else {
                        Button {
                            triggerHaptic()
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }

                if !isShowingLaps && !records.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Menu {
                            Menu {
                                Button(role: .destructive) {
                                    deleteAllRecords()
                                } label: {
                                    Label(String(localized: "Confirm Remove"), systemImage: "checkmark.circle.badge.xmark")
                                }
                            } label: {
                                Label(String(localized: "Remove All"), systemImage: "minus.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var recordsPage: some View {
        if records.isEmpty {
            // Blank State
            ContentUnavailableView {
                Label(String(localized: "No Records"), systemImage: "stopwatch")
            } description: {
                Text(String(localized: "Reset the stopwatch to keep its time and laps here"))
            }
            .frame(maxHeight: .infinity)
        } else {
            List {
                ForEach(records) { record in
                    Section {
                        recordRow(record)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteRecord(record)
                                } label: {
                                    Label(String(localized: "Remove"), systemImage: "minus.circle.fill")
                                }
                            }
                            .contextMenu {
                                Menu {
                                    Button(role: .destructive) {
                                        deleteRecord(record)
                                    } label: {
                                        Label(String(localized: "Confirm Remove"), systemImage: "checkmark.circle.badge.xmark")
                                    }
                                } label: {
                                    Label(String(localized: "Remove"), systemImage: "minus.circle")
                                }
                            }
                    }
                }
            }
            .listSectionSpacing(12) // List paddings
            .scrollIndicators(.hidden)
        }
    }

    /// Only a session with laps has somewhere to go, so only it gets the
    /// chevron and opens on tap.
    private func recordRow(_ record: StopwatchRecord) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(recordedAtText(for: record))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .blendMode(.plusLighter)

                Text(StopwatchTimeFormatter.string(from: record.totalSeconds))
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .monospacedDigit()

                if !record.laps.isEmpty {
                    Text(lapCountText(for: record))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                }
            }

            if !record.laps.isEmpty {
                Spacer()

                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !record.laps.isEmpty else { return }
            triggerHaptic()
            openedRecord = record
        }
    }

    /// "Today · 2:41 pm": the day in the user's date style, then the time.
    private func recordedAtText(for record: StopwatchRecord) -> String {
        let day = record.recordedAt.formattedDate(style: dateStyle)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = use24HourFormat ? "HH:mm" : "h:mm a"
        let time = formatter.string(from: record.recordedAt)

        return "\(day) · \(use24HourFormat ? time : time.lowercased())"
    }

    private func lapCountText(for record: StopwatchRecord) -> String {
        if record.laps.count == 1 {
            return String(localized: "1 Lap")
        }
        return String.localizedStringWithFormat(String(localized: "%d Laps"), record.laps.count)
    }

    private func deleteRecord(_ record: StopwatchRecord) {
        records.removeAll { $0.id == record.id }
        StopwatchRecordStore.save(records)
        triggerHaptic()
    }

    private func deleteAllRecords() {
        records.removeAll()
        StopwatchRecordStore.save(records)
        triggerHaptic()
    }

    private func triggerHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}
