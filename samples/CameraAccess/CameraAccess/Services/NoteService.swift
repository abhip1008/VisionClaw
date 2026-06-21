// Services/NoteService.swift
// Saves notes to a local JSON file and creates reminders in Apple Reminders.

import Foundation
import EventKit

class NoteService {

  private static let eventStore = EKEventStore()

  // Saves a note to a local JSON file (no external account needed).
  @discardableResult
  static func saveNote(title: String, body: String, imagePath: String? = nil) async -> Bool {
    let note: [String: Any] = [
      "id": UUID().uuidString,
      "title": title,
      "body": body,
      "imagePath": imagePath ?? "",
      "createdAt": ISO8601DateFormatter().string(from: Date())
    ]

    var notes = loadAllNotes()
    notes.append(note)

    do {
      let data = try JSONSerialization.data(withJSONObject: notes, options: .prettyPrinted)
      try data.write(to: notesFileURL())
      return true
    } catch {
      return false
    }
  }

  // Creates a reminder in Apple Reminders, optionally with a due date + alarm.
  @discardableResult
  static func createReminder(title: String, dueDate: Date?) async -> Bool {
    let granted: Bool
    if #available(iOS 17.0, *) {
      granted = (try? await eventStore.requestFullAccessToReminders()) ?? false
    } else {
      granted = await withCheckedContinuation { continuation in
        eventStore.requestAccess(to: .reminder) { ok, _ in continuation.resume(returning: ok) }
      }
    }
    guard granted else { return false }

    let reminder = EKReminder(eventStore: eventStore)
    reminder.title = title
    reminder.calendar = eventStore.defaultCalendarForNewReminders()

    if let date = dueDate {
      reminder.dueDateComponents = Calendar.current.dateComponents(
        [.year, .month, .day, .hour, .minute], from: date
      )
      reminder.addAlarm(EKAlarm(absoluteDate: date))
    }

    do {
      try eventStore.save(reminder, commit: true)
      return true
    } catch {
      return false
    }
  }

  // Reads all saved notes.
  static func loadAllNotes() -> [[String: Any]] {
    guard let data = try? Data(contentsOf: notesFileURL()),
          let notes = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
      return []
    }
    return notes
  }

  // Returns today's notes as a readable string.
  static func getTodaysNotes() -> String {
    let today = Calendar.current.startOfDay(for: Date())
    let formatter = ISO8601DateFormatter()
    let todayNotes = loadAllNotes().filter { note in
      if let dateStr = note["createdAt"] as? String, let date = formatter.date(from: dateStr) {
        return date >= today
      }
      return false
    }
    if todayNotes.isEmpty { return "No notes captured today." }
    return todayNotes.compactMap { $0["title"] as? String }
      .map { "- \($0)" }
      .joined(separator: "\n")
  }

  private static func notesFileURL() -> URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("visionclaw_notes.json")
  }
}
