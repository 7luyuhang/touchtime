//
//  TimerClockComponents.swift
//  touchtime
//
//  Extracted from AnalogClockFullView.swift for file organization.
//

import SwiftUI
import UIKit
import CoreHaptics

// MARK: - Timer Clock Face
struct TimerClockFaceView: View {
    let size: CGFloat
    let remainingSeconds: Int
    let configuredSeconds: Int
    let resetAnimationTrigger: Int
    let resetAnimationFromSeconds: Int
    let isAdjustable: Bool
    let hapticEnabled: Bool
    let onAdjustSeconds: (Int) -> Bool
    let onAdjustingChanged: (Bool) -> Void

    @State private var resetAnimationHandAngle: Double
    @State private var isResetAnimating = false
    @State private var resetAnimationTask: Task<Void, Never>? = nil
    @State private var lastDragAngle: Double? = nil
    @State private var accumulatedDragDegrees: Double = 0
    @State private var hapticEngine: CHHapticEngine?
    @State private var hapticPlayer: CHHapticPatternPlayer?

    private let resetAnimationDuration: TimeInterval = 0.25
    private let degreesPerMinute: Double = 6.0

    init(
        size: CGFloat,
        remainingSeconds: Int,
        configuredSeconds: Int,
        resetAnimationTrigger: Int = 0,
        resetAnimationFromSeconds: Int = 0,
        isAdjustable: Bool = false,
        hapticEnabled: Bool = true,
        onAdjustSeconds: @escaping (Int) -> Bool = { _ in false },
        onAdjustingChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.size = size
        self.remainingSeconds = remainingSeconds
        self.configuredSeconds = configuredSeconds
        self.resetAnimationTrigger = resetAnimationTrigger
        self.resetAnimationFromSeconds = resetAnimationFromSeconds
        self.isAdjustable = isAdjustable
        self.hapticEnabled = hapticEnabled
        self.onAdjustSeconds = onAdjustSeconds
        self.onAdjustingChanged = onAdjustingChanged
        _resetAnimationHandAngle = State(initialValue: Self.angle(for: remainingSeconds))
    }

    private func angleDegrees(at location: CGPoint) -> Double {
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

    private func playAdjustHaptic(intensity: Float = 0.50) {
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

    private static func angle(for seconds: Int) -> Double {
        let clampedSeconds = max(0, min(seconds, 59 * 60 + 59))
        let minute = clampedSeconds / 60
        let second = clampedSeconds % 60
        return Double(minute) * 6.0 + Double(second) * 0.1
    }

    private static func normalizedAngle(_ angle: Double) -> Double {
        let normalized = angle.truncatingRemainder(dividingBy: 360)
        return normalized >= 0 ? normalized : normalized + 360
    }

    private var clampedRemainingSeconds: Int {
        max(0, min(remainingSeconds, 59 * 60 + 59))
    }

    private var clampedConfiguredSeconds: Int {
        max(0, min(configuredSeconds, 59 * 60 + 59))
    }

    private var remainingAngle: Double {
        Self.angle(for: clampedRemainingSeconds)
    }

    private var numberRingRadius: CGFloat {
        size / 2 - 36
    }

    private var configuredAngle: Double {
        let minute = clampedConfiguredSeconds / 60
        let second = clampedConfiguredSeconds % 60
        return Double(minute) * 6.0 + Double(second) * 0.1
    }

    private var displayedHandAngle: Double {
        isResetAnimating ? resetAnimationHandAngle : remainingAngle
    }

    private func animateTimerResetHand() {
        guard clampedConfiguredSeconds > 0 else { return }

        let fromAngle = Self.angle(for: resetAnimationFromSeconds)
        let targetAngle = configuredAngle

        guard abs(fromAngle - targetAngle) > 0.0001 else {
            resetAnimationTask?.cancel()
            resetAnimationHandAngle = targetAngle
            isResetAnimating = false
            return
        }

        resetAnimationTask?.cancel()

        var animatedTargetAngle = targetAngle
        if animatedTargetAngle <= fromAngle {
            animatedTargetAngle += 360
        }

        isResetAnimating = true
        resetAnimationHandAngle = fromAngle

        withAnimation(.easeInOut(duration: resetAnimationDuration)) {
            resetAnimationHandAngle = animatedTargetAngle
        }

        let animationDurationInNanoseconds = UInt64(resetAnimationDuration * 1_000_000_000)
        resetAnimationTask = Task {
            try? await Task.sleep(nanoseconds: animationDurationInNanoseconds)
            guard !Task.isCancelled else { return }

            await MainActor.run {
                resetAnimationHandAngle = Self.normalizedAngle(targetAngle)
                isResetAnimating = false
                resetAnimationTask = nil
            }
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.25))
                .glassEffect(.clear.interactive())
                .frame(width: max(size - 24, 0), height: max(size - 24, 0))
                .contentShape(Circle())
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            guard isAdjustable else { return }
                            let angle = angleDegrees(at: value.location)
                            if let lastAngle = lastDragAngle {
                                let delta = normalizedAngleDelta(angle - lastAngle)
                                accumulatedDragDegrees += delta
                                let minuteDelta = Int(
                                    (accumulatedDragDegrees / degreesPerMinute).rounded(.towardZero)
                                )
                                if minuteDelta != 0 {
                                    accumulatedDragDegrees -= Double(minuteDelta) * degreesPerMinute
                                    let didAdjust = onAdjustSeconds(minuteDelta * 60)
                                    if didAdjust {
                                        playAdjustHaptic()
                                    }
                                }
                            } else {
                                accumulatedDragDegrees = 0
                                onAdjustingChanged(true)
                            }
                            lastDragAngle = angle
                        }
                        .onEnded { _ in
                            lastDragAngle = nil
                            accumulatedDragDegrees = 0
                            onAdjustingChanged(false)
                        }
                )

            if clampedConfiguredSeconds > 0 {
                TimerRangeFillView(
                    startAngle: 0,
                    endAngle: configuredAngle,
                    size: size
                )

                TimerRangeArcView(
                    startAngle: 0,
                    endAngle: configuredAngle,
                    size: size
                )

                TimerBoundaryLineView(
                    angle: 0,
                    size: size
                )

                TimerBoundaryLineView(
                    angle: configuredAngle,
                    size: size
                )
            }

            ForEach(0..<12, id: \.self) { index in
                let angle = Double(index) * 30.0 - 90
                let x = numberRingRadius * cos(angle * .pi / 180)
                let y = numberRingRadius * sin(angle * .pi / 180)
                let markValue = (index * 5) % 60

                Text("\(markValue)")
                    .font(.headline)
                    .fontDesign(.rounded)
                    .foregroundColor(.white)
                    .position(x: size / 2 + x, y: size / 2 + y)
            }

            TimerMinuteTickMarksView(
                size: size,
                ringRadius: numberRingRadius
            )
                .allowsHitTesting(false)

            TimerAnimatedHandView(
                angle: displayedHandAngle,
                size: size,
                color: .white
            )
            .allowsHitTesting(false)

            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
        }
        .frame(width: size, height: size)
        .onChange(of: resetAnimationTrigger) { _, _ in
            animateTimerResetHand()
        }
        .onChange(of: isAdjustable) { _, newValue in
            if !newValue {
                lastDragAngle = nil
                accumulatedDragDegrees = 0
                onAdjustingChanged(false)
            }
        }
        .onAppear {
            prepareHaptics()
        }
        .onDisappear {
            resetAnimationTask?.cancel()
            resetAnimationTask = nil
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

// MARK: - Timer Range Arc View
struct TimerRangeArcView: View {
    let startAngle: Double
    let endAngle: Double
    let size: CGFloat

    var body: some View {
        let center = CGPoint(x: size / 2, y: size / 2)
        let radius = (size - 24) / 2
        let startRadians = (startAngle - 90) * .pi / 180
        let endRadians = (endAngle - 90) * .pi / 180

        Path { path in
            path.addArc(
                center: center,
                radius: radius,
                startAngle: Angle(radians: startRadians),
                endAngle: Angle(radians: endRadians),
                clockwise: false
            )
        }
        .stroke(Color.white, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        .drawingGroup()
    }
}

// MARK: - Timer Range Fill View
struct TimerRangeFillView: View {
    let startAngle: Double
    let endAngle: Double
    let size: CGFloat

    var body: some View {
        let center = CGPoint(x: size / 2, y: size / 2)
        let radius = (size - 24) / 2
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
                    Color.white.opacity(0.10),
                    Color.white.opacity(0)
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

// MARK: - Timer Boundary Line View
struct TimerBoundaryLineView: View {
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

// MARK: - Timer Minute Tick Marks
struct TimerMinuteTickMarksView: View {
    let size: CGFloat
    let ringRadius: CGFloat

    private let tickLength: CGFloat = 6 // Timer Scale Length
    private let tickWidth: CGFloat = 2

    private var tickRadius: CGFloat {
        max(ringRadius, 0)
    }

    var body: some View {
        ZStack {
            ForEach(0..<60, id: \.self) { index in
                if index % 5 != 0 {
                    RoundedRectangle(cornerRadius: tickWidth / 2, style: .continuous)
                        .fill(.white.opacity(0.25))
                        .frame(width: tickWidth, height: tickLength)
                        .offset(y: -tickRadius)
                        .rotationEffect(.degrees(Double(index) * 6.0))
                        .blendMode(.plusLighter)
                }
            }
        }
    }
}

// MARK: - Timer Animated Hand
struct TimerAnimatedHandView: View {
    let angle: Double
    let size: CGFloat
    let color: Color
    private let tailLength: CGFloat = 24

    init(angle: Double, size: CGFloat, color: Color = .white) {
        self.angle = angle
        self.size = size
        self.color = color
    }

    private var forwardLength: CGFloat {
        max(size / 2 - 20, 0)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(color)
                .frame(width: 2, height: forwardLength + tailLength)
                .offset(y: -(forwardLength - tailLength) / 2)

            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .offset(y: -forwardLength)
        }
        .rotationEffect(.degrees(angle))
    }
}
