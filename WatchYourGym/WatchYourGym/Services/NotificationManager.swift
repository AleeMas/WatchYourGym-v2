//
//  NotificationManager.swift
//  WatchYourGym
//
//  Local notification fired when a rest ends while the app is in the
//  background. In the foreground the banner is suppressed (see
//  `willPresent`) because the app already plays its own sound.
//
//  Permission is requested lazily, the first time a workout starts: asking at
//  launch, with no context, is the classic way to get a "Don't Allow".
//

import Foundation
import UserNotifications
import UIKit

final class NotificationManager: NSObject, ObservableObject {

    static let shared = NotificationManager()

    private static let restIdentifier = "rest-finished"
    private static let testIdentifier = "test-notification"

    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    /// Last scheduling error, shown in Settings so failures are not silent.
    @Published private(set) var lastError: String?

    private let center = UNUserNotificationCenter.current()

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    /// Called once at launch so notifications behave correctly in the foreground.
    func configure() {
        center.delegate = self
        refreshAuthorizationStatus()
    }

    func refreshAuthorizationStatus() {
        center.getNotificationSettings { [weak self] settings in
            Task { @MainActor in
                self?.authorizationStatus = settings.authorizationStatus
            }
        }
    }

    /// Asks for permission if it was never asked before.
    /// Returns true when notifications can actually be delivered.
    @discardableResult
    func ensureAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        await MainActor.run { self.authorizationStatus = settings.authorizationStatus }

        switch settings.authorizationStatus {
        case .notDetermined:
            return await requestAuthorization()
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            refreshAuthorizationStatus()
            return granted
        } catch {
            await MainActor.run { self.lastError = error.localizedDescription }
            print("NotificationManager: authorization failed: \(error)")
            return false
        }
    }

    /// Opens WatchYourGym's page in the iOS Settings app.
    func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Rest

    /// Schedules the alert for the end of the current rest.
    /// Any previously scheduled one is replaced.
    func scheduleRestFinished(in seconds: TimeInterval, exerciseName: String?) {
        guard seconds > 0 else { return }

        guard isAuthorized else {
            // Nothing would be delivered: make it visible instead of failing
            // silently, which is exactly how this went unnoticed before.
            Task { @MainActor in
                self.lastError = "Notifications are not allowed, the rest alert cannot be delivered."
            }
            print("NotificationManager: not authorized (\(authorizationStatus.rawValue)), rest alert skipped")
            return
        }

        cancelRestFinished()

        let content = UNMutableNotificationContent()
        content.title = "Rest over"
        content.body = {
            if let exerciseName, !exerciseName.isEmpty {
                return "Next: \(exerciseName)"
            }
            return "Time to get back to work."
        }()
        content.sound = .default
        // Breaks through Focus modes only if the "Time Sensitive Notifications"
        // capability is added to the target; without it iOS simply treats this
        // as a normal alert, so it is safe to keep either way.
        content.interruptionLevel = .timeSensitive

        schedule(content: content, identifier: Self.restIdentifier, in: seconds)
    }

    /// The rest was skipped, ended in-app, or the workout was stopped.
    func cancelRestFinished() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.restIdentifier])
        center.removeDeliveredNotifications(withIdentifiers: [Self.restIdentifier])
    }

    // MARK: - Test

    /// Fires a notification a few seconds from now, so the alert can be
    /// checked from Settings without running a whole workout.
    func sendTestNotification(in seconds: TimeInterval = 5) async {
        guard await ensureAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest over"
        content.body = "This is what you will hear during a workout."
        content.sound = .default
        content.interruptionLevel = .timeSensitive

        schedule(content: content, identifier: Self.testIdentifier, in: seconds)
    }

    // MARK: - Private

    private func schedule(content: UNNotificationContent, identifier: String, in seconds: TimeInterval) {
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            // Below one second the trigger is rejected by iOS.
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: max(seconds, 1), repeats: false)
        )
        center.add(request) { [weak self] error in
            Task { @MainActor in
                if let error {
                    self?.lastError = error.localizedDescription
                    print("NotificationManager: could not schedule \(identifier): \(error)")
                } else {
                    self?.lastError = nil
                }
            }
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {

    /// With the app open the user already hears the in-app sound and sees the
    /// rest overlay, so the rest banner would be redundant. Anything else
    /// (the test notification) is presented normally.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        notification.request.identifier == Self.restIdentifier ? [] : [.banner, .sound]
    }
}
