import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

/// Fork: Claude account cards title with the user's account label, not the fetched login email.
struct MenuCardForkAccountLabelTests {
    private func makeModel(provider: UsageProvider, label: String, authoritative: Bool = true) throws
        -> UsageMenuCardView.Model
    {
        let metadata = try #require(ProviderDefaults.metadata[provider])
        let snapshot = UsageSnapshot(
            primary: RateWindow(usedPercent: 20, windowMinutes: 300, resetsAt: nil, resetDescription: nil),
            secondary: nil,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000),
            identity: ProviderIdentitySnapshot(
                providerID: provider.instanceID,
                accountEmail: "login@example.com",
                accountOrganization: nil,
                loginMethod: nil))
        return UsageMenuCardView.Model.make(.init(
            provider: provider,
            metadata: metadata,
            snapshot: snapshot,
            credits: nil,
            creditsError: nil,
            dashboardError: nil,
            tokenSnapshot: nil,
            tokenError: nil,
            account: AccountInfo(email: label, plan: nil),
            accountIsAuthoritative: authoritative,
            isRefreshing: false,
            lastError: nil,
            usageBarsShowUsed: true,
            resetTimeDisplayStyle: .countdown,
            tokenCostUsageEnabled: false,
            showOptionalCreditsAndExtraUsage: false,
            hidePersonalInfo: false,
            now: Date(timeIntervalSince1970: 1_800_000_000)))
    }

    @Test
    func `claude account card titles with the account label`() throws {
        #expect(try self.makeModel(provider: .claude, label: "la").email == "la")
    }

    @Test
    func `claude card without an account keeps the login email`() throws {
        #expect(try self.makeModel(provider: .claude, label: "la", authoritative: false).email == "login@example.com")
    }

    @Test
    func `other providers keep the login email`() throws {
        #expect(try self.makeModel(provider: .codex, label: "work").email == "login@example.com")
    }
}
