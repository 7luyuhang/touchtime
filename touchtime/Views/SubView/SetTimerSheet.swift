//
//  SetTimerSheet.swift
//  touchtime
//
//  Created on 28/03/2026.
//

import SwiftUI

struct SetTimerSheet: View {
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                
                ZStack {
                    HStack(spacing: 0) {
                        Picker("Minutes", selection: selectedMinutesBinding) {
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

                        Picker("Seconds", selection: selectedSecondsBinding) {
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
                        Text("min")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 24)
                        Text("sec")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 24)
                    }
                    .allowsHitTesting(false)
                }
                .frame(height: 200)
            }
            .padding(.horizontal)
            .navigationTitle("Timer")
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
                            .foregroundStyle(totalSeconds == 0 ? .white : .black)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .disabled(totalSeconds == 0)
                }
            }
        }
        .presentationDetents([.height(280)])
    }
}
