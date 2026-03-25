//
//  ShakeToRestoreDeletedCity.swift
//  touchtime
//
//  Created on 25/03/2026.
//

import SwiftUI
import UIKit

struct DeletedCityRecord {
    struct CollectionPlacement {
        let collectionId: UUID
        let cityIndex: Int
    }

    let clock: WorldClock
    let worldClockIndex: Int
    let collectionPlacements: [CollectionPlacement]
}

struct ShakeToRestoreDeletedCityModifier: ViewModifier {
    @Binding var lastDeletedCityRecord: DeletedCityRecord?
    let onRestore: () -> Void

    func body(content: Content) -> some View {
        content.background(
            ShakeDetectorView {
                guard lastDeletedCityRecord != nil else { return }
                onRestore()
            }
            .allowsHitTesting(false)
        )
    }
}

extension View {
    func shakeToRestoreDeletedCity(
        lastDeletedCityRecord: Binding<DeletedCityRecord?>,
        onRestore: @escaping () -> Void
    ) -> some View {
        modifier(
            ShakeToRestoreDeletedCityModifier(
                lastDeletedCityRecord: lastDeletedCityRecord,
                onRestore: onRestore
            )
        )
    }
}

private struct ShakeDetectorView: UIViewControllerRepresentable {
    let onShake: () -> Void

    func makeUIViewController(context: Context) -> ShakeDetectorController {
        let controller = ShakeDetectorController()
        controller.onShake = onShake
        return controller
    }

    func updateUIViewController(_ uiViewController: ShakeDetectorController, context: Context) {
        uiViewController.onShake = onShake
        DispatchQueue.main.async {
            _ = uiViewController.becomeFirstResponder()
        }
    }

    final class ShakeDetectorController: UIViewController {
        var onShake: (() -> Void)?

        override var canBecomeFirstResponder: Bool { true }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            becomeFirstResponder()
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            resignFirstResponder()
        }

        override func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {
            guard motion == .motionShake else { return }
            onShake?()
        }
    }
}
