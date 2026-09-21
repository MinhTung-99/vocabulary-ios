//
//  NotificationManager.swift
//  vocabulary
//

import UserNotifications

enum SettingsDefaultsKey {
    static let notificationsEnabled = "settings.notificationsEnabled"
    static let selectedSectionKey = "settings.selectedSectionKey" // legacy single selection
    static let selectedSectionKeys = "settings.selectedSectionKeys"

    /// Saved list selection; falls back to the legacy single-list key.
    static func savedSectionKeys(_ defaults: UserDefaults = .standard) -> [String] {
        if let keys = defaults.stringArray(forKey: selectedSectionKeys) { return keys }
        return defaults.string(forKey: selectedSectionKey).map { [$0] } ?? []
    }
    static let intervalMinutes = "settings.intervalMinutes"
    static let startHour = "settings.startHour"
    static let startMinute = "settings.startMinute"
    static let endHour = "settings.endHour"
    static let endMinute = "settings.endMinute"
}

final class NotificationManager {
    static let shared = NotificationManager()

    private let identifierPrefix = "vocabulary.reminder."
    private let categoryIdentifier = "vocabularyReminder"
    private let maxPending = 64

    private init() {}

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func cancelAllScheduled() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// iOS keeps at most 64 pending local notifications, so a daily-repeating schedule silently drops
    /// everything past the 64th slot. Instead, schedule the next `maxPending` occurrences (one-shot,
    /// across as many days as needed); this is re-run on launch/foreground to keep the window topped up.
    /// Only words not yet marked as learned are scheduled.
    /// Returns the "HH:mm" slots of a single day, for display (empty when nothing was scheduled).
    @discardableResult
    func scheduleNotifications(
        sections: [VocabularySection],
        intervalMinutes: Int,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int
    ) -> [String] {
        cancelAllScheduled()
        let words = unlearnedEntries(in: sections)
        guard !words.isEmpty, intervalMinutes > 0 else { return [] }

        let center = UNUserNotificationCenter.current()
        let calendar = Calendar.current
        let startTotal = startHour * 60 + startMinute
        var endTotal = endHour * 60 + endMinute
        if endTotal < startTotal { endTotal += 24 * 60 }

        // Minutes since midnight of the day the window starts (may exceed 1440 for overnight windows).
        var slots: [Int] = []
        var current = startTotal
        while current <= endTotal {
            slots.append(current)
            current += intervalMinutes
        }

        let now = Date()
        let today = calendar.startOfDay(for: now)
        let reference = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1)) ?? today
        let slotsPerDay = slots.count
        var scheduled = 0
        var dayOffset = 0

        while scheduled < maxPending, dayOffset < 90 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { break }
            let dayNumber = calendar.dateComponents([.day], from: reference, to: day).day ?? 0

            for (slotIndex, minutes) in slots.enumerated() {
                guard scheduled < maxPending else { break }
                guard let fireDate = calendar.date(byAdding: .minute, value: minutes, to: day),
                      fireDate > now else { continue }

                // Stable word per slot, so re-scheduling later doesn't restart the cycle.
                let word = words[abs(dayNumber * slotsPerDay + slotIndex) % words.count]
                let (title, body) = word.item.notificationContent

                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default
                content.categoryIdentifier = categoryIdentifier
                content.userInfo = ["fields": word.item.fieldPairs, "sectionTitle": word.sectionTitle]

                let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                center.add(UNNotificationRequest(
                    identifier: identifierPrefix + "\(scheduled)",
                    content: content,
                    trigger: trigger
                ))
                scheduled += 1
            }
            dayOffset += 1
        }

        return slots.map { String(format: "%02d:%02d", ($0 / 60) % 24, $0 % 60) }
    }

    /// Not-yet-learned words of all the given lists, in list order, each tagged with its list title.
    func unlearnedEntries(in sections: [VocabularySection]) -> [(sectionTitle: String, item: JSONValue)] {
        sections.flatMap { section in
            section.items
                .filter { !RememberedStore.shared.isRemembered($0, title: section.title) }
                .map { (sectionTitle: section.title, item: $0) }
        }
    }

    /// Re-applies the saved settings (if notifications are enabled) to top up the pending window.
    func refreshFromSavedSettings(sections: [VocabularySection]) {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: SettingsDefaultsKey.notificationsEnabled),
              case let keys = SettingsDefaultsKey.savedSectionKeys(defaults),
              !keys.isEmpty else { return }
        let selected = sections.filter { keys.contains($0.key) }
        guard !selected.isEmpty else { return }

        let interval = defaults.integer(forKey: SettingsDefaultsKey.intervalMinutes)
        scheduleNotifications(
            sections: selected,
            intervalMinutes: interval > 0 ? interval : 60,
            startHour: defaults.object(forKey: SettingsDefaultsKey.startHour) as? Int ?? 8,
            startMinute: defaults.object(forKey: SettingsDefaultsKey.startMinute) as? Int ?? 0,
            endHour: defaults.object(forKey: SettingsDefaultsKey.endHour) as? Int ?? 23,
            endMinute: defaults.object(forKey: SettingsDefaultsKey.endMinute) as? Int ?? 0
        )
    }
}
