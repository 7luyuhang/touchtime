//
//  EmojiParticlesView.swift
//  touchtime
//
//  Created on 30/08/2026.
//

import SwiftUI

/// Emoji particles floating up a card background: every bump of `burst`
/// spawns a handful of copies of the emoji that rise from the bottom edge
/// with random size, blur and sideways drift, dissolving before they reach
/// the top. Used behind the countdown editor's preview card whenever an
/// emoji cover is picked; place it behind content and clip it to the card.
struct EmojiParticlesView: View {
    /// The current cover emoji; snapshotted into each particle so
    /// in-flight bursts keep their glyph when the cover changes.
    let emoji: String?
    /// Bumped by the parent on every emoji pick; each change is one burst.
    let burst: Int

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
                    let position = CGPoint(
                        x: particle.xFraction * size.width + particle.drift * eased,
                        y: size.height + particle.size - travel * eased
                    )

                    // Quick fade in, cruise, dissolve over the last stretch.
                    let fadeIn = min(progress / 0.15, 1)
                    let fadeOut = progress < 0.6 ? 1 : (1 - progress) / 0.4

                    var layer = context
                    layer.opacity = fadeIn * fadeOut
                    if particle.blur > 0.1 {
                        layer.addFilter(.blur(radius: particle.blur))
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
        guard let emoji else { return }
        let now = Date().timeIntervalSinceReferenceDate
        let newParticles = (0..<Int.random(in: 10...15)).map { _ in
            Particle(
                emoji: emoji,
                birth: now,
                xFraction: .random(in: 0.05...0.95),
                drift: .random(in: -24...24),
                size: .random(in: 12...36),
                blur: .random(in: 0...1.0),
                duration: .random(in: 1.0...2.0),
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
