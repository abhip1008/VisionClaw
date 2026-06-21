// Services/LocationService.swift
// Location monitoring, driving-ETA calculation, and geofence-exit triggers.

import Foundation
import CoreLocation
import MapKit

class LocationService: NSObject, CLLocationManagerDelegate {

  static let shared = LocationService()

  private let locationManager = CLLocationManager()
  private var pendingGeofenceMessage: (contact: String, message: String)?

  /// Fired when the user exits a monitored region. Parameters: (contact, message).
  var onGeofenceExit: ((String, String) -> Void)?

  override init() {
    super.init()
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    locationManager.requestAlwaysAuthorization()
  }

  /// The most recent known location, if available.
  var currentLocation: CLLocation? { locationManager.location }

  func getCurrentLocation() async -> CLLocation? {
    return locationManager.location
  }

  /// Calculates driving ETA from the current location to a destination string.
  /// Returns a readable string like "about 18 minutes".
  func getETA(to destination: String) async -> String {
    guard let currentLocation = locationManager.location else {
      return "unknown time"
    }

    return await withCheckedContinuation { continuation in
      let geocoder = CLGeocoder()
      geocoder.geocodeAddressString(destination) { placemarks, _ in
        guard let destLocation = placemarks?.first?.location else {
          continuation.resume(returning: "unknown time")
          return
        }

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: currentLocation.coordinate))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destLocation.coordinate))
        request.transportType = .automobile

        MKDirections(request: request).calculate { response, _ in
          if let route = response?.routes.first {
            let minutes = Int(route.expectedTravelTime / 60)
            continuation.resume(returning: "about \(minutes) minutes")
          } else {
            continuation.resume(returning: "unknown time")
          }
        }
      }
    }
  }

  /// Sets a 200m geofence at the current location. When the user exits it,
  /// `onGeofenceExit` fires with the contact and message.
  func setGeofenceAtCurrentLocation(contact: String, message: String) {
    guard let location = locationManager.location else { return }
    pendingGeofenceMessage = (contact: contact, message: message)

    let region = CLCircularRegion(
      center: location.coordinate,
      radius: 200,  // ~1 city block
      identifier: "geofence_exit_\(Date().timeIntervalSince1970)"
    )
    region.notifyOnExit = true
    region.notifyOnEntry = false
    locationManager.startMonitoring(for: region)
  }

  // Called automatically by iOS when the user exits a monitored region.
  func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    if region.identifier.hasPrefix("geofence_exit_"), let pending = pendingGeofenceMessage {
      onGeofenceExit?(pending.contact, pending.message)
      locationManager.stopMonitoring(for: region)
      pendingGeofenceMessage = nil
    }
  }
}
