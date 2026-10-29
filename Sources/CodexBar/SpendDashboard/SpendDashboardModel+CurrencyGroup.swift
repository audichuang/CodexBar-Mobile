import CodexBarCore
import Foundation

extension SpendDashboardModel.CurrencyGroup {
    var incompleteRequestCount: Int {
        CostUsageIncompleteRequests.sum(self.providers.map(\.incompleteRequestCount))
    }

    var pricedProviderCount: Int {
        self.providers.count { $0.totalCost != nil }
    }

    var hasPartialCost: Bool {
        if self.incompleteRequestCount > 0 { return true }
        if self.providers.contains(where: \.costIsLowerBound) { return true }
        let values = self.providers.map(\.totalCost)
        return values.contains { $0 != nil } && values.contains { $0 == nil }
    }

    var hasPartialTokens: Bool {
        if self.incompleteRequestCount > 0 { return true }
        if self.providers.contains(where: \.tokensAreLowerBound) { return true }
        let values = self.providers.map(\.totalTokens)
        return values.contains { $0 != nil } && values.contains { $0 == nil }
    }

    /// Distinguishes "one subscription of several has no price" from "this subscription's own spend
    /// is a floor", so the caption never reports `1 of 1 subscriptions have spend`.
    var hasUnpricedProviders: Bool {
        self.pricedProviderCount < self.providers.count
    }
}
