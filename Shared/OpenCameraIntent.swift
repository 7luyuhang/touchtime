//
//  OpenCameraIntent.swift
//  touchtime
//
//  Opens the Clock tab's camera from the Camera Control, the Action button,
//  or the Camera button in Control Center and on the Lock Screen. While the
//  iPhone is locked the system opens the capture extension instead. Compiled
//  into the app, the widget extension (the button) and the capture
//  extension, as the system requires.
//

import AppIntents

/// The app's settings the Lock Screen camera shows the time with: the
/// capture extension can't read the app's defaults.
nonisolated struct CameraCaptureContext: Codable, Sendable {
    var use24HourFormat = false
    var dateStyle = "Relative"
    var hapticEnabled = true
}

/// The system runs the intent in the app's process when it opens the app,
/// so the app sets `openCamera` when it launches.
@MainActor
enum CameraCaptureRouter {
    static var openCamera: (@MainActor () -> Void)?
}

struct OpenCameraIntent: CameraCaptureIntent {
    typealias AppContext = CameraCaptureContext

    static let title: LocalizedStringResource = "Open Camera"
    static let description = IntentDescription("Opens the camera in Touch Time.")

    @MainActor
    func perform() async throws -> some IntentResult {
        CameraCaptureRouter.openCamera?()
        return .result()
    }
}
