//
//  SettingsView.swift
//  touchtimeWatch
//

import SwiftUI

/// The 24-Hour Format and Additional Time settings, how many cities the
/// iPhone sent, a link to share the app, and the app's version.
struct SettingsView: View {
    @Environment(WatchCityStore.self) private var cityStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(WatchTimeFormat.use24HourFormatKey) private var use24HourFormat = WatchTimeFormat.systemUses24HourFormat
    @AppStorage(AdditionalTime.storageKey) private var additionalTime: AdditionalTime = .timeShift

    /// The version and build, like "2.1.4 (223)", as in the iPhone app's About.
    private var version: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            List {
                Toggle("24-Hour Format", isOn: $use24HourFormat)

                Picker("Additional Time", selection: $additionalTime) {
                    ForEach(AdditionalTime.allCases) { option in
                        Text(option.title)
                            .tag(option)
                    }
                }
                .pickerStyle(.navigationLink)

                Section {
                    Text("\(cityStore.cities.count) Cities Added")
                } footer: {
                    Text("Add, delete or arrange cities on iPhone.")
                }

                ShareLink(
                    item: URL(string: "https://apps.apple.com/us/app/touch-time-world-clock/id6753721487")!,
                    message: Text("Download Touch Time.")
                ) {
                    Text("Share with Friends")
                }

                VStack(spacing: 10) {
                    Image("TouchTimeAppIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 32, height: 32)
                        .accessibilityHidden(true)

                    VStack(spacing: 0) {
                        Text(verbatim: "Touch Time")
                        Text(verbatim: version)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                }
                .padding(.top, 16)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
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
        }
    }
}
