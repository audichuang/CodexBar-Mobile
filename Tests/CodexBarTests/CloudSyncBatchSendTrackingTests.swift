import CloudKit
import Foundation
import Testing
@testable import CodexBar

struct CloudSyncBatchSendTrackingTests {
    private final class ProvidedRecords: @unchecked Sendable {
        private let lock = NSLock()
        private var names: [String] = []

        func append(_ name: String) {
            self.lock.withLock { self.names.append(name) }
        }

        var all: [String] {
            self.lock.withLock { self.names }
        }
    }

    private static let zoneID = CKRecordZone.ID(zoneName: "CodexBarSyncTests", ownerName: CKCurrentUserDefaultName)

    private static func largeSnapshotRecords(count: Int) -> [CKRecord.ID: CKRecord] {
        let payload = String(repeating: "x", count: 20000)
        var records: [CKRecord.ID: CKRecord] = [:]
        for index in 0..<count {
            let id = CKRecord.ID(recordName: String(format: "snap-test-%03d", index), zoneID: self.zoneID)
            let record = CKRecord(recordType: "AccountSnapshot", recordID: id)
            record.encryptedValues["usagePayload"] = payload as CKRecordValue
            records[id] = record
        }
        return records
    }

    @Test
    func `a full batch asks the record provider for a record it then leaves out`() async throws {
        let records = Self.largeSnapshotRecords(count: 100)
        let provided = ProvidedRecords()
        let changes = records.keys.sorted { $0.recordName < $1.recordName }.map {
            CKSyncEngine.PendingRecordZoneChange.saveRecord($0)
        }

        let batch = try #require(await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changes) { id in
            provided.append(id.recordName)
            return records[id]
        })

        let saved = Set(batch.recordsToSave.map(\.recordID.recordName))
        let left = Set(provided.all).subtracting(saved)
        #expect(saved.count < records.count)
        #expect(left.count == 1)
    }

    @Test
    func `a record a full batch left out is not counted as sent and does not stall later saves`() async throws {
        let records = Self.largeSnapshotRecords(count: 100)
        let pending = Dictionary(uniqueKeysWithValues: records.keys.map { ($0.recordName, "hash-\($0.recordName)") })
        let provided = ProvidedRecords()
        let changes = records.keys.sorted { $0.recordName < $1.recordName }.map {
            CKSyncEngine.PendingRecordZoneChange.saveRecord($0)
        }
        let first = try #require(await CKSyncEngine.RecordZoneChangeBatch(pendingChanges: changes) { id in
            provided.append(id.recordName)
            return records[id]
        })
        let firstNames = first.recordsToSave.map(\.recordID.recordName)
        let leftOut = try #require(Set(provided.all).subtracting(firstNames).first)

        var sent: [String: [String]] = [:]
        CloudSyncSnapshotMigration.recordSentSaveHashes(
            batchRecordNames: firstNames,
            providedHashes: pending.filter { provided.all.contains($0.key) },
            sentSaveHashes: &sent)
        #expect(sent.count == firstNames.count)
        #expect(sent[leftOut] == nil)

        // The next batch really sends the record that was left out; its result clears it.
        let leftOutHash = try #require(pending[leftOut])
        CloudSyncSnapshotMigration.recordSentSaveHashes(
            batchRecordNames: [leftOut],
            providedHashes: [leftOut: leftOutHash],
            sentSaveHashes: &sent)
        #expect(sent[leftOut] == [leftOutHash])
        let superseded = CloudSyncSnapshotMigration.takeSupersededSaveResults(
            recordNames: [leftOut], sentSaveHashes: &sent, pendingSaveHashes: pending)
        #expect(superseded.isEmpty)
        #expect(sent[leftOut] == nil)
        #expect(CloudSyncSnapshotMigration.saveQueueState(
            recordName: leftOut,
            pendingSaveHashes: pending,
            engineHasPendingSave: false,
            hasUnprocessedSend: sent[leftOut] != nil) == .orphaned)
    }
}
