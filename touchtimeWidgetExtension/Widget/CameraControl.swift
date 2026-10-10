//
//  CameraControl.swift
//  touchtimeWidgetExtension
//
//  Opens Touch Time's camera from Control Center, the Lock Screen, or the
//  Action button. Together with the capture extension, it also lets Touch
//  Time be chosen for the Camera Control.
//

import AppIntents
import SwiftUI
import WidgetKit

struct CameraControl: ControlWidget {
    let kind: String = "CameraControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: kind) {
            ControlWidgetButton(action: OpenCameraIntent()) {
                Label("Camera", systemImage: "camera.aperture")
            }
        }
        .displayName("Camera")
        .description("Opens the camera in Touch Time.")
    }
}
