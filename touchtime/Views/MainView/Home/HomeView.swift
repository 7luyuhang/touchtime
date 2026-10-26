//
//  HomeView.swift
//  touchtime
//
//  Created on 23/09/2025.
//

import SwiftUI
import Combine
import UIKit
import EventKit
import EventKitUI
import WeatherKit
import Shimmer

// Data struct for city time adjustment sheet
struct CityTimeAdjustmentData: Identifiable {
    let id = UUID()
    let cityName: String
    let timeZoneIdentifier: String
}

struct HomeView: View {
    struct DeletedCitySnapshot {
        struct CollectionPosition {
            let collectionId: UUID
            let cityIndex: Int
        }

        let clock: WorldClock
        let worldClockIndex: Int
        let collectionPositions: [CollectionPosition]
    }

    /// City whose card is being shared as an image. The time is fixed
    /// when the menu item is tapped, so the share preview shows that
    /// moment instead of ticking (and reseeding its stars) every second.
    struct CityShareData: Identifiable {
        let id = UUID()
        let cityName: String
        let timeZoneIdentifier: String
        /// Wall-clock time and Slide to Adjust offset at the tap.
        let baseDate: Date
        let timeOffset: TimeInterval

        /// The time the card shows.
        var date: Date {
            baseDate.addingTimeInterval(timeOffset)
        }
    }

    /// Pinned countdown whose card is being shared as an image, with the
    /// scrubbed time at the tap so the share screen shows that moment.
    struct CountdownShareData: Identifiable {
        let id = UUID()
        let item: CountdownItem
        let now: Date
    }

    @Binding var worldClocks: [WorldClock]
    @Binding var timeOffset: TimeInterval
    @Binding var showScrollTimeButtons: Bool
    @ObservedObject var weatherManager: WeatherManager
    @ObservedObject var googleMeet = GoogleMeetManager.shared
    @State var currentDate = Date()
    @State var showingRenameAlert = false
    @State var renamingClockId: UUID? = nil
    @State private var renamingLocalTime = false
    @State var newClockName = ""
    @State var originalClockName = ""
    @State var showingTimerRenameAlert = false
    @State var newTimerName = ""
    @State var showShareSheet = false
    @State var showSettingsSheet = false
    @State var showLifetimeStore = false
    @State var showLifetimePromo = false
    @State var eventStore = EKEventStore()
    @State var showEventEditor = false
    @State var eventToEdit: EKEvent?
    @State var scheduleForTimeZone: String = TimeZone.current.identifier
    @State var showSunriseSunsetSheet = false
    @State var selectedTimeZone: String = ""
    @State var selectedCityName: String = ""
    // iPhone Duo landscape: the list and a city's details side by side
    @State private var isLandscape = false
    // City shown in the detail pane; nil means the local time
    @State var detailPaneCityId: UUID? = nil
    @State var showArrangeListSheet = false
    @State var showSetAlarmSheet = false
    @State var showSetTimerSheet = false
    @State var showStopwatchRecordsSheet = false
    @State var showCountdownSheet = false
    // Pinned countdowns show their preview below the home timer; the shared
    // store is observed, so pins toggled inside the countdown sheet update
    // the cards immediately.
    @Environment(CountdownStore.self) var countdownStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) var scenePhase
    // Countdown being edited after tapping its pinned card on Home.
    @State var editingHomeCountdown: CountdownItem? = nil
    // Pinned countdown being shared as an image from its card's context menu.
    @State var countdownShareData: CountdownShareData? = nil
    // Pinned countdowns folded into a stack from a card's context menu;
    // tapping the stack unfolds them.
    @State var isCountdownStackCollapsed = false
    @State var showComplicationsSheet = false
    @State var showWidgetIntroSheet = false
    @State var showEarthView = false
    @State var cityTimeAdjustmentData: CityTimeAdjustmentData? = nil
    // City card being shared as an image from its context menu.
    @State var cityShareData: CityShareData? = nil
    @State var showCalendarPermissionAlert = false
    
    // Collection management
    @State var collections: [CityCollection] = []
    @State var selectedCollectionId: UUID? = nil
    @State var recentlyDeletedCity: DeletedCitySnapshot? = nil
    @AppStorage("selectedCollectionId") var savedSelectedCollectionId: String = ""
    
    // Computed binding for picker
    private var pickerSelection: Binding<UUID?> {
        Binding(
            get: { selectedCollectionId },
            set: { newValue in
                selectedCollectionId = newValue
                saveSelectedCollection()
                if hapticEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.impactOccurred()
                }
            }
        )
    }
    
    @AppStorage("use24HourFormat") var use24HourFormat = false
    @AppStorage("additionalTimeDisplay") var additionalTimeDisplay = "None"
    @AppStorage("showLocalTime") var showLocalTime = true
    @AppStorage("customLocalName") private var customLocalName = ""
    @AppStorage("showSkyDot") var showSkyDot = true
    @AppStorage("hapticEnabled") var hapticEnabled = true
    @AppStorage("defaultEventDuration") var defaultEventDuration: Double = 3600 // Default 1 hour in seconds
    @AppStorage("selectedCalendarIdentifier") var selectedCalendarIdentifier: String = ""
    @AppStorage("addMeetLinkToEvents") var addMeetLinkToEvents = false
    @AppStorage("availableTimeEnabled") private var availableTimeEnabled = false
    @AppStorage("availableStartTime") private var availableStartTime = "09:00"
    @AppStorage("availableEndTime") private var availableEndTime = "17:00"
    @AppStorage("availableWeekdays") private var availableWeekdays = "2,3,4,5,6" // Default Mon-Fri
    @AppStorage("hasLifetimeAccess") var hasLifetimeAccess = false
    @AppStorage("dateStyle") var dateStyle = "Relative"
    @AppStorage("showWeather") var showWeather = false
    @AppStorage("useCelsius") var useCelsius = true
    @AppStorage("showAnalogClock") var showAnalogClock = false
    @AppStorage("analogClockShowScale") private var analogClockShowScale = false
    @AppStorage("showSunPosition") var showSunPosition = false
    @AppStorage("showWeatherCondition") var showWeatherCondition = false
    @AppStorage("showTemperatureIndicator") var showTemperatureIndicator = false
    @AppStorage("showTemperatureRange") var showTemperatureRange = false
    @AppStorage("showUVIndex") var showUVIndex = false
    @AppStorage("showWindDirection") var showWindDirection = false
    @AppStorage("showWindSpeed") var showWindSpeed = false
    @AppStorage("showPressure") var showPressure = false
    @AppStorage("showSunAzimuth") var showSunAzimuth = false
    @AppStorage("showMoonAzimuth") var showMoonAzimuth = false
    @AppStorage("showMoonSunAzimuth") var showMoonSunAzimuth = false
    @AppStorage("showSunriseSunset") var showSunriseSunset = false
    @AppStorage("showDaylight") var showDaylight = false
    @AppStorage("showTimeOverlay") var showTimeOverlay = false
    @AppStorage("showSolarCurve") var showSolarCurve = false
    @AppStorage("solarCurveShowSun") private var solarCurveShowSun = false
    @AppStorage("showWhatsNewSwipeAdjust") var showWhatsNewSwipeAdjust = true
    @AppStorage("showShakeToResetTip") var showShakeToResetTip = false
    @AppStorage("hasTriggeredShakeToResetTip") var hasTriggeredShakeToResetTip = false
    @AppStorage("showTimeZoneUpdatedTip") var showTimeZoneUpdatedTip = false
    @AppStorage("lastKnownTimeZoneIdentifier") var lastKnownTimeZoneIdentifier = ""
    // Pacing of the Unlock All Features sheet, see showLifetimePromoIfDue()
    @AppStorage("lifetimePromoStartTime") var lifetimePromoStartTime: Double = 0
    @AppStorage("lifetimePromoLastShownTime") var lifetimePromoLastShownTime: Double = 0
    @AppStorage("lifetimePromoShownCount") var lifetimePromoShownCount = 0
    @AppStorage("homeTimerConfiguredSeconds") var homeTimerConfiguredSeconds = 0
    @AppStorage("homeTimerEndDateEpoch") var homeTimerEndDateEpoch: Double = 0
    @AppStorage("homeTimerCompletionHandled") var homeTimerCompletionHandled = false
    @AppStorage("homeTimerPaused") var homeTimerPaused = false
    @AppStorage("homeTimerPausedRemainingSeconds") var homeTimerPausedRemainingSeconds = 0
    @AppStorage("homeTimerAlarmID") var homeTimerAlarmIDRawValue = ""
    @AppStorage("homeTimerName") var homeTimerName = ""
    @AppStorage("homeStopwatchStartEpoch") var homeStopwatchStartEpoch: Double = 0
    @AppStorage("homeStopwatchAccumulatedSeconds") var homeStopwatchAccumulatedSeconds: Double = 0
    @AppStorage("homeStopwatchLapsData") var homeStopwatchLapsData = Data()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // UserDefaults key for storing world clocks
    let worldClocksKey = "savedWorldClocks"
    let collectionsKey = "savedCityCollections"
    
    var effectiveShowWeatherCondition: Bool {
        showWeatherCondition
    }

    var effectiveShowTemperatureIndicator: Bool {
        hasLifetimeAccess && showTemperatureIndicator
    }

    private var effectiveShowTemperatureRange: Bool {
        hasLifetimeAccess && showTemperatureRange
    }

    var effectiveShowUVIndex: Bool {
        hasLifetimeAccess && showUVIndex
    }

    var effectiveShowWindDirection: Bool {
        hasLifetimeAccess && showWindDirection
    }

    private var effectiveShowWindSpeed: Bool {
        hasLifetimeAccess && showWindSpeed
    }

    private var effectiveShowPressure: Bool {
        hasLifetimeAccess && showPressure
    }

    private var effectiveShowMoonAzimuth: Bool {
        hasLifetimeAccess && showMoonAzimuth
    }

    private var effectiveShowMoonSunAzimuth: Bool {
        hasLifetimeAccess && showMoonSunAzimuth
    }

    private var effectiveShowDaylight: Bool {
        hasLifetimeAccess && showDaylight
    }

    private var effectiveShowTimeOverlay: Bool {
        hasLifetimeAccess && showTimeOverlay && availableTimeEnabled
    }

    var complicationOptions: ComplicationDisplayOptions {
        ComplicationDisplayOptions(
            showAnalogClock: showAnalogClock,
            analogClockShowScale: analogClockShowScale,
            showSunPosition: showSunPosition,
            showWeatherCondition: effectiveShowWeatherCondition,
            showTemperatureIndicator: effectiveShowTemperatureIndicator,
            showTemperatureRange: effectiveShowTemperatureRange,
            showUVIndex: effectiveShowUVIndex,
            showWindDirection: effectiveShowWindDirection,
            showWindSpeed: effectiveShowWindSpeed,
            showPressure: effectiveShowPressure,
            showSunAzimuth: showSunAzimuth,
            showMoonAzimuth: effectiveShowMoonAzimuth,
            showMoonSunAzimuth: effectiveShowMoonSunAzimuth,
            showSunriseSunset: showSunriseSunset,
            showDaylight: effectiveShowDaylight,
            showTimeOverlay: effectiveShowTimeOverlay,
            showSolarCurve: showSolarCurve,
            solarCurveShowSun: solarCurveShowSun
        )
    }

    private var hasVisibleComplication: Bool {
        complicationOptions.hasVisibleComplication
    }
    
    /// On iPhone Duo a city's details share the screen with the list instead
    /// of opening as a sheet: side by side in landscape, and stacked on the
    /// unfolded screen in portrait, flat or partially open, the details above
    /// the fold and the list below it.
    var splitAxis: Axis? {
        guard #available(iOS 27.1, *) else { return nil }
        if isLandscape {
            return .horizontal
        }
        return horizontalSizeClass == .regular ? .vertical : nil
    }

    var usesSplitLayout: Bool {
        splitAxis != nil
    }

    /// The city in the detail pane: the tapped row while it's still listed,
    /// otherwise the first row.
    private var detailPaneCity: (name: String, timeZoneIdentifier: String)? {
        if let cityId = detailPaneCityId,
           let clock = displayedClocks.first(where: { $0.id == cityId }) {
            return (getLocalizedCityName(for: clock), clock.timeZoneIdentifier)
        }
        if showLocalTime {
            return (String(localized: "Local"), TimeZone.current.identifier)
        }
        if let clock = displayedClocks.first {
            return (getLocalizedCityName(for: clock), clock.timeZoneIdentifier)
        }
        return nil
    }

    var body: some View {
        Group {
            if #available(iOS 27.1, *), let splitAxis {
                ArrangementView {
                    cityDetailPane
                } secondary: {
                    homeContent
                }
                .arrangementViewStyle(.split.axes(splitAxis == .horizontal ? .horizontal : .vertical))
                .background { splitSkyBackground }
            } else {
                homeContent
            }
        }
        .background {
            // Measures the whole window, so the keyboard can't make a portrait
            // screen look wide
            Color.clear
                .ignoresSafeArea()
                .onGeometryChange(for: Bool.self) { proxy in
                    proxy.size.width > proxy.size.height
                } action: { isWide in
                    isLandscape = isWide
                }
        }
        // The detail pane takes over from the details sheet
        .onChange(of: usesSplitLayout) { _, usesSplitLayout in
            if usesSplitLayout {
                showSunriseSunsetSheet = false
            }
        }
    }

    /// The widest iPhone's width, for the list column on wider screens.
    private static let maximumColumnWidth: CGFloat = 440

    /// On a wide screen without the details beside it (the unfolded iPhone
    /// Duo in portrait, flat or partially open) the list and Slide to Adjust
    /// keep to a phone-wide column.
    var usesPhoneColumn: Bool {
        horizontalSizeClass == .regular && splitAxis != .horizontal
    }

    // Fades in from 20% of the way across the window to full at 80%.
    // Smoothstep opacity ramp: a linear one shows hard bands where the fade
    // starts and ends
    private static let splitSkyFadeStops: [Gradient.Stop] = (0...8).map { step in
        let progress = Double(step) / 8
        return .init(color: .black.opacity(progress * progress * (3 - 2 * progress)), location: 0.2 + progress * 0.6)
    }

    /// Behind both panes: the detail pane city's sky, fading in from under
    /// the list to full strength on the left, or at the top when stacked.
    private var splitSkyBackground: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)

            if showSkyDot, let city = detailPaneCity {
                SkyBackgroundView(
                    date: currentDate.addingTimeInterval(timeOffset),
                    timeZoneIdentifier: city.timeZoneIdentifier,
                    weatherCondition: showWeather ? weatherManager.weatherData[city.timeZoneIdentifier]?.condition : nil,
                    appliesCardChrome: false,
                    // Full screen, like the Clock tab's sky
                    starCount: 150,
                    starsMotion: StarsView.Motion(timeOffset: timeOffset, timeZoneIdentifier: city.timeZoneIdentifier)
                )
                .mask {
                    LinearGradient(
                        stops: Self.splitSkyFadeStops,
                        startPoint: splitAxis == .vertical ? .bottom : .trailing,
                        endPoint: splitAxis == .vertical ? .top : .leading
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var cityDetailPane: some View {
        if let city = detailPaneCity {
            SunriseSunsetSheet(
                cityName: city.name,
                timeZoneIdentifier: city.timeZoneIdentifier,
                initialDate: currentDate,
                timeOffset: timeOffset,
                splitAxis: splitAxis
            )
            .environmentObject(weatherManager)
            // Above the list its cards line up with the list's: they sit 16pt
            // inside the pane, the list's 20pt inside the column
            .frame(maxWidth: usesPhoneColumn ? Self.maximumColumnWidth - 8 : nil)
            .frame(maxWidth: .infinity)
        } else {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()
        }
    }

    private var homeContent: some View {
        NavigationStack {
            homeScreen
                // Navigation Title
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .scrollEdgeEffectStyle(.soft, for: .top)
                // Next to the details pane everything in the list's bar brings
                // its own glass
                .scrollEdgeEffectHidden(usesSplitLayout, for: .top)
                .toolbar { homeToolbar }
                // Kept as separate steps: as a single expression the compiler
                // needs many seconds to type-check this chain
                .apply(handlingEvents)
                .apply(handlingRequests)
                .apply(presentingAlerts)
                .apply(presentingCitySheets)
                .apply(presentingToolSheets)
                .apply(presentingAppSheets)
        }
    }

    private var homeScreen: some View {
        ZStack(alignment: .bottom) {
            ShakeDetectorView {
                withAnimation(.spring()) {
                    restoreLastDeletedCity()
                }
            }
            .frame(width: 0, height: 0)
            .allowsHitTesting(false)
            
            // Blank View
            if displayedClocks.isEmpty && !showLocalTime && !hasConfiguredHomeTimer && !homeStopwatch.hasStarted && !hasPinnedCountdowns {
                emptyState
            } else {
                homeList
            }
            
            // Scroll Time View - Hide when renaming or when there's no content to display
            if !showingRenameAlert && !(displayedClocks.isEmpty && !showLocalTime) {
                scrollTimeBar
            }
        }
        .frame(maxWidth: usesPhoneColumn ? Self.maximumColumnWidth : nil)
        .frame(maxWidth: .infinity)
        .background(homeBackground)
        
        // Animations
        .animation(.spring(), value: showingRenameAlert)
        .animation(.spring(), value: customLocalName)
        .animation(.spring(), value: worldClocks)
        .animation(.spring(), value: showSkyDot)
        .animation(.spring(), value: showLocalTime)
        .animation(.spring(), value: hasLifetimeAccess && availableTimeEnabled)
        .animation(.spring(), value: showWhatsNewSwipeAdjust)
        .animation(.spring(), value: showShakeToResetTip)
        .animation(.spring(), value: showTimeZoneUpdatedTip)
        .animation(.snappy(), value: selectedCollectionId) // Collection Animation
        
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .verticalBarBottomInset()
        // Lets the split's sky background show through the stack
        .containerBackground(usesSplitLayout ? .clear : Color(UIColor.systemGroupedBackground), for: .navigation)
    }

    private var homeBackground: some View {
        ZStack {
            // Base system background. Beside the detail pane the split's
            // sky background shows through instead
            if !usesSplitLayout {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
            }
            
            // Sky Background Effect for System Time
            if showLocalTime && showSkyDot && !usesSplitLayout {
                VStack {
                    LocalSkyGlowBackground(
                        currentDate: $currentDate,
                        timeOffset: $timeOffset,
                        weatherManager: weatherManager
                    )
                    
                    Spacer()
                }
                .ignoresSafeArea()
            }
        }
    }

    private var scrollTimeBar: some View {
        ScrollTimeView(
            timeOffset: $timeOffset,
            showButtons: $showScrollTimeButtons,
            worldClocks: $worldClocks,
            enableDoubleTapExpandedControls: true,
            onAlarmTap: {
                showSetAlarmSheet = true
            },
            onTimerTap: {
                showSetTimerSheet = true
            },
            onCountdownTap: {
                showCountdownSheet = true
            },
            onStopwatchTap: {
                showStopwatchRecordsSheet = true
            }
        )
            .padding(.horizontal)
            .padding(.bottom, 8)
            .transition(.blurReplace())
    }
}

private extension View {
    /// Hands the view to `transform`, so a long modifier chain can be split
    /// into methods.
    func apply<Modified: View>(_ transform: (Self) -> Modified) -> Modified {
        transform(self)
    }
}
