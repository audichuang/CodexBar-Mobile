import CodexBarSync
import Foundation

// Fork: per-account widget summaries (account label, session window) and the
// accounts widget's sample data. The stored fields live on
// `CodexBarWidgetProviderSummary` in CodexBarWidgetSnapshot.swift.

extension CodexBarWidgetSnapshot {
    #if targetEnvironment(simulator)
    static func withSampleClaudeAccounts(
        _ providers: [CodexBarWidgetProviderSummary],
        now: Date) -> [CodexBarWidgetProviderSummary]
    {
        let accounts = Self.sampleClaudeAccounts(now: now)
        return providers.flatMap { $0.id == "claude|sample" ? [accounts[0]] : [$0] } + accounts.dropFirst()
    }
    #endif

    /// The weekly reset `CodexBarWidgetPaceSummary.sample` uses for its lane.
    private static func sampleAccountWeeklyReset(now: Date, days: Double) -> Date {
        now.addingTimeInterval(-120).addingTimeInterval(days * 86400)
    }

    /// Three Claude accounts for the accounts widget's gallery preview.
    static func sampleClaudeAccounts(now: Date) -> [CodexBarWidgetProviderSummary] {
        let samples: [(label: String, session: Double?, sessionHours: Double, weekly: Double, days: Double)] = [
            ("Work", 12, 2.6, 8, 6.0),
            ("Personal", 81, 0.9, 64, 2.4),
            ("Side", nil, 0, 5, 5.6),
        ]
        return samples.map { sample in
            CodexBarWidgetProviderSummary(
                id: "claude|\(sample.label)",
                providerName: "Claude",
                providerID: "claude",
                loginMethod: "Max",
                usagePercent: max(sample.session ?? 0, sample.weekly),
                todayCostUSD: nil,
                thirtyDayCostUSD: nil,
                tokensToday: nil,
                isError: false,
                statusMessage: nil,
                lastUpdated: now.addingTimeInterval(-240),
                weeklyResetsAt: self.sampleAccountWeeklyReset(now: now, days: sample.days),
                weeklyUsedPercent: sample.weekly,
                accountLabel: sample.label,
                sessionUsedPercent: sample.session,
                sessionResetsAt: sample.session.map { _ in now.addingTimeInterval(sample.sessionHours * 3600) },
                sessionWindowMinutes: 300)
        }
    }

    static func accountsPreview(now: Date = .now) -> CodexBarWidgetSnapshot {
        let accounts = Self.sampleClaudeAccounts(now: now)
        return CodexBarWidgetSnapshot(
            state: .placeholder,
            generatedAt: now,
            latestSyncAt: now.addingTimeInterval(-240),
            deviceCount: 1,
            providerCount: accounts.count,
            errorCount: 0,
            todayCostUSD: nil,
            thirtyDayCostUSD: nil,
            todayTokens: nil,
            maxUsagePercent: accounts.compactMap(\.usagePercent).max(),
            topProviders: accounts,
            message: nil,
            isStale: false)
    }
}

extension CodexBarWidgetSnapshotBuilder {
    /// The shortest window under a day, e.g. Claude's 5-hour session.
    static func sessionWindow(for provider: ProviderUsageSnapshot) -> SyncRateWindow? {
        provider.allRateWindows
            .filter { window in
                guard window.usageKnown, !window.isSyntheticPlaceholder, window.usedPercent.isFinite,
                      let minutes = window.windowMinutes
                else { return false }
                return minutes > 0 && minutes < 24 * 60
            }
            .min { ($0.windowMinutes ?? 0) < ($1.windowMinutes ?? 0) }
    }

    /// The account part of a summary id; also keys the widget account choice.
    static func accountKey(for provider: ProviderUsageSnapshot) -> String {
        provider.accountEmail ?? "_"
    }

    static func accountLabel(label: String?, email: String?, organization: String?) -> String? {
        if let label = label?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            // Labels that are emails (Antigravity names accounts by address) keep the local part.
            return label.contains("@") ? self.accountLabel(label: nil, email: label, organization: nil) : label
        }
        if let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            let local = email.split(separator: "@", maxSplits: 1).first.map(String.init) ?? email
            return local.isEmpty ? email : local
        }
        guard let organization = organization?.trimmingCharacters(in: .whitespacesAndNewlines),
              !organization.isEmpty
        else { return nil }
        return organization
    }
}
