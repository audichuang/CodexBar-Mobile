import SwiftUI

struct CostGroupOrderEditor: View {
    @ObservedObject var preferences: CostDashboardPreferencesStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(self.preferences.preferences.orderedGroups) { group in
                        Text(group.title)
                            .accessibilityIdentifier("cost-order-\(group.rawValue)")
                    }
                    .onMove { indices, destination in
                        var groups = self.preferences.preferences.orderedGroups
                        groups.move(fromOffsets: indices, toOffset: destination)
                        self.preferences.reorder(groups)
                    }
                    .moveDisabled(self.preferences.isReadOnly)
                } footer: {
                    Text(
                        String(
                            localized: "Move whole groups. Groups without data appear in their saved position when data becomes available."))
                }
                .listRowBackground(MobileSurfaceStyle.rowBackground)
            }
            .listStyle(.insetGrouped)
            .mobilePageSurface()
            .environment(\.editMode, .constant(.active))
            .navigationTitle(String(localized: "Cost Group Order"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "Done")) { self.dismiss() }
                        .accessibilityIdentifier("cost-order-done")
                }
            }
        }
    }
}
