import CloudKit
import Foundation

extension CloudSyncCoordinator {
    func didReceiveRemoteNotification(_ userInfo: [String: Any]) {
        Self.routeRemoteNotification(userInfo, enabled: self.settings.macFleetSyncEnabled) {
            self.scheduleResume(debounce: false)
        }
    }

    nonisolated static func routeRemoteNotification(
        _ userInfo: [String: Any],
        enabled: Bool,
        fetch: () -> Void)
    {
        guard enabled,
              let notification = CKNotification(fromRemoteNotificationDictionary: userInfo) as? CKDatabaseNotification,
              notification.containerIdentifier == CloudSyncEngine.containerIdentifier,
              notification.databaseScope == .private else { return }
        fetch()
    }
}
