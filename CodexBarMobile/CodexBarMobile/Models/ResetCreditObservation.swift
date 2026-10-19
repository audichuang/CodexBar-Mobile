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

    /// Stable per provider account across Macs: the merger's account identity, never a per-install record key
    /// when a real identity exists.
    let scopeKey: String
    /// Every stable identity of the account (merger identities without per-install record keys). Lets the
    /// calendar keep one scope when Macs report overlapping but different identity sets.
    let identities: [String]
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
            identities: CloudSyncReader.effectiveIdentifiers(for: provider).sorted(),
            providerID: provider.providerID,
            providerName: provider.providerName,
            accountLabel: provider.accountEmail,
            observedAt: observedAt,
            expirations: Self.sorted(expirations),
            isComplete: isComplete)
    }

    private static let knownCodexStatuses: Set<String> = ["available", "redeeming", "redeemed", "expired"]

    /// The merged card's `accountRecordKey` comes from whichever Mac published last and is per install, so the
    /// scope uses the merger's stable account identity instead, preferring the email identity.
    static func scopeKey(for provider: ProviderUsageSnapshot) -> String {
        let identities = CloudSyncReader.effectiveIdentifiers(for: provider)
        let identity = identities.first { $0.contains(":email:") } ?? identities.sorted().first ?? ""
        return "\(provider.providerID)|\(identity)"
    }

    /// Observations eligible for the user's calendar. Synthetic mock providers never reach it, and neither does an
    /// account without any identity: two such accounts would share a scope and could remove each other's events.
    static func observations(from providers: [ProviderUsageSnapshot]) -> [ResetCreditObservation] {
        var seen: Set<String> = []
        return providers
            .filter { !MockProviderDetector.isMock($0) }
            .compactMap(Self.make(from:))
            .filter { !$0.scopeKey.hasSuffix(":legacy-no-identity") }
            .filter { seen.insert($0.scopeKey).inserted }
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
