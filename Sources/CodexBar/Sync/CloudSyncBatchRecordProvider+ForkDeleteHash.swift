import CloudKit

/// Fork-carried fix from upstream-fork PR 234. Both snapshot delete loops in `CloudSyncEngine`
/// call this (fork hook). Drop this file and restore the call sites once upstream merges #234.
extension CloudSyncBatchRecordProvider {
    /// Replaces a snapshot save with a delete. A save that never left the queue gets no result
    /// callback, so its in-flight marker is cleared here. A save that was already sent cannot confirm
    /// a later payload with different contents: its result no longer matches `desiredRecords` (see
    /// `shouldApplySaveResult`). A later identical payload may be confirmed by it, which is what the
    /// server then stores.
    static func replaceSaveWithDelete(
        _ recordID: CKRecord.ID,
        desiredRecords: inout [CKRecord.ID: CKRecord],
        pendingSaveHashes: inout [String: String],
        changePending: (
            _ remove: CKSyncEngine.PendingRecordZoneChange,
            _ add: CKSyncEngine.PendingRecordZoneChange) -> Void)
    {
        desiredRecords.removeValue(forKey: recordID)
        pendingSaveHashes.removeValue(forKey: recordID.recordName)
        changePending(.saveRecord(recordID), .deleteRecord(recordID))
    }

    /// Engine-side form of `replaceSaveWithDelete(_:desiredRecords:pendingSaveHashes:changePending:)`, so each
    /// upstream delete loop needs only one call.
    static func replaceSaveWithDelete(
        _ recordID: CKRecord.ID,
        desiredRecords: inout [CKRecord.ID: CKRecord],
        pendingSaveHashes: inout [String: String],
        in engine: CKSyncEngine)
    {
        self.replaceSaveWithDelete(
            recordID,
            desiredRecords: &desiredRecords,
            pendingSaveHashes: &pendingSaveHashes)
        { remove, add in
            engine.state.remove(pendingRecordZoneChanges: [remove])
            engine.state.add(pendingRecordZoneChanges: [add])
        }
    }
}
