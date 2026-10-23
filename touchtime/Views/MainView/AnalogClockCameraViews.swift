//
//  AnalogClockCameraViews.swift
//  touchtime
//
//  Extracted from AnalogClockFullView.swift for camera UI organization.
//

import SwiftUI
import AVFoundation
import UIKit

struct AnalogClockCameraBackgroundLayer: View {
    let isCameraBackgroundEnabled: Bool
    let staticCameraFrame: UIImage?
    let cameraSession: AVCaptureSession
    let cameraSaturation: Double
    let cameraContrast: Double
    let isBlurFilterEnabled: Bool
    let showSkyDot: Bool
    let skyGradient: SkyColorGradient
    let selectedTimeZoneIdentifier: String
    let timeOffset: TimeInterval

    private var starsMotion: StarsView.Motion {
        StarsView.Motion(timeOffset: timeOffset, timeZoneIdentifier: selectedTimeZoneIdentifier)
    }

    var body: some View {
        ZStack {
            // Stays mounted while off, and under the captured frame, so the
            // session starts with its preview attached instead of
            // reconfiguring for it once running
            CameraBackgroundView(session: cameraSession)
                .overlay {
                    if let staticFrame = staticCameraFrame {
                        Image(uiImage: staticFrame)
                            .resizable()
                            .scaledToFill()
                    }
                }
                .clipped()
                .saturation(cameraSaturation)
                .contrast(cameraContrast)
                .ignoresSafeArea()
                .opacity(isCameraBackgroundEnabled ? 1 : 0)

            if !isCameraBackgroundEnabled {
                if showSkyDot {
                    ZStack {
                        skyGradient.linearGradient()
                            .ignoresSafeArea()
                            .opacity(0.65)
                            .animation(.spring(), value: selectedTimeZoneIdentifier)

                        // Stars overlay for nighttime. Kept in place while hidden so
                        // the stars keep turning as they fade in and out.
                        StarsView(starCount: 150, motion: starsMotion)
                            .ignoresSafeArea()
                            .animation(.spring()) { $0.opacity(skyGradient.starOpacity) }
                            .blendMode(.plusLighter)
                            .allowsHitTesting(false)
                    }
                } else {
                    Color(UIColor.systemBackground)
                        .ignoresSafeArea()
                }
            }
        }
        .overlay {
            if isCameraBackgroundEnabled && isBlurFilterEnabled {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(), value: showSkyDot)
        .animation(.spring(), value: isCameraBackgroundEnabled)
    }
}

struct AnalogClockCameraCaptureButton: View {
    let isVisible: Bool
    /// The Camera Control or a volume button is held down
    let isHardwareButtonPressed: Bool
    let action: () -> Void

    var body: some View {
        Group {
            if isVisible {
                Button(action: action) {
                    ZStack {
                        Circle()
                            .strokeBorder(.white, lineWidth: 2.5)
                        Circle()
                            .fill(.white)
                            .padding(5)
                    }
                    .frame(width: 52, height: 52)
                    .scaleEffect(isHardwareButtonPressed ? 0.9 : 1)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isHardwareButtonPressed)
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .padding(.trailing, 20)
                .padding(.bottom, 12)
                .offset(y: -73) // bottom padding
                .transition(.blurReplace().combined(with: .opacity).combined(with: .scale(0.95)))
            }
        }
    }
}

struct AnalogClockCameraCloseButton: View {
    let isVisible: Bool
    let action: () -> Void

    var body: some View {
        Group {
            if isVisible {
                Button(action: action) {
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
                .offset(y: -73)
                .transition(.blurReplace().combined(with: .opacity).combined(with: .scale(0.95)))
            }
        }
    }
}

/// Zooms the camera, between the close and capture buttons, along a ruler of
/// Slide to Adjust's ticks: from the camera's widest zoom on the left to its
/// closest on the right, with a taller tick at each of the Camera app's stops
/// and a dot under the one for 1x.
/// The ruler follows the finger, and the zoom is wherever its middle reads.
struct AnalogClockCameraZoomSlider: View {
    let isVisible: Bool
    /// Lines the bottom of the ruler, under the 1x dot, up with the buttons'
    /// bottoms, rather than its ticks with their middles
    let alignsWithButtonBottoms: Bool
    @Binding var zoomFactor: Double
    /// The camera's widest and closest zooms
    let zoomFactorRange: ClosedRange<Double>

    @AppStorage("hapticEnabled") private var hapticEnabled = true
    /// The drag's translation so far, nil between drags
    @State private var lastDragTranslation: CGFloat?
    /// Where the drag has the ruler, in points along it, nil between drags
    @State private var dragPosition: CGFloat?

    /// The Camera app's zoom stops
    private static let zoomStops: [Double] = [0.5, 1, 2, 3, 5]
    private static let tickSpacing = ScrollTimeDotsIndicator.tickSpacing
    /// As many as from one taller tick to the next on Slide to Adjust
    private static let ticksPerStop = ScrollTimeDotsIndicator.majorInterval
    private static let stopSpacing = CGFloat(ticksPerStop) * tickSpacing
    /// The dot under the 1x tick, and its gap from the tick
    private static let oneXDotDiameter: CGFloat = 4
    private static let oneXDotGap: CGFloat = 6

    /// The camera's widest and closest zooms, with the stops between them
    private var stops: [Double] {
        let widest = zoomFactorRange.lowerBound
        let closest = zoomFactorRange.upperBound
        let between = Self.zoomStops.filter { widest < $0 && $0 < closest }
        return [widest] + between + (closest > widest ? [closest] : [])
    }

    private var rulerLength: CGFloat {
        CGFloat(stops.count - 1) * Self.stopSpacing
    }

    var body: some View {
        Group {
            if isVisible {
                ruler
                    .frame(maxWidth: .infinity)
                    .frame(height: 52, alignment: alignsWithButtonBottoms ? .bottom : .center)
                    .contentShape(Rectangle())
                    .gesture(zoomGesture)
                    // Clear of the 52pt buttons 20pt in from the edges
                    .padding(.horizontal, 20 + 52 + 12)
                    .padding(.bottom, 12)
                    .offset(y: -73)
                    .transition(.blurReplace().combined(with: .opacity).combined(with: .scale(0.95)))
            }
        }
        // Also hidden while the time is adjusted, which changes without animation
        .animation(.spring(), value: isVisible)
    }

    private var ruler: some View {
        let tickCount = (stops.count - 1) * Self.ticksPerStop
        let rulerPosition = position(of: zoomFactor)
        // Nil when the camera can't zoom to 1x
        let oneXTickIndex = stops.firstIndex(of: 1).map { $0 * Self.ticksPerStop }

        return Canvas { context, size in
            let midX = size.width / 2
            let tickBottom = (size.height + ScrollTimeDotsIndicator.majorHeight) / 2

            for index in 0...tickCount {
                let x = midX - rulerPosition + CGFloat(index) * Self.tickSpacing
                // Same center-out fade as Slide to Adjust
                let opacity = max(0, 1 - abs(x - midX) / midX)
                guard opacity > 0 else { continue }

                let height = index.isMultiple(of: Self.ticksPerStop)
                    ? ScrollTimeDotsIndicator.majorHeight
                    : ScrollTimeDotsIndicator.minorHeight
                let rect = CGRect(
                    x: x - ScrollTimeDotsIndicator.tickWidth / 2,
                    y: tickBottom - height,
                    width: ScrollTimeDotsIndicator.tickWidth,
                    height: height
                )
                context.fill(
                    Capsule().path(in: rect),
                    with: .color(.primary.opacity(opacity))
                )

                if index == oneXTickIndex {
                    let dotRect = CGRect(
                        x: x - Self.oneXDotDiameter / 2,
                        y: tickBottom + Self.oneXDotGap,
                        width: Self.oneXDotDiameter,
                        height: Self.oneXDotDiameter
                    )
                    context.fill(
                        Circle().path(in: dotRect),
                        with: .color(.primary.opacity(opacity))
                    )
                }
            }
        }
        // Room for the 1x dot under the ticks, and as much over them, so
        // centering the ruler centers the ticks
        .frame(height: ScrollTimeDotsIndicator.majorHeight + 2 * (Self.oneXDotGap + Self.oneXDotDiameter))
    }

    /// Where `factor` is along the ruler, in points from its start
    private func position(of factor: Double) -> CGFloat {
        let stops = self.stops
        guard let segment = stops.indices.dropLast().last(where: { stops[$0] <= factor }) else { return 0 }
        // Each tick between two stops zooms by the same ratio
        let fraction = min(log(factor / stops[segment]) / log(stops[segment + 1] / stops[segment]), 1)
        return (CGFloat(segment) + CGFloat(fraction)) * Self.stopSpacing
    }

    /// The zoom factor `position` points along the ruler
    private func factor(at position: CGFloat) -> Double {
        let stops = self.stops
        guard stops.count > 1 else { return stops[0] }
        let stopsAlong = min(max(Double(position / Self.stopSpacing), 0), Double(stops.count - 1))
        let segment = min(Int(stopsAlong), stops.count - 2)
        return stops[segment] * pow(stops[segment + 1] / stops[segment], stopsAlong - Double(segment))
    }

    private func hapticTick(at position: CGFloat) -> Int {
        Int((position / Self.tickSpacing).rounded(.down))
    }

    private var zoomGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // By the drag's change rather than its total, so turning back
                // from past either end zooms straight away
                let delta = value.translation.width - (lastDragTranslation ?? 0)
                lastDragTranslation = value.translation.width

                let previousPosition = dragPosition ?? position(of: zoomFactor)
                // The ruler follows the finger, so dragging left brings the
                // closer zooms to the middle
                let newPosition = min(max(previousPosition - delta, 0), rulerLength)
                dragPosition = newPosition
                zoomFactor = factor(at: newPosition)
                if hapticEnabled && hapticTick(at: newPosition) != hapticTick(at: previousPosition) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred(intensity: 0.6)
                }
            }
            .onEnded { _ in
                lastDragTranslation = nil
                dragPosition = nil
                if hapticEnabled {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }
            }
    }
}

/// The camera button: it turns the camera background on, then opens its
/// filters. Its button style is up to the caller: plain in the navigation bar,
/// a glass circle outside it.
struct AnalogClockCameraToolbarControls: View {
    let isCameraBackgroundEnabled: Bool
    let isStandardSelected: Bool
    let isBlurSelected: Bool
    let isBlackAndWhiteSelected: Bool
    let onSelectStandard: () -> Void
    let onSelectBlur: () -> Void
    let onSelectBlackAndWhite: () -> Void
    let onFlipCamera: () -> Void
    let onEnableCamera: () -> Void

    @Environment(\.isEnabled) private var isEnabled

    /// Neither button style dims on its own, so fade the symbol when disabled
    private var symbolStyle: HierarchicalShapeStyle {
        isEnabled ? .primary : .tertiary
    }

    var body: some View {
        if isCameraBackgroundEnabled {
            Menu {
                Section("Camera Filter") {
                    Button(action: onSelectStandard) {
                        if isStandardSelected {
                            Label("Standard", systemImage: "checkmark.circle")
                        } else {
                            Text("Standard")
                        }
                    }
                    Button(action: onSelectBlur) {
                        if isBlurSelected {
                            Label("Blur", systemImage: "checkmark.circle")
                        } else {
                            Text("Blur")
                        }
                    }
                    Button(action: onSelectBlackAndWhite) {
                        if isBlackAndWhiteSelected {
                            Label("Black and White", systemImage: "checkmark.circle")
                        } else {
                            Text("Black and White")
                        }
                    }
                }
                Section("Camera Tool") {
                    Button(action: onFlipCamera) {
                        Label("Flip", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
                    }
                }
            } label: {
                Image(systemName: "camera.filters")
                    .foregroundStyle(symbolStyle)
            }
        } else {
            Button(action: onEnableCamera) {
                Image(systemName: "camera.aperture")
                    .foregroundStyle(symbolStyle)
            }
        }
    }
}
