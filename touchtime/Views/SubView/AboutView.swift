//
//  AboutView.swift
//  touchtime
//
//  Created on 28/12/2025.
//

import SwiftUI

struct AboutView: View {
    @State private var showOnboarding = false
    
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
    
            }
            
            // Credits Section
            Section {
                
                // Terms & Privacy
                Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                    HStack {
                        Text("Terms of Use")
                    }
                }
                .foregroundStyle(.primary)
                
                Link(destination: URL(string: "https://www.handstime.app/privacy")!) {
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
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView(hasCompletedOnboarding: Binding(
                get: { !showOnboarding },
                set: { newValue in
                    if newValue {
                        showOnboarding = false
                    }
                }
            ))
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
}

#Preview {
    AboutView()
}
