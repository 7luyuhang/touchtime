//
//  HomeView+Presentations.swift
//  touchtime
//

import SwiftUI

extension HomeView {
    func presentingAlerts(_ content: some View) -> some View {
        content
            // Rename
            .alert("Rename", isPresented: $showingRenameAlert) {
                TextField(originalClockName, text: $newClockName)
                Button("Cancel", role: .cancel) {
                    newClockName = ""
                    originalClockName = ""
                    renamingClockId = nil
                }
                Button("Save") {
                    let nameToSave = newClockName.isEmpty ? originalClockName : newClockName
                    
                    if let clockId = renamingClockId,
                       let index = worldClocks.firstIndex(where: { $0.id == clockId }) {
                        worldClocks[index].cityName = nameToSave
                        saveWorldClocks()
                        
                        // Also update the city name in collections if it exists there
                        for collectionIndex in collections.indices {
                            if let cityIndex = collections[collectionIndex].cities.firstIndex(where: { $0.id == clockId }) {
                                collections[collectionIndex].cities[cityIndex].cityName = nameToSave
                            }
                        }
                        saveCollections()
                    }
                    newClockName = ""
                    originalClockName = ""
                    renamingClockId = nil
                }
            } message: {
                Text("Customize the name of this city")
            }

            // Rename Timer
            .alert(String(localized: "Rename Timer"), isPresented: $showingTimerRenameAlert) {
                TextField(homeTimerDisplayName, text: $newTimerName)
                Button(String(localized: "Cancel"), role: .cancel) {
                    newTimerName = ""
                }
                Button(String(localized: "Save")) {
                    saveHomeTimerName()
                }
            } message: {
                Text(String(localized: "Customize the name of this timer"))
            }
            
            // Calendar Permission Alert
            .alert("", isPresented: $showCalendarPermissionAlert) {
                Button(String(localized: "Cancel"), role: .cancel) { }
                Button(String(localized: "Go to Settings")) {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
            } message: {
                Text("Please allow calendar access in Settings to add events.")
            }
    }

    func presentingCitySheets(_ content: some View) -> some View {
        content
            // Share Sheet: empty when there is no local time, no cities and no pinned countdowns
            .sheet(isPresented: $showShareSheet) {
                if worldClocks.isEmpty && !showLocalTime && !countdownStore.countdowns.contains(where: \.isPinned) {
                    ShareCitiesEmptyView()
                } else {
                    ShareCitiesSheet(
                        worldClocks: $worldClocks,
                        showSheet: $showShareSheet,
                        currentDate: currentDate,
                        timeOffset: timeOffset
                    )
                    .environmentObject(weatherManager)
                }
            }
            
            // Share as Image: full-screen preview of one city card with
            // frame, share and save actions, from the row's context menu
            .fullScreenCover(item: $cityShareData) { share in
                ShareAsImageView(title: share.cityName) { aspectRatio, frameCornerRadius in
                    cityShareCard(for: share, aspectRatio: aspectRatio, frameCornerRadius: frameCornerRadius)
                } render: { aspectRatio in
                    renderCityShareImage(for: share, aspectRatio: aspectRatio)
                }
            }

            // Event Editor Sheet
            .sheet(isPresented: $showEventEditor) {
                EventEditView(
                    event: $eventToEdit,
                    isPresented: $showEventEditor,
                    eventStore: eventStore
                )
                .ignoresSafeArea()
            }
            
            // Sunrise/Sunset Sheet. Hidden as soon as the layout splits: opening
            // the iPhone Duo in portrait changes only the size class, and the
            // list rebuilt beside the detail pane would present it again
            .sheet(isPresented: Binding(
                get: { showSunriseSunsetSheet && !usesSplitLayout },
                set: { showSunriseSunsetSheet = $0 }
            )) {
                SunriseSunsetSheet(
                    cityName: selectedCityName,
                    timeZoneIdentifier: selectedTimeZone,
                    initialDate: currentDate,
                    timeOffset: timeOffset
                )
                .environmentObject(weatherManager)
            }
            
            // Arrange List Sheet
            .sheet(isPresented: $showArrangeListSheet) {
                ArrangeListView(
                    worldClocks: $worldClocks,
                    showSheet: $showArrangeListSheet,
                    currentDate: currentDate,
                    timeOffset: timeOffset
                )
            }
            .onChange(of: showArrangeListSheet) { oldValue, newValue in
                if !newValue && oldValue { // Sheet was dismissed
                    loadCollections() // Reload collections in case they were modified
                }
            }

            // Earth View
            .fullScreenCover(isPresented: $showEarthView) {
                EarthView(
                    timeOffset: $timeOffset,
                    worldClocks: $worldClocks,
                    weatherManager: weatherManager
                )
                    .interactiveDismissDisabled(true)
            }
            
            // City Time Adjustment Sheet
            .sheet(item: $cityTimeAdjustmentData) { data in
                CityTimeAdjustmentSheet(
                    cityName: data.cityName,
                    timeZoneIdentifier: data.timeZoneIdentifier,
                    timeOffset: $timeOffset,
                    showSheet: Binding(
                        get: { cityTimeAdjustmentData != nil },
                        set: { if !$0 { cityTimeAdjustmentData = nil } }
                    ),
                    showScrollTimeButtons: $showScrollTimeButtons
                )
            }
    }

    func presentingToolSheets(_ content: some View) -> some View {
        content
            // Set Alarm Sheet
            .sheet(isPresented: $showSetAlarmSheet) {
                SetAlarmSheet()
            }

            // Set Timer Sheet
            .sheet(isPresented: $showSetTimerSheet) {
                SetTimerSheet(
                    initialDurationSeconds: homeTimerConfiguredSeconds,
                    onConfirm: { durationSeconds in
                        startHomeTimer(durationSeconds: durationSeconds)
                    },
                    onPlayPause: handleHomeTimerTap,
                    onClearHomeTimer: clearHomeTimer
                )
            }

            // Stopwatch Records Sheet
            .sheet(isPresented: $showStopwatchRecordsSheet) {
                StopwatchRecordsSheet(stopwatch: homeStopwatch, onStart: startNewHomeStopwatch)
            }

            // Countdown Sheet
            .sheet(isPresented: $showCountdownSheet) {
                CountdownSheet()
            }

            // Countdown Editor Sheet: opened by tapping a pinned card on Home
            .sheet(item: $editingHomeCountdown) { item in
                CountdownDetailsView(countdown: item, onDelete: {
                    deleteCountdown(item)
                }) { title, targetDate, emoji, photoData, photoCrop, isPinned, repeatFrequency, reminderTime, reminderCity, reminderLeadDays, reminderKind, contact, scheduledMessage, pausedAt in
                    updateCountdown(item, title: title, targetDate: targetDate, emoji: emoji, photoData: photoData, photoCrop: photoCrop, isPinned: isPinned, repeatFrequency: repeatFrequency, reminderTime: reminderTime, reminderCity: reminderCity, reminderLeadDays: reminderLeadDays, reminderKind: reminderKind, contact: contact, scheduledMessage: scheduledMessage, pausedAt: pausedAt)
                }
                // Force a fresh view identity per item, otherwise SwiftUI reuses
                // the sheet content and @State keeps the previous item's values.
                .id(item.id)
            }

            // Share as Image for a pinned card: same full-screen preview as
            // the countdown editor, with the day count at the scrubbed time
            .fullScreenCover(item: $countdownShareData) { share in
                CountdownShareAsImageView(
                    title: share.item.title,
                    targetDate: share.item.effectiveTargetDate(at: share.now),
                    emoji: share.item.emoji,
                    photoData: share.item.photoData,
                    photoCrop: share.item.photoCrop,
                    isRepeating: share.item.repeatFrequency != .never,
                    now: share.now,
                    pausedAt: share.item.pausedAt
                )
            }
    }

    func presentingAppSheets(_ content: some View) -> some View {
        content
            // Settings Sheet
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView(
                    worldClocks: $worldClocks,
                    weatherManager: weatherManager
                )
            }
            .onChange(of: showSettingsSheet) { oldValue, newValue in
                if !newValue && oldValue { // Sheet was dismissed
                    loadCollections() // Reload collections in case they were reset
                    // If collections are empty or selected collection no longer exists, reset to default view
                    if collections.isEmpty && selectedCollectionId != nil {
                        selectedCollectionId = nil
                        saveSelectedCollection()
                    } else if let selectedId = selectedCollectionId,
                              !collections.contains(where: { $0.id == selectedId }) {
                        selectedCollectionId = nil
                        saveSelectedCollection()
                    }
                }
            }
            .fullScreenCover(isPresented: $showLifetimeStore) {
                NavigationStack {
                    LifetimeStoreView()
                }
            }
            .sheet(isPresented: $showLifetimePromo) {
                LifetimePromoSheet()
            }

            // Complications Sheet
            .sheet(isPresented: $showComplicationsSheet) {
                NavigationStack {
                    ComplicationsSettingsView(
                        showAnalogClock: $showAnalogClock,
                        showSunPosition: $showSunPosition,
                        showSunAzimuth: $showSunAzimuth,
                        showMoonAzimuth: $showMoonAzimuth,
                        showMoonSunAzimuth: $showMoonSunAzimuth,
                        showSunriseSunset: $showSunriseSunset,
                        showWeatherCondition: $showWeatherCondition,
                        showTemperatureIndicator: $showTemperatureIndicator,
                        showTemperatureRange: $showTemperatureRange,
                        showUVIndex: $showUVIndex,
                        showWindDirection: $showWindDirection,
                        showWindSpeed: $showWindSpeed,
                        showPressure: $showPressure,
                        showDaylight: $showDaylight,
                        showTimeOverlay: $showTimeOverlay,
                        showSolarCurve: $showSolarCurve,
                        showWeather: showWeather,
                        weatherManager: weatherManager
                    )
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.hidden)
            }

            // Widgets Sheet
            .sheet(isPresented: $showWidgetIntroSheet) {
                WidgetIntroSheet()
            }
            .sheet(isPresented: $showAppleWatchIntroSheet) {
                AppleWatchIntroSheet()
            }
    }
}
