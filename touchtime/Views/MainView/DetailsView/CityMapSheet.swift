//
//  CityMapSheet.swift
//  touchtime
//
//  Created on 17/10/2026.
//

import SwiftUI
import MapKit
import UIKit

/// The city pinned on a map. Zooms out of the location button.
struct CityMapSheet: View {
    let cityName: String
    let coordinate: CLLocationCoordinate2D

    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    /// Wide enough to take in a whole city around the pin
    private static let initialSpan: CLLocationDistance = 40_000

    private var initialRegion: MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: Self.initialSpan,
            longitudinalMeters: Self.initialSpan
        )
    }

    var body: some View {
        NavigationStack {
            Map(initialPosition: .region(initialRegion)) {
                Marker(cityName, coordinate: coordinate)
            }
            .mapStyle(.standard(elevation: .realistic))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        triggerHaptic()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text(cityName)
                        .font(.headline)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        triggerHaptic()
                        openInMaps()
                    } label: {
                        Image(systemName: "map")
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func openInMaps() {
        let mapItem = MKMapItem(
            location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
            address: nil
        )
        mapItem.name = cityName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsMapSpanKey: NSValue(mkCoordinateSpan: initialRegion.span)
        ])
    }

    private func triggerHaptic() {
        guard hapticEnabled else { return }
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.prepare()
        impactFeedback.impactOccurred()
    }
}
