//
//  HomeView+ContextMenus.swift
//  touchtime
//

import SwiftUI
import EventKit
import WeatherKit

extension HomeView {
    // MARK: - Context Menus
    @ViewBuilder
    func localTimeContextMenu() -> some View {
        ControlGroup {
            Button(action: {
                cityTimeAdjustmentData = CityTimeAdjustmentData(
                    cityName: String(localized: "Local"),
                    timeZoneIdentifier: TimeZone.current.identifier
                )
            }) {
                Label(String(localized: "Set Alarm"), systemImage: "alarm")
            }
            
            Button(action: {
                let cityName = String(localized: "Local")
                addToCalendar(timeZoneIdentifier: TimeZone.current.identifier, cityName: cityName)
            }) {
                Label("Schedule Event", systemImage: "plus.circle")
            }
        }
        
        Divider()
        
        Menu {
            Button(action: {
                let cityName = String(localized: "Local")
                copyTimeAsText(cityName: cityName, timeZoneIdentifier: TimeZone.current.identifier)
            }) {
                Label(String(localized: "Copy as Text"), systemImage: "quote.opening")
            }
            Button(action: {
                shareCardAsImage(cityName: String(localized: "Local"), timeZoneIdentifier: TimeZone.current.identifier)
            }) {
                Label(String(localized: "Share as Image"), systemImage: "camera.macro")
            }
        } label: {
            Label(String(localized: "Share"), systemImage: "square.and.arrow.up") // Local Share
        }
    }
    
    @ViewBuilder
    func cityContextMenu(for clock: WorldClock) -> some View {
        ControlGroup {
            Button(action: {
                cityTimeAdjustmentData = CityTimeAdjustmentData(
                    cityName: getLocalizedCityName(for: clock),
                    timeZoneIdentifier: clock.timeZoneIdentifier
                )
            }) {
                Label(String(localized: "Set Alarm"), systemImage: "alarm")
            }
            
            // Schedule event
            Button(action: {
                addToCalendar(timeZoneIdentifier: clock.timeZoneIdentifier, cityName: getLocalizedCityName(for: clock))
            }) {
                Label("Schedule Event", systemImage: "plus.circle")
            }
        }
        
        Divider()
        
        Menu {
            Button(action: {
                copyTimeAsText(cityName: getLocalizedCityName(for: clock), timeZoneIdentifier: clock.timeZoneIdentifier)
            }) {
                Label(String(localized: "Copy as Text"), systemImage: "quote.opening")
            }
            Button(action: {
                shareCardAsImage(cityName: getLocalizedCityName(for: clock), timeZoneIdentifier: clock.timeZoneIdentifier)
            }) {
                Label(String(localized: "Share as Image"), systemImage: "camera.macro")
            }
        } label: {
            Label(String(localized: "Share"), systemImage: "square.and.arrow.up") // City Share
        }
        
        // Rename
        Button(action: {
            renamingClockId = clock.id
            // Get original name from timezone identifier
            let identifier = clock.timeZoneIdentifier
            let components = identifier.split(separator: "/")
            let rawName = components.count >= 2
            ? String(components.last!).replacingOccurrences(of: "_", with: " ")
            : String(identifier)
            originalClockName = String(localized: String.LocalizationValue(rawName))
            newClockName = clock.localizedCityName
            showingRenameAlert = true
        }) {
            Label("Rename", systemImage: "pencil.tip.crop.circle")
        }
        
        Divider()
        
        // Move to Top (only for default view)
        if selectedCollectionId == nil {
            if let index = worldClocks.firstIndex(where: { $0.id == clock.id }), index != 0 {
                Button(action: {
                    // Move to top
                    withAnimation {
                        let clockToMove = worldClocks.remove(at: index)
                        worldClocks.insert(clockToMove, at: 0)
                        saveWorldClocks()
                    }
                }) {
                    Label(String(localized: "Move to Top"), systemImage: "arrow.up.to.line")
                }
            }
        }
        
        // Arrange Cities
        Button {
            showArrangeListSheet = true
        } label: {
            Label(String(localized: "Arrange"), systemImage: "list.bullet")
        }
        
        // Only show delete for default view
        if selectedCollectionId == nil {
            Divider()
            
            Button(role: .destructive, action: {
                // Delete
                withAnimation {
                    deleteCity(withId: clock.id)
                }
            }) {
                Label("Delete", systemImage: "xmark.circle")
            }
        }
    }

    // MARK: - Schedule Event

    // Add to Calendar - opens system event editor for a specific time zone
    func addToCalendar(timeZoneIdentifier: String, cityName: String) {
        // Request calendar permission
        eventStore.requestFullAccessToEvents { granted, error in
            guard granted, error == nil else {
                print("Calendar access denied or error: \(String(describing: error))")
                DispatchQueue.main.async {
                    self.showCalendarPermissionAlert = true
                    // Provide haptic feedback on permission denied if enabled
                    if self.hapticEnabled {
                        let impactFeedback = UINotificationFeedbackGenerator()
                        impactFeedback.prepare()
                        impactFeedback.notificationOccurred(.warning)
                    }
                }
                return
            }

            Task { @MainActor in
                await self.prepareAndPresentEvent(timeZoneIdentifier: timeZoneIdentifier, cityName: cityName)
            }
        }
    }

    // Build the event (notes + optional Google Meet link) and present the editor
    @MainActor
    private func prepareAndPresentEvent(timeZoneIdentifier: String, cityName: String) async {
        // Create event with adjusted time
        let event = EKEvent(eventStore: eventStore)

        // Calculate the adjusted start time for the selected timezone
        let currentDate = Date()
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Get the current time in the target timezone
        let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current

        // Calculate time in target timezone adjusted by the offset
        let adjustedDate = currentDate.addingTimeInterval(timeOffset)

        // Set the start date
        event.startDate = adjustedDate

        // Set end date with user-configured default duration
        event.endDate = adjustedDate.addingTimeInterval(defaultEventDuration)

        // Set calendar - use selected calendar if available, otherwise default
        if !selectedCalendarIdentifier.isEmpty,
           let selectedCalendar = eventStore.calendars(for: .event).first(where: { $0.calendarIdentifier == selectedCalendarIdentifier }) {
            event.calendar = selectedCalendar
        } else {
            event.calendar = eventStore.defaultCalendarForNewEvents
        }

        // Add notes with the city and time information
        formatter.timeZone = targetTimeZone
        if use24HourFormat {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "h:mm a"
        }
        let timeString = formatter.string(from: adjustedDate)

        // Format date - use different format for Chinese locale
        formatter.locale = Locale.current
        if Locale.current.language.languageCode?.identifier == "zh" {
            formatter.dateFormat = "MMMd日 E"
        } else {
            formatter.dateFormat = "E, d MMM"
        }
        let dateString = formatter.string(from: adjustedDate)

        // Reset locale
        formatter.locale = Locale(identifier: "en_US_POSIX")

        // Build notes: city time first, then optionally a Google Meet link below it.
        var noteSections: [String] = [
            String(format: String(localized: "Time in %@: %@ · %@"), cityName, timeString, dateString)
        ]
        if addMeetLinkToEvents,
           googleMeet.isSignedIn,
           let meetLink = try? await googleMeet.createMeetLink() {
            noteSections.append(String(localized: "Google Meet:") + "\n" + meetLink)
        }
        event.notes = noteSections.joined(separator: "\n\n")

        // Store the event and show the editor
        eventToEdit = event
        scheduleForTimeZone = timeZoneIdentifier
        showEventEditor = true
    }

    // MARK: - Copy as Text

    // Copy time as text
    func copyTimeAsText(cityName: String, timeZoneIdentifier: String) {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeZoneIdentifier)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        if use24HourFormat {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "h:mma"
        }
        
        let adjustedDate = currentDate.addingTimeInterval(timeOffset)
        let timeString = formatter.string(from: adjustedDate).lowercased()
        let textToCopy = "\(cityName) \(timeString)"
        
        UIPasteboard.general.string = textToCopy
        
        // Provide haptic feedback if enabled
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
    }

    // MARK: - Share as Image
    
    /// Opens the share-as-image screen for a city card, fixing the time it
    /// shows at this moment.
    private func shareCardAsImage(cityName: String, timeZoneIdentifier: String) {
        cityShareData = CityShareData(
            cityName: cityName,
            timeZoneIdentifier: timeZoneIdentifier,
            baseDate: currentDate,
            timeOffset: timeOffset
        )
    }
    
    /// The share card for a city at the export size of the given frame: the
    /// row's card replica on its sky backdrop, with the local time as the
    /// footer. Built here because it reads the same settings as the rows;
    /// the share screen previews it live and renders it for the file.
    func cityShareCard(for share: CityShareData, aspectRatio: ShareAspectRatio, frameCornerRadius: CGFloat = 0) -> some View {
        let timeZoneIdentifier = share.timeZoneIdentifier
        let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone.current
        let weather = showWeather ? weatherManager.weatherData[timeZoneIdentifier] : nil
        let clock = WorldClock(cityName: share.cityName, timeZoneIdentifier: timeZoneIdentifier)
        
        return CityCardSnapshotView(
            cityName: share.cityName,
            timeString: RowTimeFormat.time(
                date: share.baseDate,
                offset: share.timeOffset,
                timeZone: targetTimeZone,
                use24Hour: use24HourFormat
            ),
            localCityName: localCityName,
            localTimeString: RowTimeFormat.time(
                date: share.baseDate,
                offset: share.timeOffset,
                timeZone: TimeZone.current,
                use24Hour: use24HourFormat
            ),
            dateString: getCityDate(
                timeZoneIdentifier: timeZoneIdentifier,
                baseDate: share.baseDate,
                offset: share.timeOffset
            ),
            date: share.date,
            timeZone: targetTimeZone,
            timeZoneIdentifier: timeZoneIdentifier,
            weather: weather,
            weatherCondition: weather?.condition,
            useCelsius: useCelsius,
            complications: complicationOptions,
            additionalTimeDisplay: additionalTimeDisplay,
            showSkyDot: showSkyDot,
            additionalTimeText: RowTimeFormat.additionalText(
                for: clock,
                display: additionalTimeDisplay,
                baseDate: share.baseDate,
                offset: share.timeOffset
            ),
            aspectRatio: aspectRatio,
            frameCornerRadius: frameCornerRadius
        )
        .environmentObject(weatherManager)
        .environment(\.colorScheme, .dark)
    }
    
    /// Renders the city share card into the image that gets saved or
    /// shared, falling back to a placeholder if rendering fails.
    func renderCityShareImage(for share: CityShareData, aspectRatio: ShareAspectRatio) -> UIImage {
        let renderer = ImageRenderer(content: cityShareCard(for: share, aspectRatio: aspectRatio))
        renderer.scale = 3
        return renderer.uiImage ?? UIImage(systemName: "photo") ?? UIImage()
    }

    // Get formatted date for city with Natural Dates setting
    /// `currentDate + timeOffset`, floored to the whole minute.
    ///
    /// Sky colors and the astronomical complications (sunrise/sunset, sun/moon
    /// position, daylight, analog clock, …) only change at minute granularity.
    /// Feeding them a value that still carries the seconds component forces SwiftUI
    /// to re-evaluate those (expensive) subtrees on every body pass, even when the
    /// minute hasn't changed. Quantizing to the minute keeps identical inputs equal
    /// so SwiftUI can skip re-rendering those subtrees.
    func getCityDate(timeZoneIdentifier: String, baseDate: Date, offset: TimeInterval) -> String {
        guard let targetTimeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return ""
        }
        
        // The adjusted time for the target timezone
        let adjustedTime = baseDate.addingTimeInterval(offset)
        
        return adjustedTime.formattedDate(
            style: dateStyle,
            timeZone: targetTimeZone,
            relativeTo: baseDate
        )
    }
}
