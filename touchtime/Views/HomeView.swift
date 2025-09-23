//
//  HomeView.swift
//  touchtime
//
//  Created on 23/09/2025.
//

import SwiftUI
import Combine

struct HomeView: View {
    @State private var worldClocks: [WorldClock] = []
    @State private var currentDate = Date()
    @State private var showingAddClock = false
    @State private var timeOffset: TimeInterval = 0
    
    @AppStorage("use24HourFormat") private var use24HourFormat = false
    @AppStorage("showTimeDifference") private var showTimeDifference = true
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    // UserDefaults key for storing world clocks
    private let worldClocksKey = "savedWorldClocks"
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                // Main List Content
                List {
                    ForEach(worldClocks) { clock in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(clock.cityName)
                                    .font(.headline)
                                if showTimeDifference && !clock.timeDifference.isEmpty {
                                    Text(clock.timeDifference)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(clock.currentTime(use24Hour: use24HourFormat, offset: timeOffset))
                                .font(.title2)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                            
                            Text(clock.currentDate(offset: timeOffset))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .contentTransition(.numericText())
                        }
                        }
                        .padding(.vertical, 2)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                if let index = worldClocks.firstIndex(where: { $0.id == clock.id }) {
                                    worldClocks.remove(at: index)
                                    saveWorldClocks()
                                }
                            } label: {
                                Label("", systemImage: "trash")
                            }
                        }
                        .contextMenu {
                            if let index = worldClocks.firstIndex(where: { $0.id == clock.id }), index != 0 {
                                Button(action: {
                                    // Move to top
                                    withAnimation {
                                        let clockToMove = worldClocks.remove(at: index)
                                        worldClocks.insert(clockToMove, at: 0)
                                        saveWorldClocks()
                                    }
                                }) {
                                    Label("Move to Top", systemImage: "arrow.up.to.line")
                                }
                            }
                            
                            Button(role: .destructive, action: {
                                // Delete
                                if let index = worldClocks.firstIndex(where: { $0.id == clock.id }) {
                                    withAnimation {
                                        worldClocks.remove(at: index)
                                        saveWorldClocks()
                                    }
                                }
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                    .onMove(perform: moveClocks)
                    
                    
                }
                
                // Scroll Time View at the bottom
                ScrollTimeView(timeOffset: $timeOffset)
                    .padding(.horizontal)
                    .padding(.bottom, 16)



            }
            .navigationTitle("Touch Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showingAddClock = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showingAddClock) {
                TimeZonePickerView(worldClocks: $worldClocks)
                    .onDisappear {
                        saveWorldClocks()
                    }
            }
            .onReceive(timer) { _ in
                currentDate = Date()
            }
            .onAppear {
                loadWorldClocks()
            }
        }
    }
    
    // Move function
    func moveClocks(from source: IndexSet, to destination: Int) {
        worldClocks.move(fromOffsets: source, toOffset: destination)
        saveWorldClocks()
    }
    
    // Save world clocks to UserDefaults
    func saveWorldClocks() {
        if let encoded = try? JSONEncoder().encode(worldClocks) {
            UserDefaults.standard.set(encoded, forKey: worldClocksKey)
        }
    }
    
    // Load world clocks from UserDefaults
    func loadWorldClocks() {
        if let data = UserDefaults.standard.data(forKey: worldClocksKey),
           let decoded = try? JSONDecoder().decode([WorldClock].self, from: data) {
            worldClocks = decoded
        } else {
            // 如果没有保存的数据，使用默认时钟
            worldClocks = WorldClockData.defaultClocks
            saveWorldClocks() // 保存默认数据
        }
    }
}

#Preview {
    HomeView()
}
