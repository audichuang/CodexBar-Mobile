import CodexBarSync
import Foundation

/// A merged account can contain windows retained from different Macs. Its account-level
/// source clock does not prove when each window was observed. Resolve this chart's values
/// from account-scoped original sources without changing shared merge/wire semantics.
enum UsageQuotaSourceResolver {
    struct Evidence {
        let window: SyncRateWindow
        let capturedAt: Date
        let account: ProviderUsageSnapshot
    }

    static func evidence(
        account: ProviderUsageSnapshot, windowID: String,
        sourceSnapshots: [SyncedUsageSnapshot]?, quotaSources: [String: SyncProviderQuotaSource]? = nil) -> Evidence?
    {
        // A source proves a currently exposed window; it must not resurrect a window the
        // provider's canonical merge deliberately removed or clear a global quota blocker.
        guard !account.isError, account.sourceReport?.allFailed != true,
              let canonical = QuotaPaceWindowSelection.candidates(for: account)
                  .first(where: { $0.id == windowID })?.window,
                  canonical.blockingQuota == nil else { return nil }
        guard let sourceSnapshots else {
            // Explicit direct fixtures/demo have no merger report. A merged account without
            // its original sources is deliberately not accepted as a new observation.
            guard account.sourceReport == nil,
                  let window = QuotaPaceWindowSelection.candidates(for: account)
                      .first(where: { $0.id == windowID })?.window else { return nil }
            return Evidence(window: window, capturedAt: account.lastUpdated, account: account)
        }
        let tokens = UsageAccountIdentity.tokens(for: account)
        let stable = tokens.filter(UsageAccountIdentity.isStable)
        var observations: [Evidence] = []
        for snapshot in sourceSnapshots {
            let matches = snapshot.providers.filter {
                $0.providerID == account.providerID && $0.sourceReport == nil
            }.compactMap { raw in
                let rawTokens = UsageAccountIdentity.tokens(for: raw)
                let rawStable = rawTokens.filter(UsageAccountIdentity.isStable)
                // Weak reusable slots never join two named accounts or prove an anonymous
                // source belongs to a named account. Entirely legacy sources need exact tokens.
                guard (!stable.isEmpty && !rawStable.isEmpty && !stable.isDisjoint(with: rawStable))
                    || (stable.isEmpty && rawStable.isEmpty && !tokens.isDisjoint(with: rawTokens))
                else { return nil as (score: Int, account: ProviderUsageSnapshot)? }
                return (UsageAccountIdentity.score(account: rawTokens, anchor: tokens), raw)
            }
            guard let best = matches.map(\.score).max(), matches.filter({ $0.score == best }).count == 1,
                  let raw = matches.first(where: { $0.score == best })?.account,
                  let window = QuotaPaceWindowSelection.candidates(for: raw)
                      .first(where: { $0.id == windowID })?.window else { continue }
            let quotaSource = snapshot.providerQuotaSources[SyncedUsageSnapshot.providerPublicationKey(for: raw)]
            let captured = quotaSource?.capturedAt ?? raw.lastUpdated
            // Kimi's shared merger has an explicit capable-writer authority rule. A newer
            // legacy writer is not allowed to clear that writer's monthly-block decision.
            if account.providerID == "kimi", let report = account.sourceReport {
                let sourceID = quotaSource?.deviceID ?? snapshot.deviceID ?? "legacy:\(snapshot.deviceName)"
                if let quotaSources {
                    // The final merger retains the original quota writer here, even when
                    // sourceReport's device ID has become a physical alias's canonical ID.
                    // An explicitly supplied production map with no entry is not authority.
                    guard let authority = quotaSources[SyncedUsageSnapshot.providerPublicationKey(for: account)],
                          authority.deviceID == sourceID, let expectedCapture = authority.capturedAt,
                          expectedCapture == captured, authority.isError != true else { continue }
                } else {
                    // Backward-compatible direct fixtures without reader-local provenance.
                    if let deviceID = report.sourceDeviceID, deviceID != sourceID { continue }
                    if let expectedCapture = report.sourceCapturedAt, expectedCapture != captured { continue }
                }
                guard window == canonical else { continue }
            }
            guard captured.timeIntervalSince1970.isFinite else { continue }
            observations.append(Evidence(window: window, capturedAt: captured, account: raw))
        }
        // A failed writer must not supersede another writer's actual observation.
        let successful = observations.filter { !$0.account.isError && $0.account.sourceReport?.allFailed != true }
        let eligible = successful.isEmpty ? observations : successful
        guard let newest = eligible.map(\.capturedAt).max() else { return nil }
        let latest = eligible.filter { $0.capturedAt == newest }
        guard let first = latest.first, latest.allSatisfy({ $0.window == first.window }) else { return nil }
        return first
    }

    static func resolve(
        _ card: SummaryResolvedCard, sourceSnapshots: [SyncedUsageSnapshot]?,
        quotaSources: [String: SyncProviderQuotaSource]? = nil, now: Date) -> SummaryResolvedCard
    {
        guard let account = card.provider, case let .quota(windowID) = card.configuration.metric else { return card }
        if card.state == .missingMetric || account.isError || account.sourceReport?.allFailed == true
            || card.window?.blockingQuota != nil { return card }
        let evidence = self.evidence(
            account: account, windowID: windowID, sourceSnapshots: sourceSnapshots, quotaSources: quotaSources)
        let window = evidence?.window
        let captured = evidence?.capturedAt
        var state: SummaryCardState = evidence == nil ? .unknown : .available
        var used: Double?
        let presentation = window.map(UsageWindowPresentation.init)
        let stale = captured.map { now.timeIntervalSince($0) > ProviderSourceStatus.staleInterval } ?? false
        if let window {
            if evidence?.account.isError == true || evidence?.account.sourceReport?.allFailed == true {
                state = .unavailable
            } else if presentation?.isBlocked == true { state = .blocked }
            else if !window.usageKnown || !window.usedPercent.isFinite || window.usedPercent < 0 {
                state = .unknown
            } else if presentation?.hasExpiredObservation(at: now) == true { state = .resetPassed }
            else if captured.map({ $0 <= now && $0.timeIntervalSince1970.isFinite }) != true { state = .unknown }
            else {
                used = min(100, window.usedPercent)
                if stale { state = .stale }
            }
        }
        let metricTitle = evidence.flatMap { evidence in
            QuotaPaceWindowSelection.candidates(for: evidence.account).first { $0.id == windowID }.map {
                QuotaPaceWindowSelection.title(of: $0, providerID: account.providerID)
            }
        } ?? card.metricTitle
        return SummaryResolvedCard(
            configuration: card.configuration, provider: card.provider, accountTitle: card.accountTitle,
            metricTitle: metricTitle, state: state, isStale: stale, observedAt: captured, window: window,
            usedPercent: used, resetDate: presentation?.resetDate, forecast: nil, amount: nil,
            compactAccountTitle: card.compactAccountTitle, privateAccountTitle: card.privateAccountTitle)
    }
}
