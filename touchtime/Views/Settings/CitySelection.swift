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
    
    var body: some View {
        List {
            // Master Toggle Section
            Section {
                Toggle(isOn: $showCitiesInNotes) {
                    Text("Show Time in Notes")
                }
            } footer: {
                Text("Add selected cities and times to event notes.")
            }
            
            // City Selection Section
            if showCitiesInNotes {
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
