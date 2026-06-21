// Services/ParkingService.swift
// Saves a parking location with GPS coordinates, a reverse-geocoded address, an
// Apple Maps link, and (optionally) a photo from the latest camera frame.

import Foundation
import CoreLocation
import UIKit

class ParkingService {

  struct ParkingSpot {
    let coordinate: CLLocationCoordinate2D
    let address: String
    let timestamp: Date
    let imagePath: String?
  }

  // Saves the current location as a parking spot and returns a readable summary.
  static func saveParkingSpot(image: UIImage?) async -> String {
    guard let location = LocationService.shared.currentLocation else {
      return "Could not get your location. Make sure location access is enabled."
    }

    let coordinate = location.coordinate
    let address = await reverseGeocode(location: location)
    let mapsLink = "https://maps.apple.com/?q=\(coordinate.latitude),\(coordinate.longitude)"

    var imageSummary = ""
    if let image = image, let data = image.jpegData(compressionQuality: 0.7) {
      let filename = "parking_\(Int(Date().timeIntervalSince1970)).jpg"
      let path = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
      try? data.write(to: path)
      imageSummary = " Photo saved."
    }

    return """
    Parking spot saved.\(imageSummary)
    Location: \(address)
    Maps link: \(mapsLink)
    """
  }

  // Converts GPS coordinates to a human-readable address.
  private static func reverseGeocode(location: CLLocation) async -> String {
    return await withCheckedContinuation { continuation in
      CLGeocoder().reverseGeocodeLocation(location) { placemarks, _ in
        let placemark = placemarks?.first
        let number = placemark?.subThoroughfare ?? ""
        let street = placemark?.thoroughfare ?? ""
        let city = placemark?.locality ?? ""
        let address = "\(number) \(street), \(city)".trimmingCharacters(in: .whitespaces)
        continuation.resume(returning: address.isEmpty ? "Current location" : address)
      }
    }
  }
}
