//
//  ScrollTimeQuickActionsPicker.swift
//  touchtime
//
//  Created on 22/09/2026.
//

import SwiftUI
import WeatherKit

/// Settings → Custom Quick Actions. Picks which tools appear when the time
/// slider is double-tapped (1–3, in selection order). The preview shows the
/// capsule row exactly as ScrollTimeView renders it, close button last.
struct ScrollTimeQuickActionsPicker: View {
    var weatherCondition: WeatherCondition? = nil
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage(ScrollTimeQuickAction.storageKey) private var quickActionsStorage = ""
    @Namespace private var glassNamespace

    /// Same height as the real controls (ScrollTimeView.controlHeight)
    private let controlHeight: CGFloat = 52

    private var selectedActions: [ScrollTimeQuickAction] {
        ScrollTimeQuickAction.selection(from: quickActionsStorage)
    }

    private var isSelectionFull: Bool {
        selectedActions.count >= ScrollTimeQuickAction.maxSelectionCount
    }

    /// The last remaining action can't be deselected
    private var isSelectionAtMinimum: Bool {
        selectedActions.count <= ScrollTimeQuickAction.minSelectionCount
    }

    private var isDefaultSelection: Bool {
        selectedActions == ScrollTimeQuickAction.defaultSelection
    }

    var body: some View {
        List {
            // Expanded controls preview on a live sky background
            Section {
                quickActionsPreview
                    .padding(.horizontal, 16)
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        ZStack {
                            Color.black
                            SkyBackgroundView(
                                date: Date(),
                                timeZoneIdentifier: TimeZone.current.identifier,
                                weatherCondition: weatherCondition
                            )
                        }
                    )
            } footer: {
                Text("Preview")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity)
            }

            Section {
                ForEach(ScrollTimeQuickAction.allCases) { action in
                    let selectionIndex = selectedActions.firstIndex(of: action)
                    let isSelected = selectionIndex != nil
                    // Locked when the row can't change: unselected at the
                    // limit, or the only selected one
                    let isLocked = isSelected ? isSelectionAtMinimum : isSelectionFull

                    Button(action: {
                        withAnimation {
                            toggleSelection(for: action)
                        }

                        if hapticEnabled {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }) {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: action.systemImage, topColor: .gray, bottomColor: .gray, style: .plain)
                            Text(action.localizedName)

                            Spacer()

                            Image(systemName: selectionIndex.map { "\($0 + 1).circle.fill" } ?? "circle")
                                .font(.title3.weight(.medium))
                                .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.25))
                                .contentTransition(.symbolEffect(.replace))
                                .opacity(!isSelected && isSelectionFull ? 0 : 1)
                                .animation(nil, value: isSelectionFull)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isLocked)
                }
            }
        }
        .scrollIndicators(.hidden)
        .navigationTitle("Custom Quick Actions")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation {
                        // Empty storage means "not customised" and decodes to the default set
                        quickActionsStorage = ""
                    }

                    if hapticEnabled {
                        let feedback = UINotificationFeedbackGenerator()
                        feedback.prepare()
                        feedback.notificationOccurred(.success)
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                }
                .accessibilityLabel(Text("Reset to Default"))
                .disabled(isDefaultSelection)
            }
        }
    }

    /// The capsule row as ScrollTimeView shows it after a double-tap:
    /// the selected actions in order, then the close button.
    private var quickActionsPreview: some View {
        GlassEffectContainer(spacing: 5) {
            HStack(spacing: 5) {
                ForEach(selectedActions) { action in
                    previewCapsule(systemImage: action.systemImage)
                        .glassEffectID(action.id, in: glassNamespace)
                }

                previewCapsule(systemImage: "xmark")
                    .glassEffectID("close", in: glassNamespace)
            }
        }
        .padding(.horizontal, 5)
        .animation(.spring(), value: selectedActions)
    }

    /// Mirrors ScrollTimeView.expandedControlButton, without the action
    private func previewCapsule(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.title3.weight(.medium))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: controlHeight)
            .glassEffect(.regular.interactive())
            .glassEffectTransition(.matchedGeometry)
    }

    private func toggleSelection(for action: ScrollTimeQuickAction) {
        var selection = selectedActions
        if let index = selection.firstIndex(of: action) {
            guard selection.count > ScrollTimeQuickAction.minSelectionCount else { return }
            selection.remove(at: index)
        } else {
            guard selection.count < ScrollTimeQuickAction.maxSelectionCount else { return }
            selection.append(action)
        }
        quickActionsStorage = ScrollTimeQuickAction.storageString(for: selection)
    }
}
