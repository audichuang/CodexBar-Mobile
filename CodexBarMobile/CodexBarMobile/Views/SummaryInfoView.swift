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
            }
            .mobilePageSurface()
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
