import CodexBarSync
import SwiftUI

/// Fork: user-plugin detail sections (e.g. AGY Quota: three accounts × four quota rows) in a denser layout.
/// Each quota row is one line — label, countdown, value — above a thin bar, instead of three text lines and a
/// full-height bar. Charts, pace ticks and accessibility text sizes keep the upstream `ProviderDetailsView`.
struct ForkProviderDetailsView: View {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let isUserPlugin: Bool
    let providerID: String
    let sections: [SyncProviderDetailSection]
    let tintColor: Color
    var hasResetCreditCard = false

    static func usesCompactLayout(isUserPlugin: Bool, sections: [SyncProviderDetailSection]) -> Bool {
        isUserPlugin && sections.allSatisfy { section in
            section.chart == nil && section.rows.allSatisfy { $0.progress?.expectedUsed == nil }
        }
    }

    var body: some View {
        if self.dynamicTypeSize.isAccessibilitySize
            || !Self.usesCompactLayout(isUserPlugin: self.isUserPlugin, sections: self.sections)
        {
            ProviderDetailsView(
                providerID: self.providerID,
                sections: self.sections,
                tintColor: self.tintColor,
                hasResetCreditCard: self.hasResetCreditCard)
        } else {
            // Same minute clock as upstream so a Mac-observed expiry flips while the page stays open.
            TimelineView(.periodic(from: .now, by: 60)) { context in
                VStack(spacing: 12) {
                    ForEach(Array(self.sections.enumerated()), id: \.offset) { index, section in
                        self.sectionView(section, now: context.date)
                            .accessibilityIdentifier("provider-details-section-\(index)")
                    }
                }
            }
        }
    }

    private func sectionView(_ section: SyncProviderDetailSection, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = section.title {
                Text(ProviderDetailLocalization.localized(title, providerID: self.providerID, locale: self.locale))
                    .font(.headline)
            }
            ForEach(Array(section.rows.enumerated()), id: \.offset) { index, row in
                self.rowView(row, index: index, section: section, now: now)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private func rowView(
        _ row: SyncProviderDetailSection.Row,
        index: Int,
        section: SyncProviderDetailSection,
        now: Date) -> some View
    {
        let presentation = ProviderDetailRowPresentation(
            providerID: self.providerID, row: row, sectionTitle: section.title, now: now, locale: self.locale)
        let label = ProviderDetailLocalization.localized(
            row.label,
            providerID: self.providerID,
            context: ProviderDetailLocalization.rowContext(
                providerID: self.providerID, section: section, row: row, index: index),
            locale: self.locale)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                ProviderDetailSeverityIndicator(severity: row.severity)
                Text(label)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                // Short countdowns share the line with a bar row; longer status text (expired, unknown) stacks.
                let inline = presentation.progressFraction != nil
                if inline, let secondary = presentation.secondaryValue {
                    Text(secondary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                VStack(alignment: .trailing, spacing: 2) {
                    Text(presentation.value)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                        .foregroundStyle(presentation.isExpired ? HierarchicalShapeStyle.secondary : .primary)
                    if !inline, let secondary = presentation.secondaryValue {
                        Text(secondary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let fraction = presentation.progressFraction {
                ProgressView(value: fraction)
                    .tint(self.tintColor)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
