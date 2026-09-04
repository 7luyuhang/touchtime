//
//  CustomRepeatSheet.swift
//  touchtime
//
//  Created on 03/09/2026.
//

import SwiftUI

/// Custom countdown repeat, set with wheels in the style of the time
/// offset sheet: every [n] [weeks | months | years]. The bindings are
/// live while scrolling; the caller applies them on confirm.
struct CustomRepeatSheet: View {
    @Binding var interval: Int
    @Binding var unit: CountdownItem.RepeatFrequency.Unit

    let onClose: () -> Void
    let onConfirm: () -> Void

    /// Selectable intervals; 1 maps back to the matching preset on confirm.
    static let intervalRange = 1...99

    var body: some View {
        NavigationStack {
            VStack {
                // Two wheels, count then unit: 2 | weeks.
                HStack(spacing: 0) {
                    Picker(String(localized: "Every"), selection: $interval) {
                        ForEach(Self.intervalRange, id: \.self) { value in
                            Text("\(value)")
                                .monospacedDigit()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)

                    Picker(String(localized: "Unit"), selection: $unit) {
                        ForEach(CountdownItem.RepeatFrequency.Unit.allCases, id: \.self) { unit in
                            Text(unitName(unit))
                                .frame(maxWidth: .infinity, alignment: .center)
                                .tag(unit)
                        }
                    }
                    .pickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                }
                .frame(height: 200)
            }
            .padding(.horizontal)
            .navigationTitle(String(localized: "Custom Repeat"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onConfirm) {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.hidden)
    }

    /// Unit wheel label, singular while the interval is 1 ("week") and
    /// plural otherwise ("weeks"), following the number as it scrolls.
    private func unitName(_ unit: CountdownItem.RepeatFrequency.Unit) -> String {
        switch unit {
        case .week: interval == 1 ? String(localized: "week") : String(localized: "weeks")
        case .month: interval == 1 ? String(localized: "month") : String(localized: "months")
        case .year: interval == 1 ? String(localized: "year") : String(localized: "years")
        }
    }
}

#Preview {
    @Previewable @State var interval = 2
    @Previewable @State var unit = CountdownItem.RepeatFrequency.Unit.week

    Color.clear
        .sheet(isPresented: .constant(true)) {
            CustomRepeatSheet(interval: $interval, unit: $unit, onClose: {}, onConfirm: {})
        }
}
