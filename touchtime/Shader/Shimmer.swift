//
//  Shimmer.swift
//  touchtime
//
//  A band of light that sweeps across a view over and over, moved by Core
//  Animation so the app does no work per frame.
//

import SwiftUI

/// Dims the view but for a band at full strength, which sweeps across it
/// from the top left corner to the bottom right, over and over. The view is
/// masked by a gradient layer and Core Animation moves the band, so the
/// sweep is drawn outside the app, which does no work per frame. With Reduce
/// Motion the view is left as it is.
private struct ShimmerEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.mask {
            if reduceMotion {
                Rectangle()
            } else {
                ShimmerMask()
            }
        }
    }
}

/// The shimmer's mask: faint all over but for an opaque band, which Core
/// Animation carries across it.
private struct ShimmerMask: UIViewRepresentable {
    func makeUIView(context: Context) -> SweepView {
        SweepView()
    }

    func updateUIView(_ view: SweepView, context: Context) {}

    final class SweepView: UIView {
        /// Seconds the band takes to cross the view.
        private static let period: CFTimeInterval = 1.5
        /// The band's width, as a fraction of the view's diagonal.
        private static let bandSize: CGFloat = 0.3
        /// How much of the view shows outside the band.
        private static let dimOpacity: CGFloat = 0.3

        override class var layerClass: AnyClass { CAGradientLayer.self }
        private var gradientLayer: CAGradientLayer { layer as! CAGradientLayer }

        /// The size the sweep was last set up for.
        private var sweepSize: CGSize = .zero

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            let dim = UIColor.black.withAlphaComponent(Self.dimOpacity).cgColor
            gradientLayer.colors = [dim, UIColor.black.cgColor, dim]
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            // The band's path depends on the view's shape
            if bounds.size != sweepSize {
                startSweep()
            }
        }

        /// Sets the band off from just before the top left corner to just
        /// past the bottom right one, over and over.
        private func startSweep() {
            sweepSize = bounds.size
            guard bounds.width > 0, bounds.height > 0 else { return }

            // The band lies square to the view's diagonal. A gradient layer
            // measures in unit space, though, where a view of any shape is a
            // square, so the band's far side is put where it comes out
            // square to the diagonal on screen.
            let band = Self.bandSize
            let widthSquared = bounds.width * bounds.width
            let heightSquared = bounds.height * bounds.height
            let reach = band * (widthSquared + heightSquared)
                / (widthSquared * widthSquared + heightSquared * heightSquared)
            let across = CGVector(dx: reach * widthSquared, dy: reach * heightSquared)

            let nearSideStart = CGPoint(x: -band, y: -band)
            let farSideStart = CGPoint(x: -band + across.dx, y: -band + across.dy)
            gradientLayer.startPoint = nearSideStart
            gradientLayer.endPoint = farSideStart

            let nearSide = CABasicAnimation(keyPath: #keyPath(CAGradientLayer.startPoint))
            nearSide.fromValue = nearSideStart
            nearSide.toValue = CGPoint(x: 1, y: 1)

            let farSide = CABasicAnimation(keyPath: #keyPath(CAGradientLayer.endPoint))
            farSide.fromValue = farSideStart
            farSide.toValue = CGPoint(x: 1 + across.dx, y: 1 + across.dy)

            let sweep = CAAnimationGroup()
            sweep.animations = [nearSide, farSide]
            sweep.duration = Self.period
            sweep.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            sweep.repeatCount = .infinity
            // Or the sweep would be gone once the view had left its window,
            // or the app the foreground
            sweep.isRemovedOnCompletion = false
            // Takes the place of any sweep already running
            gradientLayer.add(sweep, forKey: "sweep")
        }
    }
}

extension View {
    /// Dims the view but for a band at full strength that sweeps across it,
    /// over and over.
    func shimmering() -> some View {
        modifier(ShimmerEffect())
    }
}
