import CodexBarSync
import Foundation
import SwiftUI

struct UsageQuotaBinding: Codable, Hashable, Sendable {
    let providerID: String
    let accountAnchorID: String
    let windowID: String
}

struct UsageQuotaSelection: Codable, Equatable, Identifiable, Sendable {
    var id: UUID = .init()
    let providerID: String
    let accountAnchorID: String
    let windowID: String
    var colorHex: String
    var accountTitle: String = ""
    var metricTitle: String = ""

    var binding: UsageQuotaBinding {
        UsageQuotaBinding(providerID: self.providerID, accountAnchorID: self.accountAnchorID, windowID: self.windowID)
    }
}

struct UsageQuotaCandidate: Identifiable, Equatable, Sendable {
    let providerID: String
    let providerName: String
    let accountAnchorID: String
    let windowID: String
    let accountTitle: String
    let metricTitle: String
    var providerTintHex: String?

    var id: UsageQuotaBinding {
        UsageQuotaBinding(providerID: self.providerID, accountAnchorID: self.accountAnchorID, windowID: self.windowID)
    }

    func configuration(colorHex: String) -> UsageQuotaSelection {
        UsageQuotaSelection(
            providerID: self.providerID, accountAnchorID: self.accountAnchorID, windowID: self.windowID,
            colorHex: colorHex, accountTitle: self.accountTitle, metricTitle: self.metricTitle)
    }
}

struct UsageQuotaPreferences: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1
    static let maximumSelections = 5
    var schemaVersion = Self.currentSchemaVersion
    var hasInitialized = false
    var selections: [UsageQuotaSelection] = []
    var accountAnchors: [UsageAccountAnchor] = []

    var identityPreferences: SummaryPreferences {
        var preferences = SummaryPreferences()
        preferences.accountAnchors = self.accountAnchors
        return preferences
    }
}

/// One direct iPhone receipt of an account/window's actual Mac observation. No shared provider
/// utilizationHistory is imported: that wire payload does not establish account ownership.
struct UsageQuotaObservation: Codable, Equatable, Sendable {
    let capturedAt: Date
    let usedPercent: Double
    let resetDate: Date
    var windowDuration: TimeInterval?
    /// Captured before downsampling. Nil belongs to older archives without gap metadata.
    var startsSegment: Bool?

    static func maximumContinuousGap(windowDuration: TimeInterval?) -> TimeInterval {
        max(1800, min(7200, (windowDuration ?? 18000) * 0.1))
    }
}

struct UsageQuotaHistory: Codable, Equatable, Sendable {
    let binding: UsageQuotaBinding
    var observations: [UsageQuotaObservation] = []
    /// Frozen stable owner of these samples. Legacy archives without this proof retain
    /// their settings, but their observations cannot establish an account-specific pattern.
    var stableAccountTokens: [String]?
}

struct UsageQuotaPoint: Equatable, Sendable {
    let date: Date
    let remainingPercent: Double
    var segment: Int = 0
}

struct UsageQuotaResolvedLine: Identifiable, Equatable, Sendable {
    let selection: UsageQuotaSelection
    let provider: ProviderUsageSnapshot?
    let accountTitle: String
    let compactAccountTitle: String?
    let privateAccountTitle: String?
    let metricTitle: String
    let state: SummaryCardState
    let isStale: Bool
    let currentRemainingPercent: Double?
    let observedAt: Date?
    let resetDate: Date?
    let observedSamples: [UsageQuotaPoint]
    let localObservationCount: Int

    var id: UUID {
        self.selection.id
    }
}

struct UsageQuotaOverview: Equatable, Sendable {
    let start: Date
    let end: Date
    let lines: [UsageQuotaResolvedLine]

    /// Seven calendar labels ending on the reset day. The plot itself retains the
    /// complete 7 x 24 hours, including the preceding day's unlabeled left edge.
    func dateTicks(calendar: Calendar = .autoupdatingCurrent) -> [Date] {
        let lastDay = calendar.startOfDay(for: self.end)
        return (0..<7).reversed().compactMap {
            calendar.date(byAdding: .day, value: -$0, to: lastDay)
        }.map { max(self.start, $0) }.filter { $0 <= self.end }
    }
}

enum UsageQuotaColor {
    static func normalized(_ raw: String) -> String? {
        let hex = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#")).uppercased()
        guard hex.count == 6, UInt32(hex, radix: 16) != nil else { return nil }
        return hex
    }

    /// Related metrics start in related colors; the user may choose any valid RGB color per line.
    @MainActor static func suggested(providerID: String, ordinal: Int, tintHex: String? = nil) -> String {
        let color = UIColor(ProviderColorPalette.color(for: providerID, tintHex: tintHex))
            .resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard color.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return "007AFF" }
        let rgb = [red, green, blue].map { UInt32((min(1, max(0, $0)) * 255).rounded()) }
        let base = String(format: "%06X", (rgb[0] << 16) | (rgb[1] << 8) | rgb[2])
        guard ordinal > 0, let value = UInt32(base, radix: 16) else { return base }
        let factor = min(0.32, Double(ordinal) * 0.08)
        let components = [16, 8, 0].map { shift in
            let channel = Double((value >> shift) & 255)
            return UInt32((channel + (255 - channel) * factor).rounded())
        }
        return String(format: "%06X", (components[0] << 16) | (components[1] << 8) | components[2])
    }
}
