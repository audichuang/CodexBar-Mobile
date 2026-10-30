import Foundation
import Testing
@testable import CodexBarCore

#if canImport(SQLite3)
import SQLite3
#elseif canImport(CSQLite3)
import CSQLite3
#endif

/// Fork-only end-to-end checks of the cost store's persistence contract. Everything runs in temp directories.
/// The scanner shares one store per cache root, so these tests must not interleave with the archive tests.
@Suite(.serialized)
struct CostUsageStoreForkRoundTripTests {
    /// Parser hash of the published fork 0.81.0.1 (tags `v0.81.0.1-mobile.3.1.0-audi.*`). b425bdc2b deliberately
    /// left it out of the compatible predecessors so installed caches rebuild once and pick up `.jsonl.zst` history.
    private static let publishedFork081ParserHash = "a2e66f2e3692d85b"

    @Test
    func `a store written by the current build reads back with the same totals and parser hash`() async throws {
        let env = try CostUsageTestEnvironment()
        defer { env.cleanup() }
        let day = try env.makeLocalNoon(year: 2026, month: 8, day: 30)
        try env.writeCodexSessionFile(
            day: day,
            filename: "rollout-2026-08-30T12-00-00-roundtrip.jsonl",
            contents: CodexArchivedRolloutMirrorTests.rollout(stamp: env.isoString(for: day)))
        let options = Self.options(env)

        let first = CostUsageScanner.loadDailyReport(
            provider: .codex, since: day, until: day, now: day, options: options)
        #expect(first.summary?.totalTokens == 330)

        let databaseURL = CostUsageStore(cacheRoot: env.cacheRoot).databaseURL
        #expect(try Self.storedParserHash(databaseURL) == CodexParserHash.value)

        // A fresh store (a new launch) must adopt the file as-is and serve identical data.
        let reopened = CostUsageStore(cacheRoot: env.cacheRoot)
        let snapshot = await reopened.readSnapshot()
        #expect(await reopened.rebuildCount == 0)
        #expect(await reopened.configuration()?.userVersion == Int(CostUsageStore.schemaVersion))
        #expect(snapshot.files.count == 1)
        #expect(try Self.storedParserHash(databaseURL) == CodexParserHash.value)

        let second = CostUsageScanner.loadDailyReport(
            provider: .codex, since: day, until: day, now: day.addingTimeInterval(1), options: options)
        #expect(second.data == first.data)
        #expect(second.summary?.totalTokens == 330)
    }

    @Test
    func `a cache stamped with the published 0.81 fork hash is rebuilt not adopted`() async throws {
        let env = try CostUsageTestEnvironment()
        defer { env.cleanup() }
        let oldHash = Self.publishedFork081ParserHash
        #expect(oldHash != CodexParserHash.value)
        #expect(!CostUsageStore.compatiblePredecessorParserHashes.contains(oldHash))

        let ghostPath = env.root.appendingPathComponent("ghost.jsonl").path
        let old = CostUsageStore(
            cacheRoot: env.cacheRoot,
            schemaVersion: CostUsageStore.combinedSchemaVersion(
                base: CostUsageStore.baseSchemaVersion, parserHash: oldHash),
            parserHash: oldHash)
        #expect(await old.upsertFile(Self.file(path: ghostPath)))
        let seeded = await old.readSnapshot()
        #expect(seeded.files.contains { $0.path == ghostPath })
        let databaseURL = old.databaseURL
        #expect(try Self.storedParserHash(databaseURL) == oldHash)

        let current = CostUsageStore(cacheRoot: env.cacheRoot)
        let rebuilt = await current.readSnapshot()
        #expect(await current.rebuildCount == 1)
        #expect(!rebuilt.files.contains { $0.path == ghostPath })
        #expect(rebuilt.files.isEmpty)
        #expect(await current.configuration()?.userVersion == Int(CostUsageStore.schemaVersion))
        #expect(try Self.storedParserHash(databaseURL) == CodexParserHash.value)
    }

    @Test
    func `the scanner recovers real totals from a cache stamped with the published 0.81 fork hash`() async throws {
        let env = try CostUsageTestEnvironment()
        defer { env.cleanup() }
        let day = try env.makeLocalNoon(year: 2026, month: 8, day: 30)
        let oldHash = Self.publishedFork081ParserHash
        let ghostPath = env.root.appendingPathComponent("ghost.jsonl").path
        let old = CostUsageStore(
            cacheRoot: env.cacheRoot,
            schemaVersion: CostUsageStore.combinedSchemaVersion(
                base: CostUsageStore.baseSchemaVersion, parserHash: oldHash),
            parserHash: oldHash)
        #expect(await old.upsertFile(Self.file(path: ghostPath)))
        try env.writeCodexSessionFile(
            day: day,
            filename: "rollout-2026-08-30T12-00-00-after-upgrade.jsonl",
            contents: CodexArchivedRolloutMirrorTests.rollout(stamp: env.isoString(for: day)))

        let report = CostUsageScanner.loadDailyReport(
            provider: .codex, since: day, until: day, now: day, options: Self.options(env))

        #expect(report.summary?.totalTokens == 330)
        let cache = CostUsageStoreAccess.read(cacheRoot: env.cacheRoot)
        #expect(cache.files[ghostPath] == nil)
        #expect(cache.files.count == 1)
        #expect(try Self.storedParserHash(old.databaseURL) == CodexParserHash.value)
    }

    @Test
    func `an archived jsonl zst rollout is counted once and sets the scan file total`() throws {
        let env = try CostUsageTestEnvironment()
        defer { env.cleanup() }
        let day = try env.makeLocalNoon(year: 2026, month: 8, day: 30)
        try CodexArchivedRolloutMirrorTests.writeArchive(
            env: env,
            day: day,
            name: "rollout-2026-08-30T12-00-00-\(CodexArchivedRolloutMirrorTests.uuid(7)).jsonl",
            contents: Data(CodexArchivedRolloutMirrorTests.rollout(stamp: env.isoString(for: day)).utf8),
            modified: day)
        let options = Self.options(env)

        let first = CostUsageScanner.loadDailyReport(
            provider: .codex, since: day, until: day, now: day, options: options)
        #expect(first.summary?.totalTokens == 330)
        let cache = CostUsageStoreAccess.read(cacheRoot: env.cacheRoot)
        #expect(cache.codexScanTotalFiles == 1)
        #expect(cache.codexScanCatchUpPending != true)

        // A later refresh over the unchanged archive must not mirror or count it a second time.
        let again = CostUsageScanner.loadDailyReport(
            provider: .codex, since: day, until: day, now: day.addingTimeInterval(1), options: options)
        #expect(again.summary?.totalTokens == 330)
        #expect(CostUsageStoreAccess.read(cacheRoot: env.cacheRoot).codexScanTotalFiles == 1)
    }

    // MARK: - Fixtures

    private static func options(_ env: CostUsageTestEnvironment) -> CostUsageScanner.Options {
        var options = CostUsageScanner.Options(
            codexSessionsRoot: env.codexSessionsRoot,
            cacheRoot: env.cacheRoot,
            codexTraceDatabaseURL: env.root.appendingPathComponent("missing.sqlite"))
        options.refreshMinIntervalSeconds = 0
        return options
    }

    private static func file(path: String) -> CostUsageStoreFile {
        CostUsageStoreFile(
            path: path,
            inode: 42,
            mtimeUnixMs: 1000,
            size: 500,
            parsedBytes: 400,
            anchor: nil,
            scanState: CostUsageStoreScanState(targetSize: 500, isComplete: true),
            sessionID: "ghost-session",
            coverageSinceDay: "2026-08-30",
            coverageUntilDay: "2026-08-30",
            updatedAtUnixMs: 10)
    }

    private static func storedParserHash(_ databaseURL: URL) throws -> String? {
        var database: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &database, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            sqlite3_close(database)
            throw CocoaError(.fileReadUnknown)
        }
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(
            database, "SELECT value FROM meta WHERE key = 'parser_hash'", -1, &statement, nil) == SQLITE_OK
        else { throw CocoaError(.fileReadUnknown) }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW, let text = sqlite3_column_text(statement, 0) else { return nil }
        return String(cString: text)
    }
}
