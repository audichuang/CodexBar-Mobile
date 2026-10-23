import CodexBarSync
import SwiftUI
import UIKit

/// Edits only the caller's local store. Demo and live ownership stays with the Usage tab.
struct UsageQuotaEditor: View {
    @ObservedObject var store: UsageQuotaOverviewStore
    let accounts: [ProviderUsageSnapshot]
    @Environment(\.dismiss) private var dismiss
    @AppStorage(MobileSettingsKeys.hidePersonalInfo) private var hidesPersonalInfo = false
    @State private var path: [Route] = []

    private enum Route: Hashable {
        case catalog
        case accounts(providerID: String, windowID: String)
    }

    private var candidates: [UsageQuotaCandidate] {
        self.store.catalog(accounts: self.accounts)
    }

    private var selections: [UsageQuotaSelection] {
        self.store.preferences.selections
    }

    private var hasCapacity: Bool {
        self.selections.count < UsageQuotaPreferences.maximumSelections
    }

    var body: some View {
        NavigationStack(path: self.$path) {
            Form {
                if self.store.isReadOnly { self.readOnlySection }
                Section {
                    if self.selections.isEmpty {
                        Text(String(localized: "No quota lines selected."))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(self.store.overview(accounts: self.accounts).lines) { line in
                        self.selectionRow(line)
                    }
                } header: {
                    Text("\(self.selections.count) / \(UsageQuotaPreferences.maximumSelections)")
                }
                .listRowBackground(MobileSurfaceStyle.rowBackground)
                Section {
                    NavigationLink(value: Route.catalog) {
                        Label(String(localized: "Add quota"), systemImage: "plus")
                    }
                    .disabled(self.store.isReadOnly || !self.hasCapacity || self.candidates.isEmpty)
                    .accessibilityIdentifier("quota-editor-add")
                } footer: {
                    Text(String(localized: "You can display up to 5 quota lines. Remove one to add another."))
                }
                .listRowBackground(MobileSurfaceStyle.rowBackground)
                if self.candidates.isEmpty {
                    Section {
                        Text(String(localized: "No metrics available. Wait for your Mac to sync usage data."))
                            .foregroundStyle(.secondary)
                    }
                    .listRowBackground(MobileSurfaceStyle.rowBackground)
                }
            }
            .mobilePageSurface()
            .navigationTitle(String(localized: "Quota Lines"))
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .catalog:
                    self.catalogView
                case let .accounts(providerID, windowID):
                    self.accountPicker(providerID: providerID, windowID: windowID)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { self.dismiss() }
                        .accessibilityIdentifier("quota-editor-done")
                }
            }
        }
    }

    private var readOnlySection: some View {
        Section {
            Text(
                String(
                    localized: "Quota settings are read-only because the saved data could not be read. Your saved settings have been kept."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("quota-editor-read-only")
        }
        .listRowBackground(MobileSurfaceStyle.rowBackground)
    }

    private func selectionRow(_ line: UsageQuotaResolvedLine) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    // Keep the metric on its own line; a long account name must not hide it.
                    Text(self.visible(line.metricTitle))
                        .font(.headline)
                    Text(self.accountLabel(
                        line.accountTitle, providerID: line.selection.providerID,
                        anchorID: line.selection.accountAnchorID))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                Menu {
                    Button {
                        self.move(line.id, by: -1)
                    } label: {
                        Label(String(localized: "Move up"), systemImage: "arrow.up")
                    }
                    .disabled(self.selections.first?.id == line.id)
                    Button {
                        self.move(line.id, by: 1)
                    } label: {
                        Label(String(localized: "Move down"), systemImage: "arrow.down")
                    }
                    .disabled(self.selections.last?.id == line.id)
                    Button(role: .destructive) {
                        self.store.remove(id: line.id)
                    } label: {
                        Label(String(localized: "Remove"), systemImage: "trash")
                    }
                } label: {
                    Label(String(localized: "More Actions"), systemImage: "ellipsis")
                        .labelStyle(.iconOnly)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .disabled(self.store.isReadOnly)
                .accessibilityIdentifier("quota-line-actions-\(line.id)")
            }
            ColorPicker(
                String(localized: "Line color"),
                selection: self.colorBinding(id: line.id, fallback: line.selection.colorHex),
                supportsOpacity: false)
                .disabled(self.store.isReadOnly)
                .accessibilityIdentifier("quota-line-color-\(line.id)")
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("quota-editor-line-\(line.id)")
    }

    private var catalogView: some View {
        let candidates = self.candidates
        let providers = Array(Set(candidates.map(\.providerID))).sorted()
        return Form {
            if self.store.isReadOnly { self.readOnlySection }
            ForEach(providers, id: \.self) { providerID in
                Section {
                    let providerCandidates = candidates.filter { $0.providerID == providerID }
                    ForEach(self.metricChoices(providerCandidates)) { candidate in
                        NavigationLink(value: Route.accounts(
                            providerID: providerID, windowID: candidate.windowID))
                        {
                            Text(self.visible(candidate.metricTitle))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .disabled(self.store.isReadOnly || !self.hasCapacity)
                        .accessibilityIdentifier("quota-catalog-\(providerID)-\(candidate.windowID)")
                    }
                } header: {
                    Text(self.visible(SummaryPresentation.providerName(id: providerID, accounts: self.accounts)))
                }
                .listRowBackground(MobileSurfaceStyle.rowBackground)
            }
        }
        .mobilePageSurface()
        .navigationTitle(String(localized: "Add quota"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func accountPicker(providerID: String, windowID: String) -> some View {
        let choices = self.candidates.filter { $0.providerID == providerID && $0.windowID == windowID }
        return Form {
            if self.store.isReadOnly { self.readOnlySection }
            Section {
                if choices.isEmpty {
                    Text(String(localized: "No metrics available. Wait for your Mac to sync usage data."))
                }
                ForEach(choices) { candidate in
                    let selected = self.selections.contains { $0.binding == candidate.id }
                    Button {
                        if self.store.add(candidate) { self.path.removeAll() }
                    } label: {
                        HStack(alignment: .top) {
                            Text(self.accountLabel(
                                candidate.accountTitle, providerID: providerID,
                                anchorID: candidate.accountAnchorID))
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if selected {
                                Image(systemName: "checkmark")
                                    .accessibilityHidden(true)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    .disabled(selected || self.store.isReadOnly || !self.hasCapacity)
                    .accessibilityAddTraits(selected ? [.isSelected] : [])
                    .accessibilityIdentifier("quota-candidate-\(candidate.accountAnchorID)-\(candidate.windowID)")
                }
            } header: {
                Text(self.visible(SummaryPresentation.providerName(id: providerID, accounts: self.accounts)))
            } footer: {
                Text(String(localized: "Choose a provider, a metric, then the account to follow."))
            }
            .listRowBackground(MobileSurfaceStyle.rowBackground)
        }
        .mobilePageSurface()
        .navigationTitle(self.visible(choices.first?.metricTitle ?? String(localized: "Account")))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metricChoices(_ candidates: [UsageQuotaCandidate]) -> [UsageQuotaCandidate] {
        var seen = Set<String>()
        return candidates.filter { seen.insert($0.windowID).inserted }
    }

    private func visible(_ text: String) -> String {
        UsageQuotaPresentation.visible(text, hidesPersonalInfo: self.hidesPersonalInfo)
    }

    private func accountLabel(_ title: String, providerID: String, anchorID: String) -> String {
        UsageQuotaPresentation.accountLabel(
            title, providerID: providerID, anchorID: anchorID,
            preferences: self.store.preferences, candidates: self.candidates,
            hidesPersonalInfo: self.hidesPersonalInfo)
    }

    private func move(_ id: UUID, by offset: Int) {
        var ids = self.selections.map(\.id)
        guard let source = ids.firstIndex(of: id), ids.indices.contains(source + offset) else { return }
        ids.swapAt(source, source + offset)
        self.store.reorder(ids: ids)
    }

    private func colorBinding(id: UUID, fallback: String) -> Binding<Color> {
        Binding {
            let hex = self.selections.first { $0.id == id }?.colorHex ?? fallback
            let value = UInt32(UsageQuotaColor.normalized(hex) ?? "3879C7", radix: 16) ?? 0x3879C7
            return Color(
                .sRGB, red: Double((value >> 16) & 255) / 255,
                green: Double((value >> 8) & 255) / 255, blue: Double(value & 255) / 255, opacity: 1)
        } set: { color in
            guard var selection = self.selections.first(where: { $0.id == id }) else { return }
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            guard UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return }
            let channels = [red, green, blue].map { Int((min(1, max(0, $0)) * 255).rounded()) }
            selection.colorHex = String(format: "%02X%02X%02X", channels[0], channels[1], channels[2])
            self.store.update(selection)
        }
    }
}
