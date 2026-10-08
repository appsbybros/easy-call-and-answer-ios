import SwiftUI
import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [.banner, .sound] }
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        guard let id = response.notification.request.content.userInfo["personID"] as? String else { return }
        await MainActor.run {
            UserDefaults.standard.set(id,forKey:"pendingPerson")
            NotificationCenter.default.post(name: .openPerson, object: id)
        }
    }
}
extension Notification.Name { static let openPerson = Notification.Name("EasyCallOpenPerson") }

@main struct EasyCallApp: App {
    @StateObject private var library = Library()
    @StateObject private var calling = Calling()
    @StateObject private var purchases = Purchases()
    @Environment(\.scenePhase) private var phase
    private let notificationDelegate = NotificationDelegate()
    init() { UNUserNotificationCenter.current().delegate = notificationDelegate }
    var body: some Scene {
        WindowGroup {
            HomeView()
                .environmentObject(library).environmentObject(calling).environmentObject(purchases)
                .tint(Palette.teal)
                .preferredColorScheme(.light)
                .environment(\.colorSchemeContrast, library.value.highContrast ? .increased : .standard)
                .onChange(of: phase) { _, value in
                    if value == .active { library.recordVisit(); Task { await purchases.refresh() } }
                }
        }
    }
}
