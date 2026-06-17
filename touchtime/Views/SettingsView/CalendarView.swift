//
//  CalendarView.swift
//  touchtime
//
//  Created on 23/09/2025.
//

import SwiftUI
import EventKit
import UIKit

struct CalendarView: View {
    let worldClocks: [WorldClock]
    @AppStorage("defaultEventDuration") private var defaultEventDuration: Double = 3600 // Default 1 hour in seconds
    @AppStorage("showCitiesInNotes") private var showCitiesInNotes = true
    @AppStorage("selectedCitiesForNotes") private var selectedCitiesForNotes: String = ""
    @AppStorage("selectedCalendarIdentifier") private var selectedCalendarIdentifier: String = ""
    @AppStorage("addMeetLinkToEvents") private var addMeetLinkToEvents = false
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @State private var eventStore = EKEventStore()
    @State private var availableCalendars: [EKCalendar] = []
    @State private var hasCalendarPermission = false
    @State private var showDisconnectConfirmation = false
    @ObservedObject private var googleMeet = GoogleMeetManager.shared
    
    // Get city count text for Notes setting
    func getCityCountText() -> String {
        if !showCitiesInNotes {
            return ""
        }
        
        let selectedIds = selectedCitiesForNotes.split(separator: ",").map { String($0) }
        // Filter to only count cities that still exist in worldClocks
        let existingIds = worldClocks.map { $0.id.uuidString }
        let validSelectedIds = selectedIds.filter { !$0.isEmpty && existingIds.contains($0) }
        let count = validSelectedIds.count
        
        if count == 0 {
            return ""
        } else if count == 1 {
            return String(localized: "1 City")
        } else {
            return String(format: String(localized: "%d Cities"), count)
        }
    }
    
    // Load available calendars
    func loadCalendars() {
        eventStore.requestFullAccessToEvents { granted, error in
            DispatchQueue.main.async {
                self.hasCalendarPermission = granted
                if granted {
                    self.availableCalendars = self.eventStore.calendars(for: .event)
                        .filter { $0.allowsContentModifications }
                        .sorted {
                            // Sort by source title first, then by calendar title
                            if $0.source.title == $1.source.title {
                                return $0.title < $1.title
                            }
                            return $0.source.title < $1.source.title
                        }
                    
                    // If no calendar is selected, set to default
                    if self.selectedCalendarIdentifier.isEmpty || !self.availableCalendars.contains(where: { $0.calendarIdentifier == self.selectedCalendarIdentifier }) {
                        if let defaultCalendar = self.eventStore.defaultCalendarForNewEvents {
                            self.selectedCalendarIdentifier = defaultCalendar.calendarIdentifier
                        }
                    }
                } else {
                    self.availableCalendars = []
                }
            }
        }
    }
    
    // Get selected calendar or default
    var selectedCalendar: EKCalendar? {
        if let calendar = availableCalendars.first(where: { $0.calendarIdentifier == selectedCalendarIdentifier }) {
            return calendar
        }
        return eventStore.defaultCalendarForNewEvents
    }
    
    var body: some View {
        List {
            if hasCalendarPermission {
                // Default Calendar Selection
                if !availableCalendars.isEmpty {
                    NavigationLink(destination: CalendarSelectionView(
                        availableCalendars: availableCalendars,
                        selectedCalendarIdentifier: $selectedCalendarIdentifier
                    )) {
                        HStack {
                            HStack(spacing: 12) {
                                SystemIconImage(systemName: "ellipsis.calendar", topColor: .gray, bottomColor: .gray, style: .plain)
                                Text("Default Calendar")
                            }
                            .layoutPriority(1)
                            
                            Spacer(minLength: 8)
                            
                            Text(selectedCalendar?.title ?? "None")
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
                
                Section {
                    // Event Duration
                    Picker(selection: $defaultEventDuration) {
                        Text("15 min", comment: "Event duration option").tag(900.0)
                        Text("30 min", comment: "Event duration option").tag(1800.0)
                        Text("45 min", comment: "Event duration option").tag(2700.0)
                        Text("1 hr", comment: "Event duration option").tag(3600.0)
                        Text("2 hrs", comment: "Event duration option").tag(7200.0)
                    } label: {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "clock.fill", topColor: .gray, bottomColor: .gray, style: .plain)
                            Text("Event Duration")
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(.secondary)
                    
                    // Show cities in note
                    NavigationLink(destination: CitySelectionSheet(
                        worldClocks: worldClocks,
                        selectedCitiesForNotes: $selectedCitiesForNotes,
                        showCitiesInNotes: $showCitiesInNotes
                    )) {
                        HStack {
                            HStack(spacing: 12) {
                                SystemIconImage(systemName: "pencil.tip.crop.circle.fill", topColor: .gray, bottomColor: .gray, style: .plain)
                                Text("Time in Notes")
                            }
                            Spacer()
                            Text(getCityCountText())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } else {
                // No calendar permission
                Text("Need full calendar access.")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack(spacing: 12) {
                        SystemIconImage(systemName: "gear", topColor: .gray, bottomColor: .gray, style: .plain)
                        Text("Go to Settings")
                    }
                }
                .foregroundStyle(.primary)
            }

            googleMeetSection
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCalendars()
        }
        .alert("Google Meet", isPresented: Binding(
            get: { googleMeet.errorMessage != nil },
            set: { if !$0 { googleMeet.errorMessage = nil } }
        )) {
            Button(String(localized: "OK"), role: .cancel) {
                googleMeet.errorMessage = nil
            }
        } message: {
            Text(googleMeet.errorMessage ?? "")
        }
        .alert(String(localized: "Disconnect Google Account?"), isPresented: $showDisconnectConfirmation) {
            Button(String(localized: "Cancel"), role: .cancel) { }
            Button(String(localized: "Disconnect"), role: .destructive) {
                if hapticEnabled {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                googleMeet.signOut()
            }
        } message: {
            Text("Meet links will no longer be added to new events.")
        }
    }

    // MARK: - Google Meet

    /// Custom URL scheme used only to make the inline "Disconnect" link tappable.
    private static let disconnectURLScheme = "touchtime-meet-disconnect"

    /// Footer text whose trailing "Disconnect" word is an inline, tappable link
    /// that flows right after the sentence.
    private func connectedFooterText(email: String) -> AttributedString {
        var text = AttributedString(String(format: String(localized: "Connected with %@."), email))
        text.append(AttributedString(" "))

        var disconnect = AttributedString(String(localized: "Disconnect"))
        disconnect.link = URL(string: "\(Self.disconnectURLScheme)://disconnect")
        disconnect.inlinePresentationIntent = .stronglyEmphasized
        text.append(disconnect)

        return text
    }

    @ViewBuilder
    private var googleMeetSection: some View {
        Section {
            if googleMeet.isSignedIn {
                // Toggle: include a Meet link in new events
                Toggle(isOn: $addMeetLinkToEvents) {
                    HStack(spacing: 12) {
                        SystemIconImage(systemName: "plus.circle.fill", topColor: .gray, bottomColor: .gray, style: .plain)
                        Text("Add to Event Notes")
                    }
                }
                .tint(.blue)
            } else {
                // Connect account button
                Button(action: {
                    if hapticEnabled {
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
                    Task { await googleMeet.signIn() }
                }) {
                    HStack {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "video.circle.fill", topColor: .gray, bottomColor: .gray, style: .plain)
                            Text("Add Google Meet Link")
                        }
                        .layoutPriority(1)

                        Spacer(minLength: 8)

                        if googleMeet.isAuthenticating {
                            ProgressView()
                        }
                    }
                }
                .foregroundStyle(.primary)
                .disabled(googleMeet.isAuthenticating)
            }
        } header: {
            Text("Video Call")
        } footer: {
            if googleMeet.isSignedIn {
                Text(connectedFooterText(email: googleMeet.email ?? String(localized: "Google Account")))
                    .tint(.white)
                    .environment(\.openURL, OpenURLAction { url in
                        guard url.scheme == Self.disconnectURLScheme else { return .systemAction }
                        if hapticEnabled {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                        showDisconnectConfirmation = true
                        return .handled
                    })
            } else {
                Text("Connect your Google account to add a Meet link to new events.")
            }
        }
    }
}
