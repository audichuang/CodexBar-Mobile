import CodexBarSync
import SwiftUI
import UIKit

/// Settings → Calendar Reminders (Research 077).
struct ResetCreditCalendarSettingsView: View {
    let usageData: SyncedUsageData
    @State private var sync = ResetCreditCalendarSync.shared
    @State private var isUpdating = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        List {
            Section {
                Toggle(isOn: Binding(
                    get: { self.sync.isEnabled },
                    set: { newValue in self.setEnabled(newValue) }))
                {
                    Label(String(localized: "Add to Calendar"), systemImage: "calendar.badge.plus")
                }
                .disabled(self.isUpdating)
                .accessibilityIdentifier("reset-credit-calendar-toggle")
            } footer: {
                Text(
                    String(
                        localized: "CodexBar adds each reset credit's expiration to a calendar named CodexBar, with reminders one day and one hour before. If you use a reset early, its event is removed once your Mac reports the change and you open CodexBar on your iPhone. Turning this off removes upcoming events from the shared calendar; another device with this on adds them back."))
            }

            if let accessMessage = self.accessMessage {
                Section {
                    Text(accessMessage)
                        .font(.callout)
                    Button(String(localized: "Open Settings")) {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }

            if !self.sync.isEnabled, self.sync.hasPendingRemovals() {
                Section {
                    Text(
                        String(
                            localized: "Some upcoming events could not be removed yet. CodexBar removes them once it can use your calendar."))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            if self.sync.isEnabled, let lastSyncAt = self.sync.lastSyncAt {
                Section {
                    LabeledContent(
                        String(localized: "Last updated"),
                        value: lastSyncAt.formatted(date: .omitted, time: .shortened))
                    if let summary = self.sync.lastSummary {
                        LabeledContent(
                            String(localized: "Upcoming in calendar"),
                            value: String(summary.scheduled))
                    }
                    if self.sync.lastSyncFailed {
                        Text(
                            String(
                                localized: "Some events could not be saved. CodexBar will try again on the next update."))
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            Section {
                if self.observations.isEmpty {
                    Text(String(localized: "No reset credits reported yet."))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(self.observations.enumerated()), id: \.offset) { _, observation in
                        self.observationRows(observation)
                    }
                }
                ForEach(self.unreportedProviderNames, id: \.self) { name in
                    Text(String(format: String(localized: "%@: not reported by your Mac"), name))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text(String(localized: "Reset Credits"))
            } footer: {
                Text(
                    String(
                        localized: "Claude and Grok reset credits need CodexBar for Mac 0.76.0.2 or later, with Claude using the OAuth or Web source. Codex also works with earlier Mac versions."))
            }
        }
        .navigationTitle(String(localized: "Calendar Reminders"))
        .onAppear {
            self.sync.refreshAccessState()
            self.sync.retryPendingRemovals()
        }
        .onChange(of: self.scenePhase) { _, phase in
            guard phase == .active else { return }
            self.sync.refreshAccessState()
            self.sync.retryPendingRemovals()
        }
    }

    @ViewBuilder
    private func observationRows(_ observation: ResetCreditObservation) -> some View {
        let groups = observation.groups(availableAt: Date())
        VStack(alignment: .leading, spacing: 4) {
            Text(observation.providerName)
                .fontWeight(.medium)
            if let account = observation.accountLabel, !self.hidePersonalInfo {
                Text(account)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if groups.isEmpty {
                Text(String(localized: "No reset available"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                HStack(spacing: 6) {
                    Image(systemName: "timer")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ResetCreditsCard.expiryText(group.expiresAt))
                        .font(.caption)
                    if group.count > 1 {
                        Text(verbatim: "×\(group.count)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var observations: [ResetCreditObservation] {
        // Every reported inventory, including accounts the calendar leaves out because they cannot be told apart.
        (self.usageData.snapshot?.providers ?? [])
            .filter { !MockProviderDetector.isMock($0) }
            .compactMap(ResetCreditObservation.make(from:))
    }

    /// Supported providers synced from a Mac that did not report an inventory.
    private var unreportedProviderNames: [String] {
        let reported = Set(self.observations.map(\.providerID))
        var seen: Set<String> = []
        return (self.usageData.snapshot?.providers ?? [])
            .filter { provider in
                ResetCreditObservation.supportedProviderIDs.contains(provider.providerID)
                    && !MockProviderDetector.isMock(provider)
                    && !reported.contains(provider.providerID)
                    && !provider.isError
            }
            .compactMap { seen.insert($0.providerID).inserted ? $0.providerName : nil }
    }

    private var hidePersonalInfo: Bool {
        UserDefaults.standard.bool(forKey: MobileSettingsKeys.hidePersonalInfo)
    }

    private var accessMessage: String? {
        switch self.sync.accessState {
        case .denied, .restricted:
            String(localized: "CodexBar can't use your calendar. Allow Full Access in Settings → CodexBar → Calendars.")
        case .writeOnly:
            String(
                localized: "CodexBar needs Full Access to update or remove its own events. Change it in Settings → CodexBar → Calendars.")
        case .notDetermined, .granted:
            nil
        }
    }

    private func setEnabled(_ enabled: Bool) {
        self.isUpdating = true
        Task {
            await self.sync.setEnabled(enabled, input: .make(from: self.usageData))
            self.isUpdating = false
        }
    }
}
