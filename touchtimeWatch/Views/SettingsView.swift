//
//  SettingsView.swift
//  touchtimeWatch
//

import SwiftUI

/// How many cities the iPhone sent, the 24-Hour Format setting, and the
/// app's version.
struct SettingsView: View {
    @Environment(WatchCityStore.self) private var cityStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(WatchTimeFormat.use24HourFormatKey) private var use24HourFormat = WatchTimeFormat.systemUses24HourFormat
    @State private var showsCitiesAlert = false

    /// The version and build, like "2.1.4 (223)", as in the iPhone app's About.
    private var version: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Button("\(cityStore.cities.count) Cities") {
                    showsCitiesAlert = true
                }

                Toggle("24-Hour Format", isOn: $use24HourFormat)

                HStack(spacing: 10) {
                    Image("TouchTimeAppIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 0) {
                        Text(verbatim: "Touch Time")
                        Text(verbatim: version)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                }
                .accessibilityElement(children: .combine)
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", systemImage: "xmark") {
                        dismiss()
                    }
                }
            }
            .alert(Text(verbatim: ""), isPresented: $showsCitiesAlert, actions: {}) {
                Text("Add, delete or arrange cities on iPhone.")
            }
        }
    }
}
