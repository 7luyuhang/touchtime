//
//  CameraBackgroundView.swift
//  touchtime
//
//  Created by Codex on 05/03/2026.
//

import SwiftUI
import Combine
import AVFoundation

struct CameraBackgroundView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewContainerView {
        let view = CameraPreviewContainerView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewContainerView, context: Context) {
        if uiView.previewLayer.session !== session {
            uiView.previewLayer.session = session
        }
    }
}

final class CameraPreviewContainerView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}

final class CameraSessionController: ObservableObject {
    enum SessionState: Equatable {
        case idle
        case configuring
        case starting
        case running
        case stopping
    }

    @Published private(set) var authorizationStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    @Published private(set) var isSessionRunning = false
    @Published private(set) var isCameraAvailable = true
    @Published private(set) var sessionState: SessionState = .idle

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.touchtime.camera.session")
    private var didConfigureSession = false

    func requestAccess() async -> Bool {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        DispatchQueue.main.async {
            self.authorizationStatus = currentStatus
        }

        switch currentStatus {
        case .authorized:
            return true
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
            let updatedStatus = AVCaptureDevice.authorizationStatus(for: .video)
            DispatchQueue.main.async {
                self.authorizationStatus = updatedStatus
            }
            return granted
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }

    func configureIfNeeded() async -> Bool {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        await MainActor.run {
            self.authorizationStatus = currentStatus
        }

        guard currentStatus == .authorized else {
            await MainActor.run {
                self.isCameraAvailable = false
                self.sessionState = .idle
            }
            return false
        }

        await MainActor.run {
            if self.sessionState == .idle {
                self.sessionState = .configuring
            }
        }

        return await withCheckedContinuation { continuation in
            sessionQueue.async {
                var cameraAvailable = true
                var didConfigure = false

                if self.didConfigureSession || !self.session.inputs.isEmpty {
                    didConfigure = true
                } else {
                    self.session.beginConfiguration()
                    self.session.sessionPreset = .high
                    defer { self.session.commitConfiguration() }

                    guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                          let input = try? AVCaptureDeviceInput(device: camera),
                          self.session.canAddInput(input) else {
                        cameraAvailable = false
                        DispatchQueue.main.async {
                            self.isCameraAvailable = false
                            continuation.resume(returning: false)
                        }
                        return
                    }

                    self.session.addInput(input)
                    self.didConfigureSession = true
                    didConfigure = true
                }

                let available = cameraAvailable && didConfigure
                DispatchQueue.main.async {
                    self.isCameraAvailable = available
                    if self.session.isRunning {
                        self.sessionState = .running
                    } else {
                        self.sessionState = .idle
                    }
                    continuation.resume(returning: available)
                }
            }
        }
    }

    func startRunning() async -> Bool {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                if self.session.isRunning {
                    DispatchQueue.main.async {
                        self.isSessionRunning = true
                        self.sessionState = .running
                        continuation.resume(returning: true)
                    }
                    return
                }

                guard !self.session.inputs.isEmpty else {
                    DispatchQueue.main.async {
                        self.isCameraAvailable = false
                        self.isSessionRunning = false
                        self.sessionState = .idle
                        continuation.resume(returning: false)
                    }
                    return
                }

                DispatchQueue.main.async {
                    self.sessionState = .starting
                }

                if !self.session.isRunning {
                    self.session.startRunning()
                }

                let running = self.session.isRunning
                DispatchQueue.main.async {
                    self.isSessionRunning = running
                    self.sessionState = running ? .running : .idle
                    continuation.resume(returning: running)
                }
            }
        }
    }

    func stopRunning() {
        sessionQueue.async {
            if !self.session.isRunning {
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                    self.sessionState = .idle
                }
                return
            }

            DispatchQueue.main.async {
                self.sessionState = .stopping
            }

            if self.session.isRunning {
                self.session.stopRunning()
            }

            DispatchQueue.main.async {
                self.isSessionRunning = false
                self.sessionState = .idle
            }
        }
    }
}
