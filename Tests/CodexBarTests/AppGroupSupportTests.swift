import Foundation
import Testing
@testable import CodexBarCore
@testable import CodexBarWidget

struct AppGroupSupportTests {
    @Test
    func `app group identifiers use resolved team-prefixed release and debug variants`() {
        #expect(
            AppGroupSupport.currentGroupID(teamID: "Y5PE65HELJ", bundleID: "com.steipete.codexbar")
                == "Y5PE65HELJ.com.steipete.codexbar")
        #expect(
            AppGroupSupport.currentGroupID(teamID: "ABCDE12345", bundleID: "com.steipete.codexbar.debug")
                == "ABCDE12345.com.steipete.codexbar.debug")
        #expect(
            AppGroupSupport.currentGroupID(teamID: "37HFR5V2JJ", bundleID: "com.audichuang.codexbar")
                == "37HFR5V2JJ.com.steipete.codexbar")
        #expect(
            AppGroupSupport.currentGroupID(teamID: "37HFR5V2JJ", bundleID: "com.audichuang.codexbar.debug.widget")
                == "37HFR5V2JJ.com.steipete.codexbar.debug")
        #expect(
            AppGroupSupport.legacyGroupID(for: "com.steipete.codexbar")
                == "group.com.steipete.codexbar")
        #expect(
            AppGroupSupport.legacyGroupID(for: "com.steipete.codexbar.debug")
                == "group.com.steipete.codexbar.debug")
    }

    @Test
    func `resolved team id falls back to plist and then default`() {
        #expect(
            AppGroupSupport.resolvedTeamID(
                infoDictionaryOverride: [AppGroupSupport.teamIDInfoKey: "ABCDE12345"],
                bundleURLOverride: nil) == "ABCDE12345")
        #expect(
            AppGroupSupport.resolvedTeamID(
                infoDictionaryOverride: nil,
                bundleURLOverride: nil) == AppGroupSupport.defaultTeamID)
    }

    @Test
    func `signed helper executable team wins over plist and upstream fallback`() {
        let folder = URL(fileURLWithPath: "/fictional/Example.app/Contents/Helpers")
        let executable = folder.appendingPathComponent("ExampleHelper")
        var lookups: [URL?] = []
        let team = AppGroupSupport.resolvedTeamID(
            infoDictionaryOverride: [AppGroupSupport.teamIDInfoKey: "PLIST00000"],
            bundleURLOverride: folder,
            executableURLOverride: executable,
            signatureTeamIDResolver: { url in
                lookups.append(url)
                return url == executable ? "ABCDE12345" : nil
            })
        #expect(team == "ABCDE12345")
        #expect(lookups == [folder, executable])
    }

    @Test
    func `helper debug identity is read from its contained app even through a symlink`() throws {
        let fixture = try MigrationFixture()
        defer { fixture.cleanUp() }
        let app = fixture.root.appendingPathComponent("Fictional.debug.app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        let helper = contents.appendingPathComponent("Helpers/FictionalHelper")
        try FileManager.default.createDirectory(
            at: helper.deletingLastPathComponent(), withIntermediateDirectories: true)
        let info: [String: Any] = ["CFBundleIdentifier": "com.example.fictional.debug", "CFBundlePackageType": "APPL"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        try Data().write(to: helper)
        let alias = fixture.root.appendingPathComponent("fictional-helper")
        try FileManager.default.createSymbolicLink(at: alias, withDestinationURL: helper)
        #expect(AppGroupSupport.containingAppBundleIdentifier(executableURL: alias) == "com.example.fictional.debug")
    }

    @Test
    func `legacy migration copies snapshot once`() throws {
        let fixture = try MigrationFixture()
        defer { fixture.cleanUp() }
        fixture.legacyDefaults.set(true, forKey: "debugDisableKeychainAccess")
        fixture.legacyDefaults.set(UsageProvider.cursor.rawValue, forKey: "widgetSelectedProvider")
        try fixture.writeSnapshot("legacy-snapshot", to: fixture.legacySnapshotURL)

        let result = fixture.migrate()

        #expect(result.status == .migrated)
        #expect(result.copiedSnapshot)
        #expect(result.copiedDefaults == 2)
        #expect(fixture.currentDefaults.bool(forKey: "debugDisableKeychainAccess"))
        #expect(fixture.currentDefaults.string(forKey: "widgetSelectedProvider") == UsageProvider.cursor.rawValue)
        #expect(try Data(contentsOf: fixture.currentSnapshotURL) == Data("legacy-snapshot".utf8))
        #expect(
            fixture.standardDefaults.integer(forKey: AppGroupSupport.migrationVersionKey)
                == AppGroupSupport.migrationVersion)
        #expect(fixture.fileManager.operations == [
            .exists(fixture.currentSnapshotURL.path),
            .exists(fixture.legacySnapshotURL.path),
            .createDirectory(fixture.currentSnapshotURL.deletingLastPathComponent()),
            .copy(fixture.legacySnapshotURL, fixture.currentSnapshotURL),
        ])

        try fixture.writeSnapshot("changed-legacy-snapshot", to: fixture.legacySnapshotURL)
        fixture.fileManager.operations.removeAll()
        let secondResult = fixture.migrate()
        #expect(secondResult.status == .alreadyCompleted)
        #expect(!secondResult.copiedSnapshot)
        #expect(secondResult.copiedDefaults == 0)
        #expect(fixture.fileManager.operations.isEmpty)
        #expect(try Data(contentsOf: fixture.currentSnapshotURL) == Data("legacy-snapshot".utf8))
    }

    @Test
    func `legacy migration preserves existing target shared defaults`() throws {
        let fixture = try MigrationFixture()
        defer { fixture.cleanUp() }
        fixture.currentDefaults.set(false, forKey: "debugDisableKeychainAccess")
        fixture.currentDefaults.set(UsageProvider.codex.rawValue, forKey: "widgetSelectedProvider")
        fixture.legacyDefaults.set(true, forKey: "debugDisableKeychainAccess")
        fixture.legacyDefaults.set(UsageProvider.cursor.rawValue, forKey: "widgetSelectedProvider")

        let result = fixture.migrate()

        #expect(result.status == .noChangesNeeded)
        #expect(!result.copiedSnapshot)
        #expect(result.copiedDefaults == 0)
        #expect(!fixture.currentDefaults.bool(forKey: "debugDisableKeychainAccess"))
        #expect(fixture.currentDefaults.string(forKey: "widgetSelectedProvider") == UsageProvider.codex.rawValue)
        #expect(!FileManager.default.fileExists(atPath: fixture.currentSnapshotURL.path))
        #expect(fixture.fileManager.operations == [
            .exists(fixture.currentSnapshotURL.path),
            .exists(fixture.legacySnapshotURL.path),
        ])
    }

    @Test
    func `legacy migration preserves existing target snapshot bytes`() throws {
        let fixture = try MigrationFixture()
        defer { fixture.cleanUp() }
        try fixture.writeSnapshot("current-snapshot", to: fixture.currentSnapshotURL)
        try fixture.writeSnapshot("legacy-snapshot", to: fixture.legacySnapshotURL)

        let result = fixture.migrate()

        #expect(result.status == .noChangesNeeded)
        #expect(!result.copiedSnapshot)
        #expect(result.copiedDefaults == 0)
        #expect(try Data(contentsOf: fixture.currentSnapshotURL) == Data("current-snapshot".utf8))
        #expect(fixture.fileManager.operations == [.exists(fixture.currentSnapshotURL.path)])
    }

    @Test
    func `legacy migration completes when synthetic legacy data is absent`() throws {
        let fixture = try MigrationFixture()
        defer { fixture.cleanUp() }

        let result = fixture.migrate()

        #expect(result.status == .noChangesNeeded)
        #expect(!result.copiedSnapshot)
        #expect(result.copiedDefaults == 0)
        #expect(fixture.currentDefaults.dictionaryRepresentation().isEmpty)
        #expect(
            fixture.standardDefaults.integer(forKey: AppGroupSupport.migrationVersionKey)
                == AppGroupSupport.migrationVersion)
        #expect(fixture.fileManager.operations == [
            .exists(fixture.currentSnapshotURL.path),
            .exists(fixture.legacySnapshotURL.path),
        ])
    }

    @Test
    func `fallback migration preserves bytes and selection after the old migration completed`() throws {
        let fixture = try MigrationFixture()
        defer { fixture.cleanUp() }
        fixture.standardDefaults.set(1, forKey: AppGroupSupport.migrationVersionKey)
        fixture.standardDefaults.set("cursor", forKey: "widgetSelectedProvider")
        fixture.standardDefaults.set(true, forKey: "debugDisableKeychainAccess")
        let snapshot = #"{"generatedAt":"2026-01-02T03:04:05Z","entries":[]}"#
        try fixture.writeSnapshot(snapshot, to: fixture.legacySnapshotURL)

        let result = fixture.migrateFallback()

        #expect(result.status == .migrated)
        #expect(result.copiedSnapshot && result.copiedDefaults == 2)
        #expect(try Data(contentsOf: fixture.currentSnapshotURL) == Data(snapshot.utf8))
        #expect(try Data(contentsOf: fixture.legacySnapshotURL) == Data(snapshot.utf8))
        #expect(fixture.currentDefaults.string(forKey: "widgetSelectedProvider") == "cursor")
        #expect(fixture.standardDefaults.string(forKey: "widgetSelectedProvider") == "cursor")
        #expect(fixture.standardDefaults.integer(forKey: AppGroupSupport.widgetFallbackMigrationVersionKey) == 1)
    }

    @Test
    func `fallback migration never overwrites newer shared data or an existing selection`() throws {
        let fixture = try MigrationFixture()
        defer { fixture.cleanUp() }
        fixture.currentDefaults.set("codex", forKey: "widgetSelectedProvider")
        fixture.standardDefaults.set("cursor", forKey: "widgetSelectedProvider")
        try fixture.writeSnapshot("current", to: fixture.currentSnapshotURL)
        try fixture.writeSnapshot("fallback", to: fixture.legacySnapshotURL)

        let result = fixture.migrateFallback()

        #expect(result.status == .noChangesNeeded)
        #expect(try Data(contentsOf: fixture.currentSnapshotURL) == Data("current".utf8))
        #expect(try Data(contentsOf: fixture.legacySnapshotURL) == Data("fallback".utf8))
        #expect(fixture.currentDefaults.string(forKey: "widgetSelectedProvider") == "codex")
        #expect(fixture.fileManager.operations == [.exists(fixture.currentSnapshotURL.path)])
    }

    @Test
    func `failed fallback copy remains retryable without deleting the source`() throws {
        let fixture = try MigrationFixture()
        defer { fixture.cleanUp() }
        try fixture.writeSnapshot("fallback", to: fixture.legacySnapshotURL)
        fixture.fileManager.failCopies = true
        fixture.fileManager.leavePartialCopy = true

        let failed = fixture.migrateFallback()

        #expect(failed.status == .retryNeeded)
        #expect(fixture.standardDefaults.object(forKey: AppGroupSupport.widgetFallbackMigrationVersionKey) == nil)
        #expect(try Data(contentsOf: fixture.legacySnapshotURL) == Data("fallback".utf8))
        #expect(!FileManager.default.fileExists(atPath: fixture.currentSnapshotURL.path))
        let leftovers = try FileManager.default.contentsOfDirectory(
            at: fixture.currentSnapshotURL.deletingLastPathComponent(), includingPropertiesForKeys: nil)
        #expect(!leftovers.contains { $0.lastPathComponent.hasPrefix(".widget-migration-") })
        fixture.fileManager.failCopies = false
        #expect(fixture.migrateFallback().copiedSnapshot)
        #expect(fixture.migrateFallback().status == .alreadyCompleted)
    }

    @Test
    func `unavailable fallback target retains retry eligibility`() throws {
        let fixture = try MigrationFixture()
        defer { fixture.cleanUp() }
        #expect(fixture.migrateFallback(currentDefaultsAvailable: false).status == .targetUnavailable)
        #expect(fixture.standardDefaults.object(forKey: AppGroupSupport.widgetFallbackMigrationVersionKey) == nil)
        #expect(fixture.fileManager.operations == [.containerLookup])
    }

    @Test
    func `absent fallback data completes without inventing a snapshot or selection`() throws {
        let fixture = try MigrationFixture()
        defer { fixture.cleanUp() }
        #expect(fixture.migrateFallback().status == .noChangesNeeded)
        #expect(fixture.currentDefaults.dictionaryRepresentation().isEmpty)
        #expect(!FileManager.default.fileExists(atPath: fixture.currentSnapshotURL.path))
    }

    @Test
    func `widget selection reads app-local preference until migration and prefers shared choice`() {
        let current = InMemoryUserDefaults()
        let fallback = InMemoryUserDefaults()
        #expect(WidgetSelectionStore.selectedProvider(in: current, fallback: fallback) == nil)
        fallback.set("cursor", forKey: "widgetSelectedProvider")
        #expect(WidgetSelectionStore.selectedProvider(in: current, fallback: fallback)?.rawValue == "cursor")
        current.set("codex", forKey: "widgetSelectedProvider")
        #expect(WidgetSelectionStore.selectedProvider(in: current, fallback: fallback)?.rawValue == "codex")
    }

    @Test(arguments: [false, true])
    func `widget-first startup never persists an inferred default before host preference migration`(
        snapshotAvailable: Bool) throws
    {
        let fixture = try MigrationFixture()
        defer { fixture.cleanUp() }
        let widgetDefaults = InMemoryUserDefaults()
        fixture.standardDefaults.set("cursor", forKey: "widgetSelectedProvider")
        let snapshot = WidgetSnapshot(entries: [], enabledProviders: [.codex, .cursor], generatedAt: Date())
        let entry = CodexBarSwitcherTimelineProvider.makeEntry(
            snapshot: snapshotAvailable ? snapshot : nil,
            stored: WidgetSelectionStore.selectedProvider(in: fixture.currentDefaults, fallback: widgetDefaults),
            saveSelection: { fixture.currentDefaults.set($0.rawValue, forKey: "widgetSelectedProvider") })
        #expect(entry.provider == .codex)
        #expect(fixture.currentDefaults.object(forKey: "widgetSelectedProvider") == nil)

        #expect(fixture.migrateFallback().copiedDefaults == 1)
        let restored = CodexBarSwitcherTimelineProvider.makeEntry(
            snapshot: snapshot,
            stored: WidgetSelectionStore.selectedProvider(in: fixture.currentDefaults, fallback: widgetDefaults),
            saveSelection: { fixture.currentDefaults.set($0.rawValue, forKey: "widgetSelectedProvider") })
        #expect(restored.provider == .cursor)
        #expect(fixture.currentDefaults.string(forKey: "widgetSelectedProvider") == "cursor")
    }

    @Test
    func `real provider removal can still persist its supported fallback`() {
        let snapshot = WidgetSnapshot(entries: [], enabledProviders: [.codex], generatedAt: Date())
        var saved: [UsageProvider] = []
        let entry = CodexBarSwitcherTimelineProvider.makeEntry(
            snapshot: snapshot, stored: .cursor, saveSelection: { saved.append($0) })
        #expect(entry.provider == .codex)
        #expect(saved == [.codex])
    }

    @Test
    func `widget local legacy choice stays effective without overwriting a newer explicit choice`() throws {
        let fixture = try MigrationFixture()
        defer { fixture.cleanUp() }
        let widgetDefaults = InMemoryUserDefaults()
        widgetDefaults.set("cursor", forKey: "widgetSelectedProvider")
        let stored = WidgetSelectionStore.selectedProvider(in: fixture.currentDefaults, fallback: widgetDefaults)
        var writes = 0
        let save: (UsageProvider) -> Void = { provider in
            if WidgetSelectionStore.persist(provider.instanceID, to: fixture.currentDefaults) { writes += 1 }
        }
        _ = CodexBarSwitcherTimelineProvider.makeEntry(snapshot: nil, stored: stored, saveSelection: save)
        #expect(writes == 0)
        let snapshot = WidgetSnapshot(entries: [], enabledProviders: [.codex, .cursor], generatedAt: Date())
        let entry = CodexBarSwitcherTimelineProvider.makeEntry(
            snapshot: snapshot, stored: stored, saveSelection: save)
        #expect(entry.provider == .cursor)
        #expect(writes == 0)
        #expect(fixture.migrateFallback().copiedDefaults == 0)
        save(.codex)
        _ = CodexBarSwitcherTimelineProvider.makeEntry(snapshot: snapshot, stored: stored, saveSelection: save)
        #expect(writes == 1)
        #expect(fixture.currentDefaults.string(forKey: "widgetSelectedProvider") == "codex")
    }

    @Test
    func `a publisher racing migration keeps its newer snapshot`() throws {
        let fixture = try MigrationFixture()
        defer { fixture.cleanUp() }
        try fixture.writeSnapshot("fallback", to: fixture.legacySnapshotURL)
        fixture.fileManager.publishDuringCopy = fixture.currentSnapshotURL
        #expect(!fixture.migrateFallback().copiedSnapshot)
        #expect(try Data(contentsOf: fixture.currentSnapshotURL) == Data("publisher".utf8))
        #expect(try Data(contentsOf: fixture.legacySnapshotURL) == Data("fallback".utf8))
    }

    @Test
    func `unavailable synthetic target does not mark migration complete`() throws {
        let fixture = try MigrationFixture()
        defer { fixture.cleanUp() }

        let result = fixture.migrate(currentDefaultsAvailable: false)

        #expect(result.status == .targetUnavailable)
        #expect(!result.copiedSnapshot)
        #expect(result.copiedDefaults == 0)
        #expect(fixture.standardDefaults.object(forKey: AppGroupSupport.migrationVersionKey) == nil)
        #expect(fixture.fileManager.operations == [.containerLookup])
    }
}

private struct MigrationFixture {
    let root: URL
    let standardDefaults = InMemoryUserDefaults()
    let currentDefaults = InMemoryUserDefaults()
    let legacyDefaults = InMemoryUserDefaults()
    let fileManager: MigrationFileManager

    var currentSnapshotURL: URL {
        self.root.appendingPathComponent("current/widget-snapshot.json")
    }

    var legacySnapshotURL: URL {
        self.root.appendingPathComponent("legacy/widget-snapshot.json")
    }

    init() throws {
        self.root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AppGroupSupportTests-\(UUID().uuidString)", isDirectory: true)
        self.fileManager = MigrationFileManager(root: self.root)
        try FileManager.default.createDirectory(at: self.root, withIntermediateDirectories: true)
    }

    func writeSnapshot(_ value: String, to url: URL) throws {
        try self.fileManager.requireContained(url)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(value.utf8).write(to: url)
    }

    func migrate(currentDefaultsAvailable: Bool = true) -> AppGroupSupport.MigrationResult {
        // nil is intentional only for the unavailable-target case: container lookup is stubbed to nil.
        AppGroupSupport.migrateLegacyDataIfNeeded(
            bundleID: "com.steipete.codexbar",
            standardDefaults: self.standardDefaults,
            fileManager: self.fileManager,
            homeDirectory: self.root.appendingPathComponent("home", isDirectory: true),
            currentDefaultsOverride: currentDefaultsAvailable ? self.currentDefaults : nil,
            legacyDefaultsOverride: self.legacyDefaults,
            currentSnapshotURLOverride: self.currentSnapshotURL,
            legacySnapshotURLOverride: self.legacySnapshotURL)
    }

    func migrateFallback(currentDefaultsAvailable: Bool = true) -> AppGroupSupport.MigrationResult {
        AppGroupSupport.migrateWidgetFallbackDataIfNeeded(
            bundleID: "com.audichuang.codexbar",
            standardDefaults: self.standardDefaults,
            fileManager: self.fileManager,
            homeDirectory: self.root.appendingPathComponent("home"),
            currentDefaultsOverride: currentDefaultsAvailable ? self.currentDefaults : nil,
            currentSnapshotURLOverride: self.currentSnapshotURL,
            fallbackSnapshotURLOverride: self.legacySnapshotURL)
    }

    func cleanUp() {
        do {
            try FileManager.default.removeItem(at: self.root)
        } catch {
            Issue.record("Could not remove synthetic migration fixture: \(error)")
        }
    }
}

private final class MigrationFileManager: FileManager, @unchecked Sendable {
    enum Operation: Equatable {
        case containerLookup
        case homeLookup
        case searchPathLookup
        case exists(String)
        case createDirectory(URL)
        case copy(URL, URL)
        case move(URL, URL)
        case remove(URL)
    }

    let root: URL
    private let backing = FileManager()
    var operations: [Operation] = []
    var failCopies = false
    var leavePartialCopy = false
    var publishDuringCopy: URL?

    init(root: URL) {
        self.root = root
        super.init()
    }

    override func containerURL(forSecurityApplicationGroupIdentifier _: String) -> URL? {
        self.operations.append(.containerLookup)
        return nil
    }

    override var homeDirectoryForCurrentUser: URL {
        self.operations.append(.homeLookup)
        return self.root.appendingPathComponent("home", isDirectory: true)
    }

    override func urls(for _: SearchPathDirectory, in _: SearchPathDomainMask) -> [URL] {
        self.operations.append(.searchPathLookup)
        return []
    }

    override func fileExists(atPath path: String) -> Bool {
        self.operations.append(.exists(path))
        guard (try? self.requireContained(URL(fileURLWithPath: path))) != nil else { return false }
        return self.backing.fileExists(atPath: path)
    }

    override func createDirectory(
        at url: URL,
        withIntermediateDirectories createIntermediates: Bool,
        attributes: [FileAttributeKey: Any]? = nil) throws
    {
        self.operations.append(.createDirectory(url))
        try self.requireContained(url)
        try self.backing.createDirectory(
            at: url,
            withIntermediateDirectories: createIntermediates,
            attributes: attributes)
    }

    override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        self.operations.append(.copy(srcURL, dstURL))
        try self.requireContained(srcURL)
        try self.requireContained(dstURL)
        if self.failCopies {
            if self.leavePartialCopy { try Data("partial".utf8).write(to: dstURL) }
            throw CocoaError(.fileWriteNoPermission)
        }
        try self.backing.copyItem(at: srcURL, to: dstURL)
        if let published = self.publishDuringCopy {
            try self.requireContained(published)
            try Data("publisher".utf8).write(to: published)
        }
    }

    override func moveItem(at srcURL: URL, to dstURL: URL) throws {
        self.operations.append(.move(srcURL, dstURL))
        try self.requireContained(srcURL)
        try self.requireContained(dstURL)
        try self.backing.moveItem(at: srcURL, to: dstURL)
    }

    override func removeItem(at url: URL) throws {
        self.operations.append(.remove(url))
        try self.requireContained(url)
        try self.backing.removeItem(at: url)
    }

    func requireContained(_ url: URL) throws {
        let path = url.standardizedFileURL.path
        guard path == self.root.path || path.hasPrefix(self.root.path + "/") else {
            Issue.record("Migration attempted an operation outside its synthetic root: \(url)")
            throw CocoaError(.fileReadNoPermission)
        }
    }
}
