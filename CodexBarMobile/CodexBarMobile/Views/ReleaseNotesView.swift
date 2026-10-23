import SwiftUI

struct ReleaseNotesVersion: Identifiable {
    struct Section: Identifiable {
        let title: String
        let items: [String]

        var id: String {
            self.title
        }
    }

    struct Highlight: Identifiable {
        let id: String
        let symbol: String
        let title: String
        let detail: String
    }

    let version: String
    let status: String
    let summary: String
    var highlights: [Highlight] = []
    let sections: [Section]

    var id: String {
        self.version
    }
}

/// Highlights belong to each release, so future updates can lead with their own features.
struct ReleaseNotesView: View {
    private let versions = MobileReleaseNotesCatalog.versions
    var showsHistory = true
    var onDone: (() -> Void)?
    var onDemo: (() -> Void)?
    @State private var showingSetupGuide = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if let latest = self.versions.first {
                    ReleaseNotesHero(version: latest)
                    ReleaseNotesHighlights(highlights: latest.highlights)
                    ReleaseNotesContent(version: latest)
                        .padding(20)
                        .background(MobileSurfaceStyle.cardMaterial, in: RoundedRectangle(cornerRadius: 24))
                }
                if self.showsHistory {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(String(localized: "History"))
                            .font(.title2.bold())
                            .accessibilityAddTraits(.isHeader)
                        ForEach(self.versions.dropFirst()) { version in
                            DisclosureGroup {
                                VStack(alignment: .leading, spacing: 20) {
                                    ReleaseNotesHighlights(highlights: version.highlights)
                                    ReleaseNotesContent(version: version)
                                }
                                .padding(.top, 16)
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("\(String(localized: "Version")) \(version.version)")
                                        .font(.headline)
                                    Text(version.summary)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(20)
                            .background(MobileSurfaceStyle.cardMaterial, in: RoundedRectangle(cornerRadius: 20))
                        }
                    }
                }
            }
            .frame(maxWidth: 760)
            .padding(20)
            .frame(maxWidth: .infinity)
        }
        .background(MobileSurfaceStyle.pageBackground)
        .navigationTitle(String(localized: "Release Notes"))
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if let onDone = self.onDone {
                Button(action: onDone) {
                    Text(String(localized: "Continue"))
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("release-notes-done")
                .frame(maxWidth: 720)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(.bar)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: "Setup")) { self.showingSetupGuide = true }
                    .accessibilityIdentifier("release-notes-setup")
            }
        }
        .sheet(isPresented: self.$showingSetupGuide) {
            SetupGuideSheet(onDismiss: { self.showingSetupGuide = false }, onDemo: self.setupGuideDemoAction)
        }
    }

    private var setupGuideDemoAction: (() -> Void)? {
        guard let onDemo = self.onDemo else { return nil }
        return {
            self.showingSetupGuide = false
            onDemo()
        }
    }
}

private struct ReleaseNotesHero: View {
    let version: ReleaseNotesVersion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(String(localized: "What's New"), systemImage: "sparkles")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
            Text("CodexBar \(self.version.version)")
                .font(.largeTitle.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("release-notes-version")
            Text(self.version.summary)
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 8)
    }
}

private struct ReleaseNotesHighlights: View {
    let highlights: [ReleaseNotesVersion.Highlight]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible()),
                count:
                self.highlights.count > 1 && self.horizontalSizeClass == .regular
                    && !self.dynamicTypeSize.isAccessibilitySize ? 2 : 1),
            alignment: .leading,
            spacing: 16)
        {
            ForEach(self.highlights) { highlight in
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: highlight.symbol)
                        .font(.largeTitle)
                        .foregroundStyle(.tint)
                        .padding(14)
                        .background(.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 18))
                        .accessibilityHidden(true)
                    Text(highlight.title)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("release-highlight-\(highlight.id)")
                    Text(highlight.detail)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(24)
                .background(MobileSurfaceStyle.cardMaterial, in: RoundedRectangle(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24)
                        .strokeBorder(.tint.opacity(0.14), lineWidth: 1)
                }
            }
        }
    }
}

private struct ReleaseNotesContent: View {
    let version: ReleaseNotesVersion

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(self.version.sections) { section in
                VStack(alignment: .leading, spacing: 12) {
                    Text(section.title)
                        .font(.headline)
                        .accessibilityAddTraits(.isHeader)
                    ForEach(section.items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 5))
                                .padding(.top, 8)
                                .accessibilityHidden(true)
                            Text(.init(item))
                                .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
