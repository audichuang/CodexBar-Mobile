import CodexBarSync
import Foundation

/// A forecast of remaining quota, separate from QuotaPace's >= one-day pace/depletion contract.
/// Session windows may use their known cycle duration here. No future point is an observation.
enum UsageQuotaProjection {
    static func catalog(
        accounts: [ProviderUsageSnapshot],
        preferences: UsageQuotaPreferences) -> [UsageQuotaCandidate]
    {
        let bindings = SummaryCardResolver.accountBindings(
            accounts: accounts,
            preferences: preferences.identityPreferences)
        return SummaryCardResolver.catalog(accounts: accounts, preferences: preferences.identityPreferences)
            .compactMap { item in
                guard case let .quota(windowID) = item.metric, item.supportsCountdown else { return nil }
                return UsageQuotaCandidate(
                    providerID: item.providerID, providerName: item.providerName,
                    accountAnchorID: item.accountAnchorID, windowID: windowID,
                    accountTitle: item.accountTitle, metricTitle: item.metricTitle,
                    providerTintHex: bindings
                        .first { $0.0 == item.accountAnchorID && $0.1.providerID == item.providerID }?
                        .1.providerIconTintHex)
            }
    }

    static func overview(
        accounts: [ProviderUsageSnapshot], preferences: UsageQuotaPreferences,
        histories: [UsageQuotaHistory], linkages: [ProviderAccountLinkage],
        sourceSnapshots: [SyncedUsageSnapshot]? = nil,
        quotaSources: [String: SyncProviderQuotaSource]? = nil, now: Date) -> UsageQuotaOverview
    {
        var summary = preferences.identityPreferences
        summary.cards = preferences.selections.map { selection in
            SummaryCardConfiguration(
                id: selection.id, accountAnchorID: selection.accountAnchorID,
                providerID: selection.providerID, metric: .quota(windowID: selection.windowID),
                accountTitle: selection.accountTitle, metricTitle: selection.metricTitle)
        }
        let resolved = SummaryCardResolver.resolve(
            accounts: accounts, preferences: summary, linkages: linkages, now: now)
        let bindings = SummaryCardResolver.accountBindings(accounts: accounts, preferences: summary)
        let lines = zip(preferences.selections, resolved).map { selection, mergedCard in
            let card = UsageQuotaSourceResolver.resolve(
                mergedCard, sourceSnapshots: sourceSnapshots, quotaSources: quotaSources, now: now)
            let canonical = bindings
                .first { $0.0 == selection.accountAnchorID && $0.1.providerID == selection.providerID }
            // A linkage may make an old selection resolve to a different canonical account. Its
            // previous local history must not be transplanted to that account's current quota.
            let unambiguous = card.provider.map {
                self.hasUnambiguousHistorySource($0, preferences: preferences, linkages: linkages)
            } ?? false
            let history = canonical == nil || !unambiguous ? [] : histories.first { $0.binding == selection.binding }?
                .observations ?? []
            let forecast = self.forecast(card: card, observations: history, now: now)
            return UsageQuotaResolvedLine(
                selection: selection, provider: card.provider, accountTitle: card.accountTitle,
                compactAccountTitle: card.compactAccountTitle, privateAccountTitle: card.privateAccountTitle,
                metricTitle: card.metricTitle, state: card.state, isStale: card.isStale,
                currentRemainingPercent: card.usedPercent.map { 100 - $0 },
                observedAt: card.observedAt, resetDate: card.resetDate,
                estimatedSamples: forecast.samples, projectionKind: forecast.kind,
                estimatedDepletionAt: forecast.emptyAt, localObservationCount: history.count)
        }
        // The shared calendar domain includes every current usable account/window, even if its
        // line is not selected. Selecting/removing a line must not silently rescale calendar time.
        let resets = accounts.flatMap { account -> [Date] in
            guard !account.isError, account.sourceReport?.allFailed != true else { return [] }
            return QuotaPaceWindowSelection.candidates(for: account).compactMap { candidate in
                guard let evidence = UsageQuotaSourceResolver.evidence(
                    account: account, windowID: candidate.id,
                    sourceSnapshots: sourceSnapshots, quotaSources: quotaSources),
                    !evidence.account.isError, evidence.account.sourceReport?.allFailed != true,
                    evidence.capturedAt <= now,
                    now.timeIntervalSince(evidence.capturedAt) <= ProviderSourceStatus.staleInterval else { return nil }
                let window = evidence.window
                guard window.usageKnown, window.usedPercent.isFinite, window.usedPercent >= 0,
                      window.blockingQuota == nil, let reset = window.resetsAt,
                      reset.timeIntervalSince1970.isFinite, reset > now else { return nil }
                return reset
            }
        }
        return UsageQuotaOverview(start: now, end: resets.max() ?? now.addingTimeInterval(3600), lines: lines)
    }

    static func isAccountLinked(_ account: ProviderUsageSnapshot, linkages: [ProviderAccountLinkage]) -> Bool {
        let identifiers = Set(ProviderSnapshotMerger.effectiveIdentifiers(for: account))
        return UsageCardLinkages.effective(linkages).contains {
            $0.providerID == account.providerID && !identifiers.isDisjoint(with: $0.linkedIdentifiers)
        }
    }

    static func hasUnambiguousHistorySource(
        _ account: ProviderUsageSnapshot, preferences: UsageQuotaPreferences,
        linkages: [ProviderAccountLinkage]) -> Bool
    {
        guard !self.isAccountLinked(account, linkages: linkages) else { return false }
        let stable = UsageAccountIdentity.tokens(for: account).filter(UsageAccountIdentity.isStable)
        let matches = preferences.accountAnchors.filter {
            $0.providerID == account.providerID
                && !stable.isDisjoint(with: $0.tokens.filter(UsageAccountIdentity.isStable))
        }
        return matches.count <= 1
    }

    private struct Forecast {
        let samples: [UsageQuotaPoint]
        let kind: UsageQuotaProjectionKind
        let emptyAt: Date?
        static let unavailable = Self(samples: [], kind: .none, emptyAt: nil)
    }

    private struct Interval {
        let duration: TimeInterval
        let consumed: Double
    }

    static func duration(window: SyncRateWindow, providerID: String, capturedAt: Date) -> TimeInterval? {
        if let duration = QuotaPace.duration(of: window, providerID: providerID, capturedAt: capturedAt) {
            return duration
        }
        guard let minutes = window.windowMinutes, minutes > 0, minutes < 1440 else { return nil }
        return Double(minutes) * 60
    }

    private static func forecast(
        card: SummaryResolvedCard,
        observations: [UsageQuotaObservation],
        now: Date) -> Forecast
    {
        guard card.state == .available, !card.isStale,
              let window = card.window, let used = card.usedPercent,
              let captured = card.observedAt, let reset = card.resetDate,
              let provider = card.provider,
              QuotaPace.allowsPace(for: provider),
              captured <= now, now < reset
        else { return .unavailable }
        let duration = self.duration(window: window, providerID: provider.providerID, capturedAt: captured)
        let compatible = observations.filter {
            $0.capturedAt <= captured && abs($0.resetDate.timeIntervalSince(reset)) <= 120
                && $0.usedPercent.isFinite && (0...100).contains($0.usedPercent)
                && $0.windowDuration == duration
        }
        let recent = Array(compatible.suffix(12))
        let minimumSpan = max(900, min(6 * 3600, (duration ?? 18000) * 0.05))
        if recent.count >= 4, let first = recent.first, let last = recent.last,
           last.capturedAt == captured, abs(last.usedPercent - used) < 0.000001,
           last.capturedAt.timeIntervalSince(first.capturedAt) >= minimumSpan
        {
            let intervals = zip(recent, recent.dropFirst()).map { previous, next in
                Interval(
                    duration: next.capturedAt.timeIntervalSince(previous.capturedAt),
                    consumed: next.usedPercent - previous.usedPercent)
            }
            // A long missing-data gap must not be sold as a measured pause/shape.
            let maximumGap = max(1800, min(2 * 3600, (duration ?? 18000) * 0.1))
            if intervals.allSatisfy({ $0.duration >= 60 && $0.duration <= maximumGap && $0.consumed >= 0 }) {
                return self.project(
                    used: used, capturedAt: now, reset: reset, now: now,
                    intervals: intervals, kind: .observedPattern)
            }
        }
        guard let duration, duration.isFinite, duration > 0 else { return .unavailable }
        let start = reset.addingTimeInterval(-duration)
        let elapsed = captured.timeIntervalSince(start)
        // A fresh cycle has no measured average yet; do not manufacture a consumption rate.
        guard elapsed >= 60, elapsed <= duration else { return .unavailable }
        return self.project(
            used: used, capturedAt: now, reset: reset, now: now,
            intervals: [Interval(duration: elapsed, consumed: used)], kind: .uniformMean)
    }

    private static func project(
        used: Double, capturedAt: Date, reset: Date, now: Date,
        intervals: [Interval], kind: UsageQuotaProjectionKind) -> Forecast
    {
        let period = intervals.reduce(0) { $0 + $1.duration }
        let total = intervals.reduce(0) { $0 + $1.consumed }
        guard period.isFinite, period > 0, total.isFinite, total >= 0 else { return .unavailable }

        func remaining(at date: Date) -> Double {
            let elapsed = max(0, date.timeIntervalSince(capturedAt))
            let cycles = floor(elapsed / period)
            var remainder = elapsed - cycles * period
            var consumed = cycles * total
            for interval in intervals {
                let seconds = min(remainder, interval.duration)
                consumed += interval.consumed * seconds / interval.duration
                remainder -= seconds
                if remainder <= 0 { break }
            }
            return max(0, min(100, 100 - used - consumed))
        }

        var dates = [now, reset]
        if kind == .observedPattern {
            // Uniform samples keep the full calendar range bounded; include the measured
            // pattern's next four cycles of knots so short observed pauses remain visible.
            for index in 1..<128 {
                dates.append(now.addingTimeInterval(reset.timeIntervalSince(now) * Double(index) / 128))
            }
            let currentCycle = floor(max(0, now.timeIntervalSince(capturedAt)) / period)
            for cycle in 0..<4 {
                var date = capturedAt.addingTimeInterval((currentCycle + Double(cycle)) * period)
                for interval in intervals {
                    date = date.addingTimeInterval(interval.duration)
                    if date > now, date < reset { dates.append(date) }
                }
            }
        }
        var empty: Date?
        if used >= 100 {
            empty = capturedAt
        } else if total > 0, remaining(at: reset) <= 0 {
            var low = capturedAt.timeIntervalSince1970
            var high = reset.timeIntervalSince1970
            for _ in 0..<48 {
                let mid = (low + high) / 2
                if remaining(at: Date(timeIntervalSince1970: mid)) <= 0 { high = mid }
                else { low = mid }
            }
            empty = Date(timeIntervalSince1970: high)
        }
        if let empty {
            // Exhaustion ends the line at zero. Do not extend it across the remainder of the
            // window or imply automatic replenishment/availability before a fresh observation.
            dates = dates.filter { $0 <= empty }
            if empty >= now { dates.append(empty) }
        }
        let samples = Set(dates).sorted().map { UsageQuotaPoint(date: $0, remainingPercent: remaining(at: $0)) }
        return Forecast(samples: samples, kind: kind, emptyAt: empty)
    }
}
