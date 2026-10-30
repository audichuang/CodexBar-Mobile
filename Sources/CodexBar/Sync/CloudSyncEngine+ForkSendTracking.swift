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
