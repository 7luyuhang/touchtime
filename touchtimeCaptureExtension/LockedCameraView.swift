//
//  LockedCameraView.swift
//  touchtimeCaptureExtension
//
//  The Clock tab's camera on the Lock Screen: just the live camera, and a
//  button that asks to unlock and carries on in the app's camera.
//

import AVFoundation
import AVKit
import LockedCameraCapture
import SwiftUI

struct LockedCameraView: View {
    let session: LockedCameraCaptureSession

    @StateObject private var cameraSessionController = CameraSessionController()

    var body: some View {
        unlockButton
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background { cameraBackground }
            // The Camera Control (and the volume buttons) carry on in the
            // app's camera too, where they take the picture
            .onCameraCaptureEvent(isEnabled: cameraSessionController.isSessionRunning) { event in
                guard event.phase == .ended else { return }
                continueInApp()
            }
            .task {
                await startCamera()
            }
            .onDisappear {
                cameraSessionController.stopRunning()
            }
    }

    private var cameraBackground: some View {
        CameraBackgroundView(controller: cameraSessionController)
            .ignoresSafeArea()
            .background(.black)
    }

    private var unlockButton: some View {
        Button(action: continueInApp) {
            Text("Unlock to Continue")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.vertical, 15)
                .padding(.horizontal, 20)
                .background(Color.black.opacity(0.25), in: Capsule(style: .continuous))
                .glassEffect(.clear.interactive(), in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func startCamera() async {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            continueInApp()
            return
        }
        guard await cameraSessionController.configureIfNeeded() else { return }
        _ = await cameraSessionController.startRunning()
    }

    /// Asks to unlock, then carries on in the app's camera, which is also
    /// the only place camera access can be asked for
    private func continueInApp() {
        Task {
            try? await session.openApplication(
                for: NSUserActivity(activityType: NSUserActivityTypeLockedCameraCapture)
            )
        }
    }
}
