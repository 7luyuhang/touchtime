//
//  LiveCompass.swift
//  touchtimeWatch
//

import CoreLocation
import Observation

/// Which way the watch faces and where it is, for Sun Position's live
/// compass. It only updates between `start()` and `stop()`, and asks for
/// location access the first time it starts.
@Observable
final class LiveCompass: NSObject, CLLocationManagerDelegate {
    /// Degrees clockwise from north that the top of the watch faces: from
    /// true north once the watch knows where it is, magnetic north until
    /// then. Nil before the first reading, and on a watch without a compass.
    private(set) var heading: Double?
    /// Where the watch is, near enough for the sun's position.
    private(set) var location: CLLocation?

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var isRunning = false

    override init() {
        super.init()
        manager.delegate = self
        // The sun's position hardly changes over a few kilometers.
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.distanceFilter = 1000
        manager.headingFilter = 1
    }

    func start() {
        isRunning = true
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        // Kept running after the first fix, as true north needs it.
        manager.startUpdatingLocation()
        if CLLocationManager.headingAvailable() {
            manager.startUpdatingHeading()
        }
    }

    func stop() {
        isRunning = false
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Granted after starting, as on the first run.
        if isRunning, manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let latest = locations.last {
            location = latest
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
    }
}
