import AppIntents
import SwiftUI
import WidgetKit

// Fork: the single-provider quota widget. Registered in CodexBarWidgetsBundle (CodexBarWidgets.swift).

@available(iOS 27.0, *)
struct CodexBarProviderQuotaAppIntentWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: WidgetKinds.providerQuotaAppIntent,
            intent: ProviderQuotaWidgetAppIntent.self,
            provider: ProviderQuotaAppIntentTimelineProvider())
        { entry in
            ProviderQuotaWidgetView(entry: entry)
        }
        .configurationDisplayName("Provider Quota")
        .description("Show one provider's weekly and session usage.")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}
