//
//  TouchTimeCaptureExtension.swift
//  touchtimeCaptureExtension
//
//  What the Camera Control, the Action button, and the Camera button in
//  Control Center open while the iPhone is locked. Having it is what lets
//  Touch Time be chosen for the Camera Control.
//

import ExtensionKit
import Foundation
import LockedCameraCapture
import SwiftUI

@main
struct TouchTimeCaptureExtension: LockedCameraCaptureExtension {
    var body: some LockedCameraCaptureExtensionScene {
        LockedCameraCaptureUIScene { session in
            LockedCameraView(session: session)
                .environment(\.colorScheme, .dark)
        }
    }
}
