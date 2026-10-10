//
//  LockedCameraView.swift
//  touchtimeCaptureExtension
//
//  The Clock tab's camera on the Lock Screen: the live camera behind the
//  local time on Touch Time's 24-hour face. It captures the way the app
//  does, freezing the camera frame under the clock and saving the screen to
//  Photos. Only the local time is shown, as the extension can't read the
//  app's cities.
//

import AppIntents
import AVFoundation
import AVKit
import LockedCameraCapture
import Photos
import SwiftUI
import UIKit

struct LockedCameraView: View {
    let session: LockedCameraCaptureSession

    @StateObject private var cameraSessionController = CameraSessionController()
    /// The app's settings, nil until read so the time never shows in the
    /// wrong format first
    @State private var context: CameraCaptureContext?
    @State private var staticCameraFrame: UIImage?
    @State private var isCaptureButtonHidden = false
    @State private var windowSnapshotter = WindowSnapshotter()

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)

            TimelineView(.everyMinute) { timeline in
                VStack(spacing: 0) {
                    Color.clear
                        .overlay {
                            if let context {
                                digitalTime(at: timeline.date, context: context)
                            }
                        }

                    LockedClockFaceView(date: timeline.date, size: size)

                    Color.clear
                        .overlay { captureButton }
                }
            }
        }
        .background { cameraBackground }
        .background(WindowSnapshotAnchor(snapshotter: windowSnapshotter))
        // The Camera Control (and the volume buttons) take the picture like
        // the capture button
        .onCameraCaptureEvent(isEnabled: cameraSessionController.isSessionRunning) { event in
            guard event.phase == .ended else { return }
            handleCapturePhoto()
        }
        .task {
            context = (try? await OpenCameraIntent.appContext) ?? CameraCaptureContext()
        }
        .task {
            await startCamera()
        }
        .onDisappear {
            cameraSessionController.stopRunning()
        }
    }

    private var cameraBackground: some View {
        Group {
            if let staticCameraFrame {
                Color.clear
                    .overlay {
                        Image(uiImage: staticCameraFrame)
                            .resizable()
                            .scaledToFill()
                    }
                    .clipped()
            } else {
                CameraBackgroundView(session: cameraSessionController.session)
            }
        }
        .ignoresSafeArea()
        .background(.black)
    }

    private func digitalTime(at date: Date, context: CameraCaptureContext) -> some View {
        VStack(spacing: 0) {
            Text(formattedTime(date, use24HourFormat: context.use24HourFormat))
                .font(.system(size: 52))
                .fontWeight(.light)
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(.white)

            Text(date.formattedDate(style: context.dateStyle))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .blendMode(.plusLighter)
        }
    }

    private func formattedTime(_ date: Date, use24HourFormat: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = use24HourFormat ? "HH:mm" : "h:mm"
        return formatter.string(from: date)
    }

    @ViewBuilder
    private var captureButton: some View {
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
            .transition(.blurReplace().combined(with: .opacity).combined(with: .scale(0.95)))
        }
    }

    private func startCamera() async {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            continueInApp()
            return
        }
        guard await cameraSessionController.configureIfNeeded() else { return }
        _ = await cameraSessionController.startRunning()
    }

    /// The app's capture: the camera frame frozen under the clock and the
    /// button hidden while the screen is saved to Photos
    private func handleCapturePhoto() {
        guard !isCaptureButtonHidden else { return }
        triggerCaptureHaptic()

        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
              hasPhotoLibraryAddAccess else {
            continueInApp()
            return
        }
        guard let frame = cameraSessionController.getLatestFrameAsImage() else { return }

        staticCameraFrame = frame
        withAnimation(.spring()) {
            isCaptureButtonHidden = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let screenshot = windowSnapshotter.snapshot() {
                Task {
                    try? await PHPhotoLibrary.shared().performChanges {
                        PHAssetChangeRequest.creationRequestForAsset(from: screenshot)
                    }
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                staticCameraFrame = nil
                withAnimation(.spring()) {
                    isCaptureButtonHidden = false
                }
            }
        }
    }

    private var hasPhotoLibraryAddAccess: Bool {
        switch PHPhotoLibrary.authorizationStatus(for: .addOnly) {
        case .authorized, .limited:
            return true
        case .notDetermined, .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    /// Camera and Photos access can only be asked for in the app, so this
    /// asks to unlock and carries on in the app's camera
    private func continueInApp() {
        Task {
            try? await session.openApplication(
                for: NSUserActivity(activityType: NSUserActivityTypeLockedCameraCapture)
            )
        }
    }

    private func triggerCaptureHaptic() {
        guard context?.hapticEnabled ?? true else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .rigid)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}

// MARK: - Clock Face

/// The Clock tab's 24-hour face with only the local time on it
private struct LockedClockFaceView: View {
    let date: Date
    let size: CGFloat

    /// Clockwise from the top, a turn a day
    private var localHandAngle: Double {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return Double(components.hour ?? 0) * 15 + Double(components.minute ?? 0) * 0.25
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.25))
                .glassEffect(.clear)
                .frame(width: max(size - 24, 0), height: max(size - 24, 0))

            HourNumbersView(size: size, isFolded: false)

            LocalHandView(angle: localHandAngle, size: size)

            Circle()
                .fill(.white)
                .frame(width: 8, height: 8)
        }
        .frame(width: size, height: size)
    }
}

/// The app's selected Local hand: white, ending in a white label that runs
/// along it, turned over on the bottom half to stay readable
private struct LocalHandView: View {
    let angle: Double
    let size: CGFloat

    private let labelLength: CGFloat = 95

    // The label's outer end stays just inside the hour numbers
    private var labelCenterOffset: CGFloat {
        size / 2 - 47.5 - labelLength / 2
    }

    // The hand stops at the label's inner end
    private var handLength: CGFloat {
        max(labelCenterOffset - labelLength / 2 + 2, 0)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white)
                .frame(width: 2.5, height: handLength)
                .offset(y: -handLength / 2)

            HStack(spacing: 4) {
                Image(systemName: "location.fill")
                    .font(.caption2.weight(.semibold))
                Text("Local")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.black)
            .lineLimit(1)
            .truncationMode(.tail)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .frame(maxWidth: labelLength)
            .glassEffect(.regular.tint(.white), in: Capsule(style: .continuous))
            .rotationEffectIgnoringLayout(.degrees(angle > 180 ? 90 : -90))
            .offset(y: -labelCenterOffset)
        }
        .rotationEffectIgnoringLayout(.degrees(angle))
        .frame(width: size, height: size)
    }
}

private extension View {
    func rotationEffectIgnoringLayout(_ angle: Angle) -> some View {
        modifier(_RotationEffect(angle: angle, anchor: .center).ignoredByLayout())
    }
}

// MARK: - Window Snapshot

/// Draws the window the camera is in. The app finds its window through
/// `UIApplication`, which extensions can't use.
private final class WindowSnapshotter {
    weak var anchorView: UIView?

    func snapshot() -> UIImage? {
        guard let window = anchorView?.window else { return nil }
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        return renderer.image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }
}

/// A view in the camera's window for `WindowSnapshotter` to find it by
private struct WindowSnapshotAnchor: UIViewRepresentable {
    let snapshotter: WindowSnapshotter

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        snapshotter.anchorView = view
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
