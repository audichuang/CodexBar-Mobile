import SwiftUI

struct SummaryInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(
                        String(
                            localized: "Summary shows the metrics you choose. Usage has full account details; Cost has token and spending history."))
                    Text(
                        String(
                            localized: "Estimated depletion uses the Mac's observed usage rate. Time to reset is a separate countdown."))
                }
                Section(String(localized: "Brand resources")) {
                    Text(
                        String(
                            localized: "OpenAI and ChatGPT marks are owned by OpenAI. OpenRouter marks are owned by OpenRouter. They identify the connected services; no endorsement is implied."))
                    Link(
                        String(localized: "OpenAI brand guidelines"),
                        destination: URL(string: "https://openai.com/brand/")!)
                    Link(
                        String(localized: "OpenRouter brand resources"),
                        destination: URL(string: "https://openrouter.ai/brand")!)
                    Text(
                        String(
                            localized: "Other providers use neutral abbreviations where approved artwork is unavailable."))
                }
            }
            .navigationTitle(String(localized: "About Summary"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { self.dismiss() }
                }
            }
        }
    }
}
