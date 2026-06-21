// Services/LocalTools.swift
// Central dispatcher for tool calls that are handled on-device (rather than
// forwarded to the OpenClaw agent). ToolCallRouter consults this first; any tool
// name not listed here falls through to OpenClaw's `execute`.
//
// Handlers are added here as each Dad-build feature is implemented.

import Foundation
import UIKit

@MainActor
enum LocalTools {

  // Tool names handled locally. Keep in sync with the declarations in
  // ToolDeclarations.allDeclarations().
  static let names: Set<String> = [
    "read_emails",
    "send_email",
    "send_eta_text",
    "send_imessage",
    "set_location_trigger",
    "save_parking_spot",
    "remember_this",
    "create_calendar_event",
    "get_daily_summary",
    "set_focus_mode",
    "set_checkin_timer",
    "cancel_checkin",
    "end_of_day",
    "get_weather",
  ]

  static func isLocal(_ name: String) -> Bool { names.contains(name) }

  static func handle(_ call: GeminiFunctionCall, bridge: OpenClawBridge) async -> ToolResult {
    let args = call.args
    switch call.name {

    // MARK: Feature B — Voice Email Triage & Reply
    case "read_emails":
      return .success(await GmailService.fetchUrgentEmails())

    case "send_email":
      guard
        let to = args["to"] as? String,
        let subject = args["subject"] as? String,
        let body = args["body"] as? String
      else {
        return .failure("Missing email parameters.")
      }
      let ok = await GmailService.sendReply(to: to, subject: subject, body: body)
      return ok ? .success("Email sent successfully.") : .failure("Failed to send email.")

    // MARK: Feature D — Auto Messages & ETA Texts
    case "send_eta_text":
      guard
        let contact = args["contact"] as? String,
        let destination = args["destination"] as? String
      else { return .failure("Missing parameters.") }
      let eta = await LocationService.shared.getETA(to: destination)
      let message = "On my way to \(destination) — should be there in \(eta)."
      _ = await sendViaAgent("Send iMessage to \(contact) saying: \(message)", bridge: bridge)
      return .success("Sent ETA to \(contact): \(message)")

    case "send_imessage":
      guard
        let contact = args["contact"] as? String,
        let message = args["message"] as? String
      else { return .failure("Missing parameters.") }
      _ = await sendViaAgent("Send iMessage to \(contact) saying: \(message)", bridge: bridge)
      return .success("Message sent to \(contact).")

    case "set_location_trigger":
      guard
        let contact = args["contact"] as? String,
        let message = args["message"] as? String
      else { return .failure("Missing parameters.") }
      LocationService.shared.setGeofenceAtCurrentLocation(contact: contact, message: message)
      return .success("Got it. I'll text \(contact) when you leave here.")

    // MARK: Feature E — Parking Spot Logger
    case "save_parking_spot":
      let image = LatestFrameStore.shared.image
      let result = await ParkingService.saveParkingSpot(image: image)
      _ = await sendViaAgent("Send iMessage to myself saying: \(result)", bridge: bridge)
      return .success(result)

    // MARK: Feature F — "Remember This" Task Capture
    case "remember_this":
      guard
        let title = args["title"] as? String,
        let body = args["body"] as? String
      else { return .failure("Missing note content.") }

      let dueDate = (args["due_date"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
      let saved = await NoteService.saveNote(title: title, body: body)

      if let date = dueDate {
        await NoteService.createReminder(title: title, dueDate: date)
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return .success("Got it. Saved '\(title)' and set a reminder for \(f.string(from: date)).")
      }
      return saved ? .success("Saved: '\(title)'") : .failure("Could not save the note.")

    // MARK: Feature G — Sticky Note → Calendar Reminder
    case "create_calendar_event":
      guard
        let title = args["title"] as? String,
        let startTime = args["start_time"] as? String,
        let endTime = args["end_time"] as? String
      else { return .failure("Missing event details.") }
      let notes = args["notes"] as? String ?? ""
      let ok = await CalendarWriteService.createEvent(
        title: title, startTime: startTime, endTime: endTime, notes: notes
      )
      return ok ? .success("Added '\(title)' to your calendar.") : .failure("Could not create the event.")

    // MARK: Feature H — Daily Commitment Readback
    case "get_daily_summary":
      async let calendarSummary = GoogleCalendarService.fetchTodayEvents()
      let notes = NoteService.getTodaysNotes()
      let calendar = await calendarSummary
      return .success("""
      Here is everything for today:

      SCHEDULE:
      \(calendar)

      NOTES CAPTURED TODAY:
      \(notes)

      Read this back naturally and conversationally. Ask if anything needs to be moved, updated, or added.
      """)

    // MARK: Feature I — Focus Mode Trigger
    case "set_focus_mode":
      let enabled = args["enabled"] as? Bool ?? true
      let shortcutName = enabled ? "FocusOn" : "FocusOff"
      let encoded = shortcutName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? shortcutName
      if let url = URL(string: "shortcuts://run-shortcut?name=\(encoded)") {
        UIApplication.shared.open(url)
      }
      return .success("Focus mode turned \(enabled ? "on" : "off").")

    // MARK: Feature J — Check-In Safety Timer
    case "set_checkin_timer":
      guard
        let contact = args["contact"] as? String,
        let dueDateStr = args["due_time"] as? String,
        let dueDate = ISO8601DateFormatter().date(from: dueDateStr)
      else { return .failure("I need a contact and a time for the check-in.") }

      let location = await LocationService.shared.getCurrentLocation()
      let locationStr = location.map { "\($0.coordinate.latitude),\($0.coordinate.longitude)" } ?? ""
      CheckInService.setCheckIn(contact: contact, dueTime: dueDate, location: locationStr)

      let f = DateFormatter()
      f.timeStyle = .short
      return .success("Check-in set for \(f.string(from: dueDate)). If you haven't checked back in by then, I'll text \(contact) with your location.")

    case "cancel_checkin":
      if CheckInService.isActive {
        CheckInService.cancelCheckIn()
        return .success("Check-in cancelled. Glad you're back safe.")
      }
      return .success("No active check-in timer to cancel.")

    // MARK: Feature K — End-of-Day Wrap
    case "end_of_day":
      guard let contact = args["family_contact"] as? String else {
        return .failure("Who should I text?")
      }
      let customMessage = args["message"] as? String
      let notes = NoteService.getTodaysNotes()
      let calendar = await GoogleCalendarService.fetchTodayEvents()
      let familyMessage = customMessage ?? "Work's done for the day! 🏠"

      _ = await sendViaAgent("Send iMessage to \(contact) saying: \(familyMessage)", bridge: bridge)

      // Turn off Focus mode if it was on.
      if let url = URL(string: "shortcuts://run-shortcut?name=FocusOff") {
        UIApplication.shared.open(url)
      }

      return .success("""
      End of day triggered. Texted \(contact).
      Here's a quick summary of your day:

      \(calendar)

      Notes captured:
      \(notes)

      Have a good evening.
      """)

    // MARK: Feature L — Weather
    case "get_weather":
      return .success(await WeatherService.currentSummary())

    default:
      return .failure("Unknown local tool: \(call.name)")
    }
  }

  // MARK: - Helpers

  /// Sends a free-form task (e.g. an iMessage) through the OpenClaw agent.
  static func sendViaAgent(_ task: String, bridge: OpenClawBridge) async -> ToolResult {
    return await bridge.delegateTask(task: task, toolName: "execute")
  }
}
