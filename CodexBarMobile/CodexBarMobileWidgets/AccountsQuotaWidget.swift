import AppIntents
import SwiftUI
import WidgetKit

// Fork: the accounts widget. Registered in CodexBarWidgetsBundle (CodexBarWidgets.swift).

@available(iOS 27.0, *)
struct CodexBarAccountsAppIntentWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetKinds.accountsAppIntent,
            intent: AccountsWidgetAppIntent.self,
            provider: AccountsAppIntentTimelineProvider())
        { entry in
            AccountsWidgetView(entry: entry)
        }
        .configurationDisplayName("Account Quotas")
        .description("Compare the session and weekly usage of each account of one provider.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
