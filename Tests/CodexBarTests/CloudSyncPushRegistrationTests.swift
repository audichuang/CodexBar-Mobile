import AppKit
import CloudKit
import ObjectiveC
import Testing
@testable import CodexBar

@MainActor
struct CloudSyncPushRegistrationTests {
    @Test(arguments: ["development", "production"])
    func `CloudKit builds with a valid push environment register for notifications`(_ environment: String) {
        var registrations = 0
        let canActivate = CloudSyncEntitlementGate.prepareForSync(
            enabled: true,
            entitlementValue: { name in
                name == CloudSyncEntitlementGate.entitlement ? ["CloudKit"] : environment
            },
            register: { registrations += 1 })
        #expect(canActivate)
        #expect(registrations == 1)
    }

    @Test(arguments: [nil, "", "Production", "sandbox"] as [String?])
    func `missing or invalid push entitlement never registers`(_ environment: String?) {
        var registrations = 0
        let canActivate = CloudSyncEntitlementGate.prepareForSync(
            enabled: true,
            entitlementValue: { name in
                name == CloudSyncEntitlementGate.entitlement ? ["CloudKit"] : environment
            },
            register: { registrations += 1 })
        #expect(canActivate)
        #expect(registrations == 0)
    }

    @Test
    func `push entitlement alone does not bypass the CloudKit capability gate`() {
        var registrations = 0
        let canActivate = CloudSyncEntitlementGate.prepareForSync(
            enabled: true,
            entitlementValue: { name in
                name == CloudSyncEntitlementGate.entitlement ? ["CloudDocuments"] : "production"
            },
            register: { registrations += 1 })
        #expect(!canActivate)
        #expect(registrations == 0)
    }

    @Test
    func `opting out before queued activation prevents registration and engine creation`() {
        var enabled = true
        var registrations = 0
        let activate = {
            CloudSyncEntitlementGate.prepareForSync(
                enabled: enabled,
                entitlementValue: { name in
                    name == CloudSyncEntitlementGate.entitlement ? ["CloudKit"] : "production"
                },
                register: { registrations += 1 })
        }
        enabled = false

        #expect(!activate())
        #expect(registrations == 0)
    }

    @Test
    func `app delegate receives remote notifications`() {
        let selector = #selector(NSApplicationDelegate.application(_:didReceiveRemoteNotification:))
        #expect(class_getInstanceMethod(AppDelegate.self, selector) != nil)
    }

    private func payload(container: String? = CloudSyncEngine.containerIdentifier, scope: Int = 1) -> [String: Any] {
        var ck: [String: Any] = ["met": ["dbs": scope]]
        if let container { ck["cid"] = container }
        return ["ck": ck]
    }

    @Test(arguments: [true, false])
    func `private database pushes fetch only while sync is enabled`(_ enabled: Bool) throws {
        let userInfo = self.payload()
        let notification = try #require(CKNotification(fromRemoteNotificationDictionary: userInfo)
            as? CKDatabaseNotification)
        #expect(notification.databaseScope == .private)
        var fetches = 0
        CloudSyncCoordinator.routeRemoteNotification(userInfo, enabled: enabled) { fetches += 1 }
        #expect(fetches == (enabled ? 1 : 0))
    }

    @Test
    func `pushes for another container do not fetch`() {
        var fetches = 0
        CloudSyncCoordinator.routeRemoteNotification(
            self.payload(container: "iCloud.example.other"), enabled: true) { fetches += 1 }
        #expect(fetches == 0)
    }

    @Test(arguments: [2, 3])
    func `shared and public database pushes do not fetch`(_ scope: Int) {
        var fetches = 0
        CloudSyncCoordinator.routeRemoteNotification(self.payload(scope: scope), enabled: true) { fetches += 1 }
        #expect(fetches == 0)
    }

    @Test
    func `unrelated and malformed pushes do not fetch`() {
        let payloads: [[String: Any]] = [
            [:],
            ["aps": ["alert": "Unrelated notification"]],
            ["ck": ["cid": CloudSyncEngine.containerIdentifier]],
            ["ck": ["cid": CloudSyncEngine.containerIdentifier, "met": [:]]],
            ["ck": ["met": ["dbs": 1]]],
            ["ck": ["cid": CloudSyncEngine.containerIdentifier, "qry": ["dbs": 1]]],
        ]
        var fetches = 0
        for payload in payloads {
            CloudSyncCoordinator.routeRemoteNotification(payload, enabled: true) { fetches += 1 }
        }
        #expect(fetches == 0)
    }
}
