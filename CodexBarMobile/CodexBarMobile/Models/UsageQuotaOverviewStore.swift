import CodexBarSync
import Combine
import Foundation

@MainActor
protocol UsageQuotaPersistence {
    func load() -> Data?
    func save(_ data: Data)
}

@MainActor
struct UsageQuotaDefaultsPersistence: UsageQuotaPersistence {
    static let key = "usageQuotaOverview.v1"
    let defaults: UserDefaults
    func load() -> Data? { self.defaults.data(forKey: Self.key) }
    func save(_ data: Data) { self.defaults.set(data, forKey: Self.key) }
}

struct UsageQuotaArchive: Codable, Equatable, Sendable {
    var preferences = UsageQuotaPreferences()
    var histories: [UsageQuotaHistory] = []
}

/// Local account/window observations and presentation choices. Demo/test stores never read or
/// write shared defaults, CloudKit or credentials. No provider-shared history is imported.
@MainActor
final class UsageQuotaOverviewStore: ObservableObject {
    static let maximumHistoryStreams = 64
    static let maximumObservationsPerStream = 96
    @Published private var archive: UsageQuotaArchive
    @Published private var linkages: [ProviderAccountLinkage] = []
    @Published private var sourceSnapshots: [SyncedUsageSnapshot]?
    @Published private var quotaSources: [String: SyncProviderQuotaSource]?
    let isReadOnly: Bool
    private let persistence: (any UsageQuotaPersistence)?

    var preferences: UsageQuotaPreferences {
        self.archive.preferences
    }

    init(persistence: (any UsageQuotaPersistence)? = nil) {
        self.persistence = persistence
        if let data = persistence?.load() {
            if let archive = try? JSONDecoder().decode(UsageQuotaArchive.self, from: data), Self.isValid(archive) {
                self.archive = archive
                self.isReadOnly = false
            } else {
                self.archive = UsageQuotaArchive()
                self.isReadOnly = true
            }
        } else {
            self.archive = UsageQuotaArchive()
            self.isReadOnly = false
        }
    }

    static func live() -> UsageQuotaOverviewStore {
        UsageQuotaOverviewStore(persistence: UsageQuotaDefaultsPersistence(defaults: .standard))
    }

    static func inMemory() -> UsageQuotaOverviewStore { UsageQuotaOverviewStore() }

    /// Explicit synthetic fixture for the app's demo only. Never call this for live accounts.
    /// It owns a fresh in-memory archive and cannot mutate a user's persistent samples.
    static func demo(accounts: [ProviderUsageSnapshot], now: Date = .now) -> UsageQuotaOverviewStore {
        let store = Self.inMemory()
        store.reconcile(accounts: accounts, now: now)
        store.mutate { archive in
            let bindings = SummaryCardResolver.accountBindings(
                accounts: accounts, preferences: archive.preferences.identityPreferences)
            for selection in archive.preferences.selections {
                guard let account = bindings.first(where: {
                    $0.0 == selection.accountAnchorID && $0.1.providerID == selection.providerID
                })?.1,
                    let window = QuotaPaceWindowSelection.candidates(for: account)
                        .first(where: { $0.id == selection.windowID })?.window,
                        let reset = window.resetsAt,
                        let duration = UsageQuotaProjection.duration(
                            window: window, providerID: account.providerID,
                            capturedAt: SummaryCardResolver.quotaCapturedAt(account))
                else { continue }
                let captured = SummaryCardResolver.quotaCapturedAt(account)
                let elapsed = duration - reset.timeIntervalSince(captured)
                let span = min(elapsed * 0.8, min(7 * 3600, duration * 0.2))
                guard span >= 900 else { continue }
                let used = min(100, max(0, window.usedPercent))
                let delta = min(used, 8)
                let shape: [Double] = [0, 0.08, 0.08, 0.25, 0.55, 0.55, 0.62, 0.85, 1]
                let observations = shape.enumerated().map { index, fraction in
                    UsageQuotaObservation(
                        capturedAt: captured.addingTimeInterval(-span + span * Double(index) / 8),
                        usedPercent: used - delta + delta * fraction,
                        resetDate: reset, windowDuration: duration)
                }
                archive.histories.removeAll { $0.binding == selection.binding }
                archive.histories.append(UsageQuotaHistory(binding: selection.binding, observations: observations))
            }
        }
        return store
    }

    private static func isValid(_ archive: UsageQuotaArchive) -> Bool {
        let preferences = archive.preferences
        return preferences.schemaVersion == UsageQuotaPreferences.currentSchemaVersion
            && preferences.selections.count <= UsageQuotaPreferences.maximumSelections
            && Set(preferences.selections.map(\.id)).count == preferences.selections.count
            && Set(preferences.selections.map(\.binding)).count == preferences.selections.count
            && Set(preferences.accountAnchors.map(\.id)).count == preferences.accountAnchors.count
            && preferences.selections.allSatisfy { UsageQuotaColor.normalized($0.colorHex) != nil }
            && archive.histories.count <= self.maximumHistoryStreams
            && Set(archive.histories.map(\.binding)).count == archive.histories.count
            && archive.histories.allSatisfy { history in
                history.observations.count <= self.maximumObservationsPerStream
                    && history.observations.allSatisfy {
                        $0.capturedAt.timeIntervalSince1970.isFinite && $0.resetDate.timeIntervalSince1970.isFinite
                            && $0.capturedAt < $0.resetDate && $0.usedPercent.isFinite && (0...100)
                            .contains($0.usedPercent)
                            &&
                            ($0
                                .windowDuration == nil ||
                                ($0.windowDuration?.isFinite == true && ($0.windowDuration ?? 0) > 0))
                    }
            }
    }

    @discardableResult private func mutate(_ change: (inout UsageQuotaArchive) -> Void) -> Bool {
        guard !self.isReadOnly else { return false }
        var next = self.archive
        change(&next)
        guard next != self.archive, Self.isValid(next) else { return false }
        self.archive = next
        if let data = try? JSONEncoder().encode(next) { self.persistence?.save(data) }
        return true
    }

    func reconcile(
        accounts: [ProviderUsageSnapshot], sourceSnapshots: [SyncedUsageSnapshot]? = nil,
        quotaSources: [String: SyncProviderQuotaSource]? = nil, linkages: [ProviderAccountLinkage] = [],
        now: Date = .now)
    {
        if self.sourceSnapshots != sourceSnapshots { self.sourceSnapshots = sourceSnapshots }
        if self.quotaSources != quotaSources { self.quotaSources = quotaSources }
        if self.linkages != linkages { self.linkages = linkages }
        self.mutate { archive in
            let assigned = SummaryCardResolver.accountBindings(
                accounts: accounts, preferences: archive.preferences.identityPreferences)
            for (id, account) in assigned {
                let incoming = UsageAccountIdentity.tokens(for: account)
                if let index = archive.preferences.accountAnchors.firstIndex(where: { $0.id == id }) {
                    let existing = Set(archive.preferences.accountAnchors[index].tokens)
                    let ownsStable = existing.contains(where: UsageAccountIdentity.isStable)
                    let learnable = ownsStable ? incoming.filter { !UsageAccountIdentity.isStable($0) } : incoming
                    archive.preferences.accountAnchors[index].tokens = existing.union(learnable).sorted()
                } else {
                    archive.preferences.accountAnchors.append(UsageAccountAnchor(
                        id: id, providerID: account.providerID, tokens: incoming.sorted()))
                }
            }
            if !archive.preferences.hasInitialized {
                let defaults = Self.initialCandidates(
                    accounts: accounts, preferences: archive.preferences, now: now)
                for candidate in defaults {
                    let ordinal = archive.preferences.selections.filter { $0.providerID == candidate.providerID }.count
                    archive.preferences.selections.append(candidate.configuration(colorHex: UsageQuotaColor.suggested(
                        providerID: candidate.providerID, ordinal: ordinal, tintHex: candidate.providerTintHex)))
                }
                if !archive.preferences.selections.isEmpty { archive.preferences.hasInitialized = true }
            }
            for (anchor, account) in assigned where !account.isError && account.sourceReport?.allFailed != true {
                guard UsageQuotaProjection.hasUnambiguousHistorySource(
                    account, preferences: archive.preferences, linkages: linkages) else { continue }
                for candidate in QuotaPaceWindowSelection.candidates(for: account) {
                    guard let evidence = UsageQuotaSourceResolver.evidence(
                        account: account, windowID: candidate.id,
                        sourceSnapshots: sourceSnapshots, quotaSources: quotaSources),
                        !evidence.account.isError, evidence.account.sourceReport?.allFailed != true
                    else { continue }
                    let window = evidence.window
                    let captured = evidence.capturedAt
                    guard captured <= now, window.usageKnown, window.blockingQuota == nil,
                          window.usedPercent.isFinite, window.usedPercent >= 0,
                          let reset = window.resetsAt, reset.timeIntervalSince1970.isFinite,
                          captured < reset, now < reset else { continue }
                    let binding = UsageQuotaBinding(
                        providerID: account.providerID,
                        accountAnchorID: anchor,
                        windowID: candidate.id)
                    let observation = UsageQuotaObservation(
                        capturedAt: captured, usedPercent: min(100, window.usedPercent), resetDate: reset,
                        windowDuration: UsageQuotaProjection.duration(
                            window: window, providerID: account.providerID, capturedAt: captured))
                    Self.record(observation, binding: binding, archive: &archive)
                }
            }
            if archive.histories.count > Self.maximumHistoryStreams {
                let selected = Set(archive.preferences.selections.map(\.binding))
                archive.histories.sort { lhs, rhs in
                    if selected.contains(lhs.binding) != selected
                        .contains(rhs.binding) { return selected.contains(lhs.binding) }
                    return (lhs.observations.last?.capturedAt ?? .distantPast) >
                        (rhs.observations.last?.capturedAt ?? .distantPast)
                }
                archive.histories = Array(archive.histories.prefix(Self.maximumHistoryStreams))
            }
        }
    }

    /// A compact first-run cross-provider overview. Existing user choices never enter this path.
    private static func initialCandidates(
        accounts: [ProviderUsageSnapshot], preferences: UsageQuotaPreferences, now: Date) -> [UsageQuotaCandidate]
    {
        let catalog = UsageQuotaProjection.catalog(accounts: accounts, preferences: preferences)
        let bindings = SummaryCardResolver.accountBindings(
            accounts: accounts, preferences: preferences.identityPreferences)
        var ranked: [(candidate: UsageQuotaCandidate, rank: Int)] = []
        for (anchor, account) in bindings where !account.isError && account.sourceReport?.allFailed != true {
            for window in QuotaPaceWindowSelection.candidates(for: account) {
                guard window.window.blockingQuota == nil,
                      QuotaPaceWindowSelection.remainingPercent(of: window.window, now: now) != nil,
                      let reset = window.window.resetsAt, reset > now,
                      let candidate = catalog.first(where: {
                          $0.providerID == account.providerID && $0.accountAnchorID == anchor && $0.windowID == window
                              .id
                      }) else { continue }
                let weekly = QuotaPaceWindowSelection.isWeekly(
                    window.window, observedAt: SummaryCardResolver.quotaCapturedAt(account))
                    && QuotaPaceWindowSelection.isAccountWeeklyCandidate(window, providerID: account.providerID)
                let session = window.window.period == .session ||
                    (window.window.windowMinutes.map { $0 > 0 && $0 < 1440 } == true)
                ranked.append((candidate, weekly ? 0 : session ? 1 : 2))
            }
        }
        var result: [UsageQuotaCandidate] = []
        func append(_ candidate: UsageQuotaCandidate) {
            guard result.count < UsageQuotaPreferences.maximumSelections,
                  !result.contains(where: { $0.id == candidate.id }) else { return }
            result.append(candidate)
        }
        if let claude = ranked.first(where: { $0.candidate.providerID == "claude" }) {
            let firstAccount = ranked.filter {
                $0.candidate.providerID == "claude" && $0.candidate.accountAnchorID == claude.candidate.accountAnchorID
            }
            for rank in [0, 1] {
                if let preferred = firstAccount.first(where: { $0.rank == rank }) { append(preferred.candidate) }
            }
            if result.isEmpty { append(claude.candidate) }
        }
        var providers = Set<String>()
        for entry in ranked where entry.candidate.providerID != "claude" {
            let providerID = entry.candidate.providerID
            guard providers.insert(providerID).inserted else { continue }
            let available = ranked.filter { $0.candidate.providerID == providerID }
            if let preferred = available.enumerated().min(by: {
                $0.element.rank == $1.element.rank ? $0.offset < $1.offset : $0.element.rank < $1.element.rank
            }) { append(preferred.element.candidate) }
        }
        for rank in [0, 1, 2] {
            for entry in ranked where entry.rank == rank {
                append(entry.candidate)
            }
        }
        return result
    }

    private static func record(
        _ observation: UsageQuotaObservation, binding: UsageQuotaBinding, archive: inout UsageQuotaArchive)
    {
        if let index = archive.histories.firstIndex(where: { $0.binding == binding }) {
            var observations = archive.histories[index].observations
            if let last = observations.last {
                guard observation.capturedAt >= last.capturedAt else { return }
                if observation == last { return }
                if observation.capturedAt == last.capturedAt { observations.removeLast() }
                if abs(observation.resetDate.timeIntervalSince(last.resetDate)) > 120
                    || observation.windowDuration != last.windowDuration || observation.usedPercent < last.usedPercent
                {
                    observations.removeAll()
                }
            }
            observations.append(observation)
            archive.histories[index].observations = Array(observations.suffix(Self.maximumObservationsPerStream))
        } else {
            archive.histories.append(UsageQuotaHistory(binding: binding, observations: [observation]))
        }
    }

    func catalog(accounts: [ProviderUsageSnapshot], now _: Date = .now) -> [UsageQuotaCandidate] {
        UsageQuotaProjection.catalog(accounts: accounts, preferences: self.preferences)
    }

    func overview(
        accounts: [ProviderUsageSnapshot], sourceSnapshots: [SyncedUsageSnapshot]? = nil,
        quotaSources: [String: SyncProviderQuotaSource]? = nil, now: Date = .now) -> UsageQuotaOverview
    {
        UsageQuotaProjection.overview(
            accounts: accounts, preferences: self.preferences, histories: self.archive.histories,
            linkages: self.linkages, sourceSnapshots: sourceSnapshots ?? self.sourceSnapshots,
            quotaSources: quotaSources ?? self.quotaSources, now: now)
    }

    func defaultColor(for candidate: UsageQuotaCandidate) -> String {
        UsageQuotaColor.suggested(
            providerID: candidate.providerID,
            ordinal: self.preferences.selections.filter { $0.providerID == candidate.providerID }.count,
            tintHex: candidate.providerTintHex)
    }

    @discardableResult func add(_ candidate: UsageQuotaCandidate, colorHex: String? = nil) -> Bool {
        guard let hex = UsageQuotaColor.normalized(colorHex ?? self.defaultColor(for: candidate)) else { return false }
        return self.mutate { archive in
            guard archive.preferences.selections.count < UsageQuotaPreferences.maximumSelections,
                  !archive.preferences.selections.contains(where: { $0.binding == candidate.id }) else { return }
            archive.preferences.hasInitialized = true
            archive.preferences.selections.append(candidate.configuration(colorHex: hex))
        }
    }

    @discardableResult func update(_ selection: UsageQuotaSelection) -> Bool {
        guard let hex = UsageQuotaColor.normalized(selection.colorHex) else { return false }
        return self.mutate { archive in
            guard let index = archive.preferences.selections.firstIndex(where: { $0.id == selection.id }),
                  archive.preferences.selections[index].binding == selection.binding else { return }
            var normalized = selection
            normalized.colorHex = hex
            archive.preferences.selections[index] = normalized
        }
    }

    func remove(id: UUID) {
        self.mutate {
            $0.preferences.hasInitialized = true
            $0.preferences.selections.removeAll { $0.id == id }
        }
    }

    func reorder(ids: [UUID]) {
        self.mutate { archive in
            let selected = Set(ids)
            var seen = Set<UUID>()
            let order = ids.filter { seen.insert($0).inserted }
            let lookup = Dictionary(uniqueKeysWithValues: archive.preferences.selections.map { ($0.id, $0) })
            var sequence = order.compactMap { lookup[$0] }.makeIterator()
            archive.preferences.selections = archive.preferences.selections.map {
                selected.contains($0.id) ? sequence.next() ?? $0 : $0
            }
        }
    }
}
