//
//  AboutView.swift
//  touchtime
//
//  Created on 28/12/2025.
//

import SwiftUI
import SafariServices

struct AboutView: View {
    @Binding var worldClocks: [WorldClock]
    @ObservedObject var weatherManager: WeatherManager
    @State private var showOnboarding = false
    @State private var showResetConfirmation = false
    @AppStorage("hapticEnabled") private var hapticEnabled = true
    @State private var rippleCounter: Int = 0
    @State private var rippleOrigin: CGPoint = .init(x: 50, y: 50)
    @State private var safariURL: URL?
    
    // UserDefaults keys
    private let worldClocksKey = "savedWorldClocks"
    private let collectionsKey = "savedCityCollections"
    
    // Get current language display name
    var currentLanguageName: String {
        let preferredLanguage = Bundle.main.preferredLocalizations.first ?? "en"
        switch preferredLanguage {
        case "zh-Hans":
            return "简体中文"
        case "zh-Hant":
            return "繁體中文"
        case "en":
            return "English"
        default:
            return "English"
        }
    }
    
    var body: some View {
        List {
            VStack(spacing: 16){
                Image("TouchTimeAppIcon")
                    .resizable()
                    .scaledToFit()
                    .glassEffect(.clear, in:
                                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                    )
                    .frame(width: 100, height: 100)
                    .modifier(RippleEffect(at: rippleOrigin, trigger: rippleCounter))
                    .modifier(PushEffect(trigger: rippleCounter))
                    .onPressingChanged { point in
                        if let point {
                            rippleOrigin = point
                            rippleCounter += 1
                            if hapticEnabled {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .soft)
                                impactFeedback.prepare()
                                impactFeedback.impactOccurred()
                            }
                        }
                    }
                
                VStack(spacing: 4) {
                    Text("Touch Time")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Text(getVersionString())
                        .foregroundColor(.secondary)
                }
            }
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
            
            Section {
                // Language
                Button(action: {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    HStack {
                        HStack(spacing: 12) {
                            SystemIconImage(systemName: "character", topColor: .gray, bottomColor: Color(UIColor.systemGray3))
                            Text("Language")
                        }
                        .layoutPriority(1)
                        Spacer(minLength: 8)
                        Text(currentLanguageName)
                            .foregroundStyle(.secondary)
                    }
                }
                .foregroundStyle(.primary)
                
                // Onboarding
                Button(action: {
                    showOnboarding = true
                }) {
                    HStack(spacing: 12) {
                        SystemIconImage(systemName: "sparkle.magnifyingglass", topColor: .blue, bottomColor: .pink)
                        Text("Show Onboarding")
                    }
                }
                .foregroundStyle(.primary)
                
                // Reset Cities
                Button(action: {
                    if hapticEnabled {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    }
                    showResetConfirmation = true
                }) {
                    HStack(spacing: 12) {
                        SystemIconImage(systemName: "arrowshape.backward.fill", topColor: .indigo, bottomColor: .orange)
                        Text("Reset Cities")
                    }
                }
                .foregroundStyle(.primary)
                .alert("Reset Cities", isPresented: $showResetConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button("Reset", role: .destructive) {
                        resetToDefault()
                    }
                } message: {
                    Text("This will reset all cities to the default list, clear any custom city names, and reset your collections.")
                }
            } footer: {
                Text("This will reset all cities to the default list, clear any custom city names, and reset your collections.")
            }
            
            // Credits Section
            Section {
                
                // Terms & Privacy
                Button {
                    safariURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                } label: {
                    HStack {
                        Text("Terms of Use")
                    }
                }
                .foregroundStyle(.primary)
                
                Button {
                    safariURL = URL(string: "https://www.handstime.app/privacy")
                } label: {
                    HStack {
                        Text("Privacy Policy")
                    }
                }
                .foregroundStyle(.primary)
                
                
                NavigationLink(destination: CreditsView()) {
                    Text("Acknowledgements")
                }
                
                // App Info Section
                Text(String(format: String(localized: "Copyright © %d Negative Time Limited. \nAll rights reserved."), Calendar.current.component(.year, from: Date())))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            
//            Section {
//                // Version
//                HStack {
//                    Text("Version")
//                    Spacer()
//                    Text(getVersionString())
//                        .foregroundColor(.secondary)
//                }
//            }
        }
        .scrollIndicators(.hidden)
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        // Onboarding
        .sheet(item: $safariURL) { url in
            SafariView(url: url)
                .ignoresSafeArea()
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(hasCompletedOnboarding: Binding(
                get: { !showOnboarding },
                set: { newValue in
                    if newValue {
                        showOnboarding = false
                    }
                }
            ), weatherManager: weatherManager)
            .overlay(alignment: .topTrailing) {
                Button(action: {
                    showOnboarding = false
                }) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .glassEffect(.clear.interactive())
                }
                .padding(.horizontal)
            }
        }
    }
    
    // Get version and build number string
    func getVersionString() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
    
    // Reset to default clocks
    func resetToDefault() {
        // Set to default clocks
        worldClocks = WorldClockData.defaultClocks
        
        // Save to UserDefaults
        if let encoded = try? JSONEncoder().encode(worldClocks) {
            UserDefaults.standard.set(encoded, forKey: worldClocksKey)
        }
        
        // Clear all collections
        UserDefaults.standard.removeObject(forKey: collectionsKey)
        
        // Clear selected collection
        UserDefaults.standard.removeObject(forKey: "selectedCollectionId")
        
        // Post notification to reset scroll time
        NotificationCenter.default.post(name: NSNotification.Name("ResetScrollTime"), object: nil)
        
        // Provide haptic feedback if enabled
        if hapticEnabled {
            let impactFeedback = UINotificationFeedbackGenerator()
            impactFeedback.prepare()
            impactFeedback.notificationOccurred(.success)
        }
    }
}

// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let safariVC = SFSafariViewController(url: url, configuration: config)
        return safariVC
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}

#Preview {
    AboutView(
        worldClocks: .constant([]),
        weatherManager: WeatherManager()
    )
}
