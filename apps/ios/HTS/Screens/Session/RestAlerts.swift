import Foundation
import HTSDomain
import UserNotifications

/// Warns when the rest ends, also with the screen locked or the app in the background.
protocol RestAlerts: Sendable {
    func schedule(at date: Date, exerciseName: String) async
    func cancel() async
}

/// Local notification with sound (and vibration when the phone is silent).
struct LocalNotificationRestAlerts: RestAlerts {
    private static let identifier = "rest-timer"

    func schedule(at date: Date, exerciseName: String) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        if settings.authorizationStatus == .notDetermined {
            _ = try? await center.requestAuthorization(options: [.alert, .sound])
        }
        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Descanso concluído")
        content.body = String(localized: "Próxima série: \(exerciseName)")
        content.sound = .default
        content.interruptionLevel = .active
        let interval = max(date.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger))
    }

    func cancel() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.identifier])
    }
}

/// Keeps the running rest per session, so reopening the app shows the same countdown.
enum RestStore {
    private static func key(_ sessionId: UUID) -> String { "rest-\(sessionId.uuidString)" }

    static func load(sessionId: UUID) -> (timer: RestTimer, exerciseName: String)? {
        guard let data = UserDefaults.standard.data(forKey: key(sessionId)),
            let stored = try? JSONDecoder().decode(Stored.self, from: data)
        else { return nil }
        return (stored.timer, stored.exerciseName)
    }

    static func save(_ timer: RestTimer?, exerciseName: String, sessionId: UUID) {
        guard let timer, let data = try? JSONEncoder().encode(Stored(timer: timer, exerciseName: exerciseName)) else {
            UserDefaults.standard.removeObject(forKey: key(sessionId))
            return
        }
        UserDefaults.standard.set(data, forKey: key(sessionId))
    }

    private struct Stored: Codable {
        let timer: RestTimer
        let exerciseName: String
    }
}

/// UNUserNotificationCenter does not show banners for the foreground app unless asked: the footer already shows the
/// rest, so the foreground only plays the sound.
final class ForegroundNotificationDelegate: NSObject, UNUserNotificationCenterDelegate, Sendable {
    static let shared = ForegroundNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.sound]
    }
}
