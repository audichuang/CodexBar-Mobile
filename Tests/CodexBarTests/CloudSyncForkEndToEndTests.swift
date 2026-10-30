import CloudKit
import Foundation
import Testing
@testable import CodexBar

/// Walks the fork's fleet send-kick and batch-tracking seams through one publish cycle.
/// The harness applies the same static fork helpers the engine calls from its CKSyncEngine delegate,
/// and the kick runs on virtual time, so no CKContainer or CKSyncEngine is created.
@MainActor
struct CloudSyncForkEndToEndTests {
    private static let zoneID = CKRecordZone.ID(zoneName: "ForkEndToEnd", ownerName: CKCurrentUserDefaultName)
    private static let name = "snap-claude-fixture-local"

    /// Stand-in for the engine state the fork helpers read and write.
    @MainActor
    private final class Fleet {
        let forkSend = CloudSyncForkSend()
        var pendingSaveHashes: [String: String] = [:]
        var enginePending: Set<String> = []
        var desiredRecords: [CKRecord.ID: CKRecord] = [:]
        var lastSnapshotHashes: [String: String] = [:]

        /// A publication queues the payload and remembers its hash, as the engine does.
        func publish(_ name: String, hash: String) {
            self.pendingSaveHashes[name] = hash
            self.enginePending.insert(name)
        }

        /// CKSyncEngine hands the batch the pending saves; the batch asks for each record, then sends it.
        func buildBatch(_ names: [String]) {
            let provided = Dictionary(uniqueKeysWithValues: names.compactMap { name in
                self.pendingSaveHashes[name].map { (name, $0) }
            })
            CloudSyncSnapshotMigration.recordSentSaveHashes(
                batchRecordNames: names, providedHashes: provided, sentSaveHashes: &self.forkSend.sentSaveHashes)
            self.enginePending.subtract(names)
        }

        func queueState(_ name: String) -> CloudSyncSnapshotMigration.SaveQueueState {
            CloudSyncSnapshotMigration.saveQueueState(
                recordName: name,
                pendingSaveHashes: self.pendingSaveHashes,
                engineHasPendingSave: self.enginePending.contains(name),
                hasUnprocessedSend: self.forkSend.sentSaveHashes[name] != nil)
        }

        /// Mirrors the engine's `.sentRecordZoneChanges` handling for saved records.
        func receiveSaved(_ records: [CKRecord]) -> (superseded: [String: String], confirmed: [String]) {
            let superseded = CloudSyncSnapshotMigration.takeSupersededSaveResults(
                recordNames: records.map(\.recordID.recordName),
                sentSaveHashes: &self.forkSend.sentSaveHashes,
                pendingSaveHashes: self.pendingSaveHashes)
            for record in records {
                CloudSyncForkSend.applySaved(record, superseded, &self.desiredRecords, &self.lastSnapshotHashes)
            }
            let confirmed = CloudSyncForkSend.confirmed(records, superseded)
            for name in confirmed {
                // A confirmed save no longer needs its remembered hash.
                self.pendingSaveHashes.removeValue(forKey: name)
            }
            return (superseded, confirmed)
        }
    }

    /// Drives the production kick with virtual time and an in-memory pending queue.
    @MainActor
    private final class Publisher {
        var now = Date(timeIntervalSince1970: 1000)
        var pending: [CKSyncEngine.PendingRecordZoneChange] = []
        var sent: [[CKRecord.ID]] = []
        var waits: [TimeInterval] = []
        var allowedWaits = 1
        var failures: [CKError] = []
        var onSend: (() -> Void)?
        var kick: CloudSyncSnapshotSendKick!

        init() {
            self.kick = CloudSyncSnapshotSendKick(
                now: { [unowned self] in self.now },
                sleep: { [unowned self] delay in
                    guard self.waits.count < self.allowedWaits else { throw CancellationError() }
                    self.waits.append(delay)
                    self.now.addTimeInterval(delay)
                })
        }

        func schedule() {
            self.kick.schedule {
                CloudSyncSnapshotSendKickPolicy.snapshotRecordIDs(
                    in: self.pending, deviceID: "local", zoneID: CloudSyncForkEndToEndTests.zoneID)
            } isCurrentEngine: {
                true
            } send: { ids in
                self.sent.append(ids)
                self.onSend?()
                if !self.failures.isEmpty { throw self.failures.removeFirst() }
                self.pending.removeAll { change in
                    guard case let .saveRecord(id) = change else { return false }
                    return ids.contains(id)
                }
            }
        }
    }

    private func id(_ name: String) -> CKRecord.ID {
        CKRecord.ID(recordName: name, zoneID: Self.zoneID)
    }

    private func record(_ name: String, payload: String) -> CKRecord {
        let record = CKRecord(recordType: "AccountSnapshot", recordID: self.id(name))
        record.encryptedValues["usagePayload"] = payload as CKRecordValue
        return record
    }

    private static func error(_ code: CKError.Code, retryAfter: TimeInterval) -> CKError {
        CKError(_nsError: NSError(
            domain: CKErrorDomain,
            code: code.rawValue,
            userInfo: [CKErrorRetryAfterKey: NSNumber(value: retryAfter)]))
    }

    @Test
    func `a publication is kicked, and the batch that sends it records its hash`() async {
        let fleet = Fleet()
        let publisher = Publisher()
        defer { publisher.kick.stop() }
        fleet.publish(Self.name, hash: "h1")
        publisher.pending = [.saveRecord(self.id(Self.name))]

        publisher.schedule()
        await publisher.kick.waitUntilIdle()
        fleet.buildBatch([Self.name])

        #expect(publisher.sent == [[self.id(Self.name)]])
        #expect(fleet.forkSend.sentSaveHashes[Self.name] == ["h1"])
        #expect(fleet.queueState(Self.name) == .inFlight)
    }

    @Test
    func `a retryable failure postpones the next kick by the server retry after`() async {
        let publisher = Publisher()
        defer { publisher.kick.stop() }
        publisher.pending = [.saveRecord(self.id(Self.name))]
        publisher.allowedWaits = 2
        publisher.failures = [Self.error(.requestRateLimited, retryAfter: 900)]

        publisher.schedule()
        await publisher.kick.waitUntilIdle()

        #expect(publisher.waits == [120, 900])
        #expect(publisher.sent.count == 2)
    }

    @Test
    func `a successful save clears the backoff a failure set`() async {
        let publisher = Publisher()
        defer { publisher.kick.stop() }
        publisher.pending = [.saveRecord(self.id(Self.name))]
        publisher.kick.postpone(for: Self.error(.zoneBusy, retryAfter: 900))
        // The engine does this when a sent batch reports a saved record.
        publisher.kick.clearBackoff()

        publisher.schedule()
        await publisher.kick.waitUntilIdle()

        #expect(publisher.waits == [120])
        #expect(publisher.sent.count == 1)
    }

    @Test
    func `a late batch from a retired engine is ignored`() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = CloudSyncPersistence(fileURL: directory.appendingPathComponent("sync.json"))
        let stale = self.record(Self.name, payload: "synthetic usage")
        stale["deviceID"] = "current" as CKRecordValue
        stale["schemaVersion"] = 1 as CKRecordValue
        var envelope = CloudSyncPersistence.Envelope(stateSerialization: nil, encodedSystemFields: [:])
        CloudSyncPersistence.cacheSystemFields(of: stale, in: &envelope)
        try persistence.save(envelope)
        let engine = CloudSyncEngine(
            settings: testSettingsStore(suiteName: "CloudSyncForkEndToEndTests", userDefaults: InMemoryUserDefaults()),
            state: CloudSyncState(),
            persistence: persistence)
        engine.pendingSaveHashes[Self.name] = "h1"
        await engine.handleSaveFailure(
            stale, error: CKError(_nsError: NSError(domain: CKErrorDomain, code: CKError.unknownItem.rawValue)))
        // The record is prepared, so a running engine would provide it.
        #expect(engine.recordForPendingSave(self.id(Self.name)) != nil)

        let provided = engine.recordForPendingSave(self.id(Self.name), batch: UUID())

        #expect(provided == nil)
        #expect(engine.forkSend.providedSaveHashes.isEmpty)
        #expect(engine.forkSend.sentSaveHashes.isEmpty)
    }

    @Test
    func `a save the engine is sending is not queued again`() {
        let fleet = Fleet()
        fleet.publish(Self.name, hash: "h1")

        // Still held by CKSyncEngine.
        #expect(fleet.queueState(Self.name) == .inFlight)
        // Sent: it left the engine's pending changes but its result has not been processed yet.
        fleet.buildBatch([Self.name])
        #expect(fleet.queueState(Self.name) == .inFlight)
    }

    @Test
    func `an orphaned save is queued again exactly once`() {
        let fleet = Fleet()
        fleet.publish(Self.name, hash: "h1")
        fleet.enginePending.removeAll() // The engine dropped it and no batch ever sent it.

        #expect(fleet.queueState(Self.name) == .orphaned)
        // Re-queueing forgets the remembered hash, as hasInFlightSnapshotSave does, then publishes again.
        fleet.pendingSaveHashes.removeValue(forKey: Self.name)
        #expect(fleet.queueState(Self.name) == .notQueued)
        fleet.publish(Self.name, hash: "h1")
        #expect(fleet.queueState(Self.name) == .inFlight)
        #expect(fleet.queueState(Self.name) != .orphaned)
    }

    @Test
    func `a superseded result does not confirm the newer hash`() {
        let fleet = Fleet()
        fleet.publish(Self.name, hash: "h1")
        fleet.buildBatch([Self.name])
        // The remembered hash was cleared and a newer payload queued before the first result arrived.
        fleet.publish(Self.name, hash: "h2")
        fleet.desiredRecords[self.id(Self.name)] = self.record(Self.name, payload: "newer")

        let result = fleet.receiveSaved([self.record(Self.name, payload: "older")])

        #expect(result.superseded == [Self.name: "h1"])
        #expect(result.confirmed.isEmpty)
        #expect(fleet.pendingSaveHashes[Self.name] == "h2")
        #expect(fleet.lastSnapshotHashes[Self.name] == "h1")
        #expect(fleet.desiredRecords[self.id(Self.name)]?.encryptedValues["usagePayload"] as? String == "newer")
        #expect(fleet.forkSend.sentSaveHashes[Self.name] == nil)
    }
}
