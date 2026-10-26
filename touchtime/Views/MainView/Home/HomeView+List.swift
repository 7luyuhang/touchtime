//
//  HomeView+List.swift
//  touchtime
//

import SwiftUI

extension HomeView {
    var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing here", systemImage: selectedCollectionId != nil ? "questionmark.folder" : "location.magnifyingglass")
        } description: {
            Text(selectedCollectionId != nil ? "No cities in this collection." : "Add cities to track time.")
        } actions: {
            if selectedCollectionId != nil {
                Button {
                    if hapticEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                    showArrangeListSheet = true
                } label: {
                    Text("Add Cities")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                        .glassEffect(.clear.interactive())
                        .buttonStyle(.plain)
                }
            }
        }
        .background(Color.clear)
        .id("empty-\(selectedCollectionId?.uuidString ?? "")")
        .transition(.identity) // Collection Animation
    }

    var homeList: some View {
        List {
            tipSections

            timerAndStopwatchSections

            countdownSection

            localTimeSection

            addCitiesSection

            // City list
            ForEach(displayedClocks) { clock in
                citySection(for: clock)
            }
        }
        .listSectionSpacing(12) // List Paddings
        .scrollIndicators(.hidden)
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .safeAreaPadding(.bottom, 52)
        // Same width as Slide to Adjust beside the vertical bar
        .verticalBarListMargin(20)
        // In regular width the list drops its side margins; the
        // phone-wide column keeps a phone's
        .safeAreaPadding(.horizontal, usesPhoneColumn ? 20 : 0)
        // Below the details it fades in from the fold
        .foldEdgeFade(.top, isActive: splitAxis == .vertical)
        .id(selectedCollectionId?.uuidString ?? "default")
        .transition(.identity) // Collection Animation
        // Centralized batch weather prefetch for all displayed cities
        .task(id: "\(displayedClocks.map(\.timeZoneIdentifier))_\(showWeather)_\(effectiveShowWeatherCondition)_\(effectiveShowTemperatureIndicator)_\(effectiveShowUVIndex)_\(effectiveShowWindDirection)_\(showSkyDot)") {
            if showWeather || effectiveShowWeatherCondition || effectiveShowTemperatureIndicator || effectiveShowUVIndex || effectiveShowWindDirection {
                var identifiers = displayedClocks.map(\.timeZoneIdentifier)
                if showLocalTime {
                    identifiers.insert(TimeZone.current.identifier, at: 0)
                }
                await weatherManager.getWeatherForCities(identifiers)
            }
        }
    }

    @ViewBuilder
    private var tipSections: some View {
        // Time Zone Updated Tip (shown after the device's time zone changes)
        if showLocalTime && showTimeZoneUpdatedTip {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "clock.badge.airplane")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                        .frame(width: 24, height: 24)
                    
                    Text(String(localized: "Time Zone Updated"))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 24, height: 24)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.black.opacity(0.10))
                        .glassEffect(.clear.interactive(),
                                     in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring()) {
                        showTimeZoneUpdatedTip = false
                    }
                    if hapticEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                        impactFeedback.impactOccurred()
                    }
                }
            }
        }
        
        // Shake to Reset Tip (shown after first city deletion)
        if showShakeToResetTip {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .symbolEffect(.wiggle.clockwise.byLayer, options: .repeat(.periodic(delay: 1.0)))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                        .frame(width: 24, height: 24)
                    
                    Text(String(localized: "Shake device to undo"))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 24, height: 24)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.black.opacity(0.10))
                        .glassEffect(.clear.interactive(),
                                     in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring()) {
                        showShakeToResetTip = false
                    }
                    if hapticEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                        impactFeedback.impactOccurred()
                    }
                }
            }
        }
        
        // What's New Section
        if showWhatsNewSwipeAdjust {
            Section {
                HStack(spacing: 16) {
                    Image(systemName: "hand.draw.fill")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                        .blendMode(.plusLighter)
                        .frame(width: 24, height: 24)
                    
                    Text("Swipe right for precise time adjustment or set alarms")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 24, height: 24)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.black.opacity(0.10))
                        .glassEffect(.clear.interactive(),
                                     in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring()) {
                        showWhatsNewSwipeAdjust = false
                    }
                    if hapticEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                        impactFeedback.impactOccurred()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var timerAndStopwatchSections: some View {
        // Home Timer Section
        if hasConfiguredHomeTimer {
            HomeTimerSection(
                timerName: homeTimerDisplayName,
                configuredSeconds: homeTimerConfiguredSeconds,
                endDateEpoch: homeTimerEndDateEpoch,
                isPaused: homeTimerPaused,
                pausedRemainingSeconds: homeTimerPausedRemainingSeconds,
                onRename: renameHomeTimer,
                onTap: handleHomeTimerTap,
                onReset: resetHomeTimer,
                onDelete: clearHomeTimer
            )
        }

        // Home Stopwatch Section
        if homeStopwatch.hasStarted {
            HomeStopwatchSection(
                stopwatch: homeStopwatch,
                onTap: handleHomeStopwatchTap,
                onReset: resetHomeStopwatch
            )
        }
    }

    private var countdownSection: some View {
        // Countdown Preview Section: pinned countdowns live below the
        // timer, narrowed to the selected collection like the cities
        HomeCountdownSection(
            countdowns: displayedCountdowns,
            now: currentDate.addingTimeInterval(timeOffset),
            isCollapsed: isCountdownStackCollapsed,
            // Neither animated; the stack slides the cards in
            // and out itself
            onCollapse: {
                if displayedCountdowns.count > 1 {
                    isCountdownStackCollapsed = true
                }
            },
            onExpand: {
                isCountdownStackCollapsed = false
            },
            onTap: { item in
                if hapticEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
                editingHomeCountdown = item
            },
            onUnpin: { item in
                unpinCountdown(item)
            },
            onShare: { item in
                countdownShareData = CountdownShareData(
                    item: item,
                    now: currentDate.addingTimeInterval(timeOffset)
                )
            },
            onArrange: {
                showArrangeListSheet = true
            }
        )
    }

    @ViewBuilder
    private var localTimeSection: some View {
        // Local Time Section
        if showLocalTime {
            Section {
                LocalTimeRowContent(
                    currentDate: $currentDate,
                    timeOffset: $timeOffset,
                    complicationOptions: complicationOptions,
                    weatherManager: weatherManager
                )
                .listRowBackground(
                    showSkyDot ? RowSkyBackground(
                        timeZoneIdentifier: TimeZone.current.identifier,
                        currentDate: $currentDate,
                        timeOffset: $timeOffset,
                        weatherManager: weatherManager
                    ) : nil
                )
                // The row only redraws when the minute changes, so a new
                // time zone needs a fresh row to show its time right away
                .id("local-\(showSkyDot)-\(lastKnownTimeZoneIdentifier)")
                
                // Tap gesture for local time
                .onTapGesture {
                    selectedTimeZone = TimeZone.current.identifier
                    selectedCityName = String(localized: "Local")
                    detailPaneCityId = nil
                    if !usesSplitLayout {
                        showSunriseSunsetSheet = true
                    }
                    
                    // Provide haptic feedback if enabled
                    if hapticEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                        impactFeedback.impactOccurred()
                    }
                }
                
                // Swipe to adjust time (leading edge - swipe right) for local time
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    Button {
                        cityTimeAdjustmentData = CityTimeAdjustmentData(
                            cityName: String(localized: "Local"),
                            timeZoneIdentifier: TimeZone.current.identifier
                        )
                        
                        if hapticEnabled {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            impactFeedback.impactOccurred()
                        }
                    } label: {
                        Label("", systemImage: "clock.fill")
                    }
                    .tint(.blue)
                }
                
                // Menu Local Time
                .contextMenu {
                    localTimeContextMenu()
                }
            }
        }
    }

    @ViewBuilder
    private var addCitiesSection: some View {
        // Add Cities button when collection only has local time
        if showLocalTime && displayedClocks.isEmpty && selectedCollectionId != nil {
            Section {
                Button {
                    showArrangeListSheet = true
                    if hapticEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "plus")
                            .font(.system(size: 20).weight(.medium))
                            .foregroundStyle(.secondary)
                            .blendMode(.plusLighter)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(
                    Capsule()
                        .fill(.clear)
                        .glassEffect(.clear)
                )
            }
        }
    }

    private func citySection(for clock: WorldClock) -> some View {
        Section {
            CityRowContent(
                clock: clock,
                currentDate: $currentDate,
                timeOffset: $timeOffset,
                complicationOptions: complicationOptions,
                weatherManager: weatherManager
            )
            .listRowBackground(
                showSkyDot ? RowSkyBackground(
                    timeZoneIdentifier: clock.timeZoneIdentifier,
                    currentDate: $currentDate,
                    timeOffset: $timeOffset,
                    weatherManager: weatherManager
                ) : nil
            )
            .id("\(clock.id)-\(showSkyDot)")
            
            // Tap gesture for world clock
            .onTapGesture {
                selectedTimeZone = clock.timeZoneIdentifier
                selectedCityName = getLocalizedCityName(for: clock)
                detailPaneCityId = clock.id
                if !usesSplitLayout {
                    showSunriseSunsetSheet = true
                }
                
                // Provide haptic feedback if enabled
                if hapticEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                }
            }
            
            // Swipe to adjust time (leading edge - swipe right)
            .swipeActions(edge: .leading, allowsFullSwipe: true) {
                Button {
                    cityTimeAdjustmentData = CityTimeAdjustmentData(
                        cityName: getLocalizedCityName(for: clock),
                        timeZoneIdentifier: clock.timeZoneIdentifier
                    )
                    
                    if hapticEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                } label: {
                    Label("", systemImage: "clock.fill")
                }
                .tint(.blue)
            }
            
            //Swipe to delete time (only for default view)
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if selectedCollectionId == nil {
                    Button(role: .destructive) {
                        deleteCity(withId: clock.id)
                    } label: {
                        Label("", systemImage: "xmark.circle")
                    }
                }
            }
            
            // Context Menu
            .contextMenu {
                cityContextMenu(for: clock)
            }
        }
    }
}
