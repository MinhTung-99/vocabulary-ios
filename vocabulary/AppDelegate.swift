//
//  AppDelegate.swift
//  vocabulary
//
//  Created by Nguyen Minh Tung on 19/9/26.
//

import UIKit
import FirebaseCore
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {



    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }


}

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .list])
    }

    /// Tapping a reminder opens the flashcard for the exact word it was about, using the same
    /// `fields` payload the notification content extension renders from.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        openFlashCard(for: response.notification.request.content.userInfo)
        completionHandler()
    }

    private func openFlashCard(for userInfo: [AnyHashable: Any]) {
        guard let fields = Self.extractFields(from: userInfo["fields"]), !fields.isEmpty else { return }
        let word = JSONValue.object(fields.map { (key: $0.first ?? "", value: .string($0.count > 1 ? $0[1] : "")) })

        guard
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
            let tabBarController = windowScene.windows.first(where: \.isKeyWindow)?.rootViewController as? UITabBarController,
            let vocabularyNav = tabBarController.viewControllers?.first as? UINavigationController
        else { return }

        let flashCardController = UIStoryboard(name: "FlashCardController", bundle: nil)
            .instantiateInitialViewController() as! FlashCardController
        flashCardController.items = [word]
        flashCardController.startIndex = 0
        flashCardController.sectionTitle = userInfo["sectionTitle"] as? String
        // Cold launch from a notification: learned state isn't loaded yet; the flashcard re-syncs when it arrives.
        RememberedStore.shared.refresh()

        tabBarController.selectedIndex = 0
        vocabularyNav.popToRootViewController(animated: false)
        vocabularyNav.pushViewController(flashCardController, animated: true)
    }

    /// Same defensive unpacking as `NotificationViewController.extractFields` — `userInfo` can
    /// come back as `NSArray`/`NSString` rather than bridging cleanly to `[[String]]`.
    private static func extractFields(from raw: Any?) -> [[String]]? {
        guard let array = raw as? [Any] else { return nil }
        let pairs = array.compactMap { element -> [String]? in
            guard let pairArray = element as? [Any] else { return nil }
            let strings = pairArray.compactMap { $0 as? String }
            return strings.isEmpty ? nil : strings
        }
        return pairs.isEmpty ? nil : pairs
    }
}

