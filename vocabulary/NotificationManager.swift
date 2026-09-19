//
//  NotificationManager.swift
//  vocabulary
//

import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()

    private let identifierPrefix = "vocabulary.reminder."
    private let categoryIdentifier = "vocabularyReminder"

    private init() {}

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func cancelAllScheduled() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    /// Schedules up to `wordsPerDay` daily-repeating notifications, `intervalMinutes` apart,
    /// within the [startHour:startMinute, endHour:endMinute] window, cycling through `words`.
    /// Returns the "HH:mm" times that were scheduled, for display/debugging.
    @discardableResult
    func scheduleNotifications(
        words: [JSONValue],
        intervalMinutes: Int,
        wordsPerDay: Int,
        startHour: Int,
        startMinute: Int,
        endHour: Int,
        endMinute: Int
    ) -> [String] {
        cancelAllScheduled()
        guard !words.isEmpty, wordsPerDay > 0, intervalMinutes > 0 else { return [] }

        let center = UNUserNotificationCenter.current()
        let startTotal = startHour * 60 + startMinute
        var endTotal = endHour * 60 + endMinute
        if endTotal < startTotal { endTotal += 24 * 60 }

        var minutesOfDay: [Int] = []
        var current = startTotal
        while current <= endTotal, minutesOfDay.count < min(wordsPerDay, 64) {
            minutesOfDay.append(current % (24 * 60))
            current += intervalMinutes
        }

        var scheduledTimes: [String] = []

        for (i, minuteOfDay) in minutesOfDay.enumerated() {
            let word = words[i % words.count]
            let (title, body) = word.notificationContent

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.categoryIdentifier = categoryIdentifier
            content.userInfo = ["fields": word.fieldPairs]

            var dateComponents = DateComponents()
            dateComponents.hour = minuteOfDay / 60
            dateComponents.minute = minuteOfDay % 60

            let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            let request = UNNotificationRequest(
                identifier: identifierPrefix + "\(i)",
                content: content,
                trigger: trigger
            )
            center.add(request)

            scheduledTimes.append(String(format: "%02d:%02d", dateComponents.hour ?? 0, dateComponents.minute ?? 0))
        }

        return scheduledTimes
    }
}
