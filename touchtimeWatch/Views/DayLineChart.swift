//
//  DayLineChart.swift
//  touchtimeWatch
//

import SwiftUI

/// The chosen day's value through the day, under UV Index's, Humidity's and
/// Pressure's gauges, from midnight at the left to midnight at the right, on
/// a scale as tall as the chart, raised or lowered so the line has as much
/// room over it as under it, whatever its height: a line in the scale's
/// colors for how high it is at each point, and on today's, a dot at now,
/// both as on the weather ring's temperatures, with the line before it
/// uncolored, as the ring's track is.
/// From day to day, the line reshapes into the next day's rather than
/// replacing it.
struct DayLineChart: View, Animatable {
    /// Across the day, a quarter hour apart, as many for every day so one
    /// day's line can turn into another's.
    static let sampleCount = 96
    /// Of the gauge's diameter: room for the value to rise and fall, staying
    /// clear below the arc's ends and the days beside them.
    static let heightShare: CGFloat = 0.10
    /// How far the dot and the sky ringing it reach from its middle, in line
    /// widths.
    private static let dotReach: CGFloat = 1.125

    /// Evenly spaced through the day, from midnight to midnight.
    var samples: Samples
    /// The values the chart's height spans, bottom to top. Any beyond are held
    /// to its bounds.
    let scale: ClosedRange<Double>
    /// Up the scale, from its bottom to its top, or one for all of it.
    let colors: [Color]
    /// How far through today now is, where today's dot goes.
    let nowFraction: Double
    /// Whether the chosen day is today, the one with the dot.
    let isToday: Bool
    let lineWidth: CGFloat
    /// How much of the day has gone by: up to now on today, and none on the
    /// days ahead.
    private var pastFraction: Double

    init(
        samples: Samples,
        scale: ClosedRange<Double>,
        colors: [Color],
        nowFraction: Double,
        isToday: Bool,
        lineWidth: CGFloat
    ) {
        self.samples = samples
        self.scale = scale
        self.colors = colors
        self.nowFraction = nowFraction
        self.isToday = isToday
        self.lineWidth = lineWidth
        pastFraction = isToday ? nowFraction : 0
    }

    var animatableData: AnimatablePair<Samples, Double> {
        get { AnimatablePair(samples, pastFraction) }
        set { (samples, pastFraction) = (newValue.first, newValue.second) }
    }

    /// As thick as the weather ring's arc of temperatures.
    static func lineWidth(ringWidth: CGFloat) -> CGFloat {
        ringWidth * 0.10
    }

    /// How far down to move the chart from the bottom of the gauge's circle,
    /// a line's width under the label over it, to sit as far below the label
    /// as above the date `spaceBelow` under the circle.
    static func offset(lineWidth: CGFloat, spaceBelow: CGFloat) -> CGFloat {
        max(spaceBelow - lineWidth, 0) / 2
    }

    var body: some View {
        GeometryReader { geometry in
            // In from the edges by the dot's reach, so neither it nor the line
            // is cut off.
            let room = CGRect(origin: .zero, size: geometry.size)
                .insetBy(dx: lineWidth * Self.dotReach, dy: lineWidth * Self.dotReach)
            // The scale's, moved up or down for the line's lowest and highest
            // points to be as far from the bottom of the room as from its top.
            // Following the samples as they animate, the line stays there as
            // it reshapes.
            let plot = room.offsetBy(dx: 0, dy: (lineMiddle - 0.5) * room.height)
            let height = max(geometry.size.height, 1)
            let style = StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round)
            let dotPoint = point(at: nowFraction, value: value(at: nowFraction), in: plot)

            ZStack {
                // What's gone by, uncolored as the weather ring's track is:
                // lighter where the sky is, but on its own, since the color
                // on it would wash out.
                ZStack {
                    line(from: 0, to: pastFraction, in: plot)
                        .stroke(.white.opacity(0.10), style: style)
                    dot(isHole: true)
                        .position(dotPoint)
                }
                .compositingGroup()
                .blendMode(.plusLighter)

                ZStack {
                    line(from: pastFraction, to: 1, in: plot)
                        .stroke(
                            // Up the scale, so each point takes the color at
                            // its value.
                            LinearGradient(
                                colors: colors,
                                startPoint: UnitPoint(x: 0.5, y: plot.maxY / height),
                                endPoint: UnitPoint(x: 0.5, y: plot.minY / height)
                            ),
                            style: style
                        )
                    dot(isHole: false)
                        .position(dotPoint)
                }
                .compositingGroup()
            }
        }
    }

    /// From `start` to `end` of the way through the day.
    private func line(from start: Double, to end: Double, in plot: CGRect) -> Path {
        guard end > start else { return Path() }
        let last = max(samples.values.count - 1, 1)
        let between = (0...last).map { Double($0) / Double(last) }.filter { $0 > start && $0 < end }
        return Path { path in
            path.addLines(([start] + between + [end]).map { point(at: $0, value: value(at: $0), in: plot) })
        }
    }

    /// Today's, placed even while hidden so it comes and goes where it is, in
    /// a ring cut out of its layer so the sky rings it, or for the layer of
    /// what's gone by, only the hole, as on the weather ring.
    private func dot(isHole: Bool) -> some View {
        ZStack {
            if isToday {
                Circle()
                    .fill(.white)
                    .blendMode(isHole ? .destinationOut : .normal)
                    .background {
                        Circle()
                            .stroke(lineWidth: lineWidth * 0.75)
                            .blendMode(.destinationOut)
                    }
                    .frame(width: lineWidth * 1.5, height: lineWidth * 1.5)
                    .transition(.scale)
            }
        }
    }

    /// On the line, between the samples either side.
    private func value(at fraction: Double) -> Double {
        let values = samples.values
        guard values.count > 1 else { return values.first ?? 0 }
        let position = min(max(fraction, 0), 1) * Double(values.count - 1)
        let index = min(Int(position), values.count - 2)
        return values[index] + (values[index + 1] - values[index]) * (position - Double(index))
    }

    private func point(at fraction: Double, value: Double, in plot: CGRect) -> CGPoint {
        CGPoint(x: plot.minX + plot.width * fraction, y: plot.maxY - plot.height * share(of: value))
    }

    /// Halfway between the line's lowest and highest points, as a share of
    /// the scale from its bottom.
    private var lineMiddle: Double {
        let shares = samples.values.map(share(of:))
        guard let lowest = shares.min(), let highest = shares.max() else { return 0.5 }
        return (lowest + highest) / 2
    }

    /// How far up the scale `value` is, from 0 at its bottom to 1 at its top.
    private func share(of value: Double) -> Double {
        let span = scale.upperBound - scale.lowerBound
        guard span > 0 else { return 0.5 }
        return (min(max(value, scale.lowerBound), scale.upperBound) - scale.lowerBound) / span
    }
}

extension DayLineChart {
    /// A day's samples for the chart, which animate from one day's to the
    /// next sample by sample.
    struct Samples: VectorArithmetic {
        var values: [Double]

        static var zero: Self {
            Self(values: [])
        }

        var magnitudeSquared: Double {
            values.reduce(0) { $0 + $1 * $1 }
        }

        static func + (lhs: Self, rhs: Self) -> Self {
            lhs.combined(with: rhs, by: +)
        }

        static func - (lhs: Self, rhs: Self) -> Self {
            lhs.combined(with: rhs, by: -)
        }

        mutating func scale(by rhs: Double) {
            values = values.map { $0 * rhs }
        }

        /// Sample by sample, with zero for any the other lacks, as `zero` has
        /// none.
        private func combined(with other: Self, by operation: (Double, Double) -> Double) -> Self {
            Self(values: (0..<max(values.count, other.values.count)).map { index in
                operation(
                    values.indices.contains(index) ? values[index] : 0,
                    other.values.indices.contains(index) ? other.values[index] : 0
                )
            })
        }
    }
}

extension DayLineChart.Samples {
    /// `hourly`'s values, by the start of each hour, as a smooth line sampled
    /// evenly from `day`, a midnight in `calendar`, to the next, or nil unless
    /// the hours cover the day.
    init?(hourly: [Date: Double], day: Date, calendar: Calendar) {
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
        let dayHours = dayEnd.timeIntervalSince(day) / 3600
        // Hours past each end too, for the line to carry on as it would.
        let margin = SmoothLine.reach + 1
        let points = hourly
            .map { (x: $0.key.timeIntervalSince(day) / 3600, y: $0.value) }
            .filter { $0.x > -margin && $0.x < dayHours + margin }
            .sorted { $0.x < $1.x }
        // Within an hour, as hours start off a half-hour city's midnight.
        guard let first = points.first, let last = points.last, first.x <= 1, last.x >= dayHours - 1 else {
            return nil
        }
        self.init(values: SmoothLine(points: points).values(
            from: 0,
            every: dayHours / Double(DayLineChart.sampleCount),
            count: DayLineChart.sampleCount + 1
        ))
    }
}

/// Hourly values as a smooth line that never strays above or below them.
/// UV indexes, whole numbers, rise and fall in steps, which a curve through
/// each one would show; rather, they're joined straight, and each moment
/// takes the line around it, weighted by a bell curve an hour wide either
/// side.
private struct SmoothLine {
    /// How far either side of a moment it takes the line from, in hours: past
    /// three times the bell curve's width, it weighs next to nothing.
    static let reach = 3.0

    /// In order along x, in hours.
    let points: [(x: Double, y: Double)]

    /// `count` moments' values from `start`, `step` hours apart.
    func values(from start: Double, every step: Double, count: Int) -> [Double] {
        let stepsAnHour = 1 / step
        let reachSteps = Int((Self.reach * stepsAnHour).rounded(.up))
        let weights = (-reachSteps...reachSteps).map { offset in
            exp(-pow(Double(offset) / stepsAnHour, 2) / 2)
        }
        let totalWeight = weights.reduce(0, +)
        let straight = (-reachSteps..<(count + reachSteps)).map { offset in
            straightValue(at: start + Double(offset) * step)
        }
        return (0..<count).map { index in
            zip(weights, straight[index...]).reduce(0) { $0 + $1.0 * $1.1 } / totalWeight
        }
    }

    /// Joined straight from point to point, and level beyond the first and last.
    private func straightValue(at x: Double) -> Double {
        guard let first = points.first, let last = points.last else { return 0 }
        guard x > first.x else { return first.y }
        guard let next = points.firstIndex(where: { $0.x >= x }) else { return last.y }
        let previous = points[next - 1]
        return previous.y + (points[next].y - previous.y) * (x - previous.x) / (points[next].x - previous.x)
    }
}
