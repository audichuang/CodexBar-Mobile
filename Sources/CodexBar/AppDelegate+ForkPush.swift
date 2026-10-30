import AppKit

extension AppDelegate {
    /// Routes CloudKit silent pushes to the sync coordinator (steipete #4268 port).
    /// `@objc` keeps the NSApplicationDelegate selector visible to AppKit from an extension.
    @objc func application(_ application: NSApplication, didReceiveRemoteNotification userInfo: [String: Any]) {
        self.cloudSyncCoordinator?.didReceiveRemoteNotification(userInfo)
    }
}
