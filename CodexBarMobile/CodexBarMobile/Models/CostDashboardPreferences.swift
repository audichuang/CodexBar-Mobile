import Combine
import Foundation

/// Stable whole-group identities; titles and data availability never define the saved order.
enum CostDashboardGroup: String, CaseIterable, Identifiable, Codable, Sendable {
    case overview, providerShare, modelMix, budgets, dailySpend, dailyTokens, subscriptionUtilization

    var id: String {
        self.rawValue
    }

    var title: String {
        switch self {
        case .overview: String(localized: "Overview")
        case .providerShare: String(localized: "Provider Share")
        case .modelMix: String(localized: "Model Mix")
        case .budgets: String(localized: "Budgets")
        case .dailySpend: String(localized: "Daily Spend")
        case .dailyTokens: String(localized: "Daily Tokens Overview")
        case .subscriptionUtilization: String(localized: "Subscription Utilization")
        }
    }
}

struct CostDashboardPreferences: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    var schemaVersion = Self.currentSchemaVersion
    /// Strings preserve unrecognized future group identities when the current schema is readable.
    var groupOrder = CostDashboardGroup.allCases.map(\.rawValue)

    var orderedGroups: [CostDashboardGroup] {
        var seen = Set<CostDashboardGroup>()
        return (self.groupOrder.compactMap(CostDashboardGroup.init(rawValue:)) + CostDashboardGroup.allCases)
            .filter { seen.insert($0).inserted }
    }

    /// Hiding empty groups does not mutate their saved slots. Both wide panes consume this
    /// one sequence in reading order, so a group can be moved across the old pane boundary.
    func panes(availableGroups: Set<CostDashboardGroup>)
    -> (primary: [CostDashboardGroup], secondary: [CostDashboardGroup]) {
        let visible = self.orderedGroups.filter { availableGroups.contains($0) }
        let boundary = (visible.count + 1) / 2
        return (Array(visible.prefix(boundary)), Array(visible.dropFirst(boundary)))
    }

    mutating func reorder(_ groups: [CostDashboardGroup]) {
        var seen = Set<CostDashboardGroup>()
        let known = (groups + self.orderedGroups).filter { seen.insert($0).inserted }
        let unknown = self.groupOrder.filter { CostDashboardGroup(rawValue: $0) == nil }
        self.groupOrder = known.map(\.rawValue) + unknown
    }
}

@MainActor
protocol CostDashboardPreferencesPersistence {
    func load() -> Data?
    func save(_ data: Data)
}

@MainActor
struct CostDashboardDefaultsPersistence: CostDashboardPreferencesPersistence {
    static let key = "costDashboardPreferences.v1"
    let defaults: UserDefaults
    func load() -> Data? { self.defaults.data(forKey: Self.key) }
    func save(_ data: Data) { self.defaults.set(data, forKey: Self.key) }
}

/// Device-local only. Nil persistence isolates demos and tests from real preferences.
@MainActor
final class CostDashboardPreferencesStore: ObservableObject {
    @Published private(set) var preferences: CostDashboardPreferences
    let isReadOnly: Bool
    private let persistence: (any CostDashboardPreferencesPersistence)?

    init(persistence: (any CostDashboardPreferencesPersistence)? = nil) {
        self.persistence = persistence
        if let data = persistence?.load() {
            if let decoded = try? JSONDecoder().decode(CostDashboardPreferences.self, from: data),
               decoded.schemaVersion == CostDashboardPreferences.currentSchemaVersion
            {
                self.preferences = decoded
                self.isReadOnly = false
            } else {
                self.preferences = CostDashboardPreferences()
                self.isReadOnly = true
            }
        } else {
            self.preferences = CostDashboardPreferences()
            self.isReadOnly = false
        }
    }

    static func live() -> CostDashboardPreferencesStore {
        CostDashboardPreferencesStore(persistence: CostDashboardDefaultsPersistence(defaults: .standard))
    }

    static func inMemory() -> CostDashboardPreferencesStore { CostDashboardPreferencesStore() }

    func reorder(_ groups: [CostDashboardGroup]) {
        guard !self.isReadOnly else { return }
        var next = self.preferences
        next.reorder(groups)
        guard next != self.preferences else { return }
        self.preferences = next
        if let data = try? JSONEncoder().encode(next) { self.persistence?.save(data) }
    }
}
