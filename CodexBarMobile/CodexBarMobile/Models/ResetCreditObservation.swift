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

    /// Per provider account, derived only from the synced card so every device computes the same value; see
    /// `scopeKey(for:)`.
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
            scopeKey: Self.scopeKey(for: provider),
            providerID: provider.providerID,
            providerName: provider.providerName,
            accountLabel: provider.accountEmail,
            observedAt: observedAt,
            expirations: Self.sorted(expirations),
            isComplete: isComplete)
    }

    private static let knownCodexStatuses: Set<String> = ["available", "redeeming", "redeemed", "expired"]

    static let anonymousScopeSuffix = "|single"

    /// The account email (or a Mac's account label), else the record key, else a single anonymous account. Never the
    /// organization identity: teammates share it. Only the card's own fields are used, so every device that shares
    /// the calendar derives the same scope; the merged card's record key is per install and can change with the
    /// publishing Mac, so it is only a fallback for accounts without any email or label.
    static func scopeKey(for provider: ProviderUsageSnapshot) -> String {
        if let email = AccountIdentityNormalize.normalize(provider.accountEmail) {
            return "\(provider.providerID)|email:\(email)"
        }
        if let record = AccountIdentityNormalize.normalize(provider.accountRecordKey) {
            return "\(provider.providerID)|record:\(record)"
        }
        return provider.providerID + Self.anonymousScopeSuffix
    }

    /// Observations eligible for the user's calendar. Synthetic mock providers never reach it. Cards that share a
    /// scope (for example two Codex workspaces under one email) are told apart by their organization identity; cards
    /// that still collide are left out, since they would remove each other's events.
    static func observations(from providers: [ProviderUsageSnapshot]) -> [ResetCreditObservation] {
        let candidates = providers
            .filter { !MockProviderDetector.isMock($0) }
            .compactMap { provider in Self.make(from: provider).map { (provider, $0) } }
        let baseCounts = Dictionary(grouping: candidates, by: { $0.1.scopeKey }).mapValues(\.count)
        let refined = candidates.map { provider, observation -> ResetCreditObservation in
            guard baseCounts[observation.scopeKey, default: 0] > 1,
                  !observation.scopeKey.hasSuffix(Self.anonymousScopeSuffix),
                  let organization = CloudSyncReader.effectiveIdentifiers(for: provider)
                      .first(where: { $0.contains(":account:") })
            else { return observation }
            return observation.withScopeKey("\(observation.scopeKey)|\(organization)")
        }
        let refinedCounts = Dictionary(grouping: refined, by: \.scopeKey).mapValues(\.count)
        return refined.filter { refinedCounts[$0.scopeKey] == 1 }
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
