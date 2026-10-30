import CodexBarSync
import Foundation
import Testing
@testable import CodexBarMobile

/// Fork: the widget account choice crosses four layers (catalogue record,
/// summary id, App Intent entity, configuration adapter). Each layer has its
/// own tests; this suite follows one key through all of them so a change to
/// the key format in any single layer fails here.
@MainActor
@Suite("Widget account key round trip")
struct WidgetAccountRoundTripTests {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    /// Two claude accounts with emails, one claude account without an email
    /// (key `_`, labelled by the Mac) and a single-account codex provider.
    private var providers: [ProviderUsageSnapshot] {
        func claude(_ email: String?, label: String?) -> ProviderUsageSnapshot {
            ProviderUsageSnapshot(
                providerID: "claude",
                providerName: "Claude",
                primary: nil,
                secondary: nil,
                accountEmail: email,
                loginMethod: nil,
                statusMessage: nil,
                isError: false,
                lastUpdated: self.now,
                accountLabel: label)
        }
        return [
            claude("work@example.com", label: "Work"),
            claude("home@example.com", label: nil),
            claude(nil, label: "Keychain"),
        ] + TestFixtures.multiAccountProviders(id: "codex", emails: ["solo@example.com"], lastUpdated: self.now)
    }

    private var snapshot: CodexBarWidgetSnapshot {
        CodexBarWidgetSnapshotBuilder.makeSnapshot(
            from: [SyncedUsageSnapshot(
                providers: self.providers, syncTimestamp: self.now, deviceName: "Fixture Mac", deviceID: "fixture")],
            now: self.now)
    }

    private var catalogue: [WidgetProviderRecord] {
        WidgetProviderCatalogue.merged(WidgetActivityPublisher.catalogueEntities(from: self.providers, now: self.now))
    }

    /// Every `<providerID>|<key>` the catalogue offers.
    private var emittedKeys: [String] {
        self.catalogue.flatMap { record in (record.accounts ?? []).map { "\(record.id)|\($0.key)" } }
    }

    @Test func `Fixture covers several accounts and the no-email key`() {
        #expect(Set(self.emittedKeys) == [
            "claude|work@example.com", "claude|home@example.com", "claude|_", "codex|solo@example.com",
        ])
    }

    @Test func `Every catalogue key resolves to the same summary the widget renders`() {
        let rendered = self.snapshot
        #expect(Set(self.emittedKeys) == Set(rendered.topProviders.map(\.id)))
        for key in self.emittedKeys {
            let entry = CodexBarWidgetEntry(
                date: self.now,
                configuration: .init(mode: .overview),
                snapshot: rendered,
                accountChoice: key)
            #expect(WidgetProviderSelection.quotaAccount(for: entry)?.id == key)
        }
    }

    @available(iOS 27.0, *)
    @Test func `Keys survive the account entity and the configuration adapter unchanged`() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("account-round-trip-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try WidgetProviderCatalogue.write(
            WidgetActivityPublisher.catalogueEntities(from: self.providers, now: self.now),
            to: url)

        for record in self.catalogue {
            let query = ProviderQuotaAccountAppEntityQuery(providerID: record.id, catalogueURL: url)
            let suggested = try await query.suggestedEntities().dropFirst()
            let expected = (record.accounts ?? []).map { "\(record.id)|\($0.key)" }
            #expect(Set(suggested.map(\.id)) == Set(expected))

            let provider = StatusWidgetProviderAppEntity(id: record.id, displayString: record.name)
            for entity in suggested {
                // The id the picker stores comes back from the lookup with its label ...
                let resolved = try #require(try await query.entities(for: [entity.id]).first)
                #expect(resolved == entity)
                // ... and the adapter hands it to the timeline unchanged.
                #expect(StatusWidgetConfigurationAdapter.accountChoice(
                    from: .init(provider: provider, account: resolved)) == entity.id)
            }
        }
    }

    @available(iOS 27.0, *)
    @Test func `An unknown account id falls back to the overview pick and keeps its id in the picker`() async throws {
        let rendered = self.snapshot
        func entry(_ choice: String?) -> CodexBarWidgetEntry {
            CodexBarWidgetEntry(
                date: self.now,
                configuration: .init(mode: .overview),
                snapshot: rendered,
                accountChoice: choice)
        }
        let automatic = try #require(WidgetProviderSelection.quotaAccount(for: entry(nil)))
        #expect(WidgetProviderSelection.quotaAccount(for: entry("claude|gone@example.com"))?.id == automatic.id)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("account-round-trip-unknown-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        try WidgetProviderCatalogue.write(
            WidgetActivityPublisher.catalogueEntities(from: self.providers, now: self.now),
            to: url)
        let query = ProviderQuotaAccountAppEntityQuery(providerID: "claude", catalogueURL: url)
        let unknown = try #require(try await query.entities(for: ["claude|gone@example.com"]).first)
        #expect(unknown.id == "claude|gone@example.com")
        #expect(unknown.displayString == "gone@example.com")

        // A choice made for another provider never reaches the timeline.
        let codex = StatusWidgetProviderAppEntity(id: "codex", displayString: "Codex")
        #expect(StatusWidgetConfigurationAdapter.accountChoice(
            from: .init(provider: codex, account: unknown)) == nil)
    }

    @Test func `Merging accounts of one provider keeps the first default window and unions accounts`() {
        // d445fce34: the default window comes from the first account that has
        // one; later accounts only add windows and accounts.
        let window = { (id: String) in WidgetProviderWindowRecord(id: id, label: id, windowMinutes: 10080) }
        let merged = WidgetProviderCatalogue.merged([
            WidgetProviderRecord(
                id: "claude",
                name: "Claude",
                windows: [window("primary")],
                defaultWindowID: nil,
                accounts: [.init(key: "a", label: "a")]),
            WidgetProviderRecord(
                id: "claude",
                name: "Claude",
                windows: [window("primary"), window("secondary")],
                defaultWindowID: "secondary",
                accounts: [.init(key: "b", label: "b")]),
            WidgetProviderRecord(
                id: "claude",
                name: "Claude",
                windows: [window("tertiary")],
                defaultWindowID: "tertiary",
                accounts: [.init(key: "a", label: "a")]),
        ])
        #expect(merged.count == 1)
        #expect(merged[0].defaultWindowID == "secondary")
        #expect(merged[0].windows?.map(\.id) == ["primary", "secondary", "tertiary"])
        #expect(merged[0].accounts?.map(\.key) == ["a", "b"])
    }
}
