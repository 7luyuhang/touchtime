//
//  VariableBlurView.swift
//  touchtime
//
//  A blur over whatever lies behind it that grows from nothing at one edge
//  to its full radius at the other.
//

import SwiftUI

/// Blurs whatever lies behind it, more and more toward `edge`: not at all at
/// the opposite edge, the most at `edge`. The blur is Core Animation's
/// variable blur filter on a backdrop layer. Neither is public API, so both
/// are looked up by name, and where either is missing the view is simply
/// clear.
struct VariableBlurView: UIViewRepresentable {
    /// The filter's radius at `edge`, in points. The filter blurs about as
    /// much as `blur(radius:)` does at twice the radius.
    let maxRadius: CGFloat
    /// The edge the blur is strongest at.
    let edge: VerticalEdge

    func makeUIView(context: Context) -> BackdropView {
        BackdropView()
    }

    func updateUIView(_ view: BackdropView, context: Context) {
        view.setBlur(maxRadius: maxRadius, edge: edge)
    }

    final class BackdropView: UIView {
        /// Core Animation's names for the layer and the filter the blur is
        /// made of. As they aren't public API, they're pieced together here
        /// rather than written out whole.
        private enum CoreAnimationName {
            static let backdropLayer = ["CA", "Backdrop", "Layer"].joined()
            static let filter = ["CA", "Filter"].joined()
            static let filterWithType = ["filter", "With", "Type:"].joined()
        }

        /// How many steps the blur's strength rises in from one edge to the
        /// other.
        private static let rampSteps = 100

        override class var layerClass: AnyClass {
            NSClassFromString(CoreAnimationName.backdropLayer) ?? CALayer.self
        }

        /// The blur the layer has now.
        private var blur: (maxRadius: CGFloat, edge: VerticalEdge)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func setBlur(maxRadius: CGFloat, edge: VerticalEdge) {
            if let blur, blur == (maxRadius, edge) { return }
            blur = (maxRadius, edge)
            layer.filters = Self.makeFilter(maxRadius: maxRadius, edge: edge).map { [$0] }
        }

        /// Core Animation's variable blur, strongest at `edge`, or nil where
        /// it can't be had.
        private static func makeFilter(maxRadius: CGFloat, edge: VerticalEdge) -> NSObject? {
            let filterWithType = NSSelectorFromString(CoreAnimationName.filterWithType)
            guard let filterClass = NSClassFromString(CoreAnimationName.filter) as? NSObject.Type,
                  filterClass.responds(to: filterWithType),
                  let filter = filterClass.perform(filterWithType, with: "variableBlur")?
                      .takeUnretainedValue() as? NSObject,
                  let ramp = makeRamp(strongestAt: edge)
            else { return nil }

            filter.setValue(maxRadius, forKey: "inputRadius")
            filter.setValue(ramp, forKey: "inputMaskImage")
            // Keeps the blur from fading out along the layer's edges
            filter.setValue(true, forKey: "inputNormalizeEdges")
            return filter
        }

        /// The filter's mask, stretched over the layer: the more opaque it
        /// is, the stronger the blur there. One pixel wide, and from clear
        /// to opaque toward `edge`.
        private static func makeRamp(strongestAt edge: VerticalEdge) -> CGImage? {
            var pixels = [UInt8](repeating: 0, count: rampSteps * 4)
            for step in 0..<rampSteps {
                let fromTop = (CGFloat(step) + 0.5) / CGFloat(rampSteps)
                let strength = edge == .bottom ? fromTop : 1 - fromTop
                pixels[step * 4 + 3] = UInt8((strength * 255).rounded())
            }
            guard let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
            return CGImage(
                width: 1,
                height: rampSteps,
                bitsPerComponent: 8,
                bitsPerPixel: 32,
                bytesPerRow: 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                provider: provider,
                decode: nil,
                shouldInterpolate: true,
                intent: .defaultIntent
            )
        }
    }
}
