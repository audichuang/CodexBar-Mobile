import CodexBarSync
import Foundation
import Testing
@testable import CodexBarCore

/// Swift twin of Scripts/test_fork_identity.sh: the identity constants compiled into the apps must agree
/// with the files that sign and entitle them. Reads the repo through `#filePath`.
struct ForkIdentityConsistencyTests {
    private static let repoRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // CodexBarTests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // repo root

    private static func read(_ relativePath: String) throws -> String {
        try String(contentsOf: self.repoRoot.appendingPathComponent(relativePath), encoding: .utf8)
    }

    private static func xcconfigValue(_ key: String) throws -> String {
        let text = try self.read("CodexBarMobile/Config/Fork.xcconfig")
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2, parts[0] == key { return parts[1] }
        }
        Issue.record("\(key) missing from Fork.xcconfig")
        return ""
    }

    private static let entitlementPaths = [
        "CodexBarMobile/CodexBarMobile/CodexBarMobile.entitlements",
        "CodexBarMobile/CodexBarMobilePushExtension/PushExtension.entitlements",
        "CodexBarMobile/CodexBarMobileWidgetOptions/WidgetOptions.entitlements",
        "CodexBarMobile/CodexBarMobileWidgets/WidgetExtension.entitlements",
    ]

    private static func entitlementList(_ path: String, key: String) throws -> [String]? {
        let data = try Data(contentsOf: self.repoRoot.appendingPathComponent(path))
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        return plist?[key] as? [String]
    }

    @Test
    func `identity constants match Fork.xcconfig`() throws {
        #expect(try CodexBarCore.ForkIdentity.iCloudContainer == Self.xcconfigValue("FORK_ICLOUD_CONTAINER"))
        #expect(try CodexBarCore.ForkIdentity.appGroup == Self.xcconfigValue("FORK_APP_GROUP"))
        #expect(try CodexBarCore.ForkIdentity.oslogSubsystem == Self.xcconfigValue("FORK_BUNDLE_PREFIX"))
        #expect(try CodexBarCore.ForkIdentity.iCloudContainer == "iCloud." + Self.xcconfigValue("FORK_BUNDLE_PREFIX"))
        #expect(try CodexBarCore.ForkIdentity.appGroup == "group." + Self.xcconfigValue("FORK_BUNDLE_PREFIX"))
    }

    @Test
    func `shared and core copies of ForkIdentity agree`() {
        #expect(CodexBarSync.ForkIdentity.iCloudContainer == CodexBarCore.ForkIdentity.iCloudContainer)
        #expect(CodexBarSync.ForkIdentity.appGroup == CodexBarCore.ForkIdentity.appGroup)
        #expect(CodexBarSync.ForkIdentity.oslogSubsystem == CodexBarCore.ForkIdentity.oslogSubsystem)
        #expect(CodexBarSync.ForkIdentity.repoSlug == CodexBarCore.ForkIdentity.repoSlug)
        #expect(CodexBarSync.ForkIdentity.repoURL == CodexBarCore.ForkIdentity.repoURL)
        #expect(CodexBarSync.ForkIdentity.helpURL == CodexBarCore.ForkIdentity.helpURL)
        #expect(CodexBarSync.ForkIdentity.widgetOslogSubsystem == CodexBarCore.ForkIdentity.widgetOslogSubsystem)
        #expect(CodexBarSync.ForkIdentity.providerZoneDidChangeNotification
            == CodexBarCore.ForkIdentity.providerZoneDidChangeNotification)
    }

    @Test
    func `helpURL points at the fork README that exists on mobile-dev`() {
        let prefix = CodexBarCore.ForkIdentity.repoURL + "/blob/mobile-dev/"
        let url = CodexBarCore.ForkIdentity.helpURL
        #expect(url.hasPrefix(prefix))
        let path = String(url.dropFirst(prefix.count))
        #expect(path == ".github/README.md")
        #expect(FileManager.default.fileExists(atPath: Self.repoRoot.appendingPathComponent(path).path))
    }

    @Test
    func `CloudKit container matches every entitlements file that declares one`() throws {
        #expect(CloudSyncConstants.containerIdentifier == CodexBarCore.ForkIdentity.iCloudContainer)
        var declared = 0
        for path in Self.entitlementPaths {
            guard let containers = try Self.entitlementList(
                path,
                key: "com.apple.developer.icloud-container-identifiers") else { continue }
            declared += 1
            #expect(containers == [CloudSyncConstants.containerIdentifier], "\(path)")
        }
        #expect(declared > 0)
    }

    @Test
    func `iOS app group matches every entitlements file that declares one`() throws {
        var declared = 0
        for path in Self.entitlementPaths {
            guard let groups = try Self.entitlementList(path, key: "com.apple.security.application-groups")
            else { continue }
            declared += 1
            #expect(groups == [CodexBarCore.ForkIdentity.appGroup], "\(path)")
        }
        #expect(declared > 0)
    }

    @Test
    func `macOS app group is the team-prefixed id packaged into the entitlements`() throws {
        let team = try Self.xcconfigValue("FORK_TEAM")
        let release = AppGroupSupport.currentGroupID(
            teamID: team,
            bundleID: "\(CodexBarCore.ForkIdentity.oslogSubsystem)")
        let debug = AppGroupSupport.currentGroupID(
            teamID: team,
            bundleID: "\(CodexBarCore.ForkIdentity.oslogSubsystem).debug")
        let package = try Self.read("Scripts/package_app.sh")
        #expect(package.contains("APP_TEAM_ID=\"${APP_TEAM_ID:-\(team)}\""))
        #expect(package.contains("APP_GROUP_ID=\"${APP_TEAM_ID}.\(release.dropFirst(team.count + 1))\""))
        #expect(package.contains("APP_GROUP_ID=\"${APP_TEAM_ID}.\(debug.dropFirst(team.count + 1))\""))
        #expect(package.contains("<string>\(CloudSyncConstants.containerIdentifier)</string>"))
    }
}
