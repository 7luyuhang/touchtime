//
//  AboutView.swift
//  touchtime
//
//  Created on 28/12/2025.
//

import SwiftUI

struct AboutView: View {
    
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
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
                .frame(maxWidth: .infinity, alignment: .center)
                .listRowBackground(Color.clear)
            
            Section {
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
            }
            
            // Credits Section
            Section {
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
