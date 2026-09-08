//
//  EmojiDominantColor.swift
//  touchtime
//
//  The dominant vibrant colour of a countdown's cover emoji, used as the
//  fill behind the app's countdown cards and the Countdown widget. Shared
//  so both render the exact same colour for the same emoji.
//

import SwiftUI
import UIKit

struct EmojiDominantColor {
    let hue: CGFloat
    let saturation: CGFloat
    let brightness: CGFloat

    var color: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    /// The bitmap analysis is not free and the Home card re-renders every
    /// second, so computed colours are memoised per emoji. Main-thread
    /// only, like all SwiftUI body evaluation.
    private static var cache: [String: EmojiDominantColor?] = [:]

    static func cached(for emoji: String) -> EmojiDominantColor? {
        if let cached = cache[emoji] {
            return cached
        }
        let value = compute(for: emoji)
        cache[emoji] = value
        return value
    }

    /// Downsamples the emoji into a small bitmap and picks its dominant
    /// vibrant colour: each pixel votes for a hue bucket, weighted by how
    /// saturated and bright it is, so a colourful accent wins instead of
    /// the muddy average of every pixel. Falls back to grey for
    /// monochrome emojis.
    static func compute(for emoji: String) -> EmojiDominantColor? {
        let font = UIFont.systemFont(ofSize: 64)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let string = emoji as NSString
        let size = string.size(withAttributes: attributes)
        guard size.width > 0, size.height > 0 else { return nil }

        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            string.draw(at: .zero, withAttributes: attributes)
        }
        guard let cgImage = image.cgImage else { return nil }

        // Downsample to a small square; colour statistics don't need detail.
        let dimension = 32
        guard let context = CGContext(
            data: nil,
            width: dimension,
            height: dimension,
            bitsPerComponent: 8,
            bytesPerRow: dimension * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: dimension, height: dimension))
        guard let data = context.data else { return nil }

        let pixels = data.bindMemory(to: UInt8.self, capacity: dimension * dimension * 4)

        let bucketCount = 12
        var bucketWeight = [CGFloat](repeating: 0, count: bucketCount)
        var bucketHue = [CGFloat](repeating: 0, count: bucketCount)
        var bucketSaturation = [CGFloat](repeating: 0, count: bucketCount)
        var bucketBrightness = [CGFloat](repeating: 0, count: bucketCount)
        var greyWeight: CGFloat = 0
        var greyBrightness: CGFloat = 0

        for index in stride(from: 0, to: dimension * dimension * 4, by: 4) {
            let alpha = CGFloat(pixels[index + 3]) / 255
            guard alpha > 0.3 else { continue }

            // Un-premultiply
            let red = min(CGFloat(pixels[index]) / 255 / alpha, 1)
            let green = min(CGFloat(pixels[index + 1]) / 255 / alpha, 1)
            let blue = min(CGFloat(pixels[index + 2]) / 255 / alpha, 1)

            let maxChannel = max(red, green, blue)
            let minChannel = min(red, green, blue)
            let delta = maxChannel - minChannel

            let brightness = maxChannel
            let saturation = maxChannel == 0 ? 0 : delta / maxChannel

            // Washed-out or very dark pixels only count towards the grey fallback.
            guard saturation > 0.2, brightness > 0.2 else {
                greyWeight += alpha
                greyBrightness += brightness * alpha
                continue
            }

            var hue: CGFloat
            if maxChannel == red {
                hue = ((green - blue) / delta).truncatingRemainder(dividingBy: 6)
            } else if maxChannel == green {
                hue = (blue - red) / delta + 2
            } else {
                hue = (red - green) / delta + 4
            }
            hue /= 6
            if hue < 0 { hue += 1 }

            // Vibrant pixels get a louder vote.
            let weight = alpha * saturation * brightness
            let bucket = min(bucketCount - 1, Int(hue * CGFloat(bucketCount)))
            bucketWeight[bucket] += weight
            bucketHue[bucket] += hue * weight
            bucketSaturation[bucket] += saturation * weight
            bucketBrightness[bucket] += brightness * weight
        }

        if let winner = bucketWeight.indices.max(by: { bucketWeight[$0] < bucketWeight[$1] }),
           bucketWeight[winner] > 0 {
            let weight = bucketWeight[winner]
            let hue = bucketHue[winner] / weight
            let saturation = bucketSaturation[winner] / weight
            let brightness = bucketBrightness[winner] / weight
            // Clamp into a range that stays vivid but keeps white text readable.
            return EmojiDominantColor(
                hue: hue,
                saturation: min(max(saturation * 1.15, 0.45), 0.9),
                brightness: min(max(brightness, 0.45), 0.8)
            )
        }

        guard greyWeight > 0 else { return nil }
        return EmojiDominantColor(
            hue: 0,
            saturation: 0,
            brightness: min(max(greyBrightness / greyWeight, 0.3), 0.6)
        )
    }
}
