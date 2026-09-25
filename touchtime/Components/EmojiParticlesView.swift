//
//  EmojiParticlesView.swift
//  touchtime
//
//  Created on 30/08/2026.
//

import SwiftUI

/// Emoji particles floating up a card background: every bump of `burst`
/// spawns a handful of emojis that rise from the bottom edge with random
/// size, blur and sideways drift, dissolving before they reach the top.
/// Used behind the countdown editor's preview card whenever an emoji cover
/// is picked; place it behind content and clip it to the card.
struct EmojiParticlesView: View {
    /// Emojis each particle picks from at random; snapshotted into each
    /// particle so in-flight bursts keep their glyph when these change.
    let emojis: [String]
    /// Bumped by the parent; each change is one burst.
    let burst: Int
    /// Seconds a particle takes to rise through the view, picked per
    /// particle from this range; lower is faster.
    let riseDuration: ClosedRange<TimeInterval>
    /// For use without a clipping card: when set, particles keep clear of the
    /// view's sides and blur out to nothing over this distance below the top
    /// edge, gone before they reach it. Otherwise they fade over the last
    /// stretch of the rise and the card's clip trims them at its edges.
    let dissolveDistance: CGFloat?

    /// Blur a fully dissolved particle reaches, as a share of its glyph size.
    private static let dissolveBlurScale: CGFloat = 0.25

    /// Every particle shows `emoji`; nil spawns nothing.
    init(emoji: String?, burst: Int) {
        self.init(emojis: emoji.map { [$0] } ?? [], burst: burst)
    }

    /// Each particle shows one of `emojis`, picked at random.
    init(
        emojis: [String],
        burst: Int,
        riseDuration: ClosedRange<TimeInterval> = 1.0...2.0,
        dissolveDistance: CGFloat? = nil
    ) {
        self.emojis = emojis
        self.burst = burst
        self.riseDuration = riseDuration
        self.dissolveDistance = dissolveDistance
    }

    private struct Particle: Identifiable {
        let id = UUID()
        let emoji: String
        /// Launch time in seconds since the reference date.
        let birth: TimeInterval
        /// Horizontal launch position as a fraction of the card width.
        let xFraction: CGFloat
        /// Sideways drift over the whole rise, in points.
        let drift: CGFloat
        /// Glyph size in points.
        let size: CGFloat
        /// Gaussian blur radius: a mix of sharp and hazy particles.
        let blur: CGFloat
        /// Seconds from launch to the top of the card.
        let duration: TimeInterval
        /// Stagger before this particle launches.
        let delay: TimeInterval
    }

    @State private var particles: [Particle] = []

    var body: some View {
        TimelineView(.animation(paused: particles.isEmpty)) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                for particle in particles {
                    let elapsed = now - particle.birth - particle.delay
                    guard elapsed >= 0 else { continue }
                    let progress = elapsed / particle.duration
                    guard progress < 1 else { continue }

                    // Ease-out rise from just below the bottom edge to
                    // just past the top one.
                    let eased = 1 - pow(1 - progress, 2)
                    let travel = size.height + particle.size * 2
                    var x = particle.xFraction * size.width + particle.drift * eased
                    if dissolveDistance != nil {
                        // No card clip to hide the sides, so the glyph and its
                        // fullest blur stay inside them instead of being cut
                        let inset = particle.size / 2 + particle.blur + particle.size * Self.dissolveBlurScale
                        x = min(max(x, inset), size.width - inset)
                    }
                    let position = CGPoint(
                        x: x,
                        y: size.height + particle.size - travel * eased
                    )

                    // Quick fade in and cruise, then either blur out on the
                    // way to the top edge or fade over the last stretch.
                    let fadeIn = min(progress / 0.15, 1)
                    var fadeOut = progress < 0.6 ? 1 : (1 - progress) / 0.4
                    var blur = particle.blur
                    if let dissolveDistance {
                        let distanceToTop = position.y - particle.size / 2
                        let remaining = min(max(distanceToTop / dissolveDistance, 0), 1)
                        fadeOut = remaining
                        blur += (1 - remaining) * particle.size * Self.dissolveBlurScale
                    }

                    let opacity = fadeIn * fadeOut
                    guard opacity > 0 else { continue }

                    var layer = context
                    layer.opacity = opacity
                    if blur > 0.1 {
                        layer.addFilter(.blur(radius: blur))
                    }
                    layer.draw(
                        Text(particle.emoji).font(.system(size: particle.size)),
                        at: position
                    )
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: burst) { _, _ in
            spawnBurst()
        }
    }

    private func spawnBurst() {
        guard !emojis.isEmpty else { return }
        let now = Date().timeIntervalSinceReferenceDate
        let newParticles = (0..<Int.random(in: 10...15)).map { _ in
            Particle(
                emoji: emojis.randomElement()!,
                birth: now,
                xFraction: .random(in: 0.05...0.95),
                drift: .random(in: -24...24),
                size: .random(in: 12...36),
                blur: .random(in: 0...1.0),
                duration: .random(in: riseDuration),
                delay: .random(in: 0...0.25)
            )
        }
        particles.append(contentsOf: newParticles)

        // Drop the burst once its slowest particle has dissolved, letting
        // the timeline pause again between taps.
        let lifetime = (newParticles.map { $0.delay + $0.duration }.max() ?? 0) + 0.3
        let ids = Set(newParticles.map(\.id))
        Task {
            try? await Task.sleep(for: .seconds(lifetime))
            particles.removeAll { ids.contains($0.id) }
        }
    }
}

#Preview {
    @Previewable @State var burst = 0

    ZStack {
        RoundedRectangle(cornerRadius: 26, style: .continuous)
            .fill(.orange.opacity(0.6))
        EmojiParticlesView(emoji: "🎂", burst: burst)
    }
    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    .frame(width: 330, height: 92)
    .onTapGesture {
        burst += 1
    }
}
