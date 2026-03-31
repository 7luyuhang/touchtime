//
//  SetTimerSheet.swift
//  touchtime
//
//  Created on 28/03/2026.
//

import SwiftUI

struct SetTimerSheet: View {
    private struct TimerPreset: Identifiable {
        let seconds: Int
        let label: String

        var id: Int { seconds }
    }

    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    let onConfirm: (Int) -> Void

    @State private var selectedDuration: Int

    init(initialDurationSeconds: Int, onConfirm: @escaping (Int) -> Void) {
        let defaultDurationSeconds = 2 * 60
        let effectiveDuration = initialDurationSeconds > 0 ? initialDurationSeconds : defaultDurationSeconds
        let clampedDuration = min(max(effectiveDuration, 0), 59 * 60 + 59)
        self.onConfirm = onConfirm
        _selectedDuration = State(initialValue: clampedDuration)
    }

    private var totalSeconds: Int {
        selectedDuration
    }

    private var selectedMinutes: Int {
        selectedDuration / 60
    }

    private var selectedSeconds: Int {
        selectedDuration % 60
    }

    private var selectedTimeText: String {
        String(format: "%02d:%02d", selectedMinutes, selectedSeconds)
    }

    private var selectedMinutesBinding: Binding<Int> {
        Binding(
            get: { selectedMinutes },
            set: { newValue in
                selectedDuration = newValue * 60 + selectedSeconds
            }
        )
    }

    private var selectedSecondsBinding: Binding<Int> {
        Binding(
            get: { selectedSeconds },
            set: { newValue in
                selectedDuration = selectedMinutes * 60 + newValue
            }
        )
    }

    private let timerPresets: [TimerPreset] = [
        .init(seconds: 5 * 60, label: "5m"),
        .init(seconds: 10 * 60, label: "10m"),
        .init(seconds: 30 * 60, label: "30m"),
        .init(seconds: 45 * 60, label: "45m")
    ]

    private func selectPreset(_ preset: TimerPreset) {
        selectedDuration = preset.seconds
        if hapticEnabled {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.prepare()
            impact.impactOccurred()
        }
    }

    @ViewBuilder
    private func presetButton(_ preset: TimerPreset) -> some View {
        let isSelected = selectedDuration == preset.seconds
        let presetMinutes = preset.seconds / 60

        Button {
            selectPreset(preset)
        } label: {
            ZStack {
                // Scales
//                ForEach(0..<12, id: \.self) { index in
//                    Capsule()
//                        .fill(isSelected ? .white.opacity(0.50) : .white.opacity(0.10))
//                        .frame(
//                            width: 1.65,
//                            height: 4.5
//                        )
//                        .offset(y: -30)
//                        .rotationEffect(.degrees(Double(index) * 30))
//                        .blendMode(.plusLighter)
//                }
                VStack(spacing: 0) {
                    Text("\(presetMinutes)")
                        .font(.headline)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                    Text(String(localized: "min"))
                        .font(.footnote.weight(.semibold))
                }
                .foregroundStyle(isSelected ? .white : .white.opacity(0.50))
                .blendMode(.plusLighter)
            }
            .frame(width: 72, height: 72)
            .overlay(
                Circle()
                    .stroke(
                        isSelected ? .white.opacity(1.0) : .white.opacity(0.025),
                        lineWidth: 2.0
                    )
                    .blendMode(.plusLighter)
            )
        }
        .glassEffect(.regular, in: Circle())
        .buttonStyle(.plain)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                ZStack {
                    HStack(spacing: 0) {
                        Picker(String(localized: "Minutes"), selection: selectedMinutesBinding) {
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

                        Picker(String(localized: "Seconds"), selection: selectedSecondsBinding) {
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
                        Text(String(localized: "min"))
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 24)
                        Text(String(localized: "sec"))
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 24)
                    }
                    .allowsHitTesting(false)
                }
                .frame(height: 200)

                HStack(spacing: 0) {
                    ForEach(timerPresets) { preset in
                        presetButton(preset)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .navigationTitle(String(localized: "Timer"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if hapticEnabled {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onConfirm(totalSeconds)
                        dismiss()
                    } label: {
                        Image(systemName: "play.fill")
                            .foregroundStyle(totalSeconds == 0 ? .white.opacity(0.50) : .black)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .disabled(totalSeconds == 0)
                }
            }
        }
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
    }
}
