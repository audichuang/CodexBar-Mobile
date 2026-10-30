import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

extension CloudSyncSnapshotMigrationSaveThenDeleteTests {
    @Test
    func `a remembered save is orphaned only when neither the engine nor an unprocessed send holds it`() {
        let hashes = ["snap-claude-a": "hash"]
        func state(_ name: String, engine: Bool, sent: Bool) -> CloudSyncSnapshotMigration.SaveQueueState {
            CloudSyncSnapshotMigration.saveQueueState(
                recordName: name, pendingSaveHashes: hashes, engineHasPendingSave: engine, hasUnprocessedSend: sent)
        }
        #expect(state("snap-claude-a", engine: true, sent: false) == .inFlight)
        #expect(state("snap-claude-a", engine: true, sent: true) == .inFlight)
        // Dropped before any batch sent it: queue it again.
        #expect(state("snap-claude-a", engine: false, sent: false) == .orphaned)
        #expect(state("snap-claude-b", engine: false, sent: false) == .notQueued)
    }

    @Test
    func `a sent save whose result is still queued stays in flight instead of being sent again`() {
        let name = "snap-claude-a"
        var pending = [name: "hash"]
        var sent: [String: [String]] = [name: ["hash"]]
        var last: [String: String] = [:]

        // The engine removed the sent save; its result is still waiting in the delegate queue.
        #expect(CloudSyncSnapshotMigration.saveQueueState(
            recordName: name,
            pendingSaveHashes: pending,
            engineHasPendingSave: false,
            hasUnprocessedSend: sent[name] != nil) == .inFlight)

        // The result then confirms the save and clears the unprocessed send.
        let superseded = CloudSyncSnapshotMigration.takeSupersededSaveResults(
            recordNames: [name], sentSaveHashes: &sent, pendingSaveHashes: pending)
        #expect(superseded.isEmpty)
        CloudSyncSnapshotMigration.applyConfirmedSaveHashes(
            savedRecordNames: [name], pendingSaveHashes: &pending, lastSnapshotHashes: &last)
        #expect(sent[name] == nil)
        #expect(pending[name] == nil)
        #expect(last[name] == "hash")
    }

    @Test
    func `a delayed result of an older save does not confirm a newer payload queued after it`() {
        let name = "snap-claude-a"
        // The remembered hash was cleared and a newer payload queued while the old result was outstanding.
        var pending = [name: "hash-new"]
        var sent = [name: ["hash-old"]]
        var last: [String: String] = [:]

        let superseded = CloudSyncSnapshotMigration.takeSupersededSaveResults(
            recordNames: [name], sentSaveHashes: &sent, pendingSaveHashes: pending)
        #expect(superseded == [name: "hash-old"])
        CloudSyncSnapshotMigration.applyConfirmedSaveHashes(
            savedRecordNames: [name].filter { superseded[$0] == nil },
            pendingSaveHashes: &pending,
            lastSnapshotHashes: &last)
        #expect(pending[name] == "hash-new")
        #expect(last[name] == nil)
        #expect(sent.isEmpty)
    }

    @Test
    func `results are matched to batches in order when the newer batch was built first`() {
        let name = "snap-claude-a"
        var pending = [name: "hash-new"]
        var last: [String: String] = [:]
        // The engine built the newer payload's batch before the old result was processed.
        var sent = [name: ["hash-old", "hash-new"]]

        let first = CloudSyncSnapshotMigration.takeSupersededSaveResults(
            recordNames: [name], sentSaveHashes: &sent, pendingSaveHashes: pending)
        #expect(first == [name: "hash-old"])
        #expect(sent[name] == ["hash-new"])

        let second = CloudSyncSnapshotMigration.takeSupersededSaveResults(
            recordNames: [name], sentSaveHashes: &sent, pendingSaveHashes: pending)
        #expect(second.isEmpty)
        #expect(sent[name] == nil)
        CloudSyncSnapshotMigration.applyConfirmedSaveHashes(
            savedRecordNames: [name], pendingSaveHashes: &pending, lastSnapshotHashes: &last)
        #expect(last[name] == "hash-new")
    }
}
