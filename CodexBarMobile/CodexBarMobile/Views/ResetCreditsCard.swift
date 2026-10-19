import CodexBarSync
import SwiftUI

/// What the reset-credit card shows for one provider account (Codex, Claude, Grok).
struct ResetCreditsCardPresentation: Equatable {
    let availableCount: Int
    /// Available resets grouped by identical expiry, soonest first.
    let groups: [ResetCreditObservation.Group]
    /// Built from an inventory the calendar can use (not a bare Codex count).
    let isCalendarEligible: Bool

    /// Only dated resets get calendar events.
    var hasSchedulableExpiry: Bool {
        self.isCalendarEligible && self.groups.contains { $0.expiresAt != nil }
    }

    static func make(provider: ProviderUsageSnapshot, now: Date) -> ResetCreditsCardPresentation? {
        if let observation = ResetCreditObservation.make(from: provider) {
            let groups = observation.groups(availableAt: now)
            let listed = groups.reduce(0) { $0 + $1.count }
            // Codex may report more available resets than it lists; never show fewer than the Mac counts.
            let reported = provider.providerID == "codex" ? provider.codexResetCredits?.availableCount ?? 0 : 0
            let count = max(listed, reported)
            guard count > 0 else { return nil }
            return ResetCreditsCardPresentation(availableCount: count, groups: groups, isCalendarEligible: true)
        }
        // Older Codex payloads may carry only a count and the next expiry.
        guard provider.providerID == "codex",
              let resetCredits = provider.codexResetCredits,
              resetCredits.availableCount > 0
        else { return nil }
        let next = resetCredits.nextExpiresAt.flatMap { $0 > now ? $0 : nil }
        return ResetCreditsCardPresentation(
            availableCount: resetCredits.availableCount,
            groups: next.map { [ResetCreditObservation.Group(expiresAt: $0, count: 1)] } ?? [],
            isCalendarEligible: false)
    }
}

/// Redeemable usage-limit resets with each reset's exact expiry (Codex since iOS 1.15.0; Claude and Grok since
/// iOS 2.10.0 with Mac 0.76.0.2). Rendered only when at least one reset is available.
struct ResetCreditsCard: View {
    let presentation: ResetCreditsCardPresentation
    let tintColor: Color
    var isInCalendar = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(self.tintColor)
                Text(String(localized: "Limit Reset Credits"))
                    .font(.headline)
                Spacer()
                Text(self.availableText)
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(self.tintColor)
            }

            ForEach(Array(self.presentation.groups.enumerated()), id: \.offset) { _, group in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Image(systemName: "timer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(Self.expiryText(group.expiresAt))
                        .font(.caption)
                        .foregroundStyle(.primary)
                    if group.count > 1 {
                        Text(verbatim: "×\(group.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 4)
                    if let expiresAt = group.expiresAt {
                        Text(Self.relativeText(expiresAt))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if self.isInCalendar {
                Label(String(localized: "Expirations are in your calendar"), systemImage: "calendar.badge.clock")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(self.tintColor.opacity(0.10)))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(self.tintColor.opacity(0.22), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("reset-credits-card")
    }

    private var availableText: String {
        if self.presentation.availableCount == 1 {
            return String(localized: "1 reset available")
        }
        return String(format: String(localized: "%d resets available"), self.presentation.availableCount)
    }

    static func expiryText(_ expiresAt: Date?) -> String {
        guard let expiresAt else { return String(localized: "No expiry") }
        let formatted = expiresAt.formatted(
            .dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute())
        return String(format: String(localized: "Expires %@"), formatted)
    }

    private static func relativeText(_ expiresAt: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: expiresAt, relativeTo: Date())
    }
}

struct UsageDataConfidenceNotice: View {
    let rawValue: String
    let tintColor: Color

    static func shouldRender(_ rawValue: String) -> Bool {
        rawValue != "exact" && rawValue != "unknown"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: self.iconName)
                .font(.subheadline)
                .foregroundStyle(self.noticeColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(self.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.primary)
                Text(self.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(self.noticeColor.opacity(0.10)))
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("usage-data-confidence-notice")
    }

    private var title: String {
        switch self.rawValue {
        case "estimated":
            String(localized: "Estimated usage")
        case "percentOnly":
            String(localized: "Percentage-only usage")
        default:
            String(localized: "Usage confidence")
        }
    }

    private var subtitle: String {
        switch self.rawValue {
        case "estimated":
            String(localized: "Mac could not read exact usage, so this view may use an estimate.")
        case "percentOnly":
            String(localized: "Mac only received percentage data for this provider.")
        default:
            String(localized: "Mac reported limited confidence for this provider's usage data.")
        }
    }

    private var iconName: String {
        switch self.rawValue {
        case "estimated", "percentOnly":
            "exclamationmark.triangle.fill"
        default:
            "info.circle.fill"
        }
    }

    private var noticeColor: Color {
        switch self.rawValue {
        case "estimated", "percentOnly":
            .orange
        default:
            self.tintColor
        }
    }
}

#Preview("Reset credits") {
    VStack(spacing: 12) {
        ResetCreditsCard(
            presentation: ResetCreditsCardPresentation(
                availableCount: 3,
                groups: [
                    .init(expiresAt: Date().addingTimeInterval(86400), count: 2),
                    .init(expiresAt: Date().addingTimeInterval(5 * 86400), count: 1),
                ],
                isCalendarEligible: true),
            tintColor: .orange,
            isInCalendar: true)
        UsageDataConfidenceNotice(rawValue: "estimated", tintColor: .purple)
    }
    .padding()
}
