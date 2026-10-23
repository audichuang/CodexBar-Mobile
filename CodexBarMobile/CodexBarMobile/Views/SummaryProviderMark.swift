import SwiftUI

/// The Summary identity mark is deliberately independent of card accents and account colors.
///
/// The SVG assets are byte-for-byte copies of this repository's existing
/// `Sources/CodexBar/Resources/ProviderIcon-<provider>.svg` monochrome resources.
/// OpenAI and OpenRouter retain the existing bundled Summary resources.
/// Codex copies `Brand-ProviderIcon-codex.png` unchanged (provenance is documented
/// in `docs/provider-brand-icons.md`). Its runtime filters match the approved
/// `summary-card-clarity.html` reference: grayscale, 0.7 brightness multiplier,
/// contrast 20, then inversion in dark appearance. A plain alpha template would
/// erase the white terminal detail inside the opaque Codex cloud.
/// These are resource/rendering facts, not a claim of additional trademark permission.
struct SummaryProviderMark: View {
    let providerID: String
    var size: CGFloat = 18
    @Environment(\.colorScheme) private var colorScheme

    private static let monochromeProviders: Set<String> = [
        "abacus", "amp", "antigravity", "bedrock", "claude", "copilot", "cursor", "deepseek",
        "factory", "gemini", "grok", "groq", "kimi", "kiro", "minimax", "mistral", "muse", "museai",
        "notion", "ollama", "opencode", "opencodego", "perplexity", "poe", "qwencloud", "replicate",
        "warp", "windsurf", "xai", "xkiro", "zai",
    ]

    private var assetName: String? {
        switch self.providerID {
        case "openai", "chatgpt": "SummaryProviderOpenAI"
        case "openrouter": "SummaryProviderOpenRouter"
        case "claudeplatform": "SummaryProvider-claude"
        default:
            Self.monochromeProviders.contains(self.providerID) ? "SummaryProvider-" + self.providerID : nil
        }
    }

    var body: some View {
        Group {
            if self.providerID == "codex" {
                self.codexMark
            } else if let assetName {
                Image(assetName)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(self.colorScheme == .dark ? Color.white : Color.black)
            } else {
                // Providers with no reliable bundled silhouette keep an honest text fallback.
                Text(String(self.providerID.prefix(2)).uppercased())
                    .font(.system(size: self.size * 0.65, weight: .semibold))
                    .foregroundStyle(self.colorScheme == .dark ? Color.white : Color.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(width: self.size, height: self.size)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var codexMark: some View {
        let image = Image("SummaryProvider-codex")
            .resizable()
            .renderingMode(.original)
            .scaledToFit()
            .saturation(0)
            .colorMultiply(Color(white: 0.7))
            .contrast(20)
        if self.colorScheme == .dark {
            image.colorInvert()
        } else {
            image
        }
    }
}
