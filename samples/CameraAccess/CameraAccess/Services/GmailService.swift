// Services/GmailService.swift
// Fetches unread emails from Gmail, identifies urgent ones, and sends replies.
//
// Google Sign-In usage is guarded with `#if canImport(GoogleSignIn)` so the
// project compiles before the package is added in Xcode.

import Foundation
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

class GmailService {

  // Returns a plain text summary of unread emails from the last 24 hours.
  static func fetchUrgentEmails() async -> String {
    #if canImport(GoogleSignIn)
    guard let user = GIDSignIn.sharedInstance.currentUser else {
      return "No email connected."
    }
    let token = user.accessToken.tokenString

    let query = "is:unread newer_than:1d".addingPercentEncoding(
      withAllowedCharacters: .urlQueryAllowed) ?? ""
    let urlString = "https://gmail.googleapis.com/gmail/v1/users/me/messages?q=\(query)&maxResults=5"
    guard let url = URL(string: urlString) else { return "Email error." }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    do {
      let (data, _) = try await URLSession.shared.data(for: request)
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
      let messages = json?["messages"] as? [[String: Any]] ?? []

      if messages.isEmpty { return "No urgent emails." }

      var summaries: [String] = []
      for message in messages.prefix(3) {
        guard let id = message["id"] as? String else { continue }
        if let detail = await fetchMessageDetail(id: id, token: token) {
          summaries.append(detail)
        }
      }

      if summaries.isEmpty { return "No urgent emails." }
      return "Unread emails:\n" + summaries.joined(separator: "\n")
    } catch {
      return "Could not load emails."
    }
    #else
    return "Google Sign-In is not installed yet."
    #endif
  }

  #if canImport(GoogleSignIn)
  // Fetches sender and subject for a single email by ID.
  private static func fetchMessageDetail(id: String, token: String) async -> String? {
    let urlString = "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(id)?format=metadata&metadataHeaders=From&metadataHeaders=Subject"
    guard let url = URL(string: urlString) else { return nil }

    var request = URLRequest(url: url)
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

    do {
      let (data, _) = try await URLSession.shared.data(for: request)
      let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
      let payload = json?["payload"] as? [String: Any]
      let headers = payload?["headers"] as? [[String: Any]] ?? []

      var from = "Unknown"
      var subject = "No subject"
      for header in headers {
        if header["name"] as? String == "From" { from = header["value"] as? String ?? from }
        if header["name"] as? String == "Subject" { subject = header["value"] as? String ?? subject }
      }
      return "- From \(from): \(subject)"
    } catch {
      return nil
    }
  }
  #endif

  // Sends an email reply using the Gmail API. Returns true on success.
  static func sendReply(to: String, subject: String, body: String) async -> Bool {
    #if canImport(GoogleSignIn)
    guard let user = GIDSignIn.sharedInstance.currentUser else { return false }
    let token = user.accessToken.tokenString

    // Build a raw email in RFC 2822 format, base64url-encoded.
    let rawEmail = "To: \(to)\r\nSubject: \(subject)\r\n\r\n\(body)"
    guard let emailData = rawEmail.data(using: .utf8) else { return false }
    let base64Email = emailData.base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")

    guard let url = URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/send") else {
      return false
    }
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try? JSONSerialization.data(withJSONObject: ["raw": base64Email])

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
