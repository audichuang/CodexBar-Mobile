import CloudKit
import Foundation
import Testing
@testable import CodexBar

/// Walks the fork's fleet send-kick through one publish cycle on virtual time, so no CKContainer
/// or CKSyncEngine is created. Save-result handling is upstream #4798 (`CloudSyncBatchRecordProviderTests`).
@MainActor
struct CloudSyncForkEndToEndTests {
    private static let zoneID = CKRecordZone.ID(zoneName: "ForkEndToEnd", ownerName: CKCurrentUserDefaultName)
    private static let name = "snap-claude-fixture-local"

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

    private static func error(_ code: CKError.Code, retryAfter: TimeInterval) -> CKError {
        CKError(_nsError: NSError(
            domain: CKErrorDomain,
            code: code.rawValue,
            userInfo: [CKErrorRetryAfterKey: NSNumber(value: retryAfter)]))
    }

    @Test
    func `a publication is kicked once`() async {
        let publisher = Publisher()
        defer { publisher.kick.stop() }
        publisher.pending = [.saveRecord(self.id(Self.name))]

        publisher.schedule()
        await publisher.kick.waitUntilIdle()

        #expect(publisher.sent == [[self.id(Self.name)]])
        #expect(publisher.pending.isEmpty)
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
}
