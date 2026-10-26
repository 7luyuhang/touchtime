//
//  HomeView+Toolbar.swift
//  touchtime
//

import SwiftUI

extension HomeView {
    @ToolbarContentBuilder
    var homeToolbar: some ToolbarContent {
        // Collection Name - Tappable to cycle through collections
        if selectedCollectionId != nil && collections.count > 1 {
            ToolbarItem(placement: .principal) {
                Button {
                    cycleToNextCollection()
                } label: {
                    Text(currentCollectionName)
                        .font(.subheadline.weight(.semibold))
                        .contentTransition(.numericText())
                        .padding(.horizontal, 16)
                        .frame(height: 44)
                        .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
                        .lineLimit(1)
                        .animation(.snappy, value: currentCollectionName)
                }
                .buttonStyle(.plain)
            }
        } else if selectedCollectionId != nil {
            // Show non-tappable collection name when only one collection exists
            ToolbarItem(placement: .principal) {
                Text(currentCollectionName)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .frame(height: 44)
                    .glassEffect(.regular, in: Capsule(style: .continuous))
                    .lineLimit(1)
            }
        }
        ToolbarItem(placement: .topBarLeading) {
            Menu {
                menuContent
            } label: {
                Image(systemName: "ellipsis")
            }
        }
        
        ToolbarItem(placement: .topBarTrailing) {
            // Earth View Button
            Button(action: {
                if hapticEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                }
                showEarthView = true
            }) {
                Image(systemName: "globe.americas.fill")
            }
        }
    }

    @ViewBuilder
    private var menuContent: some View {
        if !hasLifetimeAccess {
            Button(action: {
                if hapticEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                }
                showLifetimeStore = true
            }) {
                Text(String(localized: "Lifetime"))
                Text(String(localized: "Unlock all features"))
                Image(systemName: "heart")
            }
            
            Divider()
        }

        ControlGroup {
            // Settings Section
            Button(action: {
                if hapticEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                }
                showSettingsSheet = true
            }) {
                Label("Settings", systemImage: "gear")
            }

            // Share Section - entry stays even with nothing to share
            Button(action: {
                // Provide haptic feedback if enabled
                if hapticEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                }
                showShareSheet = true
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            // Arrange Section - only show if there are world clocks or collections
            if !worldClocks.isEmpty || !collections.isEmpty {
                Button(action: {
                    if hapticEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.prepare()
                        impactFeedback.impactOccurred()
                    }
                    showArrangeListSheet = true
                }) {
                    Label(String(localized: "Arrange"), systemImage: "list.bullet")
                }
            }
        }

        Divider()

        // Collections
        if !collections.isEmpty {
            Button {
                selectedCollectionId = nil
                saveSelectedCollection()
                if hapticEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            } label: {
                Label("All Cities", systemImage: selectedCollectionId == nil ? "checkmark.circle" : "")
            }
            
            ForEach(collections) { collection in
                Button {
                    selectedCollectionId = collection.id
                    saveSelectedCollection()
                    if hapticEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                } label: {
                    Label(collection.name, systemImage: selectedCollectionId == collection.id ? "checkmark.circle" : "")
                }
            }
            Divider()
        }
        
        Section(String(localized: "Tools")) {
            Button(action: {
                if hapticEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                }
                showSetAlarmSheet = true
            }) {
                Label(String(localized: "Alarms"), systemImage: "alarm")
            }

            Button(action: {
                if hapticEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                }
                showSetTimerSheet = true
            }) {
                Label(String(localized: "Timers"), systemImage: "timer")
            }

            Button(action: {
                if hapticEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                }
                showStopwatchRecordsSheet = true
            }) {
                Label(String(localized: "Stopwatch"), systemImage: "stopwatch")
            }

            Button(action: {
                if hapticEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                }
                showCountdownSheet = true
            }) {
                Label(String(localized: "Countdowns"), systemImage: "hourglass")
            }
        }

        Divider()

        Button(action: {
            if hapticEnabled {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.prepare()
                impactFeedback.impactOccurred()
            }
            showComplicationsSheet = true
        }) {
            Label(String(localized: "Complications"), systemImage: "watch.analog")
        }

        Button(action: {
            if hapticEnabled {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.prepare()
                impactFeedback.impactOccurred()
            }
            showWidgetIntroSheet = true
        }) {
            Label(String(localized: "Widgets"), systemImage: "widget.small")
        }
    }
}
