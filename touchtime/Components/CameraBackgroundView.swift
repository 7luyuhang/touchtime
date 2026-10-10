//
//  CameraBackgroundView.swift
//  touchtime
//
//  Created by Codex on 05/03/2026.
//

import SwiftUI
import Combine
import AVFoundation
import Photos

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

final class CameraSessionController: NSObject, ObservableObject {
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
    @Published private(set) var cameraPosition: AVCaptureDevice.Position = .back

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let videoOutputQueue = DispatchQueue(label: "com.touchtime.camera.videoOutput", qos: .userInteractive)
    private let videoFrameDelegate = VideoFrameDelegate()
    @Published var didCapturePhoto = false
    /// The zoom as the Camera app counts it: 1x on the main camera, 0.5x on
    /// the ultra wide
    @Published var zoomFactor: Double = 1 {
        didSet { applyZoomFactor(zoomFactor) }
    }
    /// How far the current camera zooms out and in, counted the same way
    @Published private(set) var zoomFactorRange: ClosedRange<Double> = 1...CameraSessionController.maximumZoomFactor

    /// Past this the digital zoom is too soft for a background
    nonisolated private static let maximumZoomFactor: Double = 5

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

        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(videoFrameDelegate, queue: videoOutputQueue)

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

                    guard let camera = Self.camera(at: .back),
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
                    if self.session.canAddOutput(self.photoOutput) {
                        self.session.addOutput(self.photoOutput)
                    }

                    if self.session.canAddOutput(self.videoDataOutput) {
                        self.session.addOutput(self.videoDataOutput)
                        if let connection = self.videoDataOutput.connection(with: .video) {
                            if connection.isVideoRotationAngleSupported(90) {
                                connection.videoRotationAngle = 90
                            }
                        }
                    }

                    self.didConfigureSession = true
                    didConfigure = true
                }

                let available = cameraAvailable && didConfigure
                let zoomFactorRange = self.videoDevice.map(Self.zoomFactorRange(of:))
                DispatchQueue.main.async {
                    self.isCameraAvailable = available
                    if let zoomFactorRange {
                        self.zoomFactorRange = zoomFactorRange
                        // A camera with an ultra wide starts out on it, below 1x
                        self.applyZoomFactor(self.zoomFactor)
                    }
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

    func flipCamera() {
        sessionQueue.async {
            guard self.didConfigureSession else { return }

            let newPosition: AVCaptureDevice.Position = self.cameraPosition == .back ? .front : .back
            guard let newCamera = Self.camera(at: newPosition),
                  let newInput = try? AVCaptureDeviceInput(device: newCamera) else { return }

            self.session.beginConfiguration()

            let currentVideoInputs = self.session.inputs
                .compactMap { $0 as? AVCaptureDeviceInput }
                .filter { $0.device.hasMediaType(.video) }
            currentVideoInputs.forEach { self.session.removeInput($0) }

            var appliedCamera = newCamera
            var appliedPosition = newPosition
            if self.session.canAddInput(newInput) {
                self.session.addInput(newInput)
            } else if let previousInput = currentVideoInputs.first, self.session.canAddInput(previousInput) {
                // Restore the previous camera if the new one can't be added.
                self.session.addInput(previousInput)
                appliedCamera = previousInput.device
                appliedPosition = previousInput.device.position
            }

            if let connection = self.videoDataOutput.connection(with: .video) {
                if connection.isVideoRotationAngleSupported(90) {
                    connection.videoRotationAngle = 90
                }
                // Mirror captured frames from the front camera to match the preview.
                if connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = appliedPosition == .front
                }
            }

            self.session.commitConfiguration()

            // The other camera starts back at 1x
            Self.setZoomFactor(1, on: appliedCamera)
            let zoomFactorRange = Self.zoomFactorRange(of: appliedCamera)

            DispatchQueue.main.async {
                self.cameraPosition = appliedPosition
                self.zoomFactorRange = zoomFactorRange
                self.zoomFactor = 1
            }
        }
    }

    /// The camera at `position` with the most lenses, so the back one zooms
    /// out to its ultra wide where it has one
    nonisolated private static func camera(at position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        let deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInTripleCamera, .builtInDualWideCamera, .builtInWideAngleCamera]
        return deviceTypes.lazy
            .compactMap { AVCaptureDevice.default($0, for: .video, position: position) }
            .first
    }

    /// The camera the session is using; on the session queue
    private var videoDevice: AVCaptureDevice? {
        session.inputs
            .compactMap { $0 as? AVCaptureDeviceInput }
            .first { $0.device.hasMediaType(.video) }?
            .device
    }

    private func applyZoomFactor(_ zoomFactor: Double) {
        sessionQueue.async {
            guard let device = self.videoDevice else { return }
            Self.setZoomFactor(zoomFactor, on: device)
        }
    }

    /// On the session queue
    nonisolated private static func setZoomFactor(_ zoomFactor: Double, on device: AVCaptureDevice) {
        guard (try? device.lockForConfiguration()) != nil else { return }
        // Assigning out of range throws, and during a flip the zoom can still
        // be the other camera's
        let videoZoomFactor = CGFloat(zoomFactor) / device.displayVideoZoomFactorMultiplier
        device.videoZoomFactor = min(max(videoZoomFactor, device.minAvailableVideoZoomFactor), device.maxAvailableVideoZoomFactor)
        device.unlockForConfiguration()
    }

    /// How far `device` zooms out and in as the Camera app counts it, up to
    /// `maximumZoomFactor`
    nonisolated private static func zoomFactorRange(of device: AVCaptureDevice) -> ClosedRange<Double> {
        let multiplier = Double(device.displayVideoZoomFactorMultiplier)
        let widest = Double(device.minAvailableVideoZoomFactor) * multiplier
        let closest = min(Double(device.maxAvailableVideoZoomFactor) * multiplier, maximumZoomFactor)
        return widest...max(widest, closest)
    }

    func capturePhoto() {
        guard session.isRunning else { return }
        let handler = PhotoCaptureHandler { [weak self] in
            DispatchQueue.main.async {
                self?.didCapturePhoto = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.didCapturePhoto = false
                }
            }
        }
        photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: handler)
    }

    func getLatestFrameAsImage() -> UIImage? {
        videoFrameDelegate.getLatestFrameAsImage()
    }
}

// MARK: - Video Frame Delegate

private final class VideoFrameDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let lock = NSLock()
    private var _pixelBuffer: CVPixelBuffer?
    private let ciContext = CIContext()

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lock.lock()
        _pixelBuffer = pixelBuffer
        lock.unlock()
    }

    func getLatestFrameAsImage() -> UIImage? {
        lock.lock()
        let pixelBuffer = _pixelBuffer
        lock.unlock()
        guard let pixelBuffer else { return nil }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        guard let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

// MARK: - Photo Capture Handler

private final class PhotoCaptureHandler: NSObject, AVCapturePhotoCaptureDelegate {
    private let onCapture: @Sendable () -> Void

    init(onCapture: @escaping @Sendable () -> Void) {
        self.onCapture = onCapture
        super.init()
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        onCapture()
    }
}
