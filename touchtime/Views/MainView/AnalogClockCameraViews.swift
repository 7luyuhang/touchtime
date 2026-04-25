//
//  AnalogClockCameraViews.swift
//  touchtime
//
//  Extracted from AnalogClockFullView.swift for camera UI organization.
//

import SwiftUI
import AVFoundation
import UIKit

struct AnalogClockCameraBackgroundLayer: View {
    let isCameraBackgroundEnabled: Bool
    let staticCameraFrame: UIImage?
    let cameraSession: AVCaptureSession
    let cameraSaturation: Double
    let cameraContrast: Double
    let isBlurFilterEnabled: Bool
    let showSkyDot: Bool
    let skyGradient: SkyColorGradient
    let selectedTimeZoneIdentifier: String

    var body: some View {
        Group {
            if isCameraBackgroundEnabled {
                Group {
                    if let staticFrame = staticCameraFrame {
                        Color.clear
                            .overlay {
                                Image(uiImage: staticFrame)
                                    .resizable()
                                    .scaledToFill()
                            }
                            .clipped()
                            .ignoresSafeArea()
                    } else {
                        CameraBackgroundView(session: cameraSession)
                            .ignoresSafeArea()
                    }
                }
                .saturation(cameraSaturation)
                .contrast(cameraContrast)
            } else {
                if showSkyDot {
                    ZStack {
                        skyGradient.linearGradient()
                            .ignoresSafeArea()
                            .opacity(0.65)
                            .animation(.spring(), value: selectedTimeZoneIdentifier)

                        // Stars overlay for nighttime.
                        if skyGradient.starOpacity > 0 {
                            StarsView(starCount: 150)
                                .ignoresSafeArea()
                                .opacity(skyGradient.starOpacity)
                                .blendMode(.plusLighter)
                                .animation(.spring(), value: skyGradient.starOpacity)
                                .allowsHitTesting(false)
                        }
                    }
                } else {
                    Color(UIColor.systemBackground)
                        .ignoresSafeArea()
                }
            }
        }
        .overlay {
            if isCameraBackgroundEnabled && isBlurFilterEnabled {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .animation(.spring(), value: showSkyDot)
        .animation(.spring(), value: isCameraBackgroundEnabled)
    }
}

struct AnalogClockCameraCaptureButton: View {
    let isVisible: Bool
    let action: () -> Void

    var body: some View {
        Group {
            if isVisible {
                Button(action: action) {
                    ZStack {
                        Circle()
                            .strokeBorder(.white, lineWidth: 2.5)
                        Circle()
                            .fill(.white)
                            .padding(5)
                    }
                    .frame(width: 52, height: 52)
                }
                .buttonStyle(.plain)
                .contentShape(Circle())
                .padding(.trailing, 20)
                .padding(.bottom, 12)
                .offset(y: -75)
                .transition(.blurReplace().combined(with: .opacity).combined(with: .scale(0.95)))
            }
        }
    }
}

struct AnalogClockCameraCloseButton: View {
    let isVisible: Bool
    let action: () -> Void

    var body: some View {
        Group {
            if isVisible {
                Button(action: action) {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.primary)
                }
                .frame(width: 52, height: 52)
                .glassEffect(.regular.interactive())
                .buttonStyle(.plain)
                .contentShape(Circle())
                .padding(.leading, 20)
                .padding(.bottom, 12)
                .offset(y: -75)
                .transition(.blurReplace().combined(with: .opacity).combined(with: .scale(0.95)))
            }
        }
    }
}

struct AnalogClockCameraToolbarControls: View {
    let isCameraBackgroundEnabled: Bool
    let isStandardSelected: Bool
    let isBlurSelected: Bool
    let isBlackAndWhiteSelected: Bool
    let onSelectStandard: () -> Void
    let onSelectBlur: () -> Void
    let onSelectBlackAndWhite: () -> Void
    let onEnableCamera: () -> Void

    var body: some View {
        if isCameraBackgroundEnabled {
            Menu {
                Section("Camera Filter") {
                    Button(action: onSelectStandard) {
                        if isStandardSelected {
                            Label("Standard", systemImage: "checkmark.circle")
                        } else {
                            Text("Standard")
                        }
                    }
                    Button(action: onSelectBlur) {
                        if isBlurSelected {
                            Label("Blur", systemImage: "checkmark.circle")
                        } else {
                            Text("Blur")
                        }
                    }
                    Button(action: onSelectBlackAndWhite) {
                        if isBlackAndWhiteSelected {
                            Label("Black and White", systemImage: "checkmark.circle")
                        } else {
                            Text("Black and White")
                        }
                    }
                }
            } label: {
                Image(systemName: "camera.filters")
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: onEnableCamera) {
                Image(systemName: "camera.aperture")
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
    }
}
