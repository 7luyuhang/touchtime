//
//  ScrollTimeOffsetAdjustmentSheet.swift
//  touchtime
//
//  Created on 31/05/2026.
//

import SwiftUI

enum ScrollTimeOffsetDirection: Int, CaseIterable, Hashable, Identifiable {
    case increase = 1
    case decrease = -1

    var id: Int { rawValue }

    var symbol: String {
        switch self {
        case .increase:
            return "+"
        case .decrease:
            return "-"
        }
    }
}

struct ScrollTimeOffsetAdjustmentSheet: View {
    @Binding var direction: ScrollTimeOffsetDirection
    @Binding var hours: Int
    @Binding var minutes: Int

    let onClose: () -> Void
    let onConfirm: () -> Void

    private var maxHourPickerValue: Int {
        24
    }

    var body: some View {
        NavigationStack {
            VStack {
                ZStack {
                    HStack(spacing: 0) {
                        Picker(String(localized: "Direction"), selection: $direction) {
                            ForEach(ScrollTimeOffsetDirection.allCases) { direction in
                                Text(direction.symbol)
                                    .font(.title3.weight(.semibold))
                                    .monospacedDigit()
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .tag(direction)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)

                        Picker(String(localized: "Hours"), selection: $hours) {
                            ForEach(0...maxHourPickerValue, id: \.self) { value in
                                Text(String(format: "%02d", value))
                                    .monospacedDigit()
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)

                        Picker(String(localized: "Minutes"), selection: $minutes) {
                            ForEach(0..<60, id: \.self) { value in
                                Text(String(format: "%02d", value))
                                    .monospacedDigit()
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .tag(value)
                            }
                        }
                        .pickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity)
                    }

                    HStack(spacing: 0) {
                        Color.clear
                            .frame(maxWidth: .infinity)
                        Text(String(localized: "hr"))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 16)
                        Text(String(localized: "min"))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 16)
                    }
                    .allowsHitTesting(false)
                }
                .frame(height: 200)
            }
            .padding(.horizontal)
            .navigationTitle(String(localized: "Adjust Time"))
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
}
