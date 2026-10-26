//
//  HomeView+Countdowns.swift
//  touchtime
//

import SwiftUI

extension HomeView {
    // Get displayed pinned countdowns based on selected collection: every
    // pinned countdown on All Cities, only the ones added to the collection
    // otherwise, both in the order arranged in ArrangeListView
    var displayedCountdowns: [CountdownItem] {
        let pinned = countdownStore.pinnedCountdowns(at: currentDate.addingTimeInterval(timeOffset))
        if let collectionId = selectedCollectionId,
           let collection = collections.first(where: { $0.id == collectionId }) {
            return pinned.filter { collection.contains(countdownId: $0.id) }
        }
        return pinned // Default - show all pinned countdowns
    }

    /// True when the current view has countdown cards to show, so the list
    /// still has content without clocks or a timer.
    var hasPinnedCountdowns: Bool {
        !displayedCountdowns.isEmpty
    }

    /// Commits edits made in the countdown editor opened from a pinned
    /// Home card, mirroring CountdownSheet's update logic.
    func updateCountdown(_ item: CountdownItem, title: String, targetDate: Date, emoji: String?, photoData: Data?, photoCrop: CountdownItem.PhotoCrop?, isPinned: Bool, repeatFrequency: CountdownItem.RepeatFrequency, reminderTime: Date?, reminderCity: WorldClock?, reminderLeadDays: Int, reminderKind: CountdownItem.ReminderKind, contact: CountdownItem.LinkedContact?, scheduledMessage: String?, pausedAt: Date?) {
        guard let index = countdownStore.countdowns.firstIndex(where: { $0.id == item.id }) else { return }
        // Assemble the edited item first so the store (and UserDefaults)
        // sees a single mutation instead of one per field.
        var updated = countdownStore.countdowns[index]
        updated.title = title
        updated.targetDate = targetDate
        updated.emoji = emoji
        updated.photoData = photoData
        updated.photoCrop = photoCrop
        updated.isPinned = isPinned
        updated.repeatFrequency = repeatFrequency
        updated.reminderTime = reminderTime
        updated.reminderCity = reminderCity
        updated.reminderLeadDays = reminderLeadDays
        updated.reminderKind = reminderKind
        updated.contact = contact
        updated.scheduledMessage = scheduledMessage
        updated.pausedAt = pausedAt
        withAnimation(.spring()) {
            countdownStore.countdowns[index] = updated
        }
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }

    /// Unpins a countdown from its Home card's context menu; the card
    /// disappears since Home only shows pinned countdowns.
    func unpinCountdown(_ item: CountdownItem) {
        guard let index = countdownStore.countdowns.firstIndex(where: { $0.id == item.id }) else { return }
        withAnimation(.spring()) {
            countdownStore.countdowns[index].isPinned = false
        }
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }

    func deleteCountdown(_ item: CountdownItem) {
        withAnimation(.spring()) {
            countdownStore.countdowns.removeAll { $0.id == item.id }
        }
        if hapticEnabled {
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        }
    }
}
