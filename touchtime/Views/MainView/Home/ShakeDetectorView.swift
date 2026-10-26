//
//  ShakeDetectorView.swift
//  touchtime
//

import SwiftUI
import UIKit

struct ShakeDetectorView: UIViewControllerRepresentable {
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeDetectorViewController {
        let viewController = ShakeDetectorViewController()
        viewController.onShake = onShake
        return viewController
    }

    func updateUIViewController(_ uiViewController: ShakeDetectorViewController, context: Context) {
        uiViewController.onShake = onShake
    }
}

final class ShakeDetectorViewController: UIViewController {
    var onShake: (() -> Void)?

    override var canBecomeFirstResponder: Bool { true }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        resignFirstResponder()
    }

    override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
        guard motion == .motionShake else {
            super.motionEnded(motion, with: event)
            return
        }
        onShake?()
    }
}
