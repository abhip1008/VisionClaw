// Services/CalendarWriteService.swift
// Creates events in Google Calendar. Google Sign-In usage is guarded so the
// project builds before the package is added.

import Foundation
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

class CalendarWriteService {

  // Creates a calendar event. startTime/endTime are ISO 8601
  // (e.g. "2025-03-15T14:00:00"). Returns true on success.
  static func createEvent(title: String, startTime: String, endTime: String, notes: String = "") async -> Bool {
    #if canImport(GoogleSignIn)
    guard let user = GIDSignIn.sharedInstance.currentUser else { return false }
    let token = user.accessToken.tokenString

    let eventBody: [String: Any] = [
      "summary": title,
      "description": notes,
      "start": ["dateTime": startTime, "timeZone": TimeZone.current.identifier],
      "end": ["dateTime": endTime, "timeZone": TimeZone.current.identifier],
      "reminders": [
        "useDefault": false,
        "overrides": [
          ["method": "popup", "minutes": 10]
        ]
      ]
    ]

    guard let url = URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events") else {
      return false
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: eventBody)

    do {
      let (_, response) = try await URLSession.shared.data(for: request)
      return (response as? HTTPURLResponse)?.statusCode == 200
    } catch {
      return false
    }
    #else
    return false
    #endif
  }
}
