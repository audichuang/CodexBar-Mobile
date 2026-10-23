import Foundation

/// Shared privacy and account disambiguation for the chart legend and its editor.
enum UsageQuotaPresentation {
    static func visible(_ text: String, hidesPersonalInfo: Bool) -> String {
        SummaryPresentation.redact(text, enabled: hidesPersonalInfo)
    }

    static func accountLabel(
        _ title: String, providerID: String, anchorID: String,
        preferences: UsageQuotaPreferences, candidates: [UsageQuotaCandidate] = [],
        hidesPersonalInfo: Bool) -> String
    {
        self.appendingAccountOrdinal(
            to: self.visible(title, hidesPersonalInfo: hidesPersonalInfo),
            providerID: providerID, anchorID: anchorID, preferences: preferences, candidates: candidates)
    }

    static func shortTitle(
        _ line: UsageQuotaResolvedLine, providerName: String,
        preferences: UsageQuotaPreferences, candidates: [UsageQuotaCandidate] = [],
        hidesPersonalInfo: Bool) -> String
    {
        self.accountLabel(
            providerName + " · " + line.metricTitle,
            providerID: line.selection.providerID, anchorID: line.selection.accountAnchorID,
            preferences: preferences, candidates: candidates, hidesPersonalInfo: hidesPersonalInfo)
    }

    /// The collapsed row prioritizes provider and metric. An account number is needed only
    /// when the two visible lines would otherwise have the same provider/metric label.
    static func collapsedTitle(
        _ line: UsageQuotaResolvedLine, visibleLines: [UsageQuotaResolvedLine], providerName: String,
        preferences: UsageQuotaPreferences, hidesPersonalInfo: Bool) -> String
    {
        let metric = self.visible(line.metricTitle, hidesPersonalInfo: hidesPersonalInfo)
        let title = self.visible(providerName, hidesPersonalInfo: hidesPersonalInfo) + " · " + metric
        let needsAccount = visibleLines.contains {
            $0.selection.providerID == line.selection.providerID
                && $0.selection.accountAnchorID != line.selection.accountAnchorID
                && self.visible($0.metricTitle, hidesPersonalInfo: hidesPersonalInfo) == metric
        }
        guard needsAccount, let ordinal = self.accountOrdinal(
            providerID: line.selection.providerID, anchorID: line.selection.accountAnchorID,
            preferences: preferences, candidates: []) else { return title }
        return title + " · #\(ordinal)"
    }

    private static func appendingAccountOrdinal(
        to title: String, providerID: String, anchorID: String,
        preferences: UsageQuotaPreferences, candidates: [UsageQuotaCandidate]) -> String
    {
        guard let ordinal = self.accountOrdinal(
            providerID: providerID, anchorID: anchorID, preferences: preferences, candidates: candidates)
        else { return title }
        return title + " · " + String(format: String(localized: "Account %lld"), Int64(ordinal))
    }

    private static func accountOrdinal(
        providerID: String, anchorID: String,
        preferences: UsageQuotaPreferences, candidates: [UsageQuotaCandidate]) -> Int?
    {
        var seen = Set<String>()
        // Persisted order survives account disappearance, input sorting, selection edits and
        // privacy changes. Current candidates only fill gaps in an uninitialized fixture.
        let anchors = (
            preferences.accountAnchors.filter { $0.providerID == providerID }.map(\.id)
                + candidates.filter { $0.providerID == providerID }.map(\.accountAnchorID)
                + preferences.selections.filter { $0.providerID == providerID }.map(\.accountAnchorID))
            .filter { seen.insert($0).inserted }
        guard anchors.count > 1, let index = anchors.firstIndex(of: anchorID) else { return nil }
        return index + 1
    }
}
