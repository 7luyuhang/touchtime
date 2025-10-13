//
//  CalendarSelectionView.swift
//  touchtime
//
//  Created on 13/10/2025.
//

import SwiftUI
import EventKit
import UIKit

struct CalendarSelectionView: View {
    let availableCalendars: [EKCalendar]
    @Binding var selectedCalendarIdentifier: String
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    
    // Group calendars by source
    var groupedCalendars: [(source: EKSource, calendars: [EKCalendar])] {
        // Filter out calendars without sources
        let calendarsWithSources = availableCalendars.compactMap { calendar -> (EKCalendar, EKSource)? in
            guard let source = calendar.source else { return nil }
            return (calendar, source)
        }
        
        // Group by source
        let grouped = Dictionary(grouping: calendarsWithSources) { $0.1 }
        
        // Transform to the desired format
        return grouped
            .map { (source, pairs) in
                (source: source, calendars: pairs.map { $0.0 })
            }
            .sorted { $0.source.title < $1.source.title }
    }
    
    var body: some View {
        List {
            ForEach(groupedCalendars, id: \.source.sourceIdentifier) { group in
                Section {
                    ForEach(group.calendars, id: \.calendarIdentifier) { calendar in
                        Button(action: {
                            selectedCalendarIdentifier = calendar.calendarIdentifier
                            
                            if hapticEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }
                            
                            dismiss()
                        }) {
                            HStack {
                                Text(calendar.title)
                                Spacer()
                                if calendar.calendarIdentifier == selectedCalendarIdentifier {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .transition(.identity)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(group.source.title)
                }
            }
        }
        .navigationTitle("Default Calendar")
        .navigationBarTitleDisplayMode(.inline)
    }
}
