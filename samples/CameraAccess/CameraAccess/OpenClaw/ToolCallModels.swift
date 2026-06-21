import Foundation

// MARK: - Gemini Tool Call (parsed from server JSON)

struct GeminiFunctionCall {
  let id: String
  let name: String
  let args: [String: Any]
}

struct GeminiToolCall {
  let functionCalls: [GeminiFunctionCall]

  init?(json: [String: Any]) {
    guard let toolCall = json["toolCall"] as? [String: Any],
          let calls = toolCall["functionCalls"] as? [[String: Any]] else {
      return nil
    }
    self.functionCalls = calls.compactMap { call in
      guard let id = call["id"] as? String,
            let name = call["name"] as? String else { return nil }
      let args = call["args"] as? [String: Any] ?? [:]
      return GeminiFunctionCall(id: id, name: name, args: args)
    }
  }
}

// MARK: - Gemini Tool Call Cancellation

struct GeminiToolCallCancellation {
  let ids: [String]

  init?(json: [String: Any]) {
    guard let cancellation = json["toolCallCancellation"] as? [String: Any],
          let ids = cancellation["ids"] as? [String] else {
      return nil
    }
    self.ids = ids
  }
}

// MARK: - Tool Result

enum ToolResult {
  case success(String)
  case failure(String)

  var responseValue: [String: Any] {
    switch self {
    case .success(let result):
      return ["result": result]
    case .failure(let error):
      return ["error": error]
    }
  }
}

// MARK: - Tool Call Status (for UI)

enum ToolCallStatus: Equatable {
  case idle
  case executing(String)
  case completed(String)
  case failed(String, String)
  case cancelled(String)

  var displayText: String {
    switch self {
    case .idle: return ""
    case .executing(let name): return "Running: \(name)..."
    case .completed(let name): return "Done: \(name)"
    case .failed(let name, let err): return "Failed: \(name) - \(err)"
    case .cancelled(let name): return "Cancelled: \(name)"
    }
  }

  var isActive: Bool {
    if case .executing = self { return true }
    return false
  }
}

// MARK: - Tool Declarations (for Gemini setup message)

enum ToolDeclarations {

  static func allDeclarations() -> [[String: Any]] {
    // Dedicated tools are BLOCKING so the model waits for the on-device result
    // before speaking the confirmation (matching the execute tool's behavior).
    let blockingTools = dadBuildTools.map { tool -> [String: Any] in
      var t = tool
      t["behavior"] = "BLOCKING"
      return t
    }
    return [execute] + blockingTools
  }

  // Dedicated on-device tools added by the Dad-build guide (Features A–K).
  // Grows as features are implemented; handled in Services/LocalTools.swift.
  static let dadBuildTools: [[String: Any]] = [
    readEmails,
    sendEmail,
    sendETAText,
    sendIMessage,
    setLocationTrigger,
    saveParkingSpot,
    rememberThis,
    createCalendarEvent,
    getDailySummary,
    setFocusMode,
    setCheckinTimer,
    cancelCheckin,
    endOfDay,
    getWeather,
    readText,
  ]

  // MARK: Feature B — Voice Email Triage & Reply

  static let readEmails: [String: Any] = [
    "name": "read_emails",
    "description": "Reads the user's unread emails aloud. Call when the user asks to check, read, or hear their emails.",
    "parameters": [
      "type": "object",
      "properties": [String: Any](),
      "required": [String]()
    ] as [String: Any]
  ]

  static let sendEmail: [String: Any] = [
    "name": "send_email",
    "description": "Sends an email. Call this when the user wants to reply to someone or send a message via email. Confirm recipient and content before sending unless clearly urgent.",
    "parameters": [
      "type": "object",
      "properties": [
        "to": ["type": "string", "description": "Recipient email address"],
        "subject": ["type": "string", "description": "Email subject line"],
        "body": ["type": "string", "description": "The full email body text"]
      ],
      "required": ["to", "subject", "body"]
    ] as [String: Any]
  ]

  // MARK: Feature D — Auto Messages & ETA Texts

  static let sendETAText: [String: Any] = [
    "name": "send_eta_text",
    "description": "Calculates driving ETA to a destination and texts it to a contact. Use when the user says they are heading somewhere.",
    "parameters": [
      "type": "object",
      "properties": [
        "contact": ["type": "string", "description": "Name of the person to text (e.g. 'wife', 'mom')"],
        "destination": ["type": "string", "description": "Where the user is heading (e.g. 'home', '123 Main St')"]
      ],
      "required": ["contact", "destination"]
    ] as [String: Any]
  ]

  static let sendIMessage: [String: Any] = [
    "name": "send_imessage",
    "description": "Sends an iMessage to a contact. Use when the user wants to notify someone of something.",
    "parameters": [
      "type": "object",
      "properties": [
        "contact": ["type": "string", "description": "Name of the contact to message"],
        "message": ["type": "string", "description": "The message to send"]
      ],
      "required": ["contact", "message"]
    ] as [String: Any]
  ]

  static let setLocationTrigger: [String: Any] = [
    "name": "set_location_trigger",
    "description": "Sets up a message to be sent automatically when the user leaves their current location.",
    "parameters": [
      "type": "object",
      "properties": [
        "contact": ["type": "string", "description": "Name of the contact to message when leaving"],
        "message": ["type": "string", "description": "The message to send when the user leaves"]
      ],
      "required": ["contact", "message"]
    ] as [String: Any]
  ]

  // MARK: Feature E — Parking Spot Logger

  static let saveParkingSpot: [String: Any] = [
    "name": "save_parking_spot",
    "description": "Saves the current parking location with GPS coordinates and a photo. Call when the user says 'remember where I parked' or similar.",
    "parameters": [
      "type": "object",
      "properties": [String: Any](),
      "required": [String]()
    ] as [String: Any]
  ]

  // MARK: Feature F — "Remember This" Task Capture

  static let rememberThis: [String: Any] = [
    "name": "remember_this",
    "description": "Saves a note about what the user is currently looking at, optionally with a due date for follow-up.",
    "parameters": [
      "type": "object",
      "properties": [
        "title": ["type": "string", "description": "Short title for the note"],
        "body": ["type": "string", "description": "Full description of what to remember"],
        "due_date": ["type": "string", "description": "Optional: ISO 8601 date string if the user wants a reminder"]
      ],
      "required": ["title", "body"]
    ] as [String: Any]
  ]

  // MARK: Feature G — Sticky Note → Calendar Reminder

  static let createCalendarEvent: [String: Any] = [
    "name": "create_calendar_event",
    "description": "Creates an event in Google Calendar. Use when the user says 'remind me to', 'add to calendar', 'don't forget to', or mentions a specific date/time for something.",
    "parameters": [
      "type": "object",
      "properties": [
        "title": ["type": "string", "description": "Event title"],
        "start_time": ["type": "string", "description": "Start time in ISO 8601 format"],
        "end_time": ["type": "string", "description": "End time in ISO 8601 format — default to 30 minutes after start"],
        "notes": ["type": "string", "description": "Optional notes or description for the event"]
      ],
      "required": ["title", "start_time", "end_time"]
    ] as [String: Any]
  ]

  // MARK: Feature H — Daily Commitment Readback

  static let getDailySummary: [String: Any] = [
    "name": "get_daily_summary",
    "description": "Returns all of today's commitments: calendar events and captured notes. Call when the user asks what they need to do, what's on their plate, or what they committed to today.",
    "parameters": [
      "type": "object",
      "properties": [String: Any](),
      "required": [String]()
    ] as [String: Any]
  ]

  // MARK: Feature I — Focus Mode Trigger

  static let setFocusMode: [String: Any] = [
    "name": "set_focus_mode",
    "description": "Turns iPhone Focus mode (Do Not Disturb) on or off via an iOS Shortcut. Use when the user says they are in a meeting, need quiet, or are done with a meeting.",
    "parameters": [
      "type": "object",
      "properties": [
        "enabled": ["type": "boolean", "description": "true to enable Focus/DND, false to disable it"]
      ],
      "required": ["enabled"]
    ] as [String: Any]
  ]

  // MARK: Feature J — Check-In Safety Timer

  static let setCheckinTimer: [String: Any] = [
    "name": "set_checkin_timer",
    "description": "Sets a safety check-in timer. If the user doesn't cancel it by the due time, a message with their location is sent to a contact.",
    "parameters": [
      "type": "object",
      "properties": [
        "contact": ["type": "string", "description": "Person to alert if the check-in is missed"],
        "due_time": ["type": "string", "description": "ISO 8601 time when the check-in is due"],
        "activity": ["type": "string", "description": "What the user is doing (for context in the message)"]
      ],
      "required": ["contact", "due_time"]
    ] as [String: Any]
  ]

  static let cancelCheckin: [String: Any] = [
    "name": "cancel_checkin",
    "description": "Cancels the active safety check-in timer. Call when the user says 'I'm back', 'I'm home', 'cancel check-in', etc.",
    "parameters": [
      "type": "object",
      "properties": [String: Any](),
      "required": [String]()
    ] as [String: Any]
  ]

  // MARK: Feature K — End-of-Day Wrap

  static let endOfDay: [String: Any] = [
    "name": "end_of_day",
    "description": "Triggers the end-of-day wrap: summarizes the day, texts family, and clears Focus mode. Call when the user says they are done for the day, logging off, or wrapping up.",
    "parameters": [
      "type": "object",
      "properties": [
        "family_contact": ["type": "string", "description": "Who to text with the end-of-day message"],
        "message": ["type": "string", "description": "Optional custom message to family. Defaults to a simple 'work is done' note."]
      ],
      "required": ["family_contact"]
    ] as [String: Any]
  ]

  // MARK: Feature L — Weather

  static let getWeather: [String: Any] = [
    "name": "get_weather",
    "description": "Returns the current weather and today's high/low for the user's location. Call when the user asks about the weather, temperature, or whether they need a jacket/umbrella.",
    "parameters": [
      "type": "object",
      "properties": [String: Any](),
      "required": [String]()
    ] as [String: Any]
  ]

  // MARK: Feature M — Read & Translate (Vision OCR)

  static let readText: [String: Any] = [
    "name": "read_text",
    "description": "Reads, summarizes, or translates text the user is looking at (a letter, label, menu, sign, or screen) using on-device OCR of the camera view. Call when the user says 'read this', 'what does this say', or 'translate this'.",
    "parameters": [
      "type": "object",
      "properties": [
        "target_language": ["type": "string", "description": "Optional: the language to translate the text into (e.g. 'Spanish'). Omit to just read it aloud."]
      ],
      "required": [String]()
    ] as [String: Any]
  ]

  static let execute: [String: Any] = [
    "name": "execute",
    "description": "Your only way to take action. You have no memory, storage, or ability to do anything on your own -- use this tool for everything: sending messages, searching the web, adding to lists, setting reminders, creating notes, research, drafts, scheduling, smart home control, app interactions, or any request that goes beyond answering a question. When in doubt, use this tool.",
    "parameters": [
      "type": "object",
      "properties": [
        "task": [
          "type": "string",
          "description": "Clear, detailed description of what to do. Include all relevant context: names, content, platforms, quantities, etc."
        ]
      ],
      "required": ["task"]
    ] as [String: Any],
    "behavior": "BLOCKING"
  ]
}
