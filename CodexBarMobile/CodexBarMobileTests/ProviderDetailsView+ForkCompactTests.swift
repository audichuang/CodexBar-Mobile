@testable import CodexBarMobile
import CodexBarSync
import Testing

/// Fork: only user-plugin details without charts or pace ticks take the compact layout.
struct ProviderDetailsViewForkCompactTests {
    private let quotaRow = SyncProviderDetailSection.Row(
        label: "Gemini · 5h", value: "剩 82%", secondaryValue: "3h12m 後重置", progress: .init(used: 0.82, total: 1))

    @Test
    func `plugin quota sections use the compact layout`() {
        let sections = [SyncProviderDetailSection(title: "coding", rows: [self.quotaRow, .init(label: "⚠ 更新", value: "42 分鐘前")])]
        #expect(ForkProviderDetailsView.usesCompactLayout(isUserPlugin: true, sections: sections))
    }

    @Test
    func `first party providers keep the upstream layout`() {
        let sections = [SyncProviderDetailSection(title: "Usage", rows: [self.quotaRow])]
        #expect(!ForkProviderDetailsView.usesCompactLayout(isUserPlugin: false, sections: sections))
    }

    @Test
    func `charts and pace ticks keep the upstream layout`() {
        let paced = SyncProviderDetailSection.Row(
            label: "Requests", value: "40%", progress: .init(used: 40, total: 100, expectedUsed: 30))
        let chart = SyncProviderDetailSection.Chart(kind: .bars, points: [.init(label: "11/24", value: 1)])
        #expect(!ForkProviderDetailsView.usesCompactLayout(
            isUserPlugin: true, sections: [SyncProviderDetailSection(rows: [paced])]))
        #expect(!ForkProviderDetailsView.usesCompactLayout(
            isUserPlugin: true, sections: [SyncProviderDetailSection(rows: [self.quotaRow], chart: chart)]))
    }
}
