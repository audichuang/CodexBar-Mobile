import CloudKit
import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

/// Fork-carried coverage for upstream-fork PR 234 (a delete that replaces a queued snapshot save
/// clears the pending save hash). Drop this file with the fork commit once upstream merges #234.
struct CloudSyncForkDeleteHashTests {
    private static let zoneID = CKRecordZone.ID(zoneName: "CodexBarSyncTests", ownerName: CKCurrentUserDefaultName)

    @Test
    func `a delete that replaces a queued save does not hold back a later publication`() throws {
        let (queued, queuedHash) = try Self.snapshotRecord(used: 10, capturedAt: 1000.125)
        let (replacement, replacementHash) = try Self.snapshotRecord(used: 20, capturedAt: 2000.125)
        let recordID = queued.recordID
        let name = recordID.recordName
        var desired = [recordID: queued]
        var hashes = [name: queuedHash]
        var enginePending: Set<CKSyncEngine.PendingRecordZoneChange> = [.saveRecord(recordID)]

        // The provider is disabled while the save is still queued, so it is never sent.
        CloudSyncBatchRecordProvider.replaceSaveWithDelete(
            recordID, desiredRecords: &desired, pendingSaveHashes: &hashes)
        { remove, add in
            enginePending.remove(remove)
            enginePending.insert(add)
        }
        #expect(enginePending == [.deleteRecord(recordID)])
        #expect(desired.isEmpty)
        // pushPendingSnapshots parks a payload while its record name has a pending save hash.
        #expect(hashes[name] == nil)

        // Re-enabled in the same engine lifetime: the replacement is queued, and a late result of
        // the replaced save still cannot confirm it.
        desired[recordID] = replacement
        hashes[name] = replacementHash
        #expect(!CloudSyncBatchRecordProvider.shouldApplySaveResult(
            queued, desiredRecords: desired, pendingSaveHashes: hashes))
        #expect(CloudSyncBatchRecordProvider.shouldApplySaveResult(
            replacement, desiredRecords: desired, pendingSaveHashes: hashes))
    }

    @Test
    func `a sent save that is replaced by a delete cannot confirm anything afterwards`() throws {
        let (sent, sentHash) = try Self.snapshotRecord(used: 10, capturedAt: 1000.125)
        var desired = [sent.recordID: sent]
        var hashes = [sent.recordID.recordName: sentHash]
        CloudSyncBatchRecordProvider.replaceSaveWithDelete(
            sent.recordID, desiredRecords: &desired, pendingSaveHashes: &hashes) { _, _ in }
        #expect(!CloudSyncBatchRecordProvider.shouldApplySaveResult(
            sent, desiredRecords: desired, pendingSaveHashes: hashes))
    }

    @Test
    func `disabling and re enabling a provider around a queued save publishes the new snapshot`() throws {
        let (queued, queuedHash) = try Self.snapshotRecord(used: 10, capturedAt: 1000.125)
        let (replacement, replacementHash) = try Self.snapshotRecord(used: 20, capturedAt: 2000.125)
        var flow = try PublicationFlow(publishing: queued, hash: queuedHash)

        // Offline: the save stays queued, then the provider is disabled.
        flow.reconcile(currentSnapshots: [], enabledProviders: [])
        #expect(flow.enginePending == [.deleteRecord(flow.recordID)])
        #expect(flow.desired.isEmpty)

        // Re-enabled in the same engine lifetime.
        let republished = try flow.reconcileAndPublish(replacement, hash: replacementHash)
        #expect(republished, "the new snapshot must not stay parked behind the dropped save")
        #expect(flow.enginePending == [.saveRecord(flow.recordID)])
        #expect(flow.batchRecord() === replacement)

        flow.finishSave(returned: replacement)
        #expect(flow.confirmedHashes[flow.recordName] == replacementHash)
        #expect(flow.hashes.isEmpty)
    }

    @Test
    func `a late result of a replaced in flight save cannot confirm a different republication`() throws {
        let (sent, sentHash) = try Self.snapshotRecord(used: 10, capturedAt: 1000.125)
        let (replacement, replacementHash) = try Self.snapshotRecord(used: 20, capturedAt: 2000.125)
        var flow = try PublicationFlow(publishing: sent, hash: sentHash)
        #expect(flow.batchRecord() === sent)
        flow.enginePending.remove(.saveRecord(flow.recordID)) // handed to CloudKit, result pending

        flow.reconcile(currentSnapshots: [], enabledProviders: [])
        #expect(try flow.reconcileAndPublish(replacement, hash: replacementHash))

        // A late success is rejected. The engine filters a late failure with the same predicate,
        // so it cannot schedule a retry or a terminal skip for the replacement either.
        #expect(!flow.acceptsResult(sent))
        flow.finishSave(returned: sent)
        #expect(flow.confirmedHashes.isEmpty)
        #expect(flow.hashes[flow.recordName] == replacementHash)
        // The rejected result only rebases the replacement onto the returned system fields.
        let next = flow.batchRecord()
        let batched = try #require(next)
        #expect(batched.encryptedValues["usagePayload"] as? String
            == replacement.encryptedValues["usagePayload"] as? String)
        #expect(flow.acceptsResult(batched))
    }

    @Test
    func `a late result of a replaced in flight save confirms an identical republication once`() throws {
        let (sent, hash) = try Self.snapshotRecord(used: 10, capturedAt: 1000.125)
        let (identical, identicalHash) = try Self.snapshotRecord(used: 10, capturedAt: 1000.125)
        #expect(hash == identicalHash)
        var flow = try PublicationFlow(publishing: sent, hash: hash)
        #expect(flow.batchRecord() === sent)
        flow.enginePending.remove(.saveRecord(flow.recordID))

        flow.reconcile(currentSnapshots: [], enabledProviders: [])
        #expect(try flow.reconcileAndPublish(identical, hash: identicalHash))
        // Re-enabling cancelled the queued delete, so the server keeps the sent content.
        #expect(!flow.enginePending.contains(.deleteRecord(flow.recordID)))

        flow.finishSave(returned: sent)
        #expect(flow.confirmedHashes[flow.recordName] == hash)
        // The redundant queued save is dropped without leaving an in-flight marker behind.
        #expect(flow.batchRecord() == nil)
        #expect(flow.enginePending.isEmpty)
        #expect(flow.hashes.isEmpty)
    }

    /// Model/helper-composition coverage, not engine integration: composes the real static helpers in
    /// the order `pushPendingSnapshots` (immediate reconciliation deletes), `makeChangeBatch` and
    /// `sentRecordZoneChanges` use them. It does not run those engine methods, nor the
    /// `applySnapshotConfigurationDeletionIntents` path. The engine only gets a `CKSyncEngine` from
    /// `initializeEngineIfNeeded`, which needs the iCloud entitlement, a `CKContainer` and an account.
    private struct PublicationFlow {
        let recordID: CKRecord.ID
        var desired: [CKRecord.ID: CKRecord] = [:]
        var hashes: [String: String] = [:]
        var confirmedHashes: [String: String] = [:]
        var fleetSnapshots: [String: AccountSnapshotSyncPayload] = [:]
        var enginePending: Set<CKSyncEngine.PendingRecordZoneChange> = []

        var recordName: String {
            self.recordID.recordName
        }

        init(publishing record: CKRecord, hash: String) throws {
            self.recordID = record.recordID
            #expect(try self.publish(record, hash: hash))
        }

        /// Mirrors the snapshot loop: a record name with an in-flight save parks the payload.
        mutating func publish(_ record: CKRecord, hash: String) throws -> Bool {
            let payload = try #require(try CloudSyncBatchRecordProvider.snapshot(record))
            if self.confirmedHashes[payload.recordName] == hash { return true }
            guard self.hashes[payload.recordName] == nil else { return false }
            self.desired[record.recordID] = record
            self.fleetSnapshots[payload.recordName] = payload
            self.hashes[payload.recordName] = hash
            self.enginePending.insert(.saveRecord(record.recordID))
            return true
        }

        mutating func reconcile(
            currentSnapshots: [AccountSnapshotSyncPayload],
            enabledProviders: Set<ProviderInstanceID>)
        {
            let plan = CloudSyncSnapshotReconciliation.plan(
                currentSnapshots: currentSnapshots,
                persistedSnapshots: self.fleetSnapshots,
                deviceID: "synthetic-device",
                enabledProviders: enabledProviders,
                authoritativeProviders: enabledProviders)
            for name in plan.recordNamesToCancelPendingDeletes where name == self.recordName {
                self.enginePending.remove(.deleteRecord(self.recordID))
            }
            let deletes = CloudSyncSnapshotMigration.immediateReconciliationDeletes(
                plan.recordNamesToDelete, protecting: [])
            for name in deletes where name == self.recordName {
                var pending = self.enginePending
                CloudSyncBatchRecordProvider.replaceSaveWithDelete(
                    self.recordID, desiredRecords: &self.desired, pendingSaveHashes: &self.hashes)
                { remove, add in
                    pending.remove(remove)
                    pending.insert(add)
                }
                self.enginePending = pending
            }
        }

        mutating func reconcileAndPublish(_ record: CKRecord, hash: String) throws -> Bool {
            let payload = try #require(try CloudSyncBatchRecordProvider.snapshot(record))
            self.reconcile(currentSnapshots: [payload], enabledProviders: [payload.provider])
            return try self.publish(record, hash: hash)
        }

        /// Mirrors `makeChangeBatch`, which only asks for records with a pending save.
        mutating func batchRecord() -> CKRecord? {
            guard self.enginePending.contains(.saveRecord(self.recordID)) else { return nil }
            var pending = self.enginePending
            let record = CloudSyncBatchRecordProvider.record(
                for: self.recordID, desiredRecords: self.desired, pendingSaveHashes: &self.hashes)
            { pending.remove($0) }
            self.enginePending = pending
            return record
        }

        func acceptsResult(_ record: CKRecord) -> Bool {
            CloudSyncBatchRecordProvider.shouldApplySaveResult(
                record, desiredRecords: self.desired, pendingSaveHashes: self.hashes)
        }

        /// Mirrors the saved-record filter in `sentRecordZoneChanges`.
        mutating func finishSave(returned record: CKRecord) {
            guard self.acceptsResult(record) else {
                if let desired = self.desired[record.recordID] {
                    self.desired[record.recordID] = CloudSyncEngine.copyUserFields(from: desired, onto: record)
                }
                return
            }
            self.desired.removeValue(forKey: record.recordID)
            CloudSyncSnapshotMigration.applyConfirmedSaveHashes(
                savedRecordNames: [record.recordID.recordName],
                pendingSaveHashes: &self.hashes,
                lastSnapshotHashes: &self.confirmedHashes)
        }
    }

    private static func snapshotRecord(
        used: Double,
        capturedAt: TimeInterval,
        provider: ProviderInstanceID = .claude,
        resetCredits: Int? = nil) throws -> (CKRecord, String)
    {
        let details: [ProviderDetailSection] = try resetCredits.map {
            try [ProviderDetailSection(rows: [.init(label: "Limit Reset Credits", value: String($0))])]
        } ?? []
        let payload = AccountSnapshotSyncPayload(
            provider: provider,
            deviceID: "synthetic-device",
            accountIdentity: "synthetic-account",
            displayLabel: "Synthetic",
            usage: UsageSnapshot(
                primary: RateWindow(usedPercent: used, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
                secondary: nil,
                details: details,
                updatedAt: Date(timeIntervalSince1970: capturedAt),
                identity: ProviderIdentitySnapshot(
                    providerID: provider, accountEmail: nil, accountOrganization: nil, loginMethod: nil)))
        let record = CKRecord(
            recordType: SyncRecordType.accountSnapshot.rawValue,
            recordID: CKRecord.ID(recordName: payload.recordName, zoneID: Self.zoneID))
        record["schemaVersion"] = payload.schemaVersion as CKRecordValue
        record["provider"] = payload.provider.rawValue as CKRecordValue
        record["deviceID"] = payload.deviceID as CKRecordValue
        record["accountKey"] = payload.accountKey as CKRecordValue
        record["fetchedAt"] = payload.fetchedAt as CKRecordValue
        record.encryptedValues["displayLabel"] = payload.displayLabel as CKRecordValue
        record.encryptedValues["usagePayload"] = try CanonicalSyncJSON.string(payload.usage) as CKRecordValue
        return try (record, CanonicalSyncJSON.hash(payload))
    }
}
