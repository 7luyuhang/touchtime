//
//  SharedCountdownInbox.swift
//  touchtime
//
//  Countdown files opened in Touch Time, held until the main screen is up
//  and then shown in the New Countdown editor.
//

import Combine
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Bridges countdown files opened from AirDrop, Messages, Mail or Files
/// into the SwiftUI hierarchy. A file is read as it arrives and waits here
/// until ContentView's tab bar is on screen, so one opened during
/// onboarding comes up once onboarding is done.
final class SharedCountdownInbox: ObservableObject {
    static let shared = SharedCountdownInbox()

    /// The countdown last opened, ready for the editor, or why it couldn't
    /// be read. ContentView shows it and clears it.
    @Published var received: Result<CountdownItem, SharedCountdown.ReadError>?

    private init() {}

    /// Reads a file the app was asked to open.
    func open(_ url: URL) {
        guard url.isFileURL,
              UTType(filenameExtension: url.pathExtension)?.conforms(to: .touchTimeCountdown) == true else { return }
        let isAccessingSecurityScope = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessingSecurityScope {
                url.stopAccessingSecurityScopedResource()
            }
            removeReceivedCopy(at: url)
        }
        do throws(SharedCountdown.ReadError) {
            received = .success(try SharedCountdown.draft(fromFileAt: url))
        } catch {
            received = .failure(error)
        }
    }

    /// Deletes the copy the system made for the app, in Documents/Inbox
    /// or tmp, since the app doesn't open files in place. A file anywhere
    /// else isn't the app's to delete.
    private func removeReceivedCopy(at url: URL) {
        let path = url.resolvingSymlinksInPath().path(percentEncoded: false)
        let copyFolders = [URL.documentsDirectory.appending(path: "Inbox", directoryHint: .isDirectory), URL.temporaryDirectory]
            .map { $0.resolvingSymlinksInPath().path(percentEncoded: false) }
            .map { $0.hasSuffix("/") ? $0 : $0 + "/" }
        guard copyFolders.contains(where: { path.hasPrefix($0) }) else { return }
        try? FileManager.default.removeItem(at: url)
    }
}

// MARK: - Presentation

extension SharedCountdownInbox {
    /// Shows a received countdown in the New Countdown editor, which adds
    /// it to `store`, or explains why the file couldn't be opened.
    /// Presented over whatever is on screen: the file can arrive while a
    /// sheet is up, and a SwiftUI sheet only comes up from a view that
    /// isn't presenting one already.
    static func present(_ received: Result<CountdownItem, SharedCountdown.ReadError>, addingTo store: CountdownStore) {
        let viewController: UIViewController
        switch received {
        case .success(let draft):
            viewController = UIHostingController(rootView: editor(for: draft, addingTo: store))
        case .failure(let error):
            let alert = UIAlertController(title: String(localized: "Can't Open Countdown"), message: error.message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: String(localized: "OK"), style: .default))
            viewController = alert
        }
        // The app is dark-only; the window may not have been switched yet
        // when a file opens the app.
        viewController.overrideUserInterfaceStyle = .dark
        presentOverEverything(viewController)
    }

    private static func editor(for draft: CountdownItem, addingTo store: CountdownStore) -> some View {
        CountdownDetailsView(draft: draft) { title, targetDate, emoji, photoData, photoCrop, isPinned, repeatFrequency, reminderTime, reminderCity, reminderLeadDays, reminderKind, contact, scheduledMessage, pausedAt in
            let countdown = CountdownItem(
                id: UUID(),
                title: title,
                targetDate: targetDate,
                createdAt: Date(),
                isPinned: isPinned,
                repeatFrequency: repeatFrequency,
                emoji: emoji,
                photoData: photoData,
                photoCrop: photoCrop,
                reminderTime: reminderTime,
                reminderCity: reminderCity,
                reminderLeadDays: reminderLeadDays,
                reminderKind: reminderKind,
                contact: contact,
                scheduledMessage: scheduledMessage,
                pausedAt: pausedAt
            )
            withAnimation(.spring()) {
                store.countdowns.append(countdown)
            }
        }
        .environment(store)
    }

    /// Presents from the topmost view controller of the active window.
    private static func presentOverEverything(_ viewController: UIViewController) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        guard var presenter = (scene?.keyWindow ?? scene?.windows.first)?.rootViewController else { return }
        while let presented = presenter.presentedViewController, !presented.isBeingDismissed {
            presenter = presented
        }
        presenter.present(viewController, animated: true)
    }
}
