//
//  CitySelectionSheet.swift
//  touchtime
//
//  Created on 10/10/2025.
//

import SwiftUI
import UIKit

struct CitySelectionSheet: View {
    let worldClocks: [WorldClock]
    @Binding var selectedCitiesForNotes: String
    @Binding var showCitiesInNotes: Bool
    @State private var selectedIds: Set<String> = []
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    
    private var exampleText: String {
        let now = Date()
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        let time = timeFormatter.string(from: now)
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE, MMM d"
        let date = dateFormatter.string(from: now)
        
        return "Time in location: \(time) · \(date)"
    }
    
    var body: some View {
        List {
            // Master Toggle Section
            Section {
                Toggle(isOn: $showCitiesInNotes) {
                    Text("Show Time in Notes")
                }
                .tint(.blue)
                .disabled(worldClocks.isEmpty)
                
            } footer: {
                if worldClocks.isEmpty {
                    HStack(spacing: 4) {
                        Text("Tap")
                        Image(systemName: "magnifyingglass")
                            .fontWeight(.medium)
                        Text("and add cities first to enable.")
                    }
                } else {
                    Text("Add selected cities and times to event notes.")
                }
            }
            
            // Example Note Section (shown when off)
            if !showCitiesInNotes {
                Section {
                        Text(exampleText)
                            .foregroundStyle(.secondary)
                } header: {
                    Text("Example")
                }
            }
            
            // City Selection Section
            if showCitiesInNotes && !worldClocks.isEmpty {
                Section {
                    ForEach(worldClocks) { clock in
                        Button(action: {
                            toggleSelection(for: clock.id.uuidString)
                            
                            if hapticEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                            }
                        }) {
                            HStack {
                                Text(clock.cityName)
                                
                                Spacer()
                                
                                if selectedIds.contains(clock.id.uuidString) {
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
                }
            }
        }
        .navigationTitle("Time in Notes")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadSelection()
            // Auto-disable if no cities available
            if worldClocks.isEmpty && showCitiesInNotes {
                showCitiesInNotes = false
            }
        }
        .onChange(of: selectedIds) {
            saveSelection()
        }
    }
    
    private func toggleSelection(for id: String) {
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }
    
    private func loadSelection() {
        let ids = selectedCitiesForNotes.split(separator: ",").map { String($0) }
        selectedIds = Set(ids)
    }
    
    private func saveSelection() {
        selectedCitiesForNotes = Array(selectedIds).joined(separator: ",")
    }
}
