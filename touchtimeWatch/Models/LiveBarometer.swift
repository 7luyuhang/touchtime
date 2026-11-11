//
//  LiveBarometer.swift
//  touchtimeWatch
//

import CoreLocation
import CoreMotion
import Observation

/// The air pressure where the watch is, how high it is and where, for
/// Pressure's barometer. It only updates between `start()` and `stop()`, and
/// asks for motion and location access the first time it starts.
@Observable
final class LiveBarometer: NSObject, CLLocationManagerDelegate {
    /// At the watch's elevation, rather than at sea level as forecasts give
    /// it. Nil before the first reading.
    private(set) var pressure: Measurement<UnitPressure>?
    /// Above sea level. Nil before the first reading, which can come a while
    /// after the pressure's, and on a watch that can't tell.
    private(set) var elevation: Measurement<UnitLength>?
    /// Near enough to read to the minute of arc. Nil before the first fix,
    /// and without location access.
    private(set) var coordinate: CLLocationCoordinate2D?
    /// Whether no pressure is coming: on a watch without a barometer, or
    /// without motion access.
    private(set) var isUnavailable = false

    /// The pressure brought down to sea level through the standard
    /// atmosphere, as forecasts give it, so the two compare. Nil until both
    /// the pressure and the elevation are known.
    var seaLevelPressure: Measurement<UnitPressure>? {
        guard let pressure, let elevation else { return nil }
        return pressure / pow(1 - 2.25577e-5 * elevation.converted(to: .meters).value, 5.25588)
    }

    @ObservationIgnored private let altimeter = CMAltimeter()
    @ObservationIgnored private let locationManager = CLLocationManager()
    @ObservationIgnored private var isRunning = false
    /// Each start of the altimeter's updates is to be balanced by a stop.
    @ObservationIgnored private var isAltimeterRunning = false

    override init() {
        super.init()
        locationManager.delegate = self
        // A minute of arc is under 2 km.
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 100
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        locationManager.startUpdatingLocation()

        let status = CMAltimeter.authorizationStatus()
        // Checked on every start, as motion access can be granted in
        // Settings since.
        isUnavailable = !CMAltimeter.isRelativeAltitudeAvailable() || status == .denied || status == .restricted
        guard !isUnavailable else { return }
        isAltimeterRunning = true
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            if let data {
                self?.pressure = Measurement(value: data.pressure.doubleValue, unit: .kilopascals)
            } else if error != nil {
                // Such as motion access refused when first asked.
                self?.isUnavailable = true
            }
        }
        if CMAltimeter.isAbsoluteAltitudeAvailable() {
            altimeter.startAbsoluteAltitudeUpdates(to: .main) { [weak self] data, _ in
                if let data {
                    self?.elevation = Measurement(value: data.altitude, unit: .meters)
                }
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        locationManager.stopUpdatingLocation()
        // Stopping updates that never started asks for motion access.
        guard isAltimeterRunning else { return }
        isAltimeterRunning = false
        altimeter.stopRelativeAltitudeUpdates()
        altimeter.stopAbsoluteAltitudeUpdates()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Granted after starting, as on the first run.
        if isRunning, manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let latest = locations.last {
            coordinate = latest.coordinate
        }
    }
}
