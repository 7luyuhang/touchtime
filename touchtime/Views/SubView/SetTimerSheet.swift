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
    private let requiresReplacementConfirmation: Bool

    @State private var selectedDuration: Int
    @State private var showReplaceTimerConfirmation = false

    init(initialDurationSeconds: Int, onConfirm: @escaping (Int) -> Void) {
        let defaultDurationSeconds = 2 * 60
        let effectiveDuration = initialDurationSeconds > 0 ? initialDurationSeconds : defaultDurationSeconds
        let clampedDuration = min(max(effectiveDuration, 0), 59 * 60 + 59)
        self.onConfirm = onConfirm
        self.requiresReplacementConfirmation = initialDurationSeconds > 0
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

    private func confirmTimer() {
        onConfirm(totalSeconds)
        dismiss()
    }

    var body: some View {
        NavigationStack {
            VStack {
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
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 16)
                        Text(String(localized: "sec"))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            .padding(.trailing, 16)
                    }
                    .allowsHitTesting(false)
                }
                .frame(height: 200)
            }
            .padding(.horizontal)
            .navigationTitle(String(localized: "New Timer"))
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
                        if requiresReplacementConfirmation {
                            showReplaceTimerConfirmation = true
                        } else {
                            confirmTimer()
                        }
                    } label: {
                        Image(systemName: "play.fill")
                            .foregroundStyle(totalSeconds == 0 ? .white.opacity(0.50) : .black)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .disabled(totalSeconds == 0)
                    .confirmationDialog(
                        String(localized: "Are you sure you want to replace current timer?"),
                        isPresented: $showReplaceTimerConfirmation,
                        titleVisibility: .visible
                    ) {
                        Button(String(localized: "Replace"), role: .destructive) {
                            confirmTimer()
                        }
                    }
                }
            }
        }
        .presentationDetents([.height(300)])
        .presentationDragIndicator(.hidden)
    }
}
