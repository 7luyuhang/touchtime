//
//  MoonPhaseDetailsView.swift
//  touchtime
//
//  Created on 12/08/2026.
//

import SwiftUI
import MoonKit

// MARK: - Lightweight Moon Astronomy

/// Instantaneous moon values for a given moment.
struct MoonSnapshot {
    /// Age of the moon in degrees within the synodic cycle [0, 360).
    let ageDegrees: Double
    /// Age of the moon in days (0 = new moon, ~14.77 = full moon).
    let ageDays: Double
    /// Illuminated fraction of the disc [0, 1].
    let illuminatedFraction: Double
    /// Earth-Moon distance in kilometers.
    let distanceKilometers: Double
}

/// Practical Astronomy (Duffett-Smith) moon computation using the same
/// constants and steps as MoonKit's coordinate math, but without the
/// expensive moonrise/moonset search. Cheap enough to evaluate on every
/// frame while scrubbing through time.
enum MoonAstronomy {
    static func snapshot(for date: Date) -> MoonSnapshot {
        // Days since the J2000 epoch, in Terrestrial Time
        // (MoonKit applies the same fixed 63.8 s ΔT correction).
        let julianDay = date.timeIntervalSince1970 / 86400.0 + 2440587.5 + 63.8 / 86400.0
        let d = julianDay - 2451545.0

        func mod360(_ value: Double) -> Double {
            let m = value.truncatingRemainder(dividingBy: 360)
            return m < 0 ? m + 360 : m
        }
        func rad(_ degrees: Double) -> Double { degrees * .pi / 180 }

        // Sun: mean anomaly and true ecliptic longitude
        let sunMeanAnomaly = mod360(360.0 / 365.242191 * d + 280.466069 - 282.938346)
        let sunEquationOfCentre = 360.0 / Double.pi * 0.016708 * sin(rad(sunMeanAnomaly))
        let sunLongitude = mod360(sunMeanAnomaly + sunEquationOfCentre + 282.938346)

        // Moon: mean elements
        let meanLongitude = mod360(13.176339686 * d + 218.316433)
        let meanAnomaly = mod360(meanLongitude - 0.1114041 * d - 83.353451)

        // Corrections: annual equation, evection, equation of the centre, variation
        let annualEquation = 0.1858 * sin(rad(sunMeanAnomaly))
        let evection = 1.2739 * sin(rad(2 * (meanLongitude - sunLongitude) - meanAnomaly))
        let correctedAnomaly = meanAnomaly + evection - annualEquation - 0.37 * sin(rad(sunMeanAnomaly))
        let equationOfCentre = 6.2886 * sin(rad(correctedAnomaly)) + 0.214 * sin(rad(2 * correctedAnomaly))
        let correctedLongitude = meanLongitude + evection + equationOfCentre - annualEquation
        let variation = 0.6583 * sin(rad(2 * (correctedLongitude - sunLongitude)))
        let trueLongitude = correctedLongitude + variation

        // Age of the moon: elongation of the true longitudes
        let ageDegrees = mod360(trueLongitude - sunLongitude)
        let ageDays = ageDegrees / 12.1907
        let illuminatedFraction = (1 - cos(rad(ageDegrees))) / 2

        // Distance from the orbit ellipse evaluated at the corrected anomaly
        let eccentricity = 0.0549
        let semiMajorAxisKm = 384401.0
        let distanceKilometers = semiMajorAxisKm * (1 - eccentricity * eccentricity)
            / (1 + eccentricity * cos(rad(correctedAnomaly + equationOfCentre)))

        return MoonSnapshot(
            ageDegrees: ageDegrees,
            ageDays: ageDays,
            illuminatedFraction: illuminatedFraction,
            distanceKilometers: distanceKilometers
        )
    }
}

// MARK: - Moon Phase Details View

struct MoonPhaseDetailsView: View {
    let timeZoneIdentifier: String
    /// The moment shown when the view opens (the tapped day).
    let initialDate: Date
    /// Scrubbing can't leave this window: the previous, current and next
    /// month, matching the pages of the moon phase calendar.
    let dateRange: ClosedRange<Date>

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    // Committed scrub offset (seconds relative to initialDate) plus the live
    // drag translation, mirroring ScrollTimeView's accumulate-then-commit model.
    @State private var accumulatedOffset: TimeInterval = 0
    @State private var dragOffset: CGFloat = 0
    @State private var lastHapticOffset: CGFloat = 0

    // Inertia scrolling, same physics as ScrollTimeView: the fling velocity
    // decays per display frame via the shared CADisplayLink driver.
    @State private var inertiaVelocity: CGFloat = 0
    @State private var inertiaActive = false
    @State private var lastInertiaHapticOffset: TimeInterval = 0
    @State private var frameDriver = ScrollTimeFrameDriver()

    // Center of the day range already prefetched into MoonPhaseCache
    @State private var prefetchAnchor: Date? = nil

    /// One day of scrubbing per 60 points of drag.
    private static let pointsPerDay: CGFloat = 60
    /// Haptic tick every quarter day of dragging.
    private static let hapticTickPoints: CGFloat = 15
    private static let moonSize: CGFloat = 240

    // The moon disc only spans ~86% of the source photo, the rest is black
    // margin. Scaling inside the circular clip crops the margin away,
    // matching DayCellView and MoonPhaseWidget.
    private static let discCropScale: CGFloat = 1.18

    private var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = timeZone
        return cal
    }

    private var displayedDate: Date {
        let dragSeconds = TimeInterval(dragOffset / Self.pointsPerDay) * 86400
        return initialDate.addingTimeInterval(accumulatedOffset + dragSeconds)
    }

    /// Clamps a total scrub offset (seconds relative to initialDate) so the
    /// displayed date stays inside the allowed month window.
    private func clampedTotalOffset(_ offset: TimeInterval) -> TimeInterval {
        let minOffset = dateRange.lowerBound.timeIntervalSince(initialDate)
        let maxOffset = dateRange.upperBound.timeIntervalSince(initialDate)
        return min(max(offset, minOffset), maxOffset)
    }

    private var snapshot: MoonSnapshot {
        MoonAstronomy.snapshot(for: displayedDate)
    }

    // Image and phase for the displayed day: prefer the shared cache so the
    // sheet always matches the calendar grid, fall back to the lightweight
    // computation while the cache warms up.
    private var displayedDayInfo: (imageName: String, phase: MoonPhase) {
        if let cached = MoonPhaseCache.shared.dayInfo(for: displayedDate, calendar: calendar) {
            return (cached.imageName, cached.phase)
        }
        let dayStartAge = MoonAstronomy.snapshot(for: calendar.startOfDay(for: displayedDate))
        let imageIndex = Int(dayStartAge.ageDays.rounded()) % 30
        let phase = MoonPhase.ageOfTheMoonDegrees2MoonPhase(snapshot.ageDegrees)
        return (String(format: "moon_age_%02d", imageIndex), phase)
    }

    private var phaseTitle: String {
        MoonPhaseView.phaseName(for: displayedDayInfo.phase) ?? ""
    }

    private var illuminationText: String {
        "\(Int((snapshot.illuminatedFraction * 100).rounded()))%"
    }

    // Road-usage formatting converts to km or miles following the system
    // Measurement System setting (Language & Region), which the older
    // MeasurementFormatter ignores in favour of the region default.
    private static let distanceStyle = Measurement<UnitLength>.FormatStyle(
        width: .abbreviated,
        usage: .road,
        numberFormatStyle: .number.precision(.fractionLength(0))
    )

    private var distanceText: String {
        Measurement(value: snapshot.distanceKilometers, unit: UnitLength.kilometers)
            .formatted(Self.distanceStyle)
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var dateText: String {
        let formatter = Self.dateFormatter
        formatter.timeZone = timeZone
        return formatter.string(from: displayedDate)
    }

    /// Prime locale-heavy formatters while the calendar is on screen, so the
    /// details sheet's first frame doesn't hitch on ICU setup.
    static func warmupFormatters() {
        _ = dateFormatter
        // Formatting once primes the format style's ICU data
        _ = Measurement(value: 384400, unit: UnitLength.kilometers).formatted(distanceStyle)
    }

    // True once the user scrubbed away from the initially opened moment
    private var isScrubbed: Bool {
        accumulatedOffset != 0 || dragOffset != 0
    }

    // MARK: Sub Views

    private var moonImage: some View {
        Image(displayedDayInfo.imageName)
            .resizable()
            .scaledToFill()
            .scaleEffect(Self.discCropScale)
            .frame(width: Self.moonSize, height: Self.moonSize)
            .clipShape(Circle())
            .grayscale(1)
            .id(displayedDayInfo.imageName)
            .transition(.opacity)
    }

    private func infoRow(_ title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)

            Spacer()

            Text(value)
                .font(.body)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .blendMode(.plusLighter)
        }
    }

    private var scrubber: some View {
        // The chevrons are plain images with tap gestures, not Buttons: a drag
        // that starts on a Button gets captured by it and never reaches the
        // pill's drag gesture, while a tap gesture fails as soon as the finger
        // moves and lets the drag through.
        let canStepBackward = stepTarget(byDays: -1) != nil
        let canStepForward = stepTarget(byDays: 1) != nil

        return HStack {
            Image(systemName: "chevron.left")
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .opacity(canStepBackward ? 1 : 0.3)
                .animation(.spring(), value: canStepBackward)
                .frame(width: 32, height: 44)
                .contentShape(Rectangle())
                .onTapGesture {
                    step(byDays: -1)
                }

            Spacer(minLength: 0)

            ScrollTimeDotsIndicator()

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .opacity(canStepForward ? 1 : 0.3)
                .animation(.spring(), value: canStepForward)
                .frame(width: 32, height: 44)
                .contentShape(Rectangle())
                .onTapGesture {
                    step(byDays: 1)
                }
        }
        .padding(.horizontal, 12)
        .font(.subheadline)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        // Same border treatment as the info card above: hairline white
        // stroke lifted with plusLighter. Applied before glassEffect so the
        // border lives inside the glass container and follows the interactive
        // glass as it deforms, instead of separating from it.
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
        }
        .contentShape(Capsule(style: .continuous))
        .glassEffect(.regular.interactive())
        .gesture(scrubGesture)
    }

    private var scrubGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // Grabbing the scrubber stops any ongoing inertia, like ScrollTimeView
                stopInertia()
                // Clamp the live translation so the displayed date can't
                // leave the allowed month window: dragging past the edge
                // goes dead and the haptic ticks stop with it.
                let proposedSeconds = accumulatedOffset
                    + TimeInterval(value.translation.width / Self.pointsPerDay) * 86400
                let clampedSeconds = clampedTotalOffset(proposedSeconds)
                dragOffset = CGFloat((clampedSeconds - accumulatedOffset) / 86400) * Self.pointsPerDay
                checkAndPlayHapticTick()
            }
            .onEnded { value in
                // Fold the drag into the committed offset without animation:
                // the sum stays constant so nothing on screen jumps.
                accumulatedOffset = clampedTotalOffset(
                    accumulatedOffset + TimeInterval(dragOffset / Self.pointsPerDay) * 86400
                )
                dragOffset = 0
                lastHapticOffset = 0

                if hapticEnabled {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }

                startInertiaScroll(velocity: value.velocity.width)
            }
    }

    // MARK: Inertia Scroll

    private func stopInertia() {
        inertiaActive = false
        inertiaVelocity = 0
        frameDriver.stop()
    }

    // Start inertia scroll animation (same thresholds as ScrollTimeView)
    private func startInertiaScroll(velocity: CGFloat) {
        guard abs(velocity) > 200 else { return }

        // Cap the initial velocity to prevent extreme scrolling
        let maxVelocity: CGFloat = 1000
        inertiaVelocity = min(max(velocity, -maxVelocity), maxVelocity)

        lastInertiaHapticOffset = accumulatedOffset
        inertiaActive = true
        frameDriver.start()
    }

    // Per-frame integration of the inertia velocity, expressed in real time so
    // the 0.96-per-frame-at-60fps feel is identical on 60 Hz and 120 Hz displays.
    private func advanceInertia(dt: CFTimeInterval) {
        guard inertiaActive else {
            frameDriver.stop()
            return
        }

        let decelerationPerSecond = pow(0.96, 60.0)
        inertiaVelocity *= CGFloat(pow(decelerationPerSecond, Double(dt)))

        // Stop when velocity is negligible
        if abs(inertiaVelocity) < 5 {
            stopInertia()
            return
        }

        let deltaPoints = inertiaVelocity * CGFloat(dt)
        let proposedOffset = accumulatedOffset + TimeInterval(deltaPoints / Self.pointsPerDay) * 86400
        let clampedOffset = clampedTotalOffset(proposedOffset)
        accumulatedOffset = clampedOffset

        // Coasting into the edge of the month window stops the fling there
        if clampedOffset != proposedOffset {
            if hapticEnabled {
                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            }
            stopInertia()
            return
        }

        checkAndPlayInertiaHapticTick()
    }

    // Lighter haptic while coasting, one tick per quarter day of time change
    // (the same spacing as the drag ticks at this view's scrub scale).
    private func checkAndPlayInertiaHapticTick() {
        guard hapticEnabled else { return }
        let tickInterval: TimeInterval = 21600

        let currentTicks = Int(accumulatedOffset / tickInterval)
        let lastTicks = Int(lastInertiaHapticOffset / tickInterval)

        if currentTicks != lastTicks {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.4)
            lastInertiaHapticOffset = accumulatedOffset
        }
    }

    /// Reset button floating above the scrubber, styled like
    /// ScrollTimeView's reset control.
    private var resetButton: some View {
        Button {
            resetScrub()
        } label: {
            Image(systemName: "arrow.counterclockwise")
                .font(.subheadline.weight(.semibold))
                .frame(width: 20, height: 20)
                .foregroundStyle(.black)
                .padding(.vertical, 5)
                .padding(.horizontal, 15)
                .contentShape(Capsule(style: .continuous))
                .glassEffect(.regular.tint(.white).interactive())
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    // Where a one-day step would land; nil when it would leave the month window
    private func stepTarget(byDays days: Int) -> Date? {
        let target = calendar.date(byAdding: .day, value: days, to: displayedDate)
            ?? displayedDate.addingTimeInterval(TimeInterval(days) * 86400)
        return dateRange.contains(target) ? target : nil
    }

    private func step(byDays days: Int) {
        stopInertia()
        // Step through the calendar so DST shifts never skip a day
        guard let target = stepTarget(byDays: days) else { return }
        if hapticEnabled {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        withAnimation(.spring()) {
            accumulatedOffset = target.timeIntervalSince(initialDate)
        }
    }

    // Return to the initially opened moment, like ScrollTimeView's reset
    private func resetScrub() {
        stopInertia()

        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
            impactFeedback.prepare()
            impactFeedback.impactOccurred()
        }

        withAnimation(.spring()) {
            accumulatedOffset = 0
            dragOffset = 0
            lastHapticOffset = 0
            lastInertiaHapticOffset = 0
        }
    }

    private func checkAndPlayHapticTick() {
        guard hapticEnabled else { return }
        let currentTicks = Int(dragOffset / Self.hapticTickPoints)
        let lastTicks = Int(lastHapticOffset / Self.hapticTickPoints)
        if currentTicks != lastTicks {
            UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
            lastHapticOffset = dragOffset
        }
    }

    // Keep MoonPhaseCache warm around the displayed day so the image and
    // phase name stay consistent with the calendar grid while scrubbing.
    // The age math is cheap enough to run inline, which also means the cache
    // is warm before this sheet's first frame instead of a version bump
    // re-rendering it mid-presentation.
    private func prefetchIfNeeded(force: Bool = false) {
        let displayed = displayedDate
        if !force,
           let anchor = prefetchAnchor,
           abs(displayed.timeIntervalSince(anchor)) < 5 * 86400 {
            return
        }
        prefetchAnchor = displayed

        let cal = calendar
        let dayStart = cal.startOfDay(for: displayed)
        let dates = (-12...12).compactMap { cal.date(byAdding: .day, value: $0, to: dayStart) }
        MoonPhaseCache.shared.prefetch(dates: dates, calendar: cal)
    }

    // MARK: Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer(minLength: 0)

                moonImage
                    .animation(.spring(duration: 0.35), value: displayedDayInfo.imageName)
                    .shadow(color: .white.opacity(0.10), radius: 50)
                    // Last so opacity/shadow don't flatten it into an isolated layer.
                    .blendMode(.plusLighter)

                Spacer(minLength: 0)

                // Bordered card around the moon data, same corner treatment
                // as the cards in DetailsSheet (20pt continuous)
                VStack(spacing: 0) {
                    infoRow("Illumination", value: illuminationText)

                    Divider()
                        .overlay(.white.opacity(0.10))
                        .blendMode(.plusLighter)
                        .padding(.vertical, 16)

                    infoRow("Distance", value: distanceText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                        .blendMode(.plusLighter)
                }

                VStack(spacing: 16) {
                    scrubber
                        .overlay(alignment: .top) {
                            // Kept permanently in the hierarchy with property-driven
                            // visibility: inserting it with `if` mid-drag (the first
                            // scrub flips isScrubbed) restructures the pill that owns
                            // the drag gesture and resets it, freezing that drag.
                            resetButton
                                .opacity(isScrubbed ? 1 : 0)
                                .blur(radius: isScrubbed ? 0 : 8)
                                .scaleEffect(isScrubbed ? 1 : 0.8)
                                .offset(y: isScrubbed ? -42 : -34)
                                .allowsHitTesting(isScrubbed)
                                .animation(.spring(), value: isScrubbed)
                        }

                    Text(dateText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .blendMode(.plusLighter)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
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

                ToolbarItem(placement: .principal) {
                    Text(phaseTitle)
                        .font(.headline)
                        .contentTransition(.numericText())
                        .animation(.spring(), value: phaseTitle)
                }
            }
            .presentationDetents([.height(600)])
            // Custom background replaces the default Liquid Glass, avoiding
            // its compositing artifacts during interactive dismissal: solid
            // black on top fading to fully transparent at the bottom.
            .presentationBackground {
                LinearGradient(
                    colors: [.black, .black.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .onReceive(frameDriver.publisher) { dt in
            advanceInertia(dt: dt)
        }
        .onAppear {
            prefetchIfNeeded(force: true)
        }
        .onDisappear {
            stopInertia()
        }
        .onChange(of: displayedDate) { _, _ in
            prefetchIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                stopInertia()
                return
            }
            // iOS may purge the NSCache-backed moon data while backgrounded;
            // re-prefetch so the image doesn't fall back mid-scrub.
            prefetchIfNeeded(force: true)
        }
    }
}
