import Foundation

nonisolated protocol NotificationServiceProtocol: Sendable {
    func requestPermission()
    func sendNotification(title: String, body: String, identifier: String)
}
