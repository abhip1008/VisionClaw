// Services/MeetingPrepService.swift
// Monitors Google Calendar and fires a spoken prep summary ~5 minutes before
// each meeting. Google Sign-In usage is guarded so the project builds before the
// package is added.

import Foundation
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

@MainActor
class MeetingPrepService {

  private var timer: Timer?
  private var onPrepNeeded: ((String) -> Void)?
  private var alreadyPrepared: Set<String> = []  // Meetings we've already prepped

  // Call once when a session starts. The callback fires with a spoken prompt.
  func startMonitoring(onPrepNeeded: @escaping (String) -> Void) {
    self.onPrepNeeded = onPrepNeeded
    timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
      Task { @MainActor in await self?.checkUpcomingMeetings() }
    }
    Task { @MainActor in await checkUpcomingMeetings() }
  }

  func stopMonitoring() {
    timer?.invalidate()
    timer = nil
    onPrepNeeded = nil
  }

  private func checkUpcomingMeetings() async {
    #if canImport(GoogleSignIn)
    guard let user = GIDSignIn.sharedInstance.currentUser else { return }
    let token = user.accessToken.tokenString

    let fiveMinutes = Date(timeIntervalSinceNow: 5 * 60)
    let tenMinutes = Date(timeIntervalSinceNow: 10 * 60)

    let formatter = ISO8601DateFormatter()
    let timeMin = formatter.string(from: fiveMinutes)
    let timeMax = formatter.string(from: tenMinutes)

    let base = "https://www.googleapis.com/calendar/v3/calendars/primary/events"
    let query = "?timeMin=\(timeMin)&timeMax=\(timeMax)&singleEvents=true"
    guard let url = URL(string: base + query) else { return }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    do {
      let (data, _) = try await URLSession.shared.data(for: request)
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
      let items = json?["items"] as? [[String: Any]] ?? []

      for item in items {
        guard let id = item["id"] as? String, !alreadyPrepared.contains(id) else { continue }

        let title = item["summary"] as? String ?? "Untitled meeting"
        let description = item["description"] as? String ?? ""
        let attendeesList = (item["attendees"] as? [[String: Any]] ?? [])
          .compactMap { $0["email"] as? String }
          .joined(separator: ", ")

        alreadyPrepared.insert(id)

        let prepPrompt = """
        You have a meeting starting in about 5 minutes. Give a brief spoken prep summary. \
        Keep it under 30 seconds. Be natural.

        Meeting title: \(title)
        Attendees: \(attendeesList.isEmpty ? "Not specified" : attendeesList)
        Description: \(description.isEmpty ? "No description" : description)

        After the summary, ask if there's anything specific to prepare.
        """
        onPrepNeeded?(prepPrompt)
      }
    } catch {
      NSLog("[MeetingPrep] error: %@", error.localizedDescription)
    }
    #endif
  }
}
