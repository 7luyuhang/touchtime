//
//  HomeCountdownSection.swift
//  touchtime
//
//  Created on 24/08/2026.
//

import SwiftUI
import UIKit

/// Pinned countdowns shown below the home timer: one preview card per
/// pinned countdown, in the order passed in (arranged in Arrange, see
/// `CountdownStore.pinnedCountdowns(at:)`), or folded into a stack from a
/// card's context menu. Day counts follow the scrubbed time passed in as
/// `now`.
struct HomeCountdownSection: View {
    let countdowns: [CountdownItem]
    /// Reference "now" (current time plus the Slide to Adjust offset)
    /// used for the day counts.
    let now: Date
    /// Set by Home after Collapse in a card's context menu: two or more
    /// cards then fold into one stack, like the Smart Stack on Apple Watch,
    /// with the first card in front and the next ones peeking out below it.
    /// Set without animation: the stack animates the fold itself, where an
    /// animated change would fade the cards' rows in and out instead.
    let isCollapsed: Bool
    /// Called from the card's context menu once it has settled back onto
    /// the card; Home then folds the cards, without animating the change.
    let onCollapse: () -> Void
    /// Called once the folded stack has been tapped and its cards have slid
    /// back out; Home then unfolds it, without animating the change.
    let onExpand: () -> Void
    /// Called with the tapped countdown; Home presents the editor for it.
    let onTap: (CountdownItem) -> Void
    /// Called from the card's context menu; Home unpins the countdown,
    /// which removes its card since only pinned ones show here.
    let onUnpin: (CountdownItem) -> Void
    /// Called from the card's context menu; Home opens the share-as-image
    /// screen for the countdown.
    let onShare: (CountdownItem) -> Void
    /// Called from the card's context menu; Home opens Arrange, where
    /// pinned countdowns are reordered.
    let onArrange: () -> Void

    // Same Time Display settings as the countdown sheet rows, so shared
    // text breaks the interval into the units chosen there.
    @AppStorage("countdownShowYears") private var showYears = false
    @AppStorage("countdownShowMonths") private var showMonths = false
    @AppStorage("countdownShowDays") private var showDays = true
    @AppStorage("hapticEnabled") private var hapticEnabled = true

    /// How long the context menu takes to settle back onto the card after
    /// Collapse; the cards must not fold before then.
    private static let contextMenuDismissDuration: TimeInterval = 0.35

    private var pinnedCountdowns: [CountdownItem] {
        countdowns.filter(\.isPinned)
    }

    /// A single card has nothing to fold behind it.
    private var isStacked: Bool {
        isCollapsed && pinnedCountdowns.count > 1
    }

    var body: some View {
        if isStacked {
            Section {
                CountdownStack(countdowns: pinnedCountdowns, now: now, onExpand: onExpand)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
        } else {
            ForEach(pinnedCountdowns) { item in
                Section {
                    CountdownPreviewCard(item: item, now: now)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onTap(item)
                        }
                        .contextMenu {
                            Button {
                                onUnpin(item)
                            } label: {
                                Label(String(localized: "Unpin"), systemImage: "pin.slash")
                            }

                            shareMenu(for: item)

                            // Collapse folds the cards and Arrange reorders them,
                            // so a single one leaves both out
                            if pinnedCountdowns.count > 1 {
                                Divider()

                                Button {
                                    collapse()
                                } label: {
                                    Label(String(localized: "Collapse"), systemImage: "rectangle.stack")
                                }

                                Button {
                                    onArrange()
                                } label: {
                                    Label(String(localized: "Arrange"), systemImage: "list.bullet")
                                }
                            }
                        }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
        }
    }

    /// Lets the context menu settle back onto the card, then has Home fold
    /// the cards into the stack.
    private func collapse() {
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        Task {
            try? await Task.sleep(for: .seconds(Self.contextMenuDismissDuration))
            onCollapse()
        }
    }

    // MARK: - Share

    @ViewBuilder
    private func shareMenu(for item: CountdownItem) -> some View {
        Menu {
            Button {
                UIPasteboard.general.string = CountdownShare.copyText(
                    title: item.title,
                    targetDate: item.effectiveTargetDate(at: now),
                    now: item.pausedAt ?? now,
                    showYears: showYears,
                    showMonths: showMonths,
                    showDays: showDays
                )
                if hapticEnabled {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                    impactFeedback.prepare()
                    impactFeedback.impactOccurred()
                }
            } label: {
                Label(String(localized: "Copy as Text"), systemImage: "quote.opening")
            }
            Button {
                onShare(item)
            } label: {
                Label(String(localized: "Share as Image"), systemImage: "camera.macro")
            }
        } label: {
            Label(String(localized: "Share"), systemImage: "square.and.arrow.up") // Countdown Share
        }
    }
}

private extension CountdownPreviewCard {
    /// The Home card for a pinned countdown, counting from `now`.
    init(item: CountdownItem, now: Date) {
        self.init(
            title: item.title,
            targetDate: item.effectiveTargetDate(at: now),
            emoji: item.emoji,
            photoData: item.photoData,
            photoCrop: item.photoCrop,
            now: now,
            isRepeating: item.repeatFrequency != .never,
            pausedAt: item.pausedAt
        )
    }
}

// MARK: - Folded stack

/// The pinned cards folded into one stack. Unlike the unfolded cards it
/// puts them all in one List row, so the ones below the first can slide up
/// behind it: they fold as the stack takes the unfolded cards' place, and
/// slide back out when it's tapped, before Home unfolds it.
private struct CountdownStack: View {
    let countdowns: [CountdownItem]
    let now: Date
    let onExpand: () -> Void

    @AppStorage("hapticEnabled") private var hapticEnabled = true
    /// Starts unfolded, matching the cards in their own rows it replaces.
    @State private var isFolded = false

    var body: some View {
        CountdownStackLayout(progress: isFolded ? 1 : 0) {
            ForEach(Array(countdowns.enumerated()), id: \.element.id) { index, item in
                CountdownPreviewCard(item: item, now: now)
                    .modifier(CountdownStackFold(index: index, progress: isFolded ? 1 : 0))
                    // The first card in front, each one after it further back
                    .zIndex(-Double(index))
                    .accessibilityHidden(index > 0)
            }
        }
        // Taps on the edges peeking out below the front card unfold it too
        .contentShape(Rectangle())
        .onTapGesture(perform: unfold)
        .onAppear {
            // A turn later, once the cards are on screen unfolded; changed
            // in the update the stack appears in, they'd show up folded
            // instead of folding
            DispatchQueue.main.async {
                withAnimation(.spring()) {
                    isFolded = true
                }
            }
        }
    }

    private func unfold() {
        // Already sliding back out
        guard isFolded else { return }
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
        // Waits for the cards to settle fully, where the separate rows
        // pick them up without a jump
        withAnimation(.spring(), completionCriteria: .removed) {
            isFolded = false
        } completion: {
            onExpand()
        }
    }
}

/// Lays the pinned cards out down the row like a VStack. Its height goes
/// with `progress`, from all the cards unfolded (0) to just the front card
/// and the edges peeking out below it (1), so the List row resizes frame
/// by frame as `CountdownStackFold` slides the cards up, and the rows below
/// move with them.
private struct CountdownStackLayout: Layout {
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let heights = subviews.map { $0.sizeThatFits(ProposedViewSize(width: proposal.width, height: nil)).height }
        guard let frontHeight = heights.first else { return .zero }
        let width = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0

        let unfoldedHeight = heights.reduce(0, +) + CGFloat(subviews.count - 1) * CountdownStackFold.spacing
        let peekingCount = min(subviews.count - 1, CountdownStackFold.peekingCount)
        let stackedHeight = frontHeight + CGFloat(peekingCount) * CountdownStackFold.peek
        return CGSize(width: width, height: unfoldedHeight + (stackedHeight - unfoldedHeight) * progress)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for subview in subviews {
            let height = subview.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
            subview.place(at: CGPoint(x: bounds.minX, y: y), proposal: ProposedViewSize(width: bounds.width, height: height))
            y += height + CountdownStackFold.spacing
        }
    }
}

/// Moves a card as the pinned cards fold into a stack, like the Smart Stack
/// on Apple Watch: the first card stays in front while each one below it
/// slides up behind the cards in front of it, a step smaller and fainter
/// each, until only its bottom edge peeks out. Cards past the peeking ones
/// fade out right behind the last of them. `progress` runs from unfolded
/// (0) to stacked (1).
private struct CountdownStackFold: ViewModifier, Animatable {
    /// Gap between unfolded cards, the same as between Home's sections, so
    /// the unfolded stack lines up with the cards in their own rows.
    nonisolated static let spacing: CGFloat = 12
    /// How far each card peeks out below the one in front of it.
    nonisolated static let peek: CGFloat = 8
    /// How many cards peek out below the front one.
    nonisolated static let peekingCount = 2
    nonisolated static let cornerRadius: CGFloat = 26
    /// How much smaller each card is than the one in front of it.
    nonisolated private static let shrink: CGFloat = 0.06

    let index: Int
    var progress: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        content
            .mask {
                CountdownStackMask(index: index, progress: progress)
            }
            .visualEffect { [index, progress] content, geometry in
                content
                    .scaleEffect(Self.scale(of: index, progress: progress), anchor: .bottom)
                    .offset(y: Self.lift(of: index, progress: progress, cardHeight: geometry.size.height))
            }
            .opacity(Self.opacity(of: index, progress: progress))
    }

    /// Steps behind the front card; past the peeking cards they hide right
    /// behind the last one.
    nonisolated private static func depth(of index: Int) -> CGFloat {
        CGFloat(min(index, peekingCount))
    }

    nonisolated static func scale(of index: Int, progress: CGFloat) -> CGFloat {
        1 - shrink * depth(of: index) * progress
    }

    nonisolated private static func opacity(of index: Int, progress: CGFloat) -> Double {
        let stackedOpacity = index > peekingCount ? 0 : 1 - 0.25 * depth(of: index)
        return 1 - (1 - stackedOpacity) * progress
    }

    /// How far the card's bottom edge moves up from its place in the list.
    nonisolated private static func lift(of index: Int, progress: CGFloat, cardHeight: CGFloat) -> CGFloat {
        let unfoldedBottom = CGFloat(index) * (cardHeight + spacing) + cardHeight
        let stackedBottom = cardHeight + depth(of: index) * peek
        return (stackedBottom - unfoldedBottom) * progress
    }

    /// Where the card at `index` shows, in the front card's frame: shrunk
    /// towards its bottom edge and lifted from its place in the list.
    nonisolated static func frame(of index: Int, progress: CGFloat, cardSize: CGSize) -> CGRect {
        let scale = scale(of: index, progress: progress)
        let size = CGSize(width: cardSize.width * scale, height: cardSize.height * scale)
        let bottom = CGFloat(index) * (cardSize.height + spacing) + cardSize.height
            + lift(of: index, progress: progress, cardHeight: cardSize.height)
        return CGRect(x: (cardSize.width - size.width) / 2, y: bottom - size.height, width: size.width, height: size.height)
    }
}

/// What shows of a card as the stack folds: all of it except where the
/// cards in front of it are, so a see-through glass card never shows the
/// ones behind it. `rect` is the card's own frame, before it's shrunk and
/// lifted.
private struct CountdownStackMask: Shape {
    let index: Int
    let progress: CGFloat

    func path(in rect: CGRect) -> Path {
        let ownFrame = CountdownStackFold.frame(of: index, progress: progress, cardSize: rect.size)
        let ownScale = CountdownStackFold.scale(of: index, progress: progress)

        // Room around the card for its glass edge
        var visible = Path(rect.insetBy(dx: -16, dy: -16))
        for front in 0..<min(index, CountdownStackFold.peekingCount + 1) {
            let frontFrame = CountdownStackFold.frame(of: front, progress: progress, cardSize: rect.size)
            // The card in front as this one sees it before its own shrink and lift
            let frontInOwnFrame = CGRect(
                x: rect.minX + (frontFrame.minX - ownFrame.minX) / ownScale,
                y: rect.minY + (frontFrame.minY - ownFrame.minY) / ownScale,
                width: frontFrame.width / ownScale,
                height: frontFrame.height / ownScale
            )
            let cornerRadius = CountdownStackFold.cornerRadius
                * CountdownStackFold.scale(of: front, progress: progress) / ownScale
            visible = visible.subtracting(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: frontInOwnFrame)
            )
        }
        return visible
    }
}

// MARK: - Shared countdown share helpers

/// Share helpers used by both the Home cards and the countdown editor:
/// pasteboard text, the relative phrase under the shared card, and the
/// card image (9:16 unless another frame is picked). The unit flags are
/// the countdown sheet's Time Display settings.
enum CountdownShare {
    /// Whole calendar days from the reference date to the target date;
    /// negative once the event has happened.
    static func dayDifference(from now: Date, to targetDate: Date) -> Int {
        let calendar = Calendar.current
        return calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: targetDate)
        ).day ?? 0
    }

    /// Pasteboard text, e.g. "Birthday in 1 year 4 days" /
    /// "Birthday 3 days ago" / "Birthday is today".
    static func copyText(title: String, targetDate: Date, now: Date, showYears: Bool, showMonths: Bool, showDays: Bool) -> String {
        let difference = dayDifference(from: now, to: targetDate)
        if difference == 0 {
            return String(format: String(localized: "%@ is today"), title)
        }
        let interval = intervalText(from: now, to: targetDate, showYears: showYears, showMonths: showMonths, showDays: showDays)
        if difference < 0 {
            return String(format: String(localized: "%1$@ %2$@ ago"), title, interval)
        }
        return String(format: String(localized: "%1$@ in %2$@"), title, interval)
    }

    /// Context line under the shared card, e.g. "in 1 year 4 days" /
    /// "3 days ago" / "Today".
    static func footerText(from now: Date, to targetDate: Date, showYears: Bool, showMonths: Bool, showDays: Bool) -> String {
        let difference = dayDifference(from: now, to: targetDate)
        if difference == 0 {
            return String(localized: "Today")
        }
        let interval = intervalText(from: now, to: targetDate, showYears: showYears, showMonths: showMonths, showDays: showDays)
        return difference < 0
            ? String(format: String(localized: "%@ ago"), interval)
            : String(format: String(localized: "in %@"), interval)
    }

    /// Renders the countdown card into a share image, like the city card
    /// share: 9:16 by default, or the frame the share sheet picked. A
    /// paused countdown (`pausedAt` set) is counted as of its pause date.
    static func renderCardImage(title: String, targetDate: Date, emoji: String?, photoData: Data?, photoCrop: CountdownItem.PhotoCrop?, isRepeating: Bool, now: Date, pausedAt: Date? = nil, showYears: Bool, showMonths: Bool, showDays: Bool, aspectRatio: ShareAspectRatio = .nineBySixteen) -> UIImage {
        let snapshotView = CountdownCardSnapshotView(
            title: title,
            targetDate: targetDate,
            emoji: emoji,
            photoData: photoData,
            photoCrop: photoCrop,
            isRepeating: isRepeating,
            now: now,
            pausedAt: pausedAt,
            footerText: footerText(from: pausedAt ?? now, to: targetDate, showYears: showYears, showMonths: showMonths, showDays: showDays),
            aspectRatio: aspectRatio
        )
        .environment(\.colorScheme, .dark)

        let renderer = ImageRenderer(content: snapshotView)
        renderer.scale = 3

        if let uiImage = renderer.uiImage {
            return uiImage
        }

        // Fallback: create a simple placeholder image
        return UIImage(systemName: "photo") ?? UIImage()
    }

    /// Interval to the target broken into the enabled units, largest
    /// first, mirroring the countdown sheet rows (e.g. "1 year 4 days").
    private static func intervalText(from now: Date, to targetDate: Date, showYears: Bool, showMonths: Bool, showDays: Bool) -> String {
        let calendar = Calendar.current

        var unitSet: Set<Calendar.Component> = []
        if showYears { unitSet.insert(.year) }
        if showMonths { unitSet.insert(.month) }
        if showDays { unitSet.insert(.day) }

        let difference = calendar.dateComponents(
            unitSet,
            from: calendar.startOfDay(for: now),
            to: calendar.startOfDay(for: targetDate)
        )

        var parts: [String] = []
        if let years = difference.year, years != 0 {
            let unit = abs(years) == 1 ? String(localized: "year") : String(localized: "years")
            parts.append("\(abs(years)) \(unit)")
        }
        if let months = difference.month, months != 0 {
            let unit = abs(months) == 1 ? String(localized: "month") : String(localized: "months")
            parts.append("\(abs(months)) \(unit)")
        }
        if let days = difference.day, days != 0 {
            let unit = abs(days) == 1 ? String(localized: "day") : String(localized: "days")
            parts.append("\(abs(days)) \(unit)")
        }

        // The target is closer than any enabled unit: fall back to days.
        if parts.isEmpty {
            let dayCount = dayDifference(from: now, to: targetDate)
            let unit = abs(dayCount) == 1 ? String(localized: "day") : String(localized: "days")
            parts.append("\(abs(dayCount)) \(unit)")
        }

        return parts.joined(separator: " ")
    }
}

// MARK: - Countdown Card Snapshot View for Sharing

/// Share image for a countdown, mirroring the city card share: the
/// pinned card replica centered on a backdrop that echoes its cover — the
/// emoji's dominant colour as a flat fill, or the photo blurred; plain
/// black without a cover. Glass effects don't render in ImageRenderer, so
/// subtle fills stand in for them.
struct CountdownCardSnapshotView: View {
    let title: String
    let targetDate: Date
    let emoji: String?
    let photoData: Data?
    /// How the photo is framed in the badge; nil shows it centred.
    let photoCrop: CountdownItem.PhotoCrop?
    /// True for repeating countdowns; swaps the top-left arrow for a
    /// repeat symbol.
    let isRepeating: Bool
    /// Reference "now" for the day count (scrubbed time on Home).
    let now: Date
    /// Set while the countdown is paused: the day count holds as of this
    /// date, and a pause symbol takes the top-left arrow's place.
    var pausedAt: Date? = nil
    /// Context line under the card, e.g. "in 1 year 4 days".
    let footerText: String
    /// Frame of the image: a centred crop of the 9:16 layout, so the card
    /// keeps its size and only the amount of backdrop around it changes.
    var aspectRatio: ShareAspectRatio = .nineBySixteen
    /// Corner radius of that frame. Square (0) for the exported file; the
    /// share preview rounds it here so the crop is its only clip, rather
    /// than a rounded clip wrapped around a square one.
    var frameCornerRadius: CGFloat = 0

    private var size: CGSize {
        aspectRatio.size
    }

    /// Everything is laid out at the tallest frame and the shorter ratios
    /// take a centred crop of it. The card sits in the middle of both
    /// boxes, so the crop lands exactly where laying the card out in the
    /// shorter frame would have put it, while the backdrop keeps its 9:16
    /// framing instead of being re-cropped per ratio.
    private static let layoutSize = ShareAspectRatio.nineBySixteen.size

    /// Memoised: decoding here would hand `Image` a fresh `UIImage` on
    /// every update, and the blurred backdrop layer gets rebuilt whenever
    /// that identity changes.
    private var photoImage: UIImage? {
        guard let photoData else { return nil }
        return CountdownPreviewCard.cachedImage(from: photoData, crop: photoCrop)
    }

    private var emojiColor: Color? {
        guard let emoji else { return nil }
        return CountdownPreviewCard.cachedDominantColor(of: emoji)
    }

    private var calendar: Calendar {
        Calendar.current
    }

    private var dayDifference: Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: pausedAt ?? now),
            to: calendar.startOfDay(for: targetDate)
        ).day ?? 0
    }

    private var hasHappened: Bool {
        dayDifference < 0
    }

    /// Same top-left symbol as the live card.
    private var statusSymbol: String {
        if isRepeating {
            return "repeat"
        }
        if pausedAt != nil {
            return "pause"
        }
        return hasHappened ? "arrow.left" : "arrow.right"
    }

    private var bigText: String {
        dayDifference == 0 ? String(localized: "Today") : "\(abs(dayDifference))"
    }

    private var dayUnit: String {
        String(localized: "d")
    }

    /// Same CJK baseline lift as the live card.
    private var dayUnitBaselineOffset: CGFloat {
        dayUnit.unicodeScalars.contains { $0.properties.isIdeographic } ? 1.8 : 0
    }

    private var hasCenterBadge: Bool {
        emoji != nil || photoImage != nil
    }

    var body: some View {
        // Read three times below; the cache is keyed on the photo blob,
        // so looking it up once keeps that comparison off the hot path.
        let photoImage = self.photoImage

        ZStack {
            // Full-bleed backdrop echoing the card cover
            Color.black
            if let photoImage {
                Image(uiImage: photoImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: Self.layoutSize.width, height: Self.layoutSize.height)
                    .clipped()
                    .blur(radius: 60, opaque: true)
                    .overlay(Color.black.opacity(0.35))
                    // Flattened into one bitmap. Left live, the blur is a
                    // Core Animation filter re-rendered on every frame of
                    // the ratio animation, and the bands where the moving
                    // crop edge cut into it flickered; a bitmap is just
                    // cropped.
                    .drawingGroup()
            } else if let emojiColor {
                // Slightly dimmed so the full-colour card reads on top.
                emojiColor.opacity(0.75)
            }

            VStack(spacing: 10) {
                // Card replica from HomeView, centered vertically
                ZStack {
                    VStack(alignment: .leading, spacing: 4) {
                        // Repeat symbol (repeating) / pause (paused) /
                        // happened (left arrow) / happening (right arrow)
                        // top-left, countdown date top-right
                        HStack {
                            Image(systemName: statusSymbol)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .blendMode(.plusLighter)

                            Spacer()

                            Text(targetDate, format: .dateTime.year().month().day())
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .blendMode(.plusLighter)
                        }

                        // Event title bottom-left, day count bottom-right
                        HStack(alignment: .lastTextBaseline) {
                            Text(title.isEmpty ? String(localized: "Event Name") : title)
                                .font(.headline)
                                .foregroundStyle(title.isEmpty ? .secondary : .primary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .frame(maxWidth: hasCenterBadge ? 120 : .infinity, alignment: .leading)

                            Spacer()

                            HStack(alignment: .lastTextBaseline, spacing: 2) {
                                Text(bigText)
                                    .font(.system(size: 36))
                                    .fontWeight(.light)
                                    .fontDesign(.rounded)
                                    .monospacedDigit()

                                // Day unit, hidden when the card reads "Today"
                                if dayDifference != 0 {
                                    Text(dayUnit)
                                        .font(.system(size: 20, weight: .regular, design: .rounded))
                                        .baselineOffset(dayUnitBaselineOffset)
                                }
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, -4)
                    .background {
                        if let photoImage {
                            Image(uiImage: photoImage)
                                .resizable()
                                .scaledToFill()
                                .blur(radius: 24, opaque: true)
                                .overlay(Color.black.opacity(0.25))
                        } else if let emojiColor {
                            emojiColor
                        } else {
                            Color(UIColor.secondarySystemBackground)
                        }
                    }
                    // Same clip + hairline border as the city share card
                    .skyBackgroundCardChrome()

                    // Complication-sized emoji or photo in the middle,
                    // glassy like the live card
                    if let photoImage {
                        Image(uiImage: photoImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(Circle())
                            .glassEffect(.clear)
                    } else if let emoji {
                        Text(emoji)
                            .font(.system(size: 36))
                            .frame(width: 64, height: 64)
                            .glassEffect(.clear)
                    }
                }
                .padding(.horizontal, 8)

                Text(footerText)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .blendMode(.plusLighter)
                    .padding(.horizontal, 24)
            }
        }
        // Pinned to 9:16 so nothing inside re-lays out when the ratio
        // changes; the second frame only shrinks the window the content
        // is seen through. That keeps the blurred backdrop, the card's
        // own blur and the glass badge off the animation's hot path,
        // where redrawing them every frame showed up as a flicker.
        .frame(width: Self.layoutSize.width, height: Self.layoutSize.height)
        .frame(width: size.width, height: size.height) // 9:16 unless another frame is picked
        .clipShape(RoundedRectangle(cornerRadius: frameCornerRadius, style: .continuous))
    }
}
