import AppIntents
import Foundation
import WidgetKit

// Fork: accounts widget and provider quota widget App Intents, plus the
// account entity. Kinds are declared on `WidgetKinds` in
// WidgetConfigurationAppIntents.swift.

/// Configuration of the accounts widget (`WidgetKinds.accountsAppIntent`):
/// every account of one provider with its session and weekly usage. It has
/// no SiriKit counterpart.
@available(iOS 27.0, *)
struct AccountsWidgetAppIntent: WidgetConfigurationIntent {
    static let title = LocalizedStringResource("Account Quotas", table: "WidgetConfiguration")
    static let description = IntentDescription(LocalizedStringResource(
        "Compare the session and weekly usage of each account of one provider.",
        table: "WidgetConfiguration"))

    /// Empty follows the provider with the most accounts.
    @Parameter(title: LocalizedStringResource("Provider", table: "WidgetConfiguration"))
    var provider: StatusWidgetProviderAppEntity?

    init() {}

    init(provider: StatusWidgetProviderAppEntity?) {
        self.provider = provider
    }
}

/// Configuration of the provider quota widget (`WidgetKinds.providerQuotaAppIntent`):
/// one provider's weekly and session usage in a small widget. It has no
/// SiriKit counterpart.
@available(iOS 27.0, *)
struct ProviderQuotaWidgetAppIntent: WidgetConfigurationIntent {
    static let title = LocalizedStringResource("Provider Quota", table: "WidgetConfiguration")
    static let description = IntentDescription(LocalizedStringResource(
        "Show one provider's weekly and session usage.",
        table: "WidgetConfiguration"))

    /// Empty follows the provider whose weekly window is fullest.
    @Parameter(title: LocalizedStringResource("Provider", table: "WidgetConfiguration"))
    var provider: StatusWidgetProviderAppEntity?

    /// Empty follows the provider's busiest account.
    @Parameter(title: LocalizedStringResource("Account", table: "WidgetConfiguration"))
    var account: ProviderQuotaAccountAppEntity?

    /// The account list follows the chosen provider.
    static var parameterSummary: some ParameterSummary {
        When(\.$provider, .hasAnyValue) {
            Summary {
                \.$provider
                \.$account
            }
        } otherwise: {
            Summary {
                \.$provider
            }
        }
    }

    init() {}

    init(provider: StatusWidgetProviderAppEntity?, account: ProviderQuotaAccountAppEntity? = nil) {
        self.provider = provider
        self.account = account
    }
}

/// An account of the provider chosen on a provider quota widget. The id is
/// `<providerID>|<account key>`, the widget summary id, or the reserved
/// automatic id.
@available(iOS 27.0, *)
struct ProviderQuotaAccountAppEntity: AppEntity, Hashable, Sendable {
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: LocalizedStringResource(
        "Account",
        table: "WidgetConfiguration"))
    static let defaultQuery = ProviderQuotaAccountAppEntityQuery()

    static let automaticIdentifier = "codexbar-widget-account:automatic"

    let id: String
    let displayString: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(self.displayString)")
    }

    static var automatic: ProviderQuotaAccountAppEntity {
        ProviderQuotaAccountAppEntity(
            id: self.automaticIdentifier,
            displayString: String(localized: LocalizedStringResource(
                "Most Used",
                table: "WidgetConfiguration")))
    }
}

@available(iOS 27.0, *)
struct ProviderQuotaAccountAppEntityQuery: EntityQuery {
    @IntentParameterDependency<ProviderQuotaWidgetAppIntent>(\.$provider)
    var intent

    /// Test seams; nil reads the App Group catalogue and the edited widget.
    private var catalogueURL: URL?
    private var providerIDOverride: String??

    init() {}

    init(providerID: String?, catalogueURL: URL?) {
        self.providerIDOverride = .some(providerID)
        self.catalogueURL = catalogueURL
    }

    func entities(for identifiers: [String]) async throws -> [ProviderQuotaAccountAppEntity] {
        let catalogue = self.catalogue()
        return identifiers.map { id in
            if id == ProviderQuotaAccountAppEntity.automaticIdentifier { return .automatic }
            let parts = id.split(separator: "|", maxSplits: 1).map(String.init)
            let account = parts.count == 2
                ? catalogue.first { $0.id == parts[0] }?.accounts?.first { $0.key == parts[1] }
                : nil
            // An account missing from the catalogue keeps the choice under its id.
            return ProviderQuotaAccountAppEntity(
                id: id,
                displayString: account.map(Self.title) ?? parts.last ?? id)
        }
    }

    func suggestedEntities() async throws -> [ProviderQuotaAccountAppEntity] {
        let providerID: String? = if let providerIDOverride { providerIDOverride } else { self.intent?.provider.id }
        guard let providerID, providerID != StatusWidgetProviderChoice.emptyIdentifier else { return [.automatic] }
        let accounts = self.catalogue().first { $0.id == providerID }?.accounts ?? []
        return [.automatic] + accounts
            .map { ProviderQuotaAccountAppEntity(id: "\(providerID)|\($0.key)", displayString: Self.title($0)) }
            .sorted { $0.displayString.localizedStandardCompare($1.displayString) == .orderedAscending }
    }

    func defaultResult() async -> ProviderQuotaAccountAppEntity? {
        .automatic
    }

    private static func title(_ account: WidgetProviderAccountRecord) -> String {
        account.label ?? account.key
    }

    private func catalogue() -> [WidgetProviderRecord] {
        (try? self.catalogueURL.map { try WidgetProviderCatalogue.read(from: $0) } ?? WidgetProviderCatalogue.read())
            ?? []
    }
}
