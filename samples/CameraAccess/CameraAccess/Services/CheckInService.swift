// Services/CheckInService.swift
// Manages a single safety check-in timer. If the user does not cancel it before
// the due time, it sends a contact the user's last known location.
//
// The actual message send is injected via `messageSender` (set by the session
// view model to route through the OpenClaw agent), since this service has no
// direct reference to the gateway.

import Foundation

@MainActor
class CheckInService {

  /// Injected sender. Receives a free-form task like
  /// "Send iMessage to <contact> saying: <message>".
  static var messageSender: ((String) async -> Void)?

  private static var activeTimer: Timer?

  // Sets a check-in timer. If not cancelled before dueTime, fires the alert.
  static func setCheckIn(contact: String, dueTime: Date, location: String) {
    cancelCheckIn()

    let interval = dueTime.timeIntervalSinceNow
    guard interval > 0 else { return }

    activeTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { _ in
      Task { @MainActor in await fireCheckInAlert(contact: contact) }
    }
  }

  // Cancels the active check-in timer (call when the user says "I'm back").
  static func cancelCheckIn() {
    activeTimer?.invalidate()
    activeTimer = nil
  }

  static var isActive: Bool { activeTimer != nil }

  // Fires when the check-in time passes without cancellation.
  private static func fireCheckInAlert(contact: String) async {
    activeTimer = nil
    let location = await LocationService.shared.getCurrentLocation()
    let coords = location.map { "\($0.coordinate.latitude),\($0.coordinate.longitude)" } ?? "unknown"
    let mapsLink = "https://maps.apple.com/?q=\(coords)"

    let message = "Automatic safety check-in alert: a check-in timer just expired without being cancelled. Last known location: \(mapsLink). Please check in."

    await messageSender?("Send iMessage to \(contact) saying: \(message)")
  }
}
