import CloudKit
import CodexBarCore
import Foundation

/// Fork-owned pure helpers for tracking which saves a CKSyncEngine batch has sent.
extension CloudSyncSnapshotMigration {
    enum SaveQueueState: Equatable {
        case notQueued
        case inFlight
        /// The app still remembers a save that CKSyncEngine no longer holds and no batch has sent,
        /// for example one a batch dropped because its prepared record was missing. Treating it as
        /// in flight would stall the record until relaunch, so it is queued again.
        case orphaned
    }

    static func saveQueueState(
        recordName: String,
        pendingSaveHashes: [String: String],
        engineHasPendingSave: Bool,
        hasUnprocessedSend: Bool) -> SaveQueueState
    {
        guard self.hasInFlightSave(recordName: recordName, pendingSaveHashes: pendingSaveHashes) else {
            return .notQueued
        }
        // A sent save leaves the engine's pending changes before its result is processed. Queuing it
        // again then would send a second save on the change tag the first one already replaced.
        return engineHasPendingSave || hasUnprocessedSend ? .inFlight : .orphaned
    }

    /// Records the payload hash of each record a built batch sends, oldest first per record.
    /// `providedHashes` holds the hashes captured when the batch asked for each record.
    static func recordSentSaveHashes(
        batchRecordNames: [String],
        providedHashes: [String: String],
        sentSaveHashes: inout [String: [String]])
    {
        for name in batchRecordNames {
            guard let hash = providedHashes[name] else { continue }
            sentSaveHashes[name, default: []].append(hash)
        }
    }

    /// Returns the save results that finished an older payload than the one now pending for their
    /// record, keyed by record name with the hash that was actually sent. A save with an
    /// unprocessed send stays in flight, so this only happens if a record's remembered hash was
    /// cleared and a newer payload queued before an older result arrived; such a result must not
    /// confirm the newer payload or drop its prepared record. `sentSaveHashes` lists the hashes
    /// each record's batches carried, oldest first; results arrive in the same order.
    static func takeSupersededSaveResults(
        recordNames: [String],
        sentSaveHashes: inout [String: [String]],
        pendingSaveHashes: [String: String]) -> [String: String]
    {
        var superseded: [String: String] = [:]
        for name in recordNames {
            guard var sent = sentSaveHashes[name], !sent.isEmpty else { continue }
            let oldest = sent.removeFirst()
            sentSaveHashes[name] = sent.isEmpty ? nil : sent
            if let pending = pendingSaveHashes[name], pending != oldest {
                superseded[name] = oldest
            }
        }
        return superseded
    }
}

/// Per-engine state for the fork's send tracking; the engine holds one instance as `forkSend`.
@MainActor
final class CloudSyncForkSend {
    let kick = CloudSyncSnapshotSendKick()
    /// Payload hashes each record's sent batches carried, oldest first.
    var sentSaveHashes: [String: [String]] = [:]
    /// Hashes captured while a batch under construction asks for its records, keyed by build.
    var providedSaveHashes: [UUID: [String: String]] = [:]
    private let logger = CodexBarLog.logger(LogCategories.settings)

    func reset() {
        self.kick.stop()
        self.sentSaveHashes = [:]
        self.providedSaveHashes = [:]
    }

    /// Keeps the prepared record of a superseded save, re-based on the change tag the save returned.
    static func applySaved(
        _ record: CKRecord,
        _ supersededSaves: [String: String],
        _ desiredRecords: inout [CKRecord.ID: CKRecord],
        _ lastSnapshotHashes: inout [String: String])
    {
        guard let sentHash = supersededSaves[record.recordID.recordName] else {
            desiredRecords.removeValue(forKey: record.recordID)
            return
        }
        // A newer payload is already queued for this record: keep it, and send it on
        // the change tag this save returned.
        lastSnapshotHashes[record.recordID.recordName] = sentHash
        if let desired = desiredRecords[record.recordID] {
            desiredRecords[record.recordID] = CloudSyncEngine.copyUserFields(from: desired, onto: record)
        }
    }

    static func confirmed(_ records: [CKRecord], _ supersededSaves: [String: String]) -> [String] {
        records.map(\.recordID.recordName).filter { supersededSaves[$0] == nil }
    }

    static func unsuperseded(
        _ failures: [CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave],
        _ supersededSaves: [String: String]) -> [CKSyncEngine.Event.SentRecordZoneChanges.FailedRecordSave]
    {
        failures.filter { supersededSaves[$0.record.recordID.recordName] == nil }
    }

    func warnOrphanedSave(_ recordName: String) {
        self.logger.warning("Re-queueing snapshot save CKSyncEngine no longer holds: \(recordName)")
    }
}

extension CloudSyncEngine {
    func takeSupersededSaves(_ changes: CKSyncEngine.Event.SentRecordZoneChanges) -> [String: String] {
        CloudSyncSnapshotMigration.takeSupersededSaveResults(
            recordNames: changes.savedRecords.map(\.recordID.recordName)
                + changes.failedRecordSaves.map(\.record.recordID.recordName),
            sentSaveHashes: &self.forkSend.sentSaveHashes,
            pendingSaveHashes: self.pendingSaveHashes)
    }

    func makeForkChangeBatch(
        _ context: CKSyncEngine.SendChangesContext,
        syncEngine: CKSyncEngine) async -> CKSyncEngine.RecordZoneChangeBatch?
    {
        // A retired engine's late callback must not read or record the current engine's saves.
        guard self.isCurrent(syncEngine: syncEngine) else { return nil }
        let changes = syncEngine.state.pendingRecordZoneChanges.filter(context.options.scope.contains)
        let build = UUID()
        self.forkSend.providedSaveHashes[build] = [:]
        let batch = await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changes) { [weak self] recordID in
            guard let self else { return nil }
            return await self.recordForPendingSave(recordID, syncEngine: syncEngine, batch: build)
        }
        let provided = self.forkSend.providedSaveHashes.removeValue(forKey: build) ?? [:]
        guard self.isCurrent(syncEngine: syncEngine) else { return nil }
        // A full batch can ask for a record and then leave it out; only the records it kept are sent.
        CloudSyncSnapshotMigration.recordSentSaveHashes(
            batchRecordNames: batch?.recordsToSave.map(\.recordID.recordName) ?? [],
            providedHashes: provided,
            sentSaveHashes: &self.forkSend.sentSaveHashes)
        return batch
    }

    /// Batch-tracking variant: refuses a retired engine and remembers the payload hash each provided save carries.
    func recordForPendingSave(
        _ recordID: CKRecord.ID,
        syncEngine: CKSyncEngine? = nil,
        batch: UUID) -> CKRecord?
    {
        guard self.isCurrent(syncEngine: syncEngine) else { return nil }
        let record = self.recordForPendingSave(recordID, syncEngine: syncEngine)
        if record != nil, let hash = self.pendingSaveHashes[recordID.recordName] {
            self.forkSend.providedSaveHashes[batch]?[recordID.recordName] = hash
        }
        return record
    }

    /// CKSyncEngine's pending changes are the source of truth for what will be sent;
    /// `pendingSaveHashes` only remembers which payload a save carries.
    func hasInFlightSnapshotSave(_ recordName: String, engine: CKSyncEngine) -> Bool {
        let recordID = CKRecord.ID(recordName: recordName, zoneID: Self.zoneID)
        switch CloudSyncSnapshotMigration.saveQueueState(
            recordName: recordName,
            pendingSaveHashes: self.pendingSaveHashes,
            engineHasPendingSave: engine.state.pendingRecordZoneChanges.contains(.saveRecord(recordID)),
            hasUnprocessedSend: self.forkSend.sentSaveHashes[recordName] != nil)
        {
        case .inFlight:
            return true
        case .orphaned:
            self.forkSend.warnOrphanedSave(recordName)
            self.pendingSaveHashes.removeValue(forKey: recordName)
            return false
        case .notQueued:
            return false
        }
    }

    func scheduleSnapshotSendKick(engine: CKSyncEngine) {
        self.forkSend.kick.schedule { [weak self] in
            guard let self, !self.state.status.needsAppUpdate else { return [] }
            return CloudSyncSnapshotSendKickPolicy.snapshotRecordIDs(
                in: engine.state.pendingRecordZoneChanges,
                deviceID: self.settings.macFleetSyncDeviceID,
                zoneID: Self.zoneID).filter { self.skippedTerminalReplacementHashes[$0.recordName] == nil }
        } isCurrentEngine: { [weak self] in
            self?.isCurrent(syncEngine: engine) ?? false
        } send: { ids in
            try await engine.sendChanges(.init(scope: .recordIDs(ids)))
        }
    }
}
