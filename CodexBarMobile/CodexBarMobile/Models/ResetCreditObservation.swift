import CodexBarSync
import Foundation

/// One provider account's redeemable usage-limit resets, as a Mac last observed them (Research 077).
///
/// Built only from data a Mac reported as a complete inventory: Codex `codexResetCredits` and the Claude / Grok
/// `resetCreditInventory`. A provider card without such data has no observation, which callers must treat as
/// "unknown" rather than "none left".
struct ResetCreditObservation: Equatable, Sendable {
    struct Group: Equatable, Sendable {
        /// `nil` means these resets have no expiry.
        let expiresAt: Date?
        let count: Int
    }

    /// Per provider account for the calendar; see `scopeKey(for:deviceID:)`.
    let scopeKey: String
    let providerID: String
    let providerName: String
    let accountLabel: String?
    /// When the Mac read this inventory.
    let observedAt: Date
    /// Resets available at `observedAt`, soonest first; resets without an expiry sort last.
    let expirations: [Date?]
    /// Whether `expirations` is the whole inventory. An incomplete observation (for example a Codex credit in a
    /// status this version does not know) may add reminders but never removes one.
    let isComplete: Bool

    static let supportedProviderIDs: Set<String> = ["codex", "claude", "grok"]

    static func make(from provider: ProviderUsageSnapshot) -> ResetCreditObservation? {
        guard self.supportedProviderIDs.contains(provider.providerID) else { return nil }

        let observedAt: Date
        let expirations: [Date?]
        let isComplete: Bool
        if provider.providerID == "codex" {
            guard let resetCredits = provider.codexResetCredits else { return nil }
            // A count without any list cannot say which expiry is gone, so it stays unknown.
            guard !(resetCredits.credits.isEmpty && resetCredits.availableCount > 0) else { return nil }
            let available = resetCredits.credits.filter { credit in
                credit.status == "available" && (credit.expiresAt.map { $0 > resetCredits.updatedAt } ?? true)
            }
            observedAt = resetCredits.updatedAt
            expirations = available.map(\.expiresAt)
            isComplete = available.count >= resetCredits.availableCount
                && resetCredits.credits.allSatisfy { Self.knownCodexStatuses.contains($0.status) }
        } else {
            guard let inventory = provider.resetCreditInventory else { return nil }
            observedAt = inventory.updatedAt
            expirations = inventory.availableExpirations(at: inventory.updatedAt)
            isComplete = true
        }

        return ResetCreditObservation(
            // Display-only until `observations(fromDeviceSnapshots:)` assigns the calendar scope.
            scopeKey: provider.providerID,
            providerID: provider.providerID,
            providerName: provider.providerName,
            accountLabel: provider.accountEmail,
            observedAt: observedAt,
            expirations: Self.sorted(expirations),
            isComplete: isComplete)
    }

    private static let knownCodexStatuses: Set<String> = ["available", "redeeming", "redeemed", "expired"]

    /// Calendar scope of one Mac's provider entry. The calendar works on each Mac's own entries, before the
    /// cross-Mac merge: a merged card can fold several accounts together (shared email or organization, or several
    /// accounts without identity) while carrying only one of their inventories.
    ///
    /// Order: a real email identity, plus the organization identity when the entry has one (two Codex workspaces can
    /// share an email); else the record key (token accounts, whose editable label is not an identity); else an email
    /// the provider reported for the Mac's main account; else the Mac itself. When Macs disagree the result is two
    /// scopes for one account, which can duplicate a reminder but never lets one account remove another's events.
    static func scopeKey(for provider: ProviderUsageSnapshot, deviceID: String) -> String {
        let id = provider.providerID
        let identities = provider.accountIdentities ?? []
        if let email = AccountIdentityNormalize.normalize(provider.accountEmail),
           identities.contains("\(id):email:\(email)")
        {
            // Codex workspaces can share an email and are told apart by organization. Claude reports its
            // organization only from some sources, so adding it would make one account's scope drift.
            let organization = id == "codex" ? identities.filter { $0.hasPrefix("codex:account:") }.min() : nil
            return "\(id)|email:\(email)" + (organization.map { "|\($0)" } ?? "")
        }
        if let record = AccountIdentityNormalize.normalize(provider.accountRecordKey) {
            return "\(id)|record:\(record)"
        }
        // Providers without account identities (Grok) report the main account's email as is. Where identities
        // exist but hold no email, the email field is an editable label, which is not an identity.
        if identities.isEmpty, let email = AccountIdentityNormalize.normalize(provider.accountEmail) {
            return "\(id)|email:\(email)"
        }
        return "\(id)|device:\(AccountIdentityNormalize.normalize(deviceID) ?? "unknown")"
    }

    /// Calendar observations from each Mac's own snapshot. Synthetic mock providers never reach the calendar, and
    /// entries of one Mac that still share a scope are left out because they would remove each other's events.
    /// The same account seen by several Macs yields several observations of one scope; the planner keeps the newest.
    /// `canonicalDeviceIDs` maps each raw device key to its physical Mac when the user merged aliases.
    static func observations(
        fromDeviceSnapshots snapshots: [SyncedUsageSnapshot],
        canonicalDeviceIDs: [String: String] = [:]) -> [ResetCreditObservation]
    {
        var result: [ResetCreditObservation] = []
        for snapshot in snapshots {
            let deviceKey = DeviceSnapshotResolver.deviceKey(for: snapshot)
            let deviceID = canonicalDeviceIDs[deviceKey] ?? deviceKey
            let entries = snapshot.providers
                .filter { !MockProviderDetector.isMock($0) }
                .compactMap { provider in
                    Self.make(from: provider)?.withScopeKey(Self.scopeKey(for: provider, deviceID: deviceID))
                }
            let counts = Dictionary(grouping: entries, by: \.scopeKey).mapValues(\.count)
            result += entries.filter { counts[$0.scopeKey] == 1 }
        }
        return result
    }

    /// Raw per-Mac snapshots of devices that are not archived, before any merge. Device-alias groups are collapsed
    /// with the cross-account merger, so their collapsed snapshot cannot be used; their raw members are, mapped to
    /// the group's canonical Mac.
    static func calendarSnapshots(
        raw: [SyncedUsageSnapshot],
        items: [SyncDeviceManagementItem]) -> (snapshots: [SyncedUsageSnapshot], canonicalDeviceIDs: [String: String])
    {
        var canonical: [String: String] = [:]
        for item in items where !item.isArchived {
            for sourceID in item.sourceDeviceIDs {
                canonical[sourceID] = item.canonicalDeviceID
            }
        }
        let snapshots = raw.filter { canonical[DeviceSnapshotResolver.deviceKey(for: $0)] != nil }
        return (snapshots, canonical)
    }

    private func withScopeKey(_ scopeKey: String) -> ResetCreditObservation {
        ResetCreditObservation(
            scopeKey: scopeKey,
            providerID: self.providerID,
            providerName: self.providerName,
            accountLabel: self.accountLabel,
            observedAt: self.observedAt,
            expirations: self.expirations,
            isComplete: self.isComplete)
    }

    /// Resets still available at `date`, grouped by identical expiry, soonest first.
    func groups(availableAt date: Date) -> [Group] {
        var groups: [Group] = []
        for expiresAt in self.expirations where expiresAt.map({ $0 > date }) ?? true {
            if let last = groups.last, last.expiresAt == expiresAt {
                groups[groups.count - 1] = Group(expiresAt: expiresAt, count: last.count + 1)
            } else {
                groups.append(Group(expiresAt: expiresAt, count: 1))
            }
        }
        return groups
    }

    func availableCount(at date: Date) -> Int {
        self.groups(availableAt: date).reduce(0) { $0 + $1.count }
    }

    private static func sorted(_ expirations: [Date?]) -> [Date?] {
        expirations.sorted { lhs, rhs in
            switch (lhs, rhs) {
            case let (lhs?, rhs?): lhs < rhs
            case (_?, nil): true
            default: false
            }
        }
    }
}
