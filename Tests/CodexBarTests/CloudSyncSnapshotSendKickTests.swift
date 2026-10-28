import CloudKit
import Foundation
import Testing
@testable import CodexBar

struct CloudSyncSnapshotSendKickPolicyTests {
    private let now = Date(timeIntervalSince1970: 1000)

    @Test
    func `pending snapshot saves past the threshold need an explicit send`() {
        #expect(self.delay(age: 120) == 0)
        #expect(self.delay(age: 600) == 0)
        #expect(self.delay(age: 119) == 1)
    }

    @Test
    func `a kick in flight prevents another kick`() {
        #expect(self.delay(age: 600, inFlight: true) == nil)
    }

    @Test
    func `kicks cannot run more often than the publish cadence`() {
        #expect(self.delay(age: 600, lastKickAge: 119) == 1)
        #expect(self.delay(age: 600, lastKickAge: 120) == 0)
    }

    @Test
    func `server retry after extends the wait beyond the cadence`() {
        #expect(self.delay(age: 600, lastKickAge: 120, retryAfter: 900) == 900)
        #expect(self.delay(age: 600, retryAfter: 0) == 0)
    }

    @Test
    func `no pending saves means no kick`() {
        #expect(self.delay(age: 600, count: 0) == nil)
    }

    private func delay(
        age: TimeInterval,
        count: Int = 1,
        inFlight: Bool = false,
        lastKickAge: TimeInterval? = nil,
        retryAfter: TimeInterval? = nil) -> TimeInterval?
    {
        CloudSyncSnapshotSendKickPolicy.delay(
            pendingCount: count,
            oldestPendingAt: self.now.addingTimeInterval(-age),
            now: self.now,
            kickInFlight: inFlight,
            lastKickAt: lastKickAge.map { self.now.addingTimeInterval(-$0) },
            retryNotBefore: retryAfter.map { self.now.addingTimeInterval($0) })
    }
}

/// Exercise the production deferred worker with an in-memory pending queue and virtual time.
/// No CKContainer or CKSyncEngine is created, so these tests cannot reach CloudKit.
@MainActor
struct CloudSyncSnapshotSendKickTests {
    private static let zoneID = CKRecordZone.ID(zoneName: "FleetKickTests", ownerName: CKCurrentUserDefaultName)

    @MainActor
    private final class Publisher {
        var now = Date(timeIntervalSince1970: 1000)
        var pending: [CKSyncEngine.PendingRecordZoneChange] = []
        var sent: [[CKRecord.ID]] = []
        var waits: [TimeInterval] = []
        var allowedWaits = 1
        var current = true
        var failures: [CKError] = []
        var onWait: (() -> Void)?
        var onSend: (() -> Void)?
        var kick: CloudSyncSnapshotSendKick!

        init() {
            self.kick = CloudSyncSnapshotSendKick(now: { [unowned self] in self.now }) { [unowned self] delay in
                guard self.waits.count < self.allowedWaits else { throw CancellationError() }
                self.waits.append(delay)
                self.now.addTimeInterval(delay)
                self.onWait?()
            }
        }

        func schedule() {
            self.kick.schedule {
                CloudSyncSnapshotSendKickPolicy.snapshotRecordIDs(
                    in: self.pending, deviceID: "local", zoneID: CloudSyncSnapshotSendKickTests.zoneID)
            } isCurrentEngine: {
                self.current
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
            domain: CKErrorDomain, code: code.rawValue,
            userInfo: [CKErrorRetryAfterKey: NSNumber(value: retryAfter)]))
    }

    @Test
    func `an unchanged inFlight snapshot queue is explicitly sent without another publication`() async {
        let publisher = Publisher()
        defer { publisher.kick.stop() }
        let snapshot = self.id("snap-claude-fixture-local")
        publisher.pending = [.saveRecord(snapshot)]

        publisher.schedule()
        #expect(publisher.sent.isEmpty) // schedule never sends in the caller's event-processing step.
        publisher.now.addTimeInterval(60)
        publisher.schedule() // Same engine-held save: no newly added save and no age reset.
        await publisher.kick.waitUntilIdle()

        #expect(publisher.waits == [60])
        #expect(publisher.sent == [[snapshot]])
    }

    @Test
    func `the worker sends only local snapshot saves and refreshes its scope after waiting`() async {
        let publisher = Publisher()
        defer { publisher.kick.stop() }
        let snapshot = self.id("snap-codex-fixture-local")
        let removed = self.id("snap-claude-removed-local")
        let otherZone = CKRecord.ID(recordName: snapshot.recordName, zoneID: .default)
        publisher.pending = [
            .saveRecord(snapshot), .saveRecord(removed), .saveRecord(self.id("snap-claude-fixture-other")),
            .saveRecord(self.id("device-local")), .saveRecord(self.id("prefs-global")),
            .deleteRecord(self.id("snap-claude-predecessor-local")), .saveRecord(otherZone),
        ]
        publisher.onWait = { [unowned publisher] in publisher.pending.removeAll { $0 == .saveRecord(removed) } }

        publisher.schedule()
        await publisher.kick.waitUntilIdle()

        #expect(publisher.sent == [[snapshot]])
        #expect(publisher.pending.count == 5)
    }

    @Test(arguments: [
        CKError.Code.networkFailure, .networkUnavailable, .serviceUnavailable, .requestRateLimited, .zoneBusy,
    ])
    func `retryable failures respect server retry after`(_ code: CKError.Code) async {
        let publisher = Publisher()
        defer { publisher.kick.stop() }
        let snapshot = self.id("snap-codex-fixture-local")
        publisher.pending = [.saveRecord(snapshot)]
        publisher.allowedWaits = 2
        publisher.failures = [Self.error(code, retryAfter: 900)]

        publisher.schedule()
        await publisher.kick.waitUntilIdle()

        #expect(publisher.waits == [120, 900])
        #expect(publisher.sent == [[snapshot], [snapshot]])
    }

    @Test
    func `publication while a kick is sending does not start a second worker`() async {
        let publisher = Publisher()
        defer { publisher.kick.stop() }
        let snapshot = self.id("snap-codex-fixture-local")
        publisher.pending = [.saveRecord(snapshot)]
        publisher.onSend = { [unowned publisher] in publisher.schedule() }

        publisher.schedule()
        await publisher.kick.waitUntilIdle()

        #expect(publisher.waits == [120])
        #expect(publisher.sent == [[snapshot]])
    }

    @Test
    func `retryable failure without retry after still waits a full cadence`() async {
        let publisher = Publisher()
        defer { publisher.kick.stop() }
        publisher.pending = [.saveRecord(self.id("snap-codex-fixture-local"))]
        publisher.allowedWaits = 2
        publisher.failures = [CKError(.networkFailure)]

        publisher.schedule()
        await publisher.kick.waitUntilIdle()

        #expect(publisher.waits == [120, 120])
        #expect(publisher.sent.count == 2)
    }

    @Test
    func `a delegate failure postpones an already scheduled kick`() async {
        let publisher = Publisher()
        defer { publisher.kick.stop() }
        publisher.pending = [.saveRecord(self.id("snap-codex-fixture-local"))]
        publisher.allowedWaits = 2
        publisher.onWait = { [unowned publisher] in
            publisher.onWait = nil
            publisher.kick.postpone(for: Self.error(.zoneBusy, retryAfter: 600))
        }

        publisher.schedule()
        await publisher.kick.waitUntilIdle()

        #expect(publisher.waits == [120, 600])
        #expect(publisher.sent.count == 1)
    }

    @Test(arguments: [true, false])
    func `a stopped or replaced engine cannot send after the wait`(_ stopped: Bool) async {
        let publisher = Publisher()
        defer { publisher.kick.stop() }
        publisher.pending = [.saveRecord(self.id("snap-codex-fixture-local"))]
        publisher.onWait = { [unowned publisher] in
            if stopped { publisher.kick.stop() } else { publisher.current = false }
        }

        publisher.schedule()
        await publisher.kick.waitUntilIdle()

        #expect(publisher.sent.isEmpty)
    }

    @Test
    func `existing quota backoff can postpone the kick longer than server retry after`() async {
        let publisher = Publisher()
        defer { publisher.kick.stop() }
        publisher.pending = [.saveRecord(self.id("snap-codex-fixture-local"))]
        publisher.kick.postpone(for: Self.error(.quotaExceeded, retryAfter: 60), minimumDelay: 1800)

        publisher.schedule()
        await publisher.kick.waitUntilIdle()

        #expect(publisher.waits == [1800])
        #expect(publisher.sent.count == 1)
    }

    @Test
    func `a successful push clears quota backoff while preserving pending age and kick cadence`() async {
        let publisher = Publisher()
        defer { publisher.kick.stop() }
        let snapshot = self.id("snap-codex-fixture-local")
        publisher.pending = [.saveRecord(snapshot)]
        publisher.allowedWaits = 2
        publisher.schedule()
        await publisher.kick.waitUntilIdle()

        publisher.pending = [.saveRecord(snapshot)]
        publisher.schedule()
        publisher.now.addTimeInterval(60)
        publisher.kick.postpone(for: Self.error(.quotaExceeded, retryAfter: 60), minimumDelay: 3600)
        publisher.kick.clearBackoff()
        await publisher.kick.waitUntilIdle()

        #expect(publisher.waits == [120, 60])
        #expect(publisher.sent == [[snapshot], [snapshot]])
    }

    @Test
    func `CloudKit operation cancellation ends the worker without retrying`() async {
        let publisher = Publisher()
        defer { publisher.kick.stop() }
        publisher.pending = [.saveRecord(self.id("snap-codex-fixture-local"))]
        publisher.allowedWaits = 2
        publisher.failures = [CKError(.operationCancelled)]

        publisher.schedule()
        await publisher.kick.waitUntilIdle()

        #expect(publisher.waits == [120])
        #expect(publisher.sent.count == 1)
    }
}
