//
//  GoogleMeetManager.swift
//  touchtime
//
//  Created on 17/06/2026.
//

import Foundation
import Combine
import CryptoKit
import AuthenticationServices
import UIKit

/// Errors surfaced while signing in or creating a Google Meet link.
enum GoogleAuthError: LocalizedError {
    case notConfigured
    case missingAuthorizationCode
    case tokenRequestFailed
    case meetLinkCreationFailed
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return String(localized: "Google Sign-In isn't set up yet. Add your OAuth client ID in GoogleAuthConfig.")
        case .missingAuthorizationCode:
            return String(localized: "Sign-in was cancelled or returned no authorization code.")
        case .tokenRequestFailed:
            return String(localized: "Couldn't complete Google Sign-In. Please try again.")
        case .meetLinkCreationFailed:
            return String(localized: "Couldn't create a Google Meet link. Please try again.")
        case .notSignedIn:
            return String(localized: "Connect a Google account first.")
        }
    }
}

/// Handles binding a Google account (OAuth 2.0 + PKCE via
/// `ASWebAuthenticationSession`) and creating Google Meet links through the
/// Google Meet REST API. A shared instance is used so the Settings screen and
/// the event-creation flow observe the same sign-in state.
@MainActor
final class GoogleMeetManager: NSObject, ObservableObject {
    static let shared = GoogleMeetManager()

    /// Email of the bound Google account, shown in Settings.
    @Published private(set) var email: String?
    /// Whether a Google account is currently connected.
    @Published private(set) var isSignedIn: Bool = false
    /// True while the sign-in web sheet / token exchange is in progress.
    @Published private(set) var isAuthenticating = false
    /// Set when an error should be presented to the user; cleared on dismiss.
    @Published var errorMessage: String?

    // In-memory access token (refreshed on demand).
    private var accessToken: String?
    private var accessTokenExpiry: Date?
    // Long-lived refresh token, persisted in the Keychain.
    private var refreshToken: String?

    private var authSession: ASWebAuthenticationSession?

    private static let keychainService = "com.time.touchtime.googlemeet"
    private static let refreshTokenAccount = "refreshToken"
    private static let emailDefaultsKey = "googleMeetAccountEmail"

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    private override init() {
        super.init()
        let storedRefreshToken = KeychainHelper.readString(
            service: Self.keychainService,
            account: Self.refreshTokenAccount
        )
        refreshToken = storedRefreshToken
        isSignedIn = storedRefreshToken != nil
        email = UserDefaults.standard.string(forKey: Self.emailDefaultsKey)
    }

    // MARK: - Public API

    /// Presents Google Sign-In and binds the account on success.
    func signIn() async {
        guard GoogleAuthConfig.isConfigured else {
            errorMessage = GoogleAuthError.notConfigured.localizedDescription
            return
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let verifier = Self.makeCodeVerifier()
            let challenge = Self.codeChallenge(for: verifier)
            let authURL = makeAuthorizationURL(codeChallenge: challenge)

            let callbackURL = try await presentAuthSession(url: authURL)
            guard let code = Self.queryValue("code", in: callbackURL) else {
                throw GoogleAuthError.missingAuthorizationCode
            }

            try await exchangeAuthorizationCode(code, codeVerifier: verifier)
            // Email lookup is best-effort; we're signed in regardless.
            try? await fetchEmail()
        } catch {
            if Self.isUserCancellation(error) { return }
            errorMessage = error.localizedDescription
        }
    }

    /// Disconnects the bound Google account and clears stored tokens.
    func signOut() {
        accessToken = nil
        accessTokenExpiry = nil
        storeRefreshToken(nil)
        setEmail(nil)
    }

    /// Creates a fresh Google Meet link and returns its join URL,
    /// e.g. "https://meet.google.com/abc-defg-hij".
    ///
    /// Uses the Google Calendar API (works for both free Gmail and Workspace
    /// accounts): a short-lived event is created with a Meet conference request,
    /// the generated link is read back, and the temporary event is then deleted.
    /// The Meet link remains valid after the event is removed.
    func createMeetLink() async throws -> String {
        guard isSignedIn else { throw GoogleAuthError.notSignedIn }

        let token = try await validAccessToken()

        let createdEvent = try await insertConferenceEvent(token: token)
        guard let eventID = createdEvent.id else {
            throw GoogleAuthError.meetLinkCreationFailed
        }

        var link = Self.meetLink(in: createdEvent)

        // The conference link is occasionally still "pending" in the create
        // response; poll the event a few times until it's ready.
        if link == nil {
            for _ in 0..<3 {
                try? await Task.sleep(nanoseconds: 700_000_000)
                if let refreshed = try? await getEvent(id: eventID, token: token),
                   let readyLink = Self.meetLink(in: refreshed) {
                    link = readyLink
                    break
                }
            }
        }

        // Remove the temporary event; the Meet link stays valid. Best-effort.
        try? await deleteEvent(id: eventID, token: token)

        guard let link else { throw GoogleAuthError.meetLinkCreationFailed }
        return link
    }

    // MARK: - Calendar API (Meet link minting)

    private func insertConferenceEvent(token: String) async throws -> CalendarEventResponse {
        let now = Date()
        let formatter = ISO8601DateFormatter()
        let body: [String: Any] = [
            "summary": "Touch Time Meet",
            "start": ["dateTime": formatter.string(from: now), "timeZone": "UTC"],
            "end": ["dateTime": formatter.string(from: now.addingTimeInterval(3600)), "timeZone": "UTC"],
            "conferenceData": [
                "createRequest": [
                    "requestId": UUID().uuidString,
                    "conferenceSolutionKey": ["type": "hangoutsMeet"]
                ]
            ]
        ]

        var request = URLRequest(url: URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events?conferenceDataVersion=1")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GoogleAuthError.meetLinkCreationFailed
        }
        return try Self.decoder.decode(CalendarEventResponse.self, from: data)
    }

    private func getEvent(id: String, token: String) async throws -> CalendarEventResponse {
        let encodedID = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events/\(encodedID)?conferenceDataVersion=1")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GoogleAuthError.meetLinkCreationFailed
        }
        return try Self.decoder.decode(CalendarEventResponse.self, from: data)
    }

    private func deleteEvent(id: String, token: String) async throws {
        let encodedID = id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? id
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/calendar/v3/calendars/primary/events/\(encodedID)")!)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        _ = try await URLSession.shared.data(for: request)
    }

    /// Extracts the Meet join URL from a calendar event, preferring the
    /// top-level `hangoutLink` and falling back to the video entry point.
    private static func meetLink(in event: CalendarEventResponse) -> String? {
        if let link = event.hangoutLink, !link.isEmpty {
            return link
        }
        if let video = event.conferenceData?.entryPoints?.first(where: { $0.entryPointType == "video" }),
           let uri = video.uri, !uri.isEmpty {
            return uri
        }
        return nil
    }

    // MARK: - OAuth flow

    private func makeAuthorizationURL(codeChallenge: String) -> URL {
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: GoogleAuthConfig.clientID),
            URLQueryItem(name: "redirect_uri", value: GoogleAuthConfig.redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: GoogleAuthConfig.scopes.joined(separator: " ")),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        return components.url!
    }

    private func presentAuthSession(url: URL) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: url,
                callbackURLScheme: GoogleAuthConfig.reversedClientID
            ) { callbackURL, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let callbackURL {
                    continuation.resume(returning: callbackURL)
                } else {
                    continuation.resume(throwing: GoogleAuthError.missingAuthorizationCode)
                }
            }
            session.presentationContextProvider = self
            session.prefersEphemeralWebBrowserSession = false
            authSession = session
            session.start()
        }
    }

    private func exchangeAuthorizationCode(_ code: String, codeVerifier: String) async throws {
        let token = try await requestToken(parameters: [
            "client_id": GoogleAuthConfig.clientID,
            "code": code,
            "code_verifier": codeVerifier,
            "grant_type": "authorization_code",
            "redirect_uri": GoogleAuthConfig.redirectURI
        ])
        apply(token)
    }

    /// Returns a non-expired access token, refreshing it if necessary.
    private func validAccessToken() async throws -> String {
        if let token = accessToken,
           let expiry = accessTokenExpiry,
           expiry > Date().addingTimeInterval(60) {
            return token
        }

        guard let refreshToken else { throw GoogleAuthError.notSignedIn }

        do {
            let token = try await requestToken(parameters: [
                "client_id": GoogleAuthConfig.clientID,
                "refresh_token": refreshToken,
                "grant_type": "refresh_token"
            ])
            apply(token)
        } catch {
            // The refresh token is invalid/revoked; reset so the UI reflects it.
            signOut()
            throw error
        }

        guard let token = accessToken else { throw GoogleAuthError.tokenRequestFailed }
        return token
    }

    private func requestToken(parameters: [String: String]) async throws -> TokenResponse {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formURLEncoded(parameters)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw GoogleAuthError.tokenRequestFailed
        }
        return try Self.decoder.decode(TokenResponse.self, from: data)
    }

    private func apply(_ token: TokenResponse) {
        accessToken = token.accessToken
        accessTokenExpiry = Date().addingTimeInterval(TimeInterval(token.expiresIn))
        // Refresh responses omit the refresh token; keep the existing one.
        if let newRefreshToken = token.refreshToken {
            storeRefreshToken(newRefreshToken)
        }
    }

    private func fetchEmail() async throws {
        let token = try await validAccessToken()

        var request = URLRequest(url: URL(string: "https://openidconnect.googleapis.com/v1/userinfo")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return
        }
        let info = try Self.decoder.decode(UserInfoResponse.self, from: data)
        setEmail(info.email)
    }

    // MARK: - Persistence

    private func storeRefreshToken(_ token: String?) {
        refreshToken = token
        isSignedIn = token != nil
        if let token {
            KeychainHelper.saveString(token, service: Self.keychainService, account: Self.refreshTokenAccount)
        } else {
            KeychainHelper.delete(service: Self.keychainService, account: Self.refreshTokenAccount)
        }
    }

    private func setEmail(_ value: String?) {
        email = value
        if let value {
            UserDefaults.standard.set(value, forKey: Self.emailDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.emailDefaultsKey)
        }
    }

    // MARK: - Helpers

    private static func isUserCancellation(_ error: Error) -> Bool {
        (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
    }

    private static func queryValue(_ name: String, in url: URL) -> String? {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first { $0.name == name }?
            .value
    }

    private static func formURLEncoded(_ parameters: [String: String]) -> Data {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let pairs = parameters.map { key, value -> String in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }
        return Data(pairs.joined(separator: "&").utf8)
    }

    private static func makeCodeVerifier() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes).base64URLEncodedString()
    }

    private static func codeChallenge(for verifier: String) -> String {
        let hash = SHA256.hash(data: Data(verifier.utf8))
        return Data(hash).base64URLEncodedString()
    }
}

// MARK: - Presentation anchor

extension GoogleMeetManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        let windowScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let scene = windowScenes.first { $0.activationState == .foregroundActive }
            ?? windowScenes.first

        if let keyWindow = scene?.keyWindow {
            return keyWindow
        }
        guard let scene else {
            preconditionFailure("No UIWindowScene available to present the authentication session.")
        }
        return ASPresentationAnchor(windowScene: scene)
    }
}

// MARK: - API response models

private struct TokenResponse: Decodable {
    let accessToken: String
    let expiresIn: Int
    let refreshToken: String?
    let idToken: String?
}

private struct UserInfoResponse: Decodable {
    let email: String?
}

private struct CalendarEventResponse: Decodable {
    let id: String?
    let hangoutLink: String?
    let conferenceData: ConferenceData?

    struct ConferenceData: Decodable {
        let entryPoints: [EntryPoint]?

        struct EntryPoint: Decodable {
            let entryPointType: String?
            let uri: String?
        }
    }
}

// MARK: - Base64URL

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
