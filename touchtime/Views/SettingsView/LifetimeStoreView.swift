//
//  LifetimeStoreView.swift
//  touchtime
//
//  Created on 01/03/2026.
//

import SwiftUI
import StoreKit
import UIKit
import Shimmer
import Combine
import WeatherKit
import VariableBlur

struct LifetimeStoreView: View {
    private static let productID = "com.time.lifetime"

    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasLifetimeAccess") private var hasLifetimeAccess = false
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @AppStorage("analogClockShowScale") private var analogClockShowScale = false
    @AppStorage("showWeather") private var showWeather = false
    @StateObject private var weatherManager = WeatherManager()
    @State private var product: Product?
    @State private var purchaseState: PurchaseState = .loading
    @State private var isRestoring = false
    @State private var currentDate = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    enum PurchaseState: Equatable {
        case idle
        case loading
        case purchasing
    }

    private enum ShowcaseComplication: Int, CaseIterable, Identifiable {
        case analogClock
        case sunElevation
        case sunAzimuth
        case sunriseSunset
        case solarCurve
        case daylight
        case moonAzimuth
        case moonSunAzimuth
        case weatherCondition
        case temperature
        case uvIndex
        case windDirection

        var id: Int { rawValue }

        var localizedName: String {
            switch self {
            case .analogClock: return String(localized: "Analog Clock")
            case .sunElevation: return String(localized: "Sun Elevation")
            case .sunAzimuth: return String(localized: "Sun Azimuth")
            case .sunriseSunset: return String(localized: "Sunrise & Sunset")
            case .solarCurve: return String(localized: "Solar Curve")
            case .daylight: return String(localized: "Daylight Curve")
            case .moonAzimuth: return String(localized: "Moon Azimuth")
            case .moonSunAzimuth: return String(localized: "Moon & Sun Azimuth")
            case .weatherCondition: return String(localized: "Weather Condition")
            case .temperature: return String(localized: "Temperature Indicator")
            case .uvIndex: return String(localized: "UV Index")
            case .windDirection: return String(localized: "Wind Direction")
            }
        }
    }

    var body: some View {
        ZStack {
            ParticleView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .opacity(0.75)
                .blendMode(.plusLighter)

            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 24) {
                        // Optically centered in the space between the navigation
                        // bar and the showcase (see `Alignment.opticalCenter`)
                        appIconEmblem
                            .frame(maxHeight: .infinity, alignment: .opticalCenter)

                        VStack(spacing: 24) {
                            complicationShowcaseRow(cardWidth: geometry.size.width - 48)

                            Text("And more features")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .blendMode(.plusLighter)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geometry.size.height, alignment: .bottom)
                }
            }

            // Square darkening gradient at the top of the screen
            GeometryReader { geometry in
                LinearGradient(
                    colors: [.black.opacity(0.10), .black.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .blendMode(.plusDarker)
                .frame(height: geometry.size.width)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            // Progressive blur behind the bottom actions
            GeometryReader { geometry in
                VariableBlurView(maxBlurRadius: 10, direction: .blurredBottomClearTop)
                    .frame(height: geometry.safeAreaInsets.bottom)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .background {
            // Full-screen local-time sky, as in DetailsSheet's large detent
            ZStack {
                Color.black

                SkyBackgroundView(
                    date: skyBackgroundDate,
                    timeZoneIdentifier: TimeZone.current.identifier,
                    weatherCondition: showWeather
                        ? weatherManager.weatherData[TimeZone.current.identifier]?.condition
                        : nil,
                    appliesCardChrome: false
                )
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
        }
        .onReceive(timer) { _ in
            currentDate = Date()
        }
        .task {
            await refreshLifetimeStatus()
            guard !hasLifetimeAccess else {
                dismiss()
                return
            }
            await loadProduct()
        }
        .task {
            for await result in Transaction.updates {
                do {
                    let transaction = try checkVerified(result)

                    if transaction.productID == Self.productID {
                        await refreshLifetimeStatus()
                    }

                    await transaction.finish()
                } catch {
                    print("Failed to process transaction update: \(error)")
                }
            }
        }
        .onChange(of: hasLifetimeAccess) { _, newValue in
            if newValue {
                dismiss()
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomActions
        }
        .navigationTitle("Lifetime")
        .navigationBarTitleDisplayMode(.inline)
        .scrollEdgeEffectStyle(.soft, for: .top)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    if hapticEnabled {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .fontWeight(.semibold)
                }
            }

            // Redeem Code
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if hapticEnabled {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                    Task { @MainActor in
                        await presentOfferCodeRedeemSheet()
                    }
                } label: {
                    Image(systemName: "infinity")
                        .fontWeight(.semibold)
                }
                .accessibilityLabel(Text("Redeem Code"))
            }
        }
    }

    // MARK: - App Icon Emblem

    /// Liquid Glass plate in the app icon's shape: the rounded square (same
    /// 100 pt / 26 pt-corner metrics as the icon in `AboutView`) with the
    /// icon's circle subtracted from it (~77% of the side: the 0.8125 circle
    /// layer at 0.95 scale in `TouchTimeApp.icon`), so the sky glow shows
    /// through the cut-out.
    private var appIconEmblem: some View {
        let plate = RoundedRectangle(cornerRadius: 26, style: .continuous)
            .subtracting(Circle().scale(0.8125 * 0.95))

        return plate
            .fill(Color.white.opacity(0.05))
            .glassEffect(.clear, in: plate)
            .frame(width: 100, height: 100)
    }

    // MARK: - Complication Showcase

    private func complicationShowcaseRow(cardWidth: CGFloat) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 16, alignment: .center),
                GridItem(.flexible(), spacing: 16, alignment: .center)
            ],
            spacing: 16
        ) {
            complicationShowcase

            ShowcaseStepCaption(
                number: 1,
                title: String(localized: "Unlock the experience with all complications")
            )

            availableTimeShowcase(cardWidth: cardWidth)

            ShowcaseStepCaption(
                number: 2,
                title: String(localized: "Compare available time across cities")
            )

            googleMeetShowcase

            ShowcaseStepCaption(
                number: 3,
                title: String(localized: "Add Google Meet Link to new events")
            )
        }
    }

    // MARK: - Google Meet Showcase

    private var googleMeetShowcase: some View {
        let circleSize: CGFloat = 64

        return ZStack {
            Circle()
                .fill(.clear)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.10))
                        .glassEffect(.clear)
                )
            Image(systemName: "video.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
        }
        .frame(width: circleSize, height: circleSize)
        .overlay(
            Circle()
                .stroke(.white.opacity(0.1), lineWidth: 1)
                .blendMode(.plusLighter)
        )
        .frame(height: showcaseHeight)
        .frame(maxWidth: .infinity)
        .skyBackgroundCardChrome(cornerRadius: 20)
    }

    // MARK: - Available Time Showcase

    // Fixed-height container (matching the complication showcase) with the
    // real-width local-time card overlaid on top. The card overflows the
    // trailing edge (big time, date, end label) and the top/bottom, and the
    // container's rounded rectangle masks the overflow, leaving a gray inset on
    // the leading edge.
    private func availableTimeShowcase(cardWidth: CGFloat) -> some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .frame(height: showcaseHeight)
            .overlay(alignment: .leading) {
                LocalAvailableTimePreview(date: previewDate, skyDate: currentDate)
                    .frame(width: cardWidth, alignment: .leading)
                    .padding(.leading, 24)
                    .padding(.bottom, 56)
            }
            .skyBackgroundCardChrome(cornerRadius: 20)
    }

    // Fixed 09:00 local time for the time label and availability indicator, so
    // they stay stable while the sky gradient follows the real current time.
    private var previewDate: Date {
        Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: currentDate) ?? currentDate
    }

    // Minute-quantized like HomeView's sky backgrounds, so the full-screen sky
    // only re-renders when the displayed minute changes rather than every second.
    private var skyBackgroundDate: Date {
        let interval = currentDate.timeIntervalSinceReferenceDate
        return Date(timeIntervalSinceReferenceDate: (interval / 60).rounded(.down) * 60)
    }

    private var complicationShowcase: some View {
        GeometryReader { geometry in
            let itemWidth = geometry.size.width / 2

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 0) {
                    ForEach(ShowcaseComplication.allCases) { complication in
                        complicationView(for: complication, size: 64)
                            .frame(width: 64, height: 64)
                            .overlay(
                                Circle()
                                    .stroke(.white.opacity(0.1), lineWidth: 1)
                                    .blendMode(.plusLighter)
                            )
                            .frame(width: itemWidth, height: geometry.size.height)
                    }
                }
            }
            .scrollTargetBehavior(CenteredComplicationScrollBehavior(itemWidth: itemWidth))
            .defaultScrollAnchor(showcaseInitialAnchor)
            .environmentObject(weatherManager)
        }
        .frame(height: showcaseHeight)
        .frame(maxWidth: .infinity)
        .skyBackgroundCardChrome(cornerRadius: 20)
    }

    private var showcaseHeight: CGFloat { 96 }

    // Rests the carousel on the 2nd complication (1st-half | 2nd-full | 3rd-half),
    // since each item spans half the viewport width.
    private var showcaseInitialAnchor: UnitPoint {
        let count = ShowcaseComplication.allCases.count
        guard count > 2 else { return .leading }
        return UnitPoint(x: 0.5 / Double(count - 2), y: 0.5)
    }

    @ViewBuilder
    private func complicationView(for complication: ShowcaseComplication, size: CGFloat) -> some View {
        switch complication {
        case .analogClock:
            AnalogClockView(
                date: currentDate,
                size: size,
                timeZone: .current,
                useMaterialBackground: false,
                showScale: analogClockShowScale
            )
        case .sunElevation:
            SunPositionIndicator(
                date: currentDate,
                timeZone: .current,
                size: size,
                useMaterialBackground: false
            )
        case .sunAzimuth:
            SunAzimuthIndicator(
                date: currentDate,
                timeZone: .current,
                size: size,
                useMaterialBackground: false
            )
        case .sunriseSunset:
            SunriseSunsetIndicator(
                date: currentDate,
                timeZone: .current,
                size: size,
                useMaterialBackground: false
            )
        case .solarCurve:
            SolarCurve(
                date: currentDate,
                timeZone: .current,
                size: size,
                useMaterialBackground: false
            )
        case .daylight:
            DaylightIndicator(
                date: currentDate,
                timeZone: .current,
                size: size,
                useMaterialBackground: false
            )
        case .moonAzimuth:
            MoonAzimuthIndicator(
                date: currentDate,
                timeZone: .current,
                size: size,
                useMaterialBackground: false
            )
        case .moonSunAzimuth:
            MoonSunAzimuthIndicator(
                date: currentDate,
                timeZone: .current,
                size: size,
                useMaterialBackground: false
            )
        case .weatherCondition:
            WeatherConditionView(
                timeZone: .current,
                size: size,
                useMaterialBackground: false
            )
        case .temperature:
            TemperatureIndicator(
                timeZone: .current,
                size: size,
                useMaterialBackground: false
            )
        case .uvIndex:
            UVIndexIndicator(
                timeZone: .current,
                size: size,
                useMaterialBackground: false
            )
        case .windDirection:
            WindDirectionIndicator(
                timeZone: .current,
                size: size,
                useMaterialBackground: false
            )
        }
    }

    private var bottomActions: some View {
        VStack(spacing: 16) {
            purchaseButton
            footerActions
        }
        .padding(.horizontal, 24)
    }

    private var purchaseButton: some View {
        Group {
            if purchaseState == .purchasing || purchaseState == .loading {
                ProgressView() // Purchasing / Loading Button
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
                    .glassEffect(.clear.tint(.white.opacity(0.10)), in: Capsule(style: .continuous))
                
            } else if let product {
                Button {
                    if hapticEnabled {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                    
                    Task {
                        await purchase(product)
                    }
                } label: {
                    Text("Continue for \(product.displayPrice)")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical)
                        .contentShape(Capsule(style: .continuous))
                        .glassEffect(.clear.interactive().tint(.white), in: Capsule(style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(purchaseState == .purchasing)
            }
        }
    }

    // Footer Actions
    private var footerActions: some View {
        HStack(spacing: 6) {
            Link(String(localized: "Privacy Policy"), destination: URL(string: "https://www.handstime.app/privacy")!)
                .buttonStyle(.plain)

            Text("·")
                .foregroundStyle(.secondary)

            Button {
                if hapticEnabled {
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }

                Task {
                    await restorePurchases()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(String(localized: "Restore Purchases"))

                    if isRestoring {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isRestoring)
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.secondary)
        .blendMode(.plusLighter)
    }

    @MainActor
    private func loadProduct() async {
        purchaseState = .loading

        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
            purchaseState = product == nil
            ? .idle
            : .idle
            if product == nil {
                print("Unable to load lifetime option.")
            }
        } catch {
            print("Failed to load lifetime product: \(error)")
            print("Unable to load lifetime option.")
            purchaseState = .idle
        }
    }

    @MainActor
    private func purchase(_ product: Product) async {
        guard purchaseState != .purchasing else { return }

        purchaseState = .purchasing

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                do {
                    let transaction = try checkVerified(verification)
                    await transaction.finish()
                    await refreshLifetimeStatus()
                    purchaseState = .idle
                } catch {
                    print("Transaction verification failed: \(error)")
                    print("Transaction couldn't be verified.")
                    purchaseState = .idle
                }

            case .pending:
                print("Purchase is pending approval.")
                purchaseState = .idle

            case .userCancelled:
                purchaseState = .idle

            @unknown default:
                purchaseState = .idle
            }
        } catch {
            print("Purchase error: \(error)")
            print("Purchase failed. Please try again.")
            purchaseState = .idle
        }
    }

    @MainActor
    private func restorePurchases() async {
        guard !isRestoring else { return }

        isRestoring = true

        do {
            try await AppStore.sync()
            await refreshLifetimeStatus()
            if hasLifetimeAccess {
                dismiss()
                return
            }
            print("No lifetime purchase found.")
        } catch {
            print("Failed to restore purchases: \(error)")
        }

        isRestoring = false
    }

    // MARK: - Offer Code Redemption

    @MainActor
    private var activeWindowScene: UIWindowScene? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }

        return scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
    }

    // Redeemed transactions arrive through `Transaction.updates`, which then
    // refreshes the lifetime status and dismisses the store.
    @MainActor
    private func presentOfferCodeRedeemSheet() async {
        guard let windowScene = activeWindowScene else {
            print("Unable to find active window scene for offer code redemption.")
            return
        }

        do {
            try await AppStore.presentOfferCodeRedeemSheet(in: windowScene)
        } catch {
            print("Failed to present offer code redemption sheet: \(error)")
        }
    }

    @MainActor
    private func refreshLifetimeStatus() async {
        var isUnlocked = false

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                guard transaction.revocationDate == nil else { continue }

                if transaction.productID == Self.productID {
                    isUnlocked = true
                    break
                }
            } catch {
                print("Failed to verify lifetime entitlement: \(error)")
            }
        }

        hasLifetimeAccess = isUnlocked
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let safe):
            return safe
        }
    }
}

// MARK: - Optical Center Alignment

/// Vertical guide at 40% of a view's height. Aligning a view inside a taller
/// frame on this guide leaves 40% of the free space above it and 60% below,
/// so it reads as centered: the eye places the middle of a space a little
/// above its geometric middle.
private struct OpticalCenterAlignment: AlignmentID {
    static func defaultValue(in context: ViewDimensions) -> CGFloat {
        context.height * 0.4
    }
}

private extension Alignment {
    /// Horizontally centered, vertically on the `OpticalCenterAlignment` guide.
    static let opticalCenter = Alignment(
        horizontal: .center,
        vertical: VerticalAlignment(OpticalCenterAlignment.self)
    )
}

// MARK: - Centered Complication Scroll Behavior

/// Keeps the complication carousel resting on a centered complication, with half
/// of each neighbour peeking on the sides (half · full · half). Snapping is
/// clamped so the first and last complications can never become the centered
/// slot; they're only the edge-half at rest and only show fully while dragging.
private struct CenteredComplicationScrollBehavior: ScrollTargetBehavior {
    /// Width of a single carousel slot (half the viewport width).
    let itemWidth: CGFloat

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard itemWidth > 0 else { return }

        // Resting offsets sit a slot's center on the viewport's leading edge,
        // producing the half · full · half layout: firstSnap + n · itemWidth.
        let firstSnap = itemWidth / 2
        let maxOffset = max(0, context.contentSize.width - context.containerSize.width)
        let maxIndex = max(0, ((maxOffset - firstSnap) / itemWidth).rounded(.down))

        let proposedIndex = ((target.rect.minX - firstSnap) / itemWidth).rounded()
        let clampedIndex = min(max(proposedIndex, 0), maxIndex)

        target.rect.origin.x = firstSnap + clampedIndex * itemWidth
    }
}

// MARK: - Showcase Step Caption

private struct ShowcaseStepCaption: View {
    let number: Int
    let title: String

    var body: some View {
        VStack(alignment: .leading) {
            Image(systemName: "\(number).circle.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.tertiary)
                .blendMode(.plusLighter)

            Spacer(minLength: 8)

            Text(title)
                .font(.subheadline.weight(.semibold))
                .multilineTextAlignment(.leading)
                .lineLimit(2)
                .truncationMode(.tail)
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Local Time + Available Time Preview

/// Recreates the `HomeView` local-time row (with the available-time indicator)
/// at its native sizes so it can be showcased inside the store.
private struct LocalAvailableTimePreview: View {
    /// Drives the time label, date label, and availability indicator (kept fixed).
    let date: Date
    /// Drives only the sky gradient so it can follow the real current time.
    let skyDate: Date

    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("dateStyle") private var dateStyle = "Relative"
    @AppStorage("showSkyDot") private var showSkyDot = true

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = use24HourFormat ? "HH:mm" : "h:mm"
        return formatter.string(from: date)
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Top row: "Local" indicator icon and date
            HStack {
                Image(systemName: "location.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)

                Spacer()

                Text(date.formattedDate(
                    style: dateStyle,
                    timeZoneIdentifier: TimeZone.current.identifier
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)
            }

            // Bottom row: Location and Time (baseline aligned)
            HStack(alignment: .lastTextBaseline) {
                Text(String(localized: "City"))
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                Text(timeText)
                    .font(.system(size: 36))
                    .fontWeight(.light)
                    .fontDesign(.rounded)
                    .monospacedDigit()
            }
            .padding(.bottom, -4)

            // Available Time Display with Progress Indicator
            AvailableTimeIndicator(
                currentDate: date,
                timeOffset: 0,
                availableStartTime: "09:00",
                availableEndTime: "17:00",
                use24HourFormat: use24HourFormat,
                availableWeekdays: "1,2,3,4,5,6,7"
            )
        }
        .padding()
        .padding(.bottom, -4)
    }

    var body: some View {
        if showSkyDot {
            cardContent
                .background(
                    ZStack {
                        Color.black
                        SkyBackgroundView(
                            date: skyDate,
                            timeZoneIdentifier: TimeZone.current.identifier
                        )
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
                .glassEffect(
                    .clear.interactive(),
                    in: RoundedRectangle(cornerRadius: 26, style: .continuous)
                )
        } else {
            cardContent
                .background(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(Color.black.opacity(0.1))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                        .blendMode(.plusLighter)
                )
                .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
    }
}
