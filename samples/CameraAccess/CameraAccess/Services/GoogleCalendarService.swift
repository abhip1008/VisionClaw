// Services/GoogleCalendarService.swift
// Fetches today's calendar events from Google Calendar.
//
// NOTE: All Google Sign-In usage is wrapped in `#if canImport(GoogleSignIn)`
// so the project keeps compiling before the GoogleSignIn-iOS Swift package is
// added in Xcode. Once the package is added, these methods activate automatically.

import Foundation
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

class GoogleCalendarService {

  // Returns a plain text summary of today's events.
  static func fetchTodayEvents() async -> String {
    #if canImport(GoogleSignIn)
    guard let user = GIDSignIn.sharedInstance.currentUser else {
      return "No calendar connected."
    }
    let token = user.accessToken.tokenString

    let now = Date()
    guard let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) else {
      return "Calendar error."
    }

    // Format dates as RFC 3339 for the Google API
    let formatter = ISO8601DateFormatter()
    let timeMin = formatter.string(from: now)
    let timeMax = formatter.string(from: endOfDay)

    let base = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
    let query = "?timeMin=\(timeMin)&timeMax=\(timeMax)&singleEvents=true&orderBy=startTime"
    guard let url = URL(string: base + query) else { return "Calendar error." }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    do {
      let (data, _) = try await URLSession.shared.data(for: request)
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
      let items = json?["items"] as? [[String: Any]] ?? []

      if items.isEmpty { return "No events scheduled today." }

      var summary = "Today's schedule:\n"
      for item in items {
        let title = item["summary"] as? String ?? "Untitled"
        let start = (item["start"] as? [String: Any])?["dateTime"] as? String ?? ""
        let time = formatTime(isoString: start)
        summary += "- \(time): \(title)\n"
      }
      return summary
    } catch {
      return "Could not load calendar."
    }
    #else
    return "Google Sign-In is not installed yet."
    #endif
  }

  // Converts an ISO 8601 time string to a readable "9:00 AM" format.
  private static func formatTime(isoString: String) -> String {
    let formatter = ISO8601DateFormatter()
    guard let date = formatter.date(from: isoString) else { return "" }
    let display = DateFormatter()
    display.timeStyle = .short
    return display.string(from: date)
  }
}
