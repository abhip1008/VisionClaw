// Services/LocalTools.swift
// Central dispatcher for tool calls that are handled on-device (rather than
// forwarded to the OpenClaw agent). ToolCallRouter consults this first; any tool
// name not listed here falls through to OpenClaw's `execute`.
//
// Handlers are added here as each Dad-build feature is implemented.

import Foundation

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
