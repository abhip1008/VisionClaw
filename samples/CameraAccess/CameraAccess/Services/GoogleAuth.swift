// Services/GoogleAuth.swift
// Thin wrapper around Google Sign-In so the rest of the app can check auth state
// and trigger sign-in without importing GoogleSignIn everywhere. All SDK usage is
// guarded with `#if canImport(GoogleSignIn)` so the project builds before the
// GoogleSignIn-iOS package is added in Xcode.

import Foundation
import SwiftUI
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

enum GoogleAuth {

  // Scopes needed across all Dad-build features:
  // - calendar (read + write) for briefing, prep, and event creation
  // - gmail.modify + gmail.send for reading and replying to email
  static let scopes = [
    "https://www.googleapis.com/auth/calendar",
    "https://www.googleapis.com/auth/gmail.modify",
    "https://www.googleapis.com/auth/gmail.send",
  ]

  static var isSignedIn: Bool {
    #if canImport(GoogleSignIn)
    return GIDSignIn.sharedInstance.currentUser != nil
    #else
    return false
    #endif
  }

  static var isAvailable: Bool {
    #if canImport(GoogleSignIn)
    return true
    #else
    return false
    #endif
  }

  static var signedInEmail: String? {
    #if canImport(GoogleSignIn)
    return GIDSignIn.sharedInstance.currentUser?.profile?.email
    #else
    return nil
    #endif
  }

  @MainActor
  static func restorePreviousSignIn() {
    #if canImport(GoogleSignIn)
    GIDSignIn.sharedInstance.restorePreviousSignIn()
    #endif
  }

  // Routes the OAuth callback URL. Call from `.onOpenURL` in the App.
  @MainActor
  static func handle(_ url: URL) {
    #if canImport(GoogleSignIn)
    GIDSignIn.sharedInstance.handle(url)
    #endif
  }

  @MainActor
  static func signIn(completion: ((Bool) -> Void)? = nil) {
    #if canImport(GoogleSignIn)
    guard let root = topViewController() else {
      completion?(false)
      return
    }
    GIDSignIn.sharedInstance.signIn(
      withPresenting: root,
      hint: nil,
      additionalScopes: scopes
    ) { _, error in
      if let error {
        NSLog("[GoogleAuth] Sign-in error: %@", error.localizedDescription)
        completion?(false)
      } else {
        completion?(true)
      }
    }
    #else
    completion?(false)
    #endif
  }

  @MainActor
  static func signOut() {
    #if canImport(GoogleSignIn)
    GIDSignIn.sharedInstance.signOut()
    #endif
  }

  #if canImport(GoogleSignIn)
  @MainActor
  private static func topViewController() -> UIViewController? {
    let root = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }?
      .rootViewController
    var top = root
    while let presented = top?.presentedViewController {
      top = presented
    }
    return top
  }
  #endif
}

// A small self-contained row you can drop into Settings (or any view) to connect
// the user's Google account. Compiles and renders even before the package is added.
struct GoogleConnectView: View {
  @State private var signedInEmail: String? = GoogleAuth.signedInEmail
  @State private var busy = false

  var body: some View {
    if !GoogleAuth.isAvailable {
      Text("Add the GoogleSignIn-iOS Swift package in Xcode to enable calendar and email features.")
        .font(.caption)
        .foregroundColor(.secondary)
    } else if let email = signedInEmail {
      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Connected")
            .font(.caption)
            .foregroundColor(.secondary)
          Text(email)
            .font(.system(.body, design: .monospaced))
        }
        Spacer()
        Button("Sign out") {
          GoogleAuth.signOut()
          signedInEmail = nil
        }
        .foregroundColor(.red)
      }
    } else {
      Button {
        busy = true
        GoogleAuth.signIn { _ in
          busy = false
          signedInEmail = GoogleAuth.signedInEmail
        }
      } label: {
        HStack {
          Image(systemName: "person.crop.circle.badge.checkmark")
          Text(busy ? "Connecting…" : "Connect Google account")
        }
      }
      .disabled(busy)
    }
  }
}
