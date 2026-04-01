//
//  AnalogClockFullView.swift
//  touchtime
//
//  Created on 28/11/2025.
//

import SwiftUI
import Combine
import UIKit
import AVFoundation
import CoreHaptics
import WeatherKit
import MoonKit
import SunKit
import CoreLocation
import TipKit
import AlarmKit

struct AnalogClockFullView: View {
    private enum CameraPreviewFilter {
        case standard
        case blur
        case blackAndWhite
    }

    private enum CameraFilterParameters {
        static let blackAndWhiteSaturation = 0.0
        static let blackAndWhiteContrast = 1.25
    }

    @Binding var worldClocks: [WorldClock]
    @Binding var timeOffset: TimeInterval
    @Binding var showScrollTimeButtons: Bool
    @ObservedObject var weatherManager: WeatherManager
    @State private var currentDate = Date()
    @State private var selectedCityId: UUID? = nil // nil means Local is selected
    @State private var showDetailsSheet = false
    @State private var showShareSheet = false
    @State private var showArrangeListSheet = false
    @State private var showSetAlarmSheet = false
    @State private var showSetTimerSheet = false
    @State private var showSettingsSheet = false
    @State private var showLifetimeStore = false
    @State private var collections: [CityCollection] = []
    @State private var selectedCollectionId: UUID? = nil
    @State private var showTimeInsteadOfCityName = false
    @State private var showTimeAdjustmentSheet = false
    @State private var isCameraBackgroundEnabled = false
    @State private var isCameraPreparing = false
    @State private var activeCameraRequestId = UUID()
    @State private var cameraToggleTask: Task<Void, Never>? = nil
    @State private var cameraWarmupTask: Task<Void, Never>? = nil
    @State private var showCameraPermissionAlert = false
    @State private var cameraAlertTitle = ""
    @State private var cameraAlertMessage = ""
    @State private var isCaptureButtonHidden = false
    @State private var staticCameraFrame: UIImage?
    @State private var cameraPreviewFilter: CameraPreviewFilter = .standard
    @StateObject private var cameraSessionController = CameraSessionController()
    @Environment(\.scenePhase) private var scenePhase
    
    @AppStorage("use24HourFormat") private var use24HourFormat = true
    @AppStorage("showLocalTime") private var showLocalTime = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("showWeather") private var showWeather = false
    @AppStorage("useCelsius") private var useCelsius = true
    @AppStorage("showSkyDot") private var showSkyDot = true
    @AppStorage("continuousScrollMode") private var continuousScrollMode = true
    @AppStorage("hasLifetimeAccess") private var hasLifetimeAccess = false
    @AppStorage("selectedCollectionId") private var savedSelectedCollectionId: String = ""
    @AppStorage("additionalTimeDisplay") private var additionalTimeDisplay = "None"
    @AppStorage("homeTimerConfiguredSeconds") private var homeTimerConfiguredSeconds = 0
    @AppStorage("homeTimerEndDateEpoch") private var homeTimerEndDateEpoch: Double = 0
    @AppStorage("homeTimerCompletionHandled") private var homeTimerCompletionHandled = false
    @AppStorage("homeTimerPaused") private var homeTimerPaused = false
    @AppStorage("homeTimerPausedRemainingSeconds") private var homeTimerPausedRemainingSeconds = 0
    @AppStorage("homeTimerAlarmID") private var homeTimerAlarmIDRawValue = ""
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private let alarmManager = AlarmManager.shared
    @State private var homeTimerAlarmSyncVersion = 0

    // Get displayed clocks based on selected collection
    private var displayedClocks: [WorldClock] {
        if let collectionId = selectedCollectionId,
           let collection = collections.first(where: { $0.id == collectionId }) {
            return collection.cities
        }
        return worldClocks
    }

    // Current collection name for display
    private var currentCollectionName: String {
        if let collectionId = selectedCollectionId,
           let collection = collections.first(where: { $0.id == collectionId }) {
            return collection.name
        }
        return String(localized: "All Cities")
    }

    private var toolbarTitleText: String {
        if selectedCollectionId == nil {
            return selectedCityName
        }
        return currentCollectionName
    }

    private var shouldShowToolbarTitle: Bool {
        !toolbarTitleText.isEmpty
    }
    
    // Get selected city name
    private var selectedCityName: String {
        // Return empty when no local time and no cities
        if displayedClocks.isEmpty && !showLocalTime {
            return ""
        }
        if let cityId = selectedCityId,
           let city = displayedClocks.first(where: { $0.id == cityId }) {
            return city.localizedCityName
        }
        return String(localized: "Local")
    }
    
    // Get selected timezone
    private var selectedTimeZone: TimeZone {
        if let cityId = selectedCityId,
           let city = displayedClocks.first(where: { $0.id == cityId }),
           let timeZone = TimeZone(identifier: city.timeZoneIdentifier) {
            return timeZone
        }
        return TimeZone.current
    }

    private func loadCollections() {
        collections = CollectionsStore.load()

        if let uuid = UUID(uuidString: savedSelectedCollectionId),
           collections.contains(where: { $0.id == uuid }) {
            selectedCollectionId = uuid
        } else {
            selectedCollectionId = nil
            if !savedSelectedCollectionId.isEmpty {
                savedSelectedCollectionId = ""
            }
        }
    }

    private func saveSelectedCollection() {
        savedSelectedCollectionId = selectedCollectionId?.uuidString ?? ""
    }

    private func ensureValidSelectedCity(in clocks: [WorldClock]) {
        if let cityId = selectedCityId,
           !clocks.contains(where: { $0.id == cityId }) {
            selectedCityId = showLocalTime ? nil : clocks.first?.id
            return
        }

        if !showLocalTime && selectedCityId == nil {
            selectedCityId = clocks.first?.id
        }
    }

    private func selectCollection(_ collectionId: UUID?) {
        selectedCollectionId = collectionId
        saveSelectedCollection()
        ensureValidSelectedCity(in: displayedClocks)
        triggerMenuHaptic()
    }

    private func cycleToNextCollection() {
        guard !collections.isEmpty else { return }

        if let currentId = selectedCollectionId,
           let currentIndex = collections.firstIndex(where: { $0.id == currentId }) {
            let nextIndex = (currentIndex + 1) % collections.count
            selectCollection(collections[nextIndex].id)
        } else {
            selectCollection(collections.first?.id)
        }
    }

    private func weatherConditionForSky(at timeZoneIdentifier: String) -> WeatherCondition? {
        guard showWeather else { return nil }
        return weatherManager.weatherData[timeZoneIdentifier]?.condition
    }

    private var selectedAdditionalTimeText: String {
        switch additionalTimeDisplay {
        case "Time Difference":
            let selectedOffset = selectedTimeZone.secondsFromGMT()
            let localOffset = TimeZone.current.secondsFromGMT()
            let differenceSeconds = selectedOffset - localOffset
            let differenceHours = differenceSeconds / 3600
            if differenceHours == 0 {
                return ""
            } else if differenceHours > 0 {
                return String(format: String(localized: "+%d hours"), differenceHours)
            } else {
                return String(format: String(localized: "%d hours"), differenceHours)
            }
        case "UTC":
            let offsetSeconds = selectedTimeZone.secondsFromGMT()
            let offsetHours = offsetSeconds / 3600
            if offsetHours == 0 {
                return "UTC +0"
            } else if offsetHours > 0 {
                return "UTC +\(offsetHours)"
            } else {
                return "UTC \(offsetHours)"
            }
        default:
            return ""
        }
    }

    private var hasConfiguredHomeTimer: Bool {
        homeTimerConfiguredSeconds > 0
    }

    private var homeTimerAlarmID: UUID? {
        UUID(uuidString: homeTimerAlarmIDRawValue)
    }

    private var homeTimerEndDate: Date? {
        guard homeTimerEndDateEpoch > 0 else { return nil }
        return Date(timeIntervalSince1970: homeTimerEndDateEpoch)
    }

    private func homeTimerRemainingFromEndDate(at date: Date) -> Int {
        guard let endDate = homeTimerEndDate else {
            return 0
        }

        let remaining = Int(ceil(endDate.timeIntervalSince(date)))
        return max(remaining, 0)
    }

    private func homeTimerRemainingSeconds(at date: Date) -> Int {
        guard hasConfiguredHomeTimer else {
            return 0
        }

        if homeTimerPaused {
            return max(0, min(homeTimerPausedRemainingSeconds, 59 * 60 + 59))
        }

        return homeTimerRemainingFromEndDate(at: date)
    }

    private func startHomeTimer(
        durationSeconds: Int,
        startPaused: Bool = false,
        requestAlarmAuthorization: Bool = true
    ) {
        let clampedDuration = min(max(durationSeconds, 1), 59 * 60 + 59)
        homeTimerConfiguredSeconds = clampedDuration

        if startPaused {
            homeTimerEndDateEpoch = 0
            homeTimerPaused = true
            homeTimerPausedRemainingSeconds = clampedDuration
        } else {
            homeTimerEndDateEpoch = Date().addingTimeInterval(TimeInterval(clampedDuration)).timeIntervalSince1970
            homeTimerPaused = false
            homeTimerPausedRemainingSeconds = 0
        }

        homeTimerCompletionHandled = false

        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }

        refreshHomeTimerAlarm(
            requestAuthorization: requestAlarmAuthorization
        )
    }

    private func handleHomeTimerTap() {
        guard hasConfiguredHomeTimer else {
            if hapticEnabled {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.prepare()
                impactFeedback.impactOccurred()
            }
            showSetTimerSheet = true
            return
        }

        let remaining = homeTimerRemainingSeconds(at: Date())
        if remaining == 0 {
            startHomeTimer(durationSeconds: homeTimerConfiguredSeconds)
            return
        }

        if homeTimerPaused {
            let secondsToResume = max(1, min(homeTimerPausedRemainingSeconds, 59 * 60 + 59))
            homeTimerEndDateEpoch = Date().addingTimeInterval(TimeInterval(secondsToResume)).timeIntervalSince1970
            homeTimerPaused = false
            homeTimerPausedRemainingSeconds = 0
            homeTimerCompletionHandled = false
            refreshHomeTimerAlarm(requestAuthorization: true)
        } else {
            homeTimerPausedRemainingSeconds = remaining
            homeTimerPaused = true
            homeTimerEndDateEpoch = 0
            refreshHomeTimerAlarm(requestAuthorization: false)
        }

        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }
    }

    private func restoreHomeTimerStateIfNeeded() {
        defer {
            refreshHomeTimerAlarm(requestAuthorization: false)
        }

        if !homeTimerAlarmIDRawValue.isEmpty, homeTimerAlarmID == nil {
            homeTimerAlarmIDRawValue = ""
        }

        let clampedConfiguredSeconds = min(max(homeTimerConfiguredSeconds, 0), 59 * 60 + 59)
        if clampedConfiguredSeconds != homeTimerConfiguredSeconds {
            homeTimerConfiguredSeconds = clampedConfiguredSeconds
        }

        guard clampedConfiguredSeconds > 0 else {
            homeTimerEndDateEpoch = 0
            homeTimerCompletionHandled = false
            homeTimerPaused = false
            homeTimerPausedRemainingSeconds = 0
            return
        }

        if homeTimerPaused {
            let clampedPausedRemaining = min(max(homeTimerPausedRemainingSeconds, 0), 59 * 60 + 59)
            if clampedPausedRemaining != homeTimerPausedRemainingSeconds {
                homeTimerPausedRemainingSeconds = clampedPausedRemaining
            }
            if homeTimerPausedRemainingSeconds == 0 {
                homeTimerPausedRemainingSeconds = clampedConfiguredSeconds
            }
            homeTimerEndDateEpoch = 0
            homeTimerCompletionHandled = homeTimerPausedRemainingSeconds == 0
            return
        }

        if homeTimerEndDateEpoch <= 0 {
            homeTimerEndDateEpoch = Date().addingTimeInterval(TimeInterval(clampedConfiguredSeconds)).timeIntervalSince1970
            homeTimerCompletionHandled = false
            return
        }

        let remaining = homeTimerRemainingFromEndDate(at: Date())
        homeTimerCompletionHandled = remaining == 0
    }

    private func refreshHomeTimerAlarm(
        requestAuthorization: Bool
    ) {
        homeTimerAlarmSyncVersion += 1
        let syncVersion = homeTimerAlarmSyncVersion
        let shouldSchedule = hasConfiguredHomeTimer && !homeTimerPaused
        let remainingSeconds = homeTimerRemainingSeconds(at: Date())
        let existingAlarmID = homeTimerAlarmID

        Task { @MainActor in
            await synchronizeHomeTimerAlarm(
                syncVersion: syncVersion,
                existingAlarmID: existingAlarmID,
                shouldSchedule: shouldSchedule,
                remainingSeconds: remainingSeconds,
                requestAuthorization: requestAuthorization
            )
        }
    }

    @MainActor
    private func synchronizeHomeTimerAlarm(
        syncVersion: Int,
        existingAlarmID: UUID?,
        shouldSchedule: Bool,
        remainingSeconds: Int,
        requestAuthorization: Bool
    ) async {
        let isStale = { syncVersion != homeTimerAlarmSyncVersion || Task.isCancelled }

        if let existingAlarmID {
            try? alarmManager.cancel(id: existingAlarmID)
        }

        guard !isStale() else { return }

        guard shouldSchedule, remainingSeconds > 0 else {
            homeTimerAlarmIDRawValue = ""
            return
        }

        if requestAuthorization {
            switch await AlarmSupport.ensureAuthorization(using: alarmManager) {
            case .authorized:
                break
            case .denied:
                homeTimerAlarmIDRawValue = ""
                return
            case .failed(let error):
                homeTimerAlarmIDRawValue = ""
                print("Failed to authorize AlarmKit for timer: \(error.localizedDescription)")
                return
            }
        } else if alarmManager.authorizationState != .authorized {
            homeTimerAlarmIDRawValue = ""
            return
        }

        let newAlarmID = UUID()

        do {
            try await AlarmSupport.scheduleTimerAlarm(
                id: newAlarmID,
                durationSeconds: remainingSeconds,
                eventTitle: String(localized: "Timer"),
                using: alarmManager
            )
        } catch {
            homeTimerAlarmIDRawValue = ""
            print("Failed to schedule AlarmKit timer reminder: \(error.localizedDescription)")
            return
        }

        guard !isStale() else {
            try? alarmManager.cancel(id: newAlarmID)
            return
        }

        homeTimerAlarmIDRawValue = newAlarmID.uuidString
    }

    private func handleHomeTimerTick(at now: Date) {
        guard hasConfiguredHomeTimer, !homeTimerPaused else { return }

        let remaining = homeTimerRemainingSeconds(at: now)
        if remaining == 0 {
            guard !homeTimerCompletionHandled else { return }
            homeTimerCompletionHandled = true

            if hapticEnabled {
                let notificationFeedback = UINotificationFeedbackGenerator()
                notificationFeedback.prepare()
                notificationFeedback.notificationOccurred(.success)
            }
        } else if homeTimerCompletionHandled {
            homeTimerCompletionHandled = false
        }
    }

    private func triggerLightHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .rigid) // Capture Haptic
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }

    private func triggerMenuHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }

    private var cityTimeSegmentSelection: Binding<Bool> {
        Binding(
            get: { showTimeInsteadOfCityName },
            set: { newValue in
                guard newValue != showTimeInsteadOfCityName else { return }
                triggerMenuHaptic()
                withAnimation(.smooth) {
                    showTimeInsteadOfCityName = newValue
                }
            }
        )
    }

    @ViewBuilder
    private var collectionTitleView: some View {
        if selectedCollectionId == nil {
            Picker("", selection: cityTimeSegmentSelection) {
                Text(String(localized: "City")).tag(false)
                Text(String(localized: "Time")).tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 128)
        } else {
            Text(toolbarTitleText)
                .font(.subheadline.weight(.semibold))
                .contentTransition(.numericText())
                .padding(.horizontal, 16)
                .frame(height: 44)
                .glassEffect(.regular.interactive(), in: Capsule(style: .continuous))
                .lineLimit(1)
                .contentShape(Capsule())
                .animation(.snappy, value: currentCollectionName)
                .onTapGesture {
                    if collections.count > 1 {
                        cycleToNextCollection()
                    } else {
                        triggerMenuHaptic()
                        withAnimation(.smooth) {
                            showTimeInsteadOfCityName.toggle()
                        }
                    }
                }
        }
    }

    @ViewBuilder
    private var leadingMenuContent: some View {
        if !hasLifetimeAccess {
            Button(action: {
                triggerMenuHaptic()
                showLifetimeStore = true
            }) {
                Text(String(localized: "Lifetime"))
                Text(String(localized: "Unlock all features"))
                Image(systemName: "heart")
            }

            Divider()
        }

        if !collections.isEmpty {
            Button {
                selectCollection(nil)
            } label: {
                Label("All Cities", systemImage: selectedCollectionId == nil ? "checkmark.circle" : "")
            }

            ForEach(collections) { collection in
                Button {
                    selectCollection(collection.id)
                } label: {
                    Label(collection.name, systemImage: selectedCollectionId == collection.id ? "checkmark.circle" : "")
                }
            }
            Divider()
        }

        // Share Section - only show if there are world clocks
        if !worldClocks.isEmpty {
            Button(action: {
                triggerMenuHaptic()
                showShareSheet = true
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }

        // Arrange Section - show if there are world clocks or collections
        if !worldClocks.isEmpty || !collections.isEmpty {
            Button(action: {
                triggerMenuHaptic()
                showArrangeListSheet = true
            }) {
                Label(String(localized: "Arrange"), systemImage: "list.bullet")
            }
        }

        Button(action: {
            triggerMenuHaptic()
            showSetAlarmSheet = true
        }) {
            Label(String(localized: "Alarms"), systemImage: "alarm")
        }

        Button(action: {
            triggerMenuHaptic()
            showSetTimerSheet = true
        }) {
            Label(String(localized: "Timer"), systemImage: "timer")
        }

        Divider()

        // Settings Section
        Button(action: {
            triggerMenuHaptic()
            showSettingsSheet = true
        }) {
            Label("Settings", systemImage: "gear")
        }
    }

    private var addCitiesButton: some View {
        Button {
            showArrangeListSheet = true
            triggerMenuHaptic()
        } label: {
            Text("Add Cities")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .glassEffect(.clear.interactive())
        }
        .buttonStyle(.plain)
    }

    private func showCameraAlert(title: String = "", message: String) {
        cameraAlertTitle = title
        cameraAlertMessage = message
        showCameraPermissionAlert = true
    }

    private func disableCameraBackground() {
        cameraToggleTask?.cancel()
        cameraToggleTask = nil
        activeCameraRequestId = UUID()
        isCameraPreparing = false
        withAnimation(.spring()) {
            isCameraBackgroundEnabled = false
        }
        cameraSessionController.stopRunning()
    }

    private func handleCameraToggle() {
        guard !isCameraBackgroundEnabled && !isCameraPreparing else { return }
        triggerLightHaptic()

        let requestId = UUID()
        activeCameraRequestId = requestId
        isCameraPreparing = true

        cameraToggleTask?.cancel()
        cameraToggleTask = Task {
            defer {
                Task { @MainActor in
                    if activeCameraRequestId == requestId {
                        cameraToggleTask = nil
                    }
                }
            }

            let granted = await cameraSessionController.requestAccess()
            if Task.isCancelled { return }
            let isRequestActiveAfterPermission = await MainActor.run { activeCameraRequestId == requestId }
            guard isRequestActiveAfterPermission else { return }
            guard granted else {
                await MainActor.run {
                    isCameraPreparing = false
                    showCameraAlert(
                        message: String(localized: "Please allow camera access in Settings to show live camera background.")
                    )
                }
                return
            }

            let configured = await cameraSessionController.configureIfNeeded()
            if Task.isCancelled { return }
            let isRequestActiveAfterConfigure = await MainActor.run { activeCameraRequestId == requestId }
            guard isRequestActiveAfterConfigure else { return }
            guard configured else {
                await MainActor.run {
                    isCameraPreparing = false
                    showCameraAlert(
                        title: String(localized: "Camera Unavailable"),
                        message: String(localized: "Please allow camera access in Settings to show live camera background.")
                    )
                }
                return
            }

            let sceneIsActive = await MainActor.run { scenePhase == .active }
            guard sceneIsActive else {
                await MainActor.run {
                    isCameraPreparing = false
                }
                return
            }

            let started = await cameraSessionController.startRunning()
            if Task.isCancelled { return }
            let isRequestActiveAfterStart = await MainActor.run { activeCameraRequestId == requestId }
            guard isRequestActiveAfterStart else { return }
            guard cameraSessionController.isCameraAvailable else {
                await MainActor.run {
                    isCameraPreparing = false
                    showCameraAlert(
                        title: String(localized: "Camera Unavailable"),
                        message: String(localized: "Please allow camera access in Settings to show live camera background.")
                    )
                }
                return
            }

            await MainActor.run {
                isCameraPreparing = false
                if started {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        isCameraBackgroundEnabled = true
                    }
                } else {
                    showCameraAlert(
                        title: String(localized: "Camera Unavailable"),
                        message: String(localized: "Please allow camera access in Settings to show live camera background.")
                    )
                }
            }
        }
    }

    private func handleCameraClose() {
        triggerLightHaptic()
        disableCameraBackground()
    }

    private func setCameraFilter(_ filter: CameraPreviewFilter) {
        guard cameraPreviewFilter != filter else { return }
        triggerLightHaptic()
        cameraPreviewFilter = filter
    }
    
    @MainActor
    private func captureScreenshot() -> UIImage? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else { return nil }

        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    private func handleCapturePhoto() {
        triggerLightHaptic()

        guard let frame = cameraSessionController.getLatestFrameAsImage() else { return }

        staticCameraFrame = frame
        withAnimation(.spring()) {
            isCaptureButtonHidden = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let screenshot = captureScreenshot()

            if let screenshot {
                UIImageWriteToSavedPhotosAlbum(screenshot, nil, nil, nil)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                staticCameraFrame = nil
                withAnimation(.spring()) {
                    isCaptureButtonHidden = false
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let size = min(geometry.size.width, geometry.size.height)
                let displayDate = currentDate.addingTimeInterval(timeOffset)
                let skyGradient = SkyColorGradient(
                    date: displayDate,
                    timeZoneIdentifier: selectedTimeZone.identifier,
                    weatherCondition: weatherConditionForSky(at: selectedTimeZone.identifier)
                )
                
                ZStack {
                    // Background
                    Group {
                        if isCameraBackgroundEnabled {
                            Group {
                                if let staticFrame = staticCameraFrame {
                                    Color.clear
                                        .overlay {
                                            Image(uiImage: staticFrame)
                                                .resizable()
                                                .scaledToFill()
                                        }
                                        .clipped()
                                        .ignoresSafeArea()
                                } else {
                                    CameraBackgroundView(session: cameraSessionController.session)
                                        .ignoresSafeArea()
                                }
                            }
                            .saturation(
                                cameraPreviewFilter == .blackAndWhite
                                ? CameraFilterParameters.blackAndWhiteSaturation
                                : 1
                            )
                            .contrast(
                                cameraPreviewFilter == .blackAndWhite
                                ? CameraFilterParameters.blackAndWhiteContrast
                                : 1
                            )
                        } else {
                            if showSkyDot {
                                ZStack {
                                    skyGradient.linearGradient()
                                        .ignoresSafeArea()
                                        .opacity(0.65)
                                        .animation(.spring(), value: selectedTimeZone.identifier)
                                    
                                    // Stars overlay for nighttime
                                    if skyGradient.starOpacity > 0 {
                                        StarsView(starCount: 150)
                                            .ignoresSafeArea()
                                            .opacity(skyGradient.starOpacity)
                                            .blendMode(.plusLighter)
                                            .animation(.spring(), value: skyGradient.starOpacity)
                                            .allowsHitTesting(false)
                                    }
                                }
                            } else {
                                Color(UIColor.systemBackground)
                                    .ignoresSafeArea()
                            }
                        }
                    }
                    .overlay {
                        if isCameraBackgroundEnabled && cameraPreviewFilter == .blur {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .ignoresSafeArea()
                                .allowsHitTesting(false)
                        }
                    }
                    .animation(.spring(), value: showSkyDot)
                    .animation(.spring(), value: isCameraBackgroundEnabled)

                    // Empty state when no local time and no cities
                    if displayedClocks.isEmpty && !showLocalTime {
                        ContentUnavailableView {
                            Label("Nothing here", systemImage: selectedCollectionId != nil ? "questionmark.folder" : "location.magnifyingglass")
                                .blendMode(.plusLighter)
                        } description: {
                            Text(selectedCollectionId != nil ? "No cities in this collection." : "Add cities to track time.")
                                .blendMode(.plusLighter)
                        } actions: {
                            if selectedCollectionId != nil {
                                addCitiesButton
                            }
                        }
                    } else {
                        // Analog Clock - always centered
                        TimelineView(.periodic(from: .now, by: 1)) { context in
                            AnalogClockFaceView(
                                date: context.date.addingTimeInterval(timeOffset),
                                timeOffset: $timeOffset,
                                selectedTimeZone: selectedTimeZone,
                                size: size,
                                worldClocks: displayedClocks,
                                showLocalTime: showLocalTime,
                                selectedCityId: $selectedCityId,
                                hapticEnabled: hapticEnabled,
                                showDetailsSheet: $showDetailsSheet,
                                weather: weatherManager.weatherData[selectedTimeZone.identifier],
                                showWeather: showWeather,
                                showTimeInsteadOfCityName: showTimeInsteadOfCityName
                            )
                        }
                        
                        // Digital time and scroll controls overlay
                        VStack(spacing: 0) {
                            // Top section - Digital time centered between nav bar and clock
                            VStack {
                                Spacer()
                                DigitalTimeDisplayView(
                                    currentDate: currentDate,
                                    timeOffset: timeOffset,
                                    selectedTimeZone: selectedTimeZone,
                                    use24HourFormat: use24HourFormat,
                                    weather: weatherManager.weatherData[selectedTimeZone.identifier],
                                    showWeather: showWeather,
                                    useCelsius: useCelsius,
                                    hapticEnabled: hapticEnabled,
                                    timerConfiguredSeconds: homeTimerConfiguredSeconds,
                                    timerEndDateEpoch: homeTimerEndDateEpoch,
                                    timerIsPaused: homeTimerPaused,
                                    timerPausedRemainingSeconds: homeTimerPausedRemainingSeconds,
                                    onTimerTap: handleHomeTimerTap,
                                    onTimerConfigureTap: {
                                        triggerMenuHaptic()
                                        showSetTimerSheet = true
                                    }
                                ) {
                                    if hapticEnabled {
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .rigid)
                                        impactFeedback.impactOccurred()
                                    }
                                    showTimeAdjustmentSheet = true
                                }
                                .animation(.spring(), value: selectedTimeZone.identifier)
                                Spacer()
                            }
                            .frame(height: (geometry.size.height - size) / 2)
                            
                            // Middle - clock area (transparent placeholder)
                            Color.clear
                                .frame(height: size)
                            
                            // Bottom section - Scroll controls
                            VStack {
                                Spacer()
                                // Local time display (hidden when continuous scroll reset button is showing)
                                if selectedCityId != nil && !(continuousScrollMode && timeOffset != 0 && !showScrollTimeButtons) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "location.fill")
                                            .font(.footnote.weight(.medium))
                                        Text({
                                            if showTimeInsteadOfCityName {
                                                // Show "Local" when hands show time
                                                return String(localized: "Local")
                                            } else {
                                                // Show local time when hands show city names
                                                let formatter = DateFormatter()
                                                formatter.locale = Locale(identifier: "en_US_POSIX")
                                                formatter.timeZone = TimeZone.current
                                                if use24HourFormat {
                                                    formatter.dateFormat = "HH:mm"
                                                } else {
                                                    formatter.dateFormat = "h:mm"
                                                }
                                                return formatter.string(from: displayDate)
                                            }
                                        }())
                                        .font(.subheadline.weight(.medium))

                                        let additionalText = selectedAdditionalTimeText
                                        let shouldShowAdditionalText = showTimeInsteadOfCityName
                                            ? (additionalTimeDisplay == "Time Difference" && !additionalText.isEmpty)
                                            : (!additionalText.isEmpty || additionalTimeDisplay == "UTC")
                                        if shouldShowAdditionalText {
                                            Text("·")
                                                .font(.subheadline.weight(.medium))
                                            Text(additionalText)
                                                .font(.subheadline.weight(.medium))
                                                .contentTransition(.numericText())
                                                .animation(.smooth(duration: 0.25), value: additionalText)
                                        }
                                    }
                                    .foregroundStyle(.secondary)
                                    .blendMode(.plusLighter)
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                                    .padding(.bottom, 16)
                                }
                                Spacer()
                                ScrollTimeView(
                                    timeOffset: $timeOffset,
                                    showButtons: $showScrollTimeButtons,
                                    worldClocks: $worldClocks
                                )
                                .padding(.horizontal)
                                .padding(.bottom, 8)
                                .overlay(alignment: .topTrailing) { // Capture Button
                                    if isCameraBackgroundEnabled {
                                        if !isCaptureButtonHidden {
                                            Button(action: handleCapturePhoto) {
                                                ZStack {
                                                    Circle()
                                                        .strokeBorder(.white, lineWidth: 2.5)
                                                    Circle()
                                                        .fill(.white)
                                                        .padding(5)
                                                }
                                                .frame(width: 52, height: 52)
                                            }
                                            .buttonStyle(.plain)
                                            .contentShape(Circle())
                                            .padding(.trailing, 20)
                                            .padding(.bottom, 12)
                                            .offset(y: -70)
                                            .transition(.blurReplace().combined(with: .opacity).combined(with: .scale(0.95)))
                                        }
                                    }
                                }
                                .overlay(alignment: .topLeading) { // Close Camera Button
                                    if isCameraBackgroundEnabled {
                                        if !isCaptureButtonHidden {
                                            Button(action: handleCameraClose) {
                                                Image(systemName: "xmark")
                                                    .font(.headline)
                                                    .foregroundStyle(.primary)
                                            }
                                            .frame(width: 52, height: 52)
                                            .glassEffect(.regular.interactive())
                                            .buttonStyle(.plain)
                                            .contentShape(Circle())
                                            .padding(.leading, 20)
                                            .padding(.bottom, 12)
                                            .offset(y: -70)
                                            .transition(.blurReplace().combined(with: .opacity).combined(with: .scale(0.95)))
                                        }
                                    }
                                }
                            }
                            .frame(height: (geometry.size.height - size) / 2)
                        }
                    }
                }
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if shouldShowToolbarTitle {
                    ToolbarItem(placement: .principal) {
                        collectionTitleView
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        leadingMenuContent
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
                
                if !displayedClocks.isEmpty {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        if isCameraBackgroundEnabled {
                            Menu {
                                Section("Camera Filter") {
                                    Button(action: { setCameraFilter(.standard) }) {
                                        if cameraPreviewFilter == .standard {
                                            Label("Standard", systemImage: "checkmark.circle")
                                        } else {
                                            Text("Standard")
                                        }
                                    }
                                    Button(action: { setCameraFilter(.blur) }) {
                                        if cameraPreviewFilter == .blur {
                                            Label("Blur", systemImage: "checkmark.circle")
                                        } else {
                                            Text("Blur")
                                        }
                                    }
                                    Button(action: { setCameraFilter(.blackAndWhite) }) {
                                        if cameraPreviewFilter == .blackAndWhite {
                                            Label("Black and White", systemImage: "checkmark.circle")
                                        } else {
                                            Text("Black and White")
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "camera.filters")
                                    .foregroundStyle(.primary)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button(action: {
                                handleCameraToggle()
                            }) {
                                Image(systemName: "camera.aperture")
                                    .foregroundStyle(.primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .onReceive(timer) { now in
                handleHomeTimerTick(at: now)

                let calendar = Calendar.current
                if calendar.component(.minute, from: now) != calendar.component(.minute, from: currentDate) {
                    currentDate = now
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ResetScrollTime"))) { _ in
                withAnimation(.smooth()) { // Hands Animation
                    timeOffset = 0
                    showScrollTimeButtons = false
                }
            }
            .sheet(isPresented: $showDetailsSheet) {
                if let cityId = selectedCityId,
                   let city = displayedClocks.first(where: { $0.id == cityId }) {
                    SunriseSunsetSheet(
                        cityName: city.localizedCityName,
                        timeZoneIdentifier: city.timeZoneIdentifier,
                        initialDate: currentDate,
                        timeOffset: timeOffset
                    )
                    .environmentObject(weatherManager)
                } else {
                    SunriseSunsetSheet(
                        cityName: String(localized: "Local"),
                        timeZoneIdentifier: TimeZone.current.identifier,
                        initialDate: currentDate,
                        timeOffset: timeOffset
                    )
                    .environmentObject(weatherManager)
                }
            }
            .sheet(isPresented: $showShareSheet) {
                ShareCitiesSheet(
                    worldClocks: $worldClocks,
                    showSheet: $showShareSheet,
                    currentDate: currentDate,
                    timeOffset: timeOffset
                )
                .environmentObject(weatherManager)
            }
            .sheet(isPresented: $showArrangeListSheet) {
                ArrangeListView(
                    worldClocks: $worldClocks,
                    showSheet: $showArrangeListSheet,
                    currentDate: currentDate,
                    timeOffset: timeOffset
                )
            }
            .onChange(of: showArrangeListSheet) { oldValue, newValue in
                if oldValue && !newValue {
                    loadCollections()
                    ensureValidSelectedCity(in: displayedClocks)
                }
            }
            .sheet(isPresented: $showSetAlarmSheet) {
                SetAlarmSheet()
            }
            .sheet(isPresented: $showSetTimerSheet) {
                SetTimerSheet(initialDurationSeconds: homeTimerConfiguredSeconds) { durationSeconds in
                    startHomeTimer(durationSeconds: durationSeconds)
                }
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView(
                    worldClocks: $worldClocks,
                    weatherManager: weatherManager
                )
            }
            .onChange(of: showSettingsSheet) { oldValue, newValue in
                if oldValue && !newValue {
                    loadCollections()
                    ensureValidSelectedCity(in: displayedClocks)
                }
            }
            .sheet(isPresented: $showLifetimeStore) {
                NavigationStack {
                    LifetimeStoreView()
                }
            }
            .sheet(isPresented: $showTimeAdjustmentSheet) {
                CityTimeAdjustmentSheet(
                    cityName: selectedCityName,
                    timeZoneIdentifier: selectedTimeZone.identifier,
                    timeOffset: $timeOffset,
                    showSheet: $showTimeAdjustmentSheet,
                    showScrollTimeButtons: $showScrollTimeButtons
                )
            }
            .alert(cameraAlertTitle, isPresented: $showCameraPermissionAlert) {
                Button(String(localized: "Cancel"), role: .cancel) { }
                Button(String(localized: "Go to Settings")) {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsURL)
                    }
                }
            } message: {
                Text(cameraAlertMessage)
            }
            // Unified weather fetch trigger for this screen.
            .task(id: "\(showWeather)-\(selectedTimeZone.identifier)") {
                if showWeather {
                    await weatherManager.getWeather(for: selectedTimeZone.identifier)
                }
            }
            .onAppear {
                loadCollections()
                ensureValidSelectedCity(in: displayedClocks)
                restoreHomeTimerStateIfNeeded()

                cameraWarmupTask?.cancel()
                cameraWarmupTask = Task {
                    let status = AVCaptureDevice.authorizationStatus(for: .video)
                    if Task.isCancelled { return }
                    if status == .authorized {
                        _ = await cameraSessionController.configureIfNeeded()
                    }
                }
            }
            .onDisappear {
                cameraWarmupTask?.cancel()
                cameraWarmupTask = nil
            }
            .onChange(of: scenePhase) { oldValue, newValue in
                if newValue == .active {
                    loadCollections()
                    ensureValidSelectedCity(in: displayedClocks)
                    if isCameraBackgroundEnabled {
                        Task {
                            _ = await cameraSessionController.startRunning()
                        }
                    }
                } else {
                    cameraSessionController.stopRunning()
                }
            }
            .onChange(of: showLocalTime) { oldValue, newValue in
                ensureValidSelectedCity(in: displayedClocks)
            }
            .onChange(of: worldClocks) { oldValue, newValue in
                ensureValidSelectedCity(in: displayedClocks)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Time Offset Arc View
struct TimeOffsetArcView: View {
    let timeOffset: TimeInterval
    let currentDate: Date  // 原始时间（未加偏移）
    let timeZone: TimeZone
    let size: CGFloat
    
    // 计算指定日期在给定时区的角度（弧度，从顶部顺时针）
    private func angleRadians(for date: Date) -> Double {
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)
        // 24小时制：0时在顶部，每小时15度
        // -90 度调整使 0 时在顶部（标准坐标系中0度在右边）
        let degrees = (hour + minute / 60 + second / 3600) * 15 - 90
        return degrees * .pi / 180
    }
    
    var body: some View {
        let adjustedDate = currentDate.addingTimeInterval(timeOffset)
        let startAngle = angleRadians(for: currentDate)
        let endAngle = angleRadians(for: adjustedDate)
        
        Path { path in
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = (size - 24) / 2
            
            path.addArc(
                center: center,
                radius: radius,
                startAngle: Angle(radians: startAngle),
                endAngle: Angle(radians: endAngle),
                clockwise: timeOffset < 0
            )
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .drawingGroup()
    }
}

// MARK: - Double Tap Tip
struct DoubleTapClockFaceTip: Tip {
    var title: Text {
        Text(String(localized: "Focus Time"))
    }
    
    var message: Text? {
        Text(String(localized: "Double-tap to focus on the selected time."))
    }
    
    var image: Image? {
        Image(systemName: "hand.rays.fill")
    }
    
    var options: [TipOption] {
        MaxDisplayCount(1)
    }
}

// MARK: - Analog Clock Face View
struct AnalogClockFaceView: View {
    let date: Date
    @Binding var timeOffset: TimeInterval
    let selectedTimeZone: TimeZone
    let size: CGFloat
    let worldClocks: [WorldClock]
    let showLocalTime: Bool
    @Binding var selectedCityId: UUID?
    let hapticEnabled: Bool
    @Binding var showDetailsSheet: Bool
    let weather: CurrentWeather?
    let showWeather: Bool
    let showTimeInsteadOfCityName: Bool
    
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showArcIndicator") private var showArcIndicator = true
    @AppStorage("availableTimeEnabled") private var availableTimeEnabled = false
    @AppStorage("availableStartTime") private var availableStartTime = "09:00"
    @AppStorage("availableEndTime") private var availableEndTime = "17:00"
    @AppStorage("availableWeekdays") private var availableWeekdays = AvailableTimeDefaults.weekdays
    @AppStorage("additionalTimeDisplay") private var additionalTimeDisplay = "None"
    @AppStorage("showSunriseSunsetLines") private var showSunriseSunsetLines = false
    @AppStorage("showGoldenHour") private var showGoldenHour = false
    @AppStorage("showMinuteHand") private var showMinuteHand = true
    @AppStorage("showUTCHand") private var showUTCHand = true
    @AppStorage("hasLifetimeAccess") private var hasLifetimeAccess = false
    @AppStorage("continuousScrollMode") private var continuousScrollMode = true
    
    @State private var hideOtherHands = false
    @State private var lastRotationAngle: Double? = nil
    private let rotationSecondsPerDegree: Double = 180
    @State private var hapticEngine: CHHapticEngine?
    @State private var hapticPlayer: CHHapticPatternPlayer?
    @State private var lastRotationHapticOffset: TimeInterval = 0
    
    private let doubleTapTip = DoubleTapClockFaceTip()

    private func angleDegrees(at location: CGPoint, in size: CGFloat) -> Double {
        let center = CGPoint(x: size / 2, y: size / 2)
        let dx = Double(location.x - center.x)
        let dy = Double(location.y - center.y)
        return atan2(dy, dx) * 180 / .pi
    }
    
    private func normalizedAngleDelta(_ delta: Double) -> Double {
        var value = delta
        if value > 180 {
            value -= 360
        } else if value < -180 {
            value += 360
        }
        return value
    }
    
    
    private func prepareHaptics() {
        guard hapticEnabled && CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            if hapticEngine == nil {
                hapticEngine = try CHHapticEngine()
                let engine = hapticEngine
                
                hapticEngine?.stoppedHandler = { _ in
                    DispatchQueue.main.async {
                        do {
                            try engine?.start()
                        } catch {
                            print("Failed to restart haptic engine: \(error.localizedDescription)")
                        }
                    }
                }
                
                hapticEngine?.resetHandler = {
                    DispatchQueue.main.async {
                        do {
                            try engine?.start()
                        } catch {
                            print("Failed to restart haptic engine: \(error.localizedDescription)")
                        }
                    }
                }
            }
            
            try hapticEngine?.start()
            prepareHapticPlayer()
        } catch {
            print("Error creating/starting haptic engine: \(error.localizedDescription)")
        }
    }
    
    private func restartHapticEngine() {
        guard hapticEnabled && CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        do {
            try hapticEngine?.start()
            prepareHapticPlayer()
        } catch {
            print("Failed to restart haptic engine: \(error.localizedDescription)")
        }
    }
    
    private func prepareHapticPlayer() {
        guard let engine = hapticEngine else { return }
        
        do {
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5)
            let tickEvent = CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [sharpness, intensity],
                relativeTime: 0
            )
            let pattern = try CHHapticPattern(events: [tickEvent], parameters: [])
            hapticPlayer = try engine.makePlayer(with: pattern)
        } catch {
            print("Failed to create haptic player: \(error.localizedDescription)")
        }
    }
    
    private func ensureHapticEngineRunning() {
        guard hapticEnabled && CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        
        if hapticEngine == nil {
            prepareHaptics()
        } else {
            do {
                try hapticEngine?.start()
            } catch {
                restartHapticEngine()
            }
        }
    }
    
    private func playTickHaptic(intensity: Float = 0.50) {
        guard hapticEnabled && CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return }
        ensureHapticEngineRunning()
        
        do {
            if let player = hapticPlayer {
                try player.start(atTime: CHHapticTimeImmediate)
            } else if let engine = hapticEngine {
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.20)
                let intensityParam = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensity)
                let tickEvent = CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [sharpness, intensityParam],
                    relativeTime: 0
                )
                let pattern = try CHHapticPattern(events: [tickEvent], parameters: [])
                let newPlayer = try engine.makePlayer(with: pattern)
                try newPlayer.start(atTime: CHHapticTimeImmediate)
            }
        } catch {
            print("Failed to play tick haptic: \(error.localizedDescription)")
            restartHapticEngine()
        }
    }
    
    private func checkAndPlayRotationHapticTick() {
        let tickInterval: TimeInterval = 1800
        let currentTicks = Int(timeOffset / tickInterval)
        let lastTicks = Int(lastRotationHapticOffset / tickInterval)
        if currentTicks != lastTicks {
            playTickHaptic(intensity: 0.5)
            lastRotationHapticOffset = timeOffset
        }
    }
    
    
    // MARK: - Sun Times Cache
    private struct SunTimesData {
        let sunrise: Date?
        let sunset: Date?
        let goldenHourStart: Date?
        let goldenHourEnd: Date?
    }
    
    private class SunTimesDataWrapper {
        let data: SunTimesData
        init(_ data: SunTimesData) { self.data = data }
    }
    
    private static let sunTimesCache: NSCache<NSString, SunTimesDataWrapper> = {
        let cache = NSCache<NSString, SunTimesDataWrapper>()
        cache.countLimit = 30
        return cache
    }()
    
    // MARK: - Moon Phase Cache
    private class MoonPhaseWrapper {
        let icon: String
        init(_ icon: String) { self.icon = icon }
    }
    
    private static let moonPhaseCache: NSCache<NSString, MoonPhaseWrapper> = {
        let cache = NSCache<NSString, MoonPhaseWrapper>()
        cache.countLimit = 30
        return cache
    }()
    
    // Calculate sunrise and sunset times using SunKit (with caching)
    private var sunTimes: SunTimesData? {
        guard let coordinates = TimeZoneCoordinates.getCoordinate(for: selectedTimeZone.identifier) else {
            return nil
        }
        
        // Create cache key based on day-level precision and timezone
        var calendar = Calendar.current
        calendar.timeZone = selectedTimeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let cacheKey = "\(selectedTimeZone.identifier)_sun_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)" as NSString
        
        // Lock-free read from NSCache (thread-safe without blocking)
        if let cached = Self.sunTimesCache.object(forKey: cacheKey) {
            return cached.data
        }
        
        var sun = Sun(
            location: CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude),
            timeZone: selectedTimeZone
        )
        sun.setDate(date)
        
        let data = SunTimesData(
            sunrise: sun.sunrise,
            sunset: sun.sunset,
            goldenHourStart: sun.eveningGoldenHourStart,
            goldenHourEnd: sun.eveningGoldenHourEnd
        )
        Self.sunTimesCache.setObject(SunTimesDataWrapper(data), forKey: cacheKey)
        return data
    }
    
    // Calculate angle for a date (hour and minute extracted from the date)
    private func angleForDate(_ date: Date?) -> Double? {
        guard let date = date else { return nil }
        var calendar = Calendar.current
        calendar.timeZone = selectedTimeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return nil }
        // 24-hour clock: full rotation = 24 hours
        let hourAngle = Double(hour) * 15.0 // 15 degrees per hour
        let minuteAngle = Double(minute) * 0.25 // 15/60 degrees per minute
        return hourAngle + minuteAngle
    }
    
    // Parse time string like "09:00" to (hour, minute)
    private func parseTimeString(_ timeString: String) -> (hour: Int, minute: Int) {
        let components = timeString.split(separator: ":")
        guard components.count == 2,
              let hour = Int(components[0]),
              let minute = Int(components[1]) else {
            return (9, 0)
        }
        return (hour, minute)
    }
    
    // Calculate position for available time indicator
    private func positionForTime(hour: Int, minute: Int, radius: CGFloat, center: CGFloat) -> CGPoint {
        let angleDegrees = Double(hour) * 15.0 + Double(minute) * 0.25 - 90
        let angleRadians = angleDegrees * .pi / 180
        let x = center + radius * CGFloat(cos(angleRadians))
        let y = center + radius * CGFloat(sin(angleRadians))
        return CGPoint(x: x, y: y)
    }
    
    // Get local time components
    private var localTime: (hour: Int, minute: Int) {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0, components.minute ?? 0)
    }
    
    // Get UTC time components
    private var utcTime: (hour: Int, minute: Int) {
        var calendar = Calendar.current
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0, components.minute ?? 0)
    }

    // Get the currently displayed time for the selected timezone.
    private var selectedClockTime: (hour: Int, minute: Int, second: Int) {
        var calendar = Calendar.current
        calendar.timeZone = selectedTimeZone
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return (
            components.hour ?? 0,
            components.minute ?? 0,
            components.second ?? 0
        )
    }
    
    // Get time for a specific timezone
    private func getTime(for timeZoneIdentifier: String) -> (hour: Int, minute: Int) {
        guard let timeZone = TimeZone(identifier: timeZoneIdentifier) else {
            return (0, 0)
        }
        var calendar = Calendar.current
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0, components.minute ?? 0)
    }
    
    // Calculate angle for a given hour and minute
    private func angleForTime(hour: Int, minute: Int) -> Double {
        // 24-hour clock: full rotation = 24 hours
        // 12 o'clock = 0 degrees (top)
        // Each hour = 15 degrees (360/24)
        let hourAngle = Double(hour) * 15.0
        let minuteAngle = Double(minute) * 0.25 // 15 degrees per hour / 60 minutes
        return hourAngle + minuteAngle - 90 // Adjust so 0 hours is at top
    }
    
    // Group non-selected world clocks by time - show only one city per unique time
    // Also excludes times that match the selected city's time
    private var groupedNonSelectedClocks: [WorldClock] {
        // Get selected city's time if any
        var selectedTime: (hour: Int, minute: Int)? = nil
        if let cityId = selectedCityId,
           let selectedClock = worldClocks.first(where: { $0.id == cityId }) {
            selectedTime = getTime(for: selectedClock.timeZoneIdentifier)
        }
        
        var seenTimes: Set<String> = []
        var result: [WorldClock] = []
        
        for clock in worldClocks where clock.id != selectedCityId {
            let time = getTime(for: clock.timeZoneIdentifier)
            let key = "\(time.hour):\(time.minute)"
            
            // Skip if we already have a clock at this time
            if seenTimes.contains(key) {
                continue
            }
            
            // Skip if this time matches local time (when showLocalTime is enabled)
            if showLocalTime && time.hour == localTime.hour && time.minute == localTime.minute {
                continue
            }
            
            // Skip if this time matches the selected city's time
            if let selectedTime = selectedTime,
               time.hour == selectedTime.hour && time.minute == selectedTime.minute {
                continue
            }
            
            seenTimes.insert(key)
            result.append(clock)
        }
        
        return result
    }
    
    // 计算原始日期（不带偏移）
    private var originalDate: Date {
        date.addingTimeInterval(-timeOffset)
    }
    
    // Get SF Symbol for current moon phase (with caching)
    private var moonPhaseIcon: String {
        // Get coordinates for the timezone
        guard let coordinates = TimeZoneCoordinates.getCoordinate(for: selectedTimeZone.identifier) else {
            return "moon.fill"
        }
        
        // Create cache key based on day-level precision and timezone
        var calendar = Calendar.current
        calendar.timeZone = selectedTimeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let cacheKey = "\(selectedTimeZone.identifier)_moon_\(components.year ?? 0)_\(components.month ?? 0)_\(components.day ?? 0)" as NSString
        
        // Lock-free read from NSCache (thread-safe without blocking)
        if let cached = Self.moonPhaseCache.object(forKey: cacheKey) {
            return cached.icon
        }
        
        let moon = Moon(
            location: CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude),
            timeZone: selectedTimeZone
        )
        moon.setDate(date)
        
        let phaseString = String(describing: moon.currentMoonPhase)
            .replacingOccurrences(of: "MoonPhase.", with: "")
            .replacingOccurrences(of: "_", with: " ")
            .lowercased()
        
        let icon: String
        switch phaseString {
        case "newmoon", "new moon":
            icon = "moonphase.new.moon"
        case "waxingcrescent", "waxing crescent":
            icon = "moonphase.waxing.crescent"
        case "firstquarter", "first quarter":
            icon = "moonphase.first.quarter"
        case "waxinggibbous", "waxing gibbous":
            icon = "moonphase.waxing.gibbous"
        case "fullmoon", "full moon":
            icon = "moonphase.full.moon"
        case "waninggibbous", "waning gibbous":
            icon = "moonphase.waning.gibbous"
        case "lastquarter", "last quarter", "thirdquarter", "third quarter":
            icon = "moonphase.last.quarter"
        case "waningcrescent", "waning crescent":
            icon = "moonphase.waning.crescent"
        default:
            icon = "moon.fill"
        }
        
        Self.moonPhaseCache.setObject(MoonPhaseWrapper(icon), forKey: cacheKey)
        return icon
    }

    private var moonPhaseName: String {
        switch moonPhaseIcon {
        case "moonphase.new.moon":
            return String(localized: "New Moon")
        case "moonphase.waxing.crescent":
            return String(localized: "Waxing Crescent")
        case "moonphase.first.quarter":
            return String(localized: "First Quarter")
        case "moonphase.waxing.gibbous":
            return String(localized: "Waxing Gibbous")
        case "moonphase.full.moon":
            return String(localized: "Full Moon")
        case "moonphase.waning.gibbous":
            return String(localized: "Waning Gibbous")
        case "moonphase.last.quarter":
            return String(localized: "Last Quarter")
        case "moonphase.waning.crescent":
            return String(localized: "Waning Crescent")
        default:
            return String(localized: "Moon")
        }
    }
    
    var body: some View {
        ZStack {
            // Clock face background
            Circle()
                .fill(Color.black.opacity(0.25))
                .glassEffect(.clear.interactive())
                .frame(width: max(size - 24, 0), height: max(size - 24, 0))
                .contentShape(Circle())
                .onTapGesture(count: 2) {
                    if hapticEnabled {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                    hideOtherHands.toggle()
                    doubleTapTip.invalidate(reason: .actionPerformed)
                }
                .popoverTip(doubleTapTip)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            guard continuousScrollMode else { return }
                            let angle = angleDegrees(at: value.location, in: size)
                            if let lastAngle = lastRotationAngle {
                                let delta = normalizedAngleDelta(angle - lastAngle)
                                if delta != 0 {
                                    timeOffset += delta * rotationSecondsPerDegree
                                    checkAndPlayRotationHapticTick()
                                }
                            } else {
                                NotificationCenter.default.post(
                                    name: NSNotification.Name("StopScrollTimeInertia"),
                                    object: nil
                                )
                                lastRotationHapticOffset = timeOffset
                            }
                            lastRotationAngle = angle
                        }
                        .onEnded { value in
                            guard continuousScrollMode else { return }
                            lastRotationHapticOffset = timeOffset
                            lastRotationAngle = nil
                        }
                )
            
            // Time offset arc (显示滚动时间的起点到终点)
            if showArcIndicator && timeOffset != 0 {
                TimeOffsetArcView(
                    timeOffset: timeOffset,
                    currentDate: originalDate,
                    timeZone: selectedTimeZone,
                    size: size
                )
                .transition(.identity)
            }
            
            // Hour numbers
            HourNumbersView(size: size)
            
            
            // Golden hour indicator (yellow)
            if hasLifetimeAccess, showGoldenHour, let times = sunTimes,
               let goldenHourStartAngle = angleForDate(times.goldenHourStart),
               let goldenHourEndAngle = angleForDate(times.goldenHourEnd) {
                // Golden hour arc fill
                GoldenHourArcView(
                    startAngle: goldenHourStartAngle,
                    endAngle: goldenHourEndAngle,
                    size: size
                )
                
                // Golden hour start line
                GoldenHourLineView(
                    angle: goldenHourStartAngle,
                    size: size
                )
                
                // Golden hour end line
                GoldenHourLineView(
                    angle: goldenHourEndAngle,
                    size: size
                )
            }
            
            // Sunrise and Sunset indicator lines with daylight arc
            if hasLifetimeAccess, showSunriseSunsetLines, let times = sunTimes {
                // Daylight arc fill between sunrise and sunset
                if let sunriseAngle = angleForDate(times.sunrise),
                   let sunsetAngle = angleForDate(times.sunset) {
                    DaylightArcView(
                        sunriseAngle: sunriseAngle,
                        sunsetAngle: sunsetAngle,
                        size: size
                    )
                    
                    // Sunrise line
                    SunriseSunsetLineView(
                        angle: sunriseAngle,
                        size: size,
                        isSunrise: true
                    )
                    
                    // Sunset line
                    SunriseSunsetLineView(
                        angle: sunsetAngle,
                        size: size,
                        isSunrise: false
                    )
                }
            }
            
            // Available time indicators
            if hasLifetimeAccess, availableTimeEnabled, !availableWeekdays.isEmpty {
                let startTime = parseTimeString(availableStartTime)
                let endTime = parseTimeString(availableEndTime)
                let indicatorRadius = (size - 24) / 2 - 10
                let center = size / 2
                
                // Start time indicator
                Circle()
                    .glassEffect(.clear)
                    .frame(width: 6, height: 6)
                    .blendMode(.plusLighter)
                    .position(positionForTime(hour: startTime.hour, minute: startTime.minute, radius: indicatorRadius, center: center))
                
                // End time indicator
                Circle()
                    .glassEffect(.clear)
                    .frame(width: 6, height: 6)
                    .blendMode(.plusLighter)
                    .position(positionForTime(hour: endTime.hour, minute: endTime.minute, radius: indicatorRadius, center: center))
            }

            if hasLifetimeAccess, showMinuteHand {
                MinuteTickMarksView(size: size)
                    .allowsHitTesting(false)
            }
            
            // Sun/Weather icon
            Image(systemName: showWeather && weather != nil ? weather!.condition.icon : "sun.max.fill")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.tertiary)
                .blendMode(.plusLighter)
                .frame(height: 24)
                .position(x: size / 2,  y: size / 2 + (size / 2 - 64))
                .contentTransition(.symbolEffect(.replace))
                .animation(.spring(), value: weather?.condition)

            if hideOtherHands, showWeather, let weather {
                Text(weather.condition.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .position(x: size / 2, y: size / 2 + (size / 2 - 64) / 2)
            }
            
            // Moon phase icon
            Image(systemName: moonPhaseIcon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.tertiary)
                .blendMode(.plusLighter)
                .frame(height: 24)
                .position(x: size / 2, y: size / 2 - (size / 2 - 62))
                .contentTransition(.symbolEffect(.replace))
                .animation(.spring(), value: moonPhaseIcon)

            if hideOtherHands {
                Text(moonPhaseName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .position(x: size / 2, y: size / 2 - (size / 2 - 62) / 2)
                    .contentTransition(.numericText())
                    .animation(.spring(), value: moonPhaseName)
            }
            
            if hasLifetimeAccess, showMinuteHand {
                MinuteHandView(
                    minute: selectedClockTime.minute,
                    second: selectedClockTime.second,
                    size: size
                )
                .allowsHitTesting(false)
            }
            
            
            // UTC Hand
            if additionalTimeDisplay == "UTC", showUTCHand {
                UTCClockHandView(
                    hour: utcTime.hour,
                    minute: utcTime.minute,
                    size: size
                )
                .allowsHitTesting(false)
            }
            
            // World clock hands with city labels (non-selected first)
            // Grouped by time to avoid overlapping labels - only one city shown per unique time
            // Hidden when hideOtherHands is true (double-tap to toggle)
            if !hideOtherHands {
                ForEach(groupedNonSelectedClocks) { clock in
                    let time = getTime(for: clock.timeZoneIdentifier)
                    ClockHandWithLabel(
                        cityId: clock.id,
                        cityName: clock.localizedCityName,
                        hour: time.hour,
                        minute: time.minute,
                        size: size,
                        color: .white.opacity(0.25), // Hand colour
                        isSelected: false,
                        isLocal: false,
                        selectedCityId: $selectedCityId,
                        hapticEnabled: hapticEnabled,
                        showDetailsSheet: $showDetailsSheet,
                        showTimeInsteadOfCityName: showTimeInsteadOfCityName,
                        use24HourFormat: use24HourFormat
                    )
                }
            }
            
            // Local time hand (non-selected)
            if showLocalTime && selectedCityId != nil {
                ClockHandWithLabel(
                    cityId: nil,
                    cityName: String(localized: "Local"),
                    hour: localTime.hour,
                    minute: localTime.minute,
                    size: size,
                    color: .blue,
                    isSelected: false,
                    isLocal: true,
                    selectedCityId: $selectedCityId,
                    hapticEnabled: hapticEnabled,
                    showDetailsSheet: $showDetailsSheet,
                    showTimeInsteadOfCityName: showTimeInsteadOfCityName,
                    use24HourFormat: use24HourFormat
                )
            }
            
            // Selected city hand (rendered last to be on top)
            if let cityId = selectedCityId,
               let clock = worldClocks.first(where: { $0.id == cityId }) {
                let time = getTime(for: clock.timeZoneIdentifier)
                if !showLocalTime || time.hour != localTime.hour || time.minute != localTime.minute {
                    ClockHandWithLabel(
                        cityId: clock.id,
                        cityName: clock.localizedCityName,
                        hour: time.hour,
                        minute: time.minute,
                        size: size,
                        color: .white.opacity(0.25),
                        isSelected: true,
                        isLocal: false,
                        selectedCityId: $selectedCityId,
                        hapticEnabled: hapticEnabled,
                        showDetailsSheet: $showDetailsSheet,
                        showTimeInsteadOfCityName: showTimeInsteadOfCityName,
                        use24HourFormat: use24HourFormat
                    )
                }
            } else if showLocalTime && selectedCityId == nil {
                // Local is selected - render on top
                ClockHandWithLabel(
                    cityId: nil,
                    cityName: String(localized: "Local"),
                    hour: localTime.hour,
                    minute: localTime.minute,
                    size: size,
                    color: .blue,
                    isSelected: true,
                    isLocal: true,
                    selectedCityId: $selectedCityId,
                    hapticEnabled: hapticEnabled,
                    showDetailsSheet: $showDetailsSheet,
                    showTimeInsteadOfCityName: showTimeInsteadOfCityName,
                    use24HourFormat: use24HourFormat
                )
            }
            
            // Center Circle
            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
//                .glassEffect(.clear.tint(.white.opacity(0.25)))
        }
        .frame(width: size, height: size)
        .onChange(of: continuousScrollMode) { _, newValue in
            if !newValue {
                lastRotationAngle = nil
                lastRotationHapticOffset = timeOffset
            }
        }
        .onAppear {
            prepareHaptics()
        }
        .onDisappear {
            hapticEngine?.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            if hapticEnabled {
                restartHapticEngine()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            hapticEngine?.stop()
        }
    }
}

// MARK: - Clock Hand with Label
struct ClockHandWithLabel: View {
    let cityId: UUID?
    let cityName: String
    let hour: Int
    let minute: Int
    let size: CGFloat
    let color: Color
    let isSelected: Bool
    let isLocal: Bool
    @Binding var selectedCityId: UUID?
    let hapticEnabled: Bool
    @Binding var showDetailsSheet: Bool
    let showTimeInsteadOfCityName: Bool
    let use24HourFormat: Bool
    
    // Format time string based on hour and minute
    private var timeString: String {
        if use24HourFormat {
            return String(format: "%02d:%02d", hour, minute)
        } else {
            let displayHour = hour % 12 == 0 ? 12 : hour % 12
            return String(format: "%d:%02d", displayHour, minute)
        }
    }
    
    // Display text - either city name or time
    private var displayText: String {
        showTimeInsteadOfCityName ? timeString : cityName
    }
    
    private var angle: Double {
        // 24-hour clock: full rotation = 24 hours
        let hourAngle = Double(hour) * 15.0 // 15 degrees per hour
        let minuteAngle = Double(minute) * 0.25 // 15/60 degrees per minute
        return hourAngle + minuteAngle
    }
    
    // Counter-rotation: flip text 180° when pointing down/left to keep it readable
    private var textCounterRotation: Double {
        // When angle is greater than 180° (bottom half), flip the text
        angle > 180 ? 180 : 0
    }
    
    // Hand color: white when selected, blue for Local when not selected
    private var handColor: Color {
        if isSelected {
            return .white
        }
        if isLocal {
            return .blue
        }
        return color
    }

    private var labelCenterOffset: CGFloat {
        size / 2 - 95
    }

    // Stop the hand at the inner edge of the label instead of its center.
    private var handLength: CGFloat {
        max(labelCenterOffset - 45.5, 0)
    }
    
    var body: some View {
        ZStack {
            // Visual layer
            ZStack {
                // Hand line - positioned straight up
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(handColor)
                    .frame(width: (isSelected || isLocal) ? 2.5 : 1.25, height: handLength)
                    .offset(y: -handLength / 2)
                    .blendMode((isSelected || isLocal) ? .normal : .plusLighter)
                
                // City label - positioned straight up, at outer end, parallel to hand
                Group {
                    if isSelected {
                        // Selected (either Local or city) - white background
                        if isLocal {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.black)
                                Text(displayText)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.black)
                                    .contentTransition(.numericText())
                            }
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: 95)
                            .glassEffect(
                                .regular.tint(.white).interactive(),
                                in: Capsule(style: .continuous)
                            )
                        } else {
                            Text(displayText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.black)
                                .contentTransition(.numericText())
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 10)
                                .frame(maxWidth: 95)
                                .glassEffect(
                                    .regular.tint(.white).interactive(),
                                    in: Capsule(style: .continuous)
                                )
                        }
                    } else if isLocal {
                        // Local not selected - blue style
                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.caption2.weight(.semibold))
                            Text(displayText)
                                .font(.caption.weight(.semibold))
                                .contentTransition(.numericText())
                        }
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: 95)
                        .glassEffect(
                            .regular.tint(.blue).interactive(),
                            in: Capsule(style: .continuous)
                        )
                    } else {
                        // Non-local not selected
                        Text(displayText)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: 95)
                        .blendMode(.plusLighter)
                        .glassEffect(
                            .regular.tint(.black.opacity(0.10)).interactive(),
                            in: Capsule(style: .continuous)
                        )
                }
            }
                .animation(.smooth, value: showTimeInsteadOfCityName)
                .allowsHitTesting(false)
                // Rotate 90° to align parallel with hand, then flip if needed for readability
                .rotationEffectIgnoringLayout(.degrees(-90 + textCounterRotation))
                // Position closer to center
                .offset(y: -labelCenterOffset)
            }
            .animation(.none, value: angle)
            .rotationEffectIgnoringLayout(.degrees(angle))
            
            // Separate hit target so taps follow the rotated label's visible position.
            Color.clear
                .frame(width: 95, height: 28)
                .contentShape(Capsule(style: .continuous))
                .rotationEffect(.degrees(-90 + textCounterRotation))
                .offset(y: -labelCenterOffset)
                .rotationEffect(.degrees(angle))
                .onTapGesture {
                    if hapticEnabled {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    }
                    // Open details sheet when tapping selected city
                    if isSelected {
                        showDetailsSheet = true
                    } else {
                        selectedCityId = cityId
                    }
                }
        }
        .frame(width: size, height: size)
    }
}

private extension View {
    func rotationEffectIgnoringLayout(_ angle: SwiftUI.Angle, anchor: UnitPoint = .center) -> some View {
        modifier(_RotationEffect(angle: angle, anchor: anchor).ignoredByLayout())
    }
}

// MARK: - UTC Clock Hand
struct UTCClockHandView: View {
    let hour: Int
    let minute: Int
    let size: CGFloat
    
    private var angle: Double {
        let hourAngle = Double(hour) * 15.0
        let minuteAngle = Double(minute) * 0.25
        return hourAngle + minuteAngle
    }
    
    private var handLength: CGFloat {
        max(size / 2 - 20, 0)
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.red)
                .frame(width: 2, height: handLength)
                .offset(y: -handLength / 2)
            
            Circle()
                .fill(.red)
                .frame(width: 8, height: 8)
                .offset(y: -handLength)
        }
        .animation(.none, value: angle)
        .rotationEffect(.degrees(angle))
    }
}

// MARK: - Minute Hand
struct MinuteHandView: View {
    let minute: Int
    let second: Int
    let size: CGFloat
    private let tailLength: CGFloat = 24
    
    private var angle: Double {
        Double(minute) * 6.0 + Double(second) * 0.1
    }
    
    private var forwardLength: CGFloat {
        max(size / 2 - 20, 0)
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white)
                .frame(width: 2, height: forwardLength + tailLength)
                .offset(y: -(forwardLength - tailLength) / 2)
            
            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
                .offset(y: -forwardLength)
        }
        .animation(.none, value: angle)
        .rotationEffect(.degrees(angle))
    }
}

// MARK: - Minute Tick Marks
struct MinuteTickMarksView: View {
    let size: CGFloat
    
    private let tickLength: CGFloat = 10
    private let tickWidth: CGFloat = 2
    
    private var tickRadius: CGFloat {
        max(size / 2 - 63, 0)
    }
    
    var body: some View {
        ZStack {
            ForEach(0..<12, id: \.self) { index in
                if index != 0 && index != 6 {
                    RoundedRectangle(cornerRadius: tickWidth / 2, style: .continuous)
                        .fill(.white.opacity(0.25))
                        .frame(width: tickWidth, height: tickLength)
                        .offset(y: -tickRadius)
                        .rotationEffect(.degrees(Double(index) * 30.0))
                        .blendMode(.plusLighter)
                }
            }
        }
    }
}

// MARK: - Daylight Arc View
struct DaylightArcView: View {
    let sunriseAngle: Double
    let sunsetAngle: Double
    let size: CGFloat
    
    var body: some View {
        let center = CGPoint(x: size / 2, y: size / 2)
        let radius = (size - 24) / 2
        
        // Convert to radians (subtract 90 to align with clock where 0 is at top)
        let startRadians = (sunriseAngle - 90) * .pi / 180
        let endRadians = (sunsetAngle - 90) * .pi / 180
        
        Path { path in
            path.move(to: center)
            path.addArc(
                center: center,
                radius: radius,
                startAngle: Angle(radians: startRadians),
                endAngle: Angle(radians: endRadians),
                clockwise: false
            )
            path.closeSubpath()
        }
        .fill(
            RadialGradient(
                colors: [
                    Color.white.opacity(0.1),
                    Color.white.opacity(0.0)
                ],
                center: .center,
                startRadius: 0,
                endRadius: radius
            )
        )
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}

// MARK: - Golden Hour Arc View
struct GoldenHourArcView: View {
    let startAngle: Double
    let endAngle: Double
    let size: CGFloat
    
    var body: some View {
        let center = CGPoint(x: size / 2, y: size / 2)
        let radius = (size - 24) / 2
        
        // Convert to radians (subtract 90 to align with clock where 0 is at top)
        let startRadians = (startAngle - 90) * .pi / 180
        let endRadians = (endAngle - 90) * .pi / 180
        
        Path { path in
            path.move(to: center)
            path.addArc(
                center: center,
                radius: radius,
                startAngle: Angle(radians: startRadians),
                endAngle: Angle(radians: endRadians),
                clockwise: false
            )
            path.closeSubpath()
        }
        .fill(
            RadialGradient(
                colors: [
                    Color.yellow.opacity(0.20),
                    Color.clear
                ],
                center: .center,
                startRadius: 0,
                endRadius: radius
            )
        )
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}

// MARK: - Sunrise/Sunset Line View
struct SunriseSunsetLineView: View {
    let angle: Double
    let size: CGFloat
    let isSunrise: Bool
    
    var body: some View {
        let center = CGPoint(x: size / 2, y: size / 2)
        let radius = (size - 24) / 2 - 50
        let angleRadians = (angle - 90) * .pi / 180
        let endPoint = CGPoint(
            x: center.x + radius * CGFloat(cos(angleRadians)),
            y: center.y + radius * CGFloat(sin(angleRadians))
        )
        
        Path { path in
            path.move(to: center)
            path.addLine(to: endPoint)
        }
        .stroke(
            LinearGradient(
                colors: [Color.white.opacity(0.25), Color.white.opacity(0)],
                startPoint: UnitPoint(x: 0.5, y: 0.5),
                endPoint: UnitPoint(
                    x: 0.5 + (radius / size) * CGFloat(cos(angleRadians)),
                    y: 0.5 + (radius / size) * CGFloat(sin(angleRadians))
                )
            ),
            style: StrokeStyle(
                lineWidth: 1.25,
                lineCap: .round
            )
        )
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}

// MARK: - Golden Hour Line View
struct GoldenHourLineView: View {
    let angle: Double
    let size: CGFloat
    
    var body: some View {
        let center = CGPoint(x: size / 2, y: size / 2)
        let radius = (size - 24) / 2 - 50
        let angleRadians = (angle - 90) * .pi / 180
        let endPoint = CGPoint(
            x: center.x + radius * CGFloat(cos(angleRadians)),
            y: center.y + radius * CGFloat(sin(angleRadians))
        )
        
        Path { path in
            path.move(to: center)
            path.addLine(to: endPoint)
        }
        .stroke(
            LinearGradient(
                colors: [Color.yellow.opacity(0.25), Color.clear],
                startPoint: UnitPoint(x: 0.5, y: 0.5),
                endPoint: UnitPoint(
                    x: 0.5 + (radius / size) * CGFloat(cos(angleRadians)),
                    y: 0.5 + (radius / size) * CGFloat(sin(angleRadians))
                )
            ),
            style: StrokeStyle(
                lineWidth: 1.25,
                lineCap: .round
            )
        )
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}

// MARK: - Digital Time Display
struct DigitalTimeDisplayView: View {
    enum DisplayPage: Int, CaseIterable {
        case time
        case timer
    }

    nonisolated private static let tabCoordinateSpaceName = "digital-time-display-tabs"

    let currentDate: Date
    let timeOffset: TimeInterval
    let selectedTimeZone: TimeZone
    let use24HourFormat: Bool
    let weather: CurrentWeather?
    let showWeather: Bool
    let useCelsius: Bool
    let hapticEnabled: Bool
    let timerConfiguredSeconds: Int
    let timerEndDateEpoch: Double
    let timerIsPaused: Bool
    let timerPausedRemainingSeconds: Int
    let onTimerTap: () -> Void
    let onTimerConfigureTap: () -> Void
    let onTimeTap: () -> Void
    
    @AppStorage("dateStyle") private var dateStyle = "Relative"
    @State private var selectedPage: DisplayPage

    init(
        currentDate: Date,
        timeOffset: TimeInterval,
        selectedTimeZone: TimeZone,
        use24HourFormat: Bool,
        weather: CurrentWeather?,
        showWeather: Bool,
        useCelsius: Bool,
        hapticEnabled: Bool,
        timerConfiguredSeconds: Int,
        timerEndDateEpoch: Double,
        timerIsPaused: Bool,
        timerPausedRemainingSeconds: Int,
        onTimerTap: @escaping () -> Void,
        onTimerConfigureTap: @escaping () -> Void,
        onTimeTap: @escaping () -> Void
    ) {
        self.currentDate = currentDate
        self.timeOffset = timeOffset
        self.selectedTimeZone = selectedTimeZone
        self.use24HourFormat = use24HourFormat
        self.weather = weather
        self.showWeather = showWeather
        self.useCelsius = useCelsius
        self.hapticEnabled = hapticEnabled
        self.timerConfiguredSeconds = timerConfiguredSeconds
        self.timerEndDateEpoch = timerEndDateEpoch
        self.timerIsPaused = timerIsPaused
        self.timerPausedRemainingSeconds = timerPausedRemainingSeconds
        self.onTimerTap = onTimerTap
        self.onTimerConfigureTap = onTimerConfigureTap
        self.onTimeTap = onTimeTap
        _selectedPage = State(initialValue: timerConfiguredSeconds > 0 ? .timer : .time)
    }

    private var adjustedDate: Date {
        currentDate.addingTimeInterval(timeOffset)
    }

    private var hasConfiguredTimer: Bool {
        timerConfiguredSeconds > 0
    }

    private var timerEndDate: Date? {
        guard timerEndDateEpoch > 0 else { return nil }
        return Date(timeIntervalSince1970: timerEndDateEpoch)
    }

    private var tabHeight: CGFloat {
        110
    }

    private func formattedCurrentTime() -> String {
        let formatter = DateFormatter()
        formatter.timeZone = selectedTimeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if use24HourFormat {
            formatter.dateFormat = "HH:mm"
        } else {
            formatter.dateFormat = "h:mm"
        }
        return formatter.string(from: adjustedDate)
    }

    private func formattedDateText() -> String {
        adjustedDate.formattedDate(style: dateStyle, timeZone: selectedTimeZone)
    }

    private func timerRemainingSeconds(at date: Date) -> Int {
        if timerIsPaused {
            return max(0, min(timerPausedRemainingSeconds, 59 * 60 + 59))
        }

        guard let timerEndDate else { return 0 }
        let remaining = Int(ceil(timerEndDate.timeIntervalSince(date)))
        return max(remaining, 0)
    }

    private func timerControlSymbol(at date: Date) -> String {
        let remaining = timerRemainingSeconds(at: date)
        return (timerIsPaused || remaining == 0) ? "play.fill" : "pause.fill"
    }

    private func formattedTimer(seconds: Int) -> String {
        let clampedSeconds = max(0, min(seconds, 59 * 60 + 59))
        let minutes = clampedSeconds / 60
        let remainingSeconds = clampedSeconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }

    private func formattedConfiguredDuration(seconds: Int) -> String {
        let clampedSeconds = max(0, min(seconds, 59 * 60 + 59))
        let minutes = clampedSeconds / 60
        let remainingSeconds = clampedSeconds % 60

        if minutes > 0 && remainingSeconds > 0 {
            return String.localizedStringWithFormat(
                String(localized: "%d min %d sec"),
                minutes,
                remainingSeconds
            )
        }
        if minutes > 0 {
            return String.localizedStringWithFormat(String(localized: "%d min"), minutes)
        }
        return String.localizedStringWithFormat(String(localized: "%d sec"), remainingSeconds)
    }
    
    private func triggerPageHapticIfNeeded() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .rigid)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }

    @ViewBuilder
    private var timePage: some View {
        VStack(spacing: 0) {
            Button(action: onTimeTap) {
                Text(formattedCurrentTime())
                    .font(.system(size: 52))
                    .fontWeight(.light)
                    .fontDesign(.rounded)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())

            HStack(spacing: 4) {
                if showWeather {
                    WeatherView(
                        weather: weather,
                        useCelsius: useCelsius
                    )
                }

                Text(formattedDateText())
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .contentTransition(.numericText())
            }
        }
    }

    @ViewBuilder
    private var timerPage: some View {
        VStack(spacing: 0) {
            if hasConfiguredTimer {
                // Timer Set
                Button(action: onTimerTap) {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let remaining = timerRemainingSeconds(at: context.date)
                        Text(formattedTimer(seconds: remaining))
                            .font(.system(size: 52))
                            .fontWeight(.light)
                            .fontDesign(.rounded)
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .contentTransition(.numericText(countsDown: true))
                            .animation(.spring(duration: 0.25), value: remaining)
                    }
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

                TimelineView(.periodic(from: .now, by: 1)) { context in
                    HStack(spacing: 8) {
                        Image(systemName: timerControlSymbol(at: context.date))
                            .contentTransition(.symbolEffect(.replace))
                        Text(formattedConfiguredDuration(seconds: timerConfiguredSeconds))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .animation(.spring(duration: 0.25), value: timerRemainingSeconds(at: context.date))
                }
            } else {
                // No timer yet
                Button(action: onTimerConfigureTap) {
                    Text("00:00")
                        .font(.system(size: 52))
                        .fontWeight(.light)
                        .fontDesign(.rounded)
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                        .blendMode(.plusLighter)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                
                Text(String(localized: "Set Timer"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { tabGeometry in
                let viewportMidX = tabGeometry.size.width / 2

                TabView(selection: $selectedPage) {
                    timePage
                        .edgeChromaticSwipeEffect(
                            viewportMidX: viewportMidX,
                            coordinateSpaceName: Self.tabCoordinateSpaceName
                        )
                        .tag(DisplayPage.time)

                    timerPage
                        .edgeChromaticSwipeEffect(
                            viewportMidX: viewportMidX,
                            coordinateSpaceName: Self.tabCoordinateSpaceName
                        )
                        .tag(DisplayPage.timer)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(width: tabGeometry.size.width, height: tabHeight)
            }
            .frame(height: tabHeight)
            .coordinateSpace(name: Self.tabCoordinateSpaceName)

            HStack(spacing: 8) {
                ForEach(DisplayPage.allCases, id: \.self) { page in
                    Circle()
                        .fill(Color.white.opacity(page == selectedPage ? 1.0 : 0.25))
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.bottom)
            .blendMode(.plusLighter)
            .animation(.spring(duration: 0.25), value: selectedPage)
        }
        .onChange(of: hasConfiguredTimer) { oldValue, newValue in
            if !oldValue && newValue {
                withAnimation(.spring(duration: 0.25)) {
                    selectedPage = .timer
                }
            } else if oldValue && !newValue && selectedPage == .timer {
                withAnimation(.spring(duration: 0.25)) {
                    selectedPage = .time
                }
            }
        }
        .onChange(of: selectedPage) { oldValue, newValue in
            guard oldValue != newValue else { return }
            triggerPageHapticIfNeeded()
        }
    }
}
