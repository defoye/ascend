import Features
import Foundation
import UIKit
import UserNotifications

/// Owns the one code path that can obtain a real APNs device token —
/// `UIApplicationDelegate`'s registration callbacks have no SwiftUI
/// equivalent — and bridges it into `Features`' `DeviceTokenStore` seam (see
/// docs/BACKEND.md "Message push notifications"). `AscendApp` wires this in
/// via `@UIApplicationDelegateAdaptor` and injects `deviceTokenStore` into
/// the environment so `SettingsView` and `RootView` can read it.
///
/// This does NOT request notification permission — that stays the existing
/// `SettingsView`/`LiveSessionReminderScheduler` flow (see
/// docs/ROADMAP.md Prompt 8). `registerForRemoteNotifications()` itself
/// doesn't prompt; it only obtains a token once permission already exists
/// (or, per Apple's docs, silently no-ops if it doesn't yet).
final class AppDelegate: NSObject, UIApplicationDelegate, @MainActor UNUserNotificationCenterDelegate {
    let deviceTokenStore = DeviceTokenStore()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        let store = deviceTokenStore
        Task { @MainActor in store.token = hex }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // No-op: a device that can't register for push (simulator without
        // entitlement provisioning, no network, etc.) should never crash or
        // block the rest of the app.
    }

    /// Shows the banner/sound while the app is foregrounded — V1 has no
    /// message-thread deep link, so this is the only presentation surface
    /// (see `userNotificationCenter(_:didReceive:withCompletionHandler:)`).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// V1 tap behavior is just "open the app" — no routing to the specific
    /// engagement/message thread yet. The payload carries `engagement_id`/
    /// `message_id` for that future deep link (see
    /// `Server/supabase/functions/notify-message/index.ts`); this stays
    /// unused until that's built.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }
}
