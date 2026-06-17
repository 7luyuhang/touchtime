//
//  GoogleAuthConfig.swift
//  touchtime
//
//  Created on 17/06/2026.
//

import Foundation

/// Configuration for Google Sign-In + Google Meet link generation.
///
/// ── ONE-TIME SETUP ──────────────────────────────────────────────────────────
/// 1. Open https://console.cloud.google.com and create (or pick) a project.
/// 2. Enable the "Google Calendar API":
///    APIs & Services → Library → search "Google Calendar API" → Enable.
///    (We use the Calendar API to mint a Meet link because it works for both
///    free Gmail accounts and Google Workspace accounts. The newer Meet REST API
///    is Workspace-only.)
/// 3. Configure the OAuth consent screen (User type: External). Add the scope
///    `https://www.googleapis.com/auth/calendar.events`. While the app is still
///    in "Testing", add your Google account under "Test users".
/// 4. Create the OAuth client:
///    APIs & Services → Credentials → Create Credentials → OAuth client ID →
///    Application type: iOS → Bundle ID: `com.time.touchtime`.
/// 5. Copy the generated iOS client ID and paste it into `clientID` below.
///
/// Notes:
/// • No client secret is required — iOS OAuth clients are public clients and we
///   use PKCE.
/// • No Info.plist URL scheme is required — sign-in uses
///   `ASWebAuthenticationSession`, which intercepts the redirect for us.
enum GoogleAuthConfig {
    /// The iOS OAuth client ID, e.g.
    /// "123456789012-abcdefghijklmnop.apps.googleusercontent.com".
    static let clientID = "145025868288-cl0hcs26gr0sospdjqvml67rjr42ui20.apps.googleusercontent.com"

    /// OAuth scopes: identify the signed-in account (email) and allow creating
    /// a calendar event that generates a Google Meet link.
    static let scopes = [
        "openid",
        "email",
        "https://www.googleapis.com/auth/calendar.events"
    ]

    /// Reversed client ID, used as the custom URL scheme for the OAuth redirect,
    /// e.g. "com.googleusercontent.apps.123456789012-abcdefghijklmnop".
    static var reversedClientID: String {
        let prefix = clientID.replacingOccurrences(
            of: ".apps.googleusercontent.com",
            with: ""
        )
        return "com.googleusercontent.apps.\(prefix)"
    }

    /// Redirect URI implicitly registered for iOS OAuth clients.
    static var redirectURI: String {
        "\(reversedClientID):/oauth2redirect"
    }

    /// Whether a real client ID has been filled in.
    static var isConfigured: Bool {
        !clientID.hasPrefix("YOUR_IOS_CLIENT_ID") && clientID.hasSuffix(".apps.googleusercontent.com")
    }
}
