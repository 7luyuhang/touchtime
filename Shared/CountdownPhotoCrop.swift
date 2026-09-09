//
//  CountdownPhotoCrop.swift
//  touchtime
//
//  How a countdown's cover photo is framed inside its circular badge, and
//  the square of the photo that framing picks out. Shared so the app's
//  cards and the Countdown widget show exactly what the cover sheet's
//  photo editor framed.
//

import UIKit

extension CountdownItem {
    /// Framing of the cover photo in the badge, as set in the cover sheet's
    /// photo editor. Independent of any view size: `scale` is the zoom on
    /// top of the photo just covering the circle, `offset` the photo's
    /// shift off centre as a fraction of the circle's diameter. The stored
    /// photo is left as picked, so the framing can be changed again later.
    struct PhotoCrop: Codable, Hashable {
        var scale: CGFloat
        var offset: CGSize

        /// The square the circle sees, in the photo's own pixels: one
        /// diameter is the shorter side over the zoom, centred opposite
        /// the shift.
        func cropRect(in imageSize: CGSize) -> CGRect {
            let side = min(imageSize.width, imageSize.height) / scale
            return CGRect(
                x: imageSize.width / 2 - offset.width * side - side / 2,
                y: imageSize.height / 2 - offset.height * side - side / 2,
                width: side,
                height: side
            )
        }

        /// The framed square cut from `image` at the photo's own
        /// resolution. Everything that shows the photo (badge, blurred card
        /// background, widget) draws this instead of the full photo, so a
        /// `scaledToFill` into a circle lands on the framed region.
        func croppedImage(from image: UIImage) -> UIImage {
            let cropRect = cropRect(in: image.size)
            let outputSide = cropRect.width.rounded()
            guard outputSide >= 1 else { return image }
            let drawScale = outputSide / cropRect.width

            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            return UIGraphicsImageRenderer(size: CGSize(width: outputSide, height: outputSide), format: format).image { _ in
                image.draw(in: CGRect(
                    x: -cropRect.minX * drawScale,
                    y: -cropRect.minY * drawScale,
                    width: image.size.width * drawScale,
                    height: image.size.height * drawScale
                ))
            }
        }
    }
}
