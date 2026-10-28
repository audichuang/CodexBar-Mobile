import CloudKit
import CodexBarCore
import Foundation

enum CloudSyncSnapshotSendKickPolicy {
    static let cadence: TimeInterval = 120

    /// Nil means there is no work to schedule; zero means send now.
    static func delay(
        pendingCount: Int,
        oldestPendingAt: Date?,
        now: Date,
        kickInFlight: Bool,
        lastKickAt: Date?,
        retryNotBefore: Date?) -> TimeInterval?
    {
        guard pendingCount > 0, let oldestPendingAt, !kickInFlight else { return nil }
        return max(
            0,
            oldestPendingAt.addingTimeInterval(self.cadence).timeIntervalSince(now),
            lastKickAt.map { $0.addingTimeInterval(self.cadence).timeIntervalSince(now) } ?? 0,
            retryNotBefore?.timeIntervalSince(now) ?? 0)
    }

    static func snapshotRecordIDs(
        in changes: [CKSyncEngine.PendingRecordZoneChange],
        deviceID: String,
        zoneID: CKRecordZone.ID) -> [CKRecord.ID]
    {
        changes.compactMap { change in
            guard case let .saveRecord(id) = change,
                  id.zoneID == zoneID,
                  id.recordName.hasPrefix("snap-"),
                  id.recordName.hasSuffix("-\(deviceID)")
            else { return nil }
            return id
        }
    }
}

/// A single deferred worker owns the wait and explicit send, including all-inFlight cycles.
/// CKSyncEngine state remains the source of truth; this never adds saves or changes save hashes.
@MainActor
final class CloudSyncSnapshotSendKick {
    private var task: Task<Void, Never>?
    private var generation = 0
    private var pendingSince: [CKRecord.ID: Date] = [:]
    private var lastKickAt: Date?
    private var retryNotBefore: Date?
    private let now: () -> Date
    private let sleep: (TimeInterval) async throws -> Void
    private let logger = CodexBarLog.logger(LogCategories.settings)

    init(
        now: @escaping () -> Date = Date.init,
        sleep: @escaping (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) })
    {
        self.now = now
        self.sleep = sleep
    }

    func schedule(
        pendingRecordIDs: @escaping () -> [CKRecord.ID],
        isCurrentEngine: @escaping () -> Bool,
        send: @escaping ([CKRecord.ID]) async throws -> Void)
    {
        guard isCurrentEngine() else { return }
        self.reconcile(pendingRecordIDs())
        guard self.task == nil, !self.pendingSince.isEmpty else { return }
        let generation = self.generation
        self.task = Task { [weak self] in
            // In particular, leave sentRecordZoneChanges processing before calling sendChanges.
            await Task.yield()
            await self?.run(
                generation: generation, pendingRecordIDs: pendingRecordIDs,
                isCurrentEngine: isCurrentEngine, send: send)
        }
    }

    func stop() {
        self.generation += 1
        self.task?.cancel()
        self.task = nil
        self.pendingSince = [:]
        self.lastKickAt = nil
        self.retryNotBefore = nil
    }

    /// Per-record send failures can arrive through delegate events rather than a thrown sendChanges error.
    func postpone(for error: CKError, minimumDelay: TimeInterval = 0) {
        guard let delay = CloudSyncSnapshotMigration.retryDelay(for: error) else { return }
        let deadline = self.now().addingTimeInterval(max(delay, minimumDelay))
        self.retryNotBefore = max(self.retryNotBefore ?? deadline, deadline)
    }

    func clearBackoff() {
        self.retryNotBefore = nil
    }

    func waitUntilIdle() async {
        await self.task?.value
    }

    private func reconcile(_ ids: [CKRecord.ID]) {
        let ids = Set(ids)
        self.pendingSince = self.pendingSince.filter { ids.contains($0.key) }
        let now = self.now()
        for id in ids where self.pendingSince[id] == nil {
            self.pendingSince[id] = now
        }
    }

    private func run(
        generation: Int,
        pendingRecordIDs: () -> [CKRecord.ID],
        isCurrentEngine: () -> Bool,
        send: ([CKRecord.ID]) async throws -> Void) async
    {
        defer {
            if self.generation == generation { self.task = nil }
        }
        while !Task.isCancelled, self.generation == generation, isCurrentEngine() {
            let ids = pendingRecordIDs()
            self.reconcile(ids)
            let now = self.now()
            guard let oldestPendingAt = self.pendingSince.values.min(),
                  let delay = CloudSyncSnapshotSendKickPolicy.delay(
                      pendingCount: ids.count, oldestPendingAt: oldestPendingAt, now: now,
                      kickInFlight: false, lastKickAt: self.lastKickAt, retryNotBefore: self.retryNotBefore)
            else { return }
            if delay > 0 {
                do {
                    try await self.sleep(delay)
                } catch {
                    return
                }
                continue // Re-check engine identity, pending saves, and server backoff after every wait.
            }
            self.lastKickAt = now
            let age = now.timeIntervalSince(oldestPendingAt)
            self.logger.warning("Fleet snapshot send kick: pending=\(ids.count) oldestWaitSeconds=\(Int(age))")
            do {
                try await send(ids)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, self.generation == generation, isCurrentEngine() else { return }
                let ckError = error as? CKError
                if ckError?.code == .operationCancelled { return }
                let code = ckError?.code.rawValue ?? (error as NSError).code
                let retryAfter = ckError?.retryAfterSeconds.map(String.init(describing:)) ?? "none"
                self.logger.warning("Fleet snapshot send kick failed: code=\(code) retryAfterSeconds=\(retryAfter)")
                guard let ckError, CloudSyncSnapshotMigration.retryDelay(for: ckError) != nil else { return }
                self.postpone(for: ckError)
            }
        }
    }
}
