import Foundation
import UserNotifications

/// Shows a notification of the system. A value with closures, so that the model can be tested
/// with a recording stand-in instead of real notifications.
struct Notifier {
    var requestAccess: @MainActor () -> Void
    var send: @MainActor (_ title: String, _ body: String) -> Void

    /// Does nothing; used in tests.
    static let silent = Notifier(requestAccess: {}, send: { _, _ in })

    static let system = Notifier(
        requestAccess: {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        },
        send: { title, body in
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    )
}
