import Foundation

// Fork: accounts in the provider catalogue, for the provider quota widget's
// account picker. The stored `accounts` field lives on `WidgetProviderRecord`
// in WidgetProviderCatalogue.swift.

/// One account of a provider in its latest synced snapshot, for the provider
/// quota widget's account picker.
struct WidgetProviderAccountRecord: Codable, Hashable, Sendable {
    /// The account part of the widget summary id (`<providerID>|<key>`).
    let key: String
    /// Short name shown in the picker, as the widget labels accounts.
    let label: String?
}

extension WidgetProviderCatalogue {
    /// Gives each merged record the union of its provider's accounts, in
    /// first-seen order. A provider's first record keeps its accounts as
    /// written; later records add the keys not seen yet.
    static func withMergedAccounts(
        _ records: [WidgetProviderRecord],
        from providers: [WidgetProviderRecord]) -> [WidgetProviderRecord]
    {
        var accountsByID: [String: [WidgetProviderAccountRecord]] = [:]
        var seenKeys: [String: Set<String>] = [:]
        var seenIDs = Set<String>()
        for provider in providers {
            let isFirst = seenIDs.insert(provider.id).inserted
            guard let extra = provider.accounts else { continue }
            if isFirst {
                accountsByID[provider.id] = extra
                seenKeys[provider.id] = Set(extra.map(\.key))
            } else {
                var seen = seenKeys[provider.id] ?? []
                accountsByID[provider.id, default: []] += extra.filter { seen.insert($0.key).inserted }
                seenKeys[provider.id] = seen
            }
        }
        return records.map { record in
            guard let accounts = accountsByID[record.id] else { return record }
            return WidgetProviderRecord(
                id: record.id,
                name: record.name,
                windows: record.windows,
                defaultWindowID: record.defaultWindowID,
                accounts: accounts)
        }
    }
}
