import Foundation
#if os(macOS)
import Security
#endif

public enum AppGroupSupport {
    public static let defaultTeamID = "Y5PE65HELJ"
    public static let teamIDInfoKey = "CodexBarTeamID"
    public static let legacyReleaseGroupID = "group.com.steipete.codexbar"
    public static let legacyDebugGroupID = "group.com.steipete.codexbar.debug"
    public static let widgetSnapshotFilename = "widget-snapshot.json"
    public static let migrationVersion = 1
    public static let migrationVersionKey = "appGroupMigrationVersion"
    public static let widgetFallbackMigrationVersionKey = "widgetFallbackMigrationVersion"
    private static let sharedDefaultsMigrationKeys = [
        "debugDisableKeychainAccess",
        "widgetSelectedProvider",
    ]

    public struct MigrationResult: Sendable {
        public enum Status: String, Sendable {
            case alreadyCompleted
            case targetUnavailable
            case noChangesNeeded
            case migrated
            case retryNeeded
        }

        public let status: Status
        public let copiedSnapshot: Bool
        public let copiedDefaults: Int

        public init(status: Status, copiedSnapshot: Bool = false, copiedDefaults: Int = 0) {
            self.status = status
            self.copiedSnapshot = copiedSnapshot
            self.copiedDefaults = copiedDefaults
        }
    }

    public static func currentGroupID(for bundleID: String? = Bundle.main.bundleIdentifier) -> String {
        self.currentGroupID(teamID: self.resolvedTeamID(), bundleID: bundleID)
    }

    static func currentGroupID(teamID: String, bundleID: String?) -> String {
        let base = "\(teamID).com.steipete.codexbar"
        return self.isDebugBundleID(bundleID) ? "\(base).debug" : base
    }

    public static func resolvedTeamID(bundle: Bundle = .main) -> String {
        self.resolvedTeamID(
            infoDictionaryOverride: bundle.infoDictionary,
            bundleURLOverride: bundle.bundleURL)
    }

    static func resolvedTeamID(
        infoDictionaryOverride: [String: Any]?,
        bundleURLOverride: URL?) -> String
    {
        if let teamID = self.codeSignatureTeamID(bundleURL: bundleURLOverride) {
            return teamID
        }
        if let teamID = infoDictionaryOverride?[self.teamIDInfoKey] as? String,
           !teamID.isEmpty
        {
            return teamID
        }
        return self.defaultTeamID
    }

    public static func legacyGroupID(for bundleID: String? = Bundle.main.bundleIdentifier) -> String {
        self.isDebugBundleID(bundleID) ? self.legacyDebugGroupID : self.legacyReleaseGroupID
    }

    public static func sharedDefaults(
        bundleID: String? = Bundle.main.bundleIdentifier,
        fileManager: FileManager = .default)
        -> UserDefaults?
    {
        guard self.currentContainerURL(bundleID: bundleID, fileManager: fileManager) != nil else { return nil }
        return UserDefaults(suiteName: self.currentGroupID(for: bundleID))
    }

    public static func currentContainerURL(
        bundleID: String? = Bundle.main.bundleIdentifier,
        fileManager: FileManager = .default)
        -> URL?
    {
        #if os(macOS)
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: self.currentGroupID(for: bundleID))
        #else
        nil
        #endif
    }

    public static func snapshotURL(
        bundleID: String? = Bundle.main.bundleIdentifier,
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser)
        -> URL
    {
        if let container = self.currentContainerURL(bundleID: bundleID, fileManager: fileManager) {
            return container.appendingPathComponent(self.widgetSnapshotFilename, isDirectory: false)
        }

        let directory = self.localFallbackDirectory(fileManager: fileManager, homeDirectory: homeDirectory)
        return directory.appendingPathComponent(self.widgetSnapshotFilename, isDirectory: false)
    }

    public static func localFallbackDirectory(
        fileManager: FileManager = .default,
        homeDirectory _: URL = FileManager.default.homeDirectoryForCurrentUser)
        -> URL
    {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = base.appendingPathComponent("CodexBar", isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    public static func legacyContainerCandidateURL(
        bundleID: String? = Bundle.main.bundleIdentifier,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser)
        -> URL
    {
        homeDirectory
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Group Containers", isDirectory: true)
            .appendingPathComponent(self.legacyGroupID(for: bundleID), isDirectory: true)
    }

    public static func migrateLegacyDataIfNeeded(
        bundleID: String? = Bundle.main.bundleIdentifier,
        standardDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        currentDefaultsOverride: UserDefaults? = nil,
        legacyDefaultsOverride: UserDefaults? = nil,
        currentSnapshotURLOverride: URL? = nil,
        legacySnapshotURLOverride: URL? = nil)
        -> MigrationResult
    {
        if standardDefaults.integer(forKey: self.migrationVersionKey) >= self.migrationVersion {
            return MigrationResult(status: .alreadyCompleted)
        }

        guard let currentDefaults = currentDefaultsOverride ?? self.sharedDefaults(
            bundleID: bundleID,
            fileManager: fileManager)
        else {
            return MigrationResult(status: .targetUnavailable)
        }

        let legacyDefaults = legacyDefaultsOverride ?? UserDefaults(suiteName: self.legacyGroupID(for: bundleID))
        let currentSnapshotURL = currentSnapshotURLOverride
            ?? self.currentContainerURL(bundleID: bundleID, fileManager: fileManager)?
            .appendingPathComponent(self.widgetSnapshotFilename, isDirectory: false)
        let legacySnapshotURL = legacySnapshotURLOverride
            ?? self.legacyContainerCandidateURL(bundleID: bundleID, homeDirectory: homeDirectory)
            .appendingPathComponent(self.widgetSnapshotFilename, isDirectory: false)

        let copiedSnapshot = currentSnapshotURL.map {
            self.copySnapshotIfNeeded(from: legacySnapshotURL, to: $0, fileManager: fileManager) == .copied
        } ?? false

        let copiedDefaults = self.copyLegacySharedDefaults(
            from: legacyDefaults,
            to: currentDefaults)

        let result = if copiedSnapshot || copiedDefaults > 0 {
            MigrationResult(
                status: .migrated,
                copiedSnapshot: copiedSnapshot,
                copiedDefaults: copiedDefaults)
        } else {
            MigrationResult(status: .noChangesNeeded)
        }

        standardDefaults.set(self.migrationVersion, forKey: self.migrationVersionKey)
        return result
    }

    /// Recover app-local data used while the shared container was unavailable.
    /// Its marker is independent of the older group-to-group migration.
    public static func migrateWidgetFallbackDataIfNeeded(
        bundleID: String? = Bundle.main.bundleIdentifier,
        standardDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        currentDefaultsOverride: UserDefaults? = nil,
        currentSnapshotURLOverride: URL? = nil,
        fallbackSnapshotURLOverride: URL? = nil) -> MigrationResult
    {
        guard standardDefaults.integer(forKey: self.widgetFallbackMigrationVersionKey) < 1 else {
            return MigrationResult(status: .alreadyCompleted)
        }
        guard let currentDefaults = currentDefaultsOverride ?? self.sharedDefaults(
            bundleID: bundleID, fileManager: fileManager),
            let currentURL = currentSnapshotURLOverride ?? self.currentContainerURL(
                bundleID: bundleID, fileManager: fileManager)?
                .appendingPathComponent(self.widgetSnapshotFilename)
        else { return MigrationResult(status: .targetUnavailable) }

        let fallbackURL = fallbackSnapshotURLOverride ?? self.localFallbackDirectory(
            fileManager: fileManager, homeDirectory: homeDirectory)
            .appendingPathComponent(self.widgetSnapshotFilename)
        let snapshotResult = self.copySnapshotIfNeeded(from: fallbackURL, to: currentURL, fileManager: fileManager)
        let copiedDefaults = self.copyLegacySharedDefaults(from: standardDefaults, to: currentDefaults)
        if snapshotResult == .failed {
            return MigrationResult(status: .retryNeeded, copiedDefaults: copiedDefaults)
        }
        standardDefaults.set(1, forKey: self.widgetFallbackMigrationVersionKey)
        return MigrationResult(
            status: snapshotResult == .copied || copiedDefaults > 0 ? .migrated : .noChangesNeeded,
            copiedSnapshot: snapshotResult == .copied,
            copiedDefaults: copiedDefaults)
    }

    private enum SnapshotCopyResult { case unchanged, copied, failed }

    private static func copySnapshotIfNeeded(
        from source: URL, to target: URL, fileManager: FileManager) -> SnapshotCopyResult
    {
        guard !fileManager.fileExists(atPath: target.path), fileManager.fileExists(atPath: source.path) else {
            return .unchanged
        }
        do {
            try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.copyItem(at: source, to: target)
            return .copied
        } catch {
            return .failed
        }
    }

    private static func copyLegacySharedDefaults(
        from legacyDefaults: UserDefaults?,
        to currentDefaults: UserDefaults) -> Int
    {
        guard let legacyDefaults else { return 0 }

        var copied = 0
        for key in self.sharedDefaultsMigrationKeys {
            guard currentDefaults.object(forKey: key) == nil,
                  let legacyValue = legacyDefaults.object(forKey: key)
            else {
                continue
            }
            currentDefaults.set(legacyValue, forKey: key)
            copied += 1
        }
        return copied
    }

    private static func isDebugBundleID(_ bundleID: String?) -> Bool {
        guard let bundleID, !bundleID.isEmpty else { return false }
        return bundleID.contains(".debug")
    }

    private static func codeSignatureTeamID(bundleURL: URL?) -> String? {
        #if os(macOS)
        guard let bundleURL else { return nil }

        var staticCode: SecStaticCode?
        guard SecStaticCodeCreateWithPath(bundleURL as CFURL, SecCSFlags(), &staticCode) == errSecSuccess,
              let code = staticCode
        else {
            return nil
        }

        var infoCF: CFDictionary?
        guard SecCodeCopySigningInformation(
            code,
            SecCSFlags(rawValue: kSecCSSigningInformation),
            &infoCF) == errSecSuccess,
            let info = infoCF as? [String: Any],
            let teamID = info[kSecCodeInfoTeamIdentifier as String] as? String,
            !teamID.isEmpty
        else {
            return nil
        }
        return teamID
        #else
        _ = bundleURL
        return nil
        #endif
    }
}
