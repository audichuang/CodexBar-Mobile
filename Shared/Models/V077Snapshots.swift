import Foundation

// Provider-agnostic reset-credit inventory added in iOS 2.10.0 / Mac 0.76.0.2
// (Research 077). Rides inside the existing compressed payload as an optional
// key, so old Mac and old iOS versions remain wire-compatible.

/// Redeemable usage-limit resets a Mac observed for one provider account.
///
/// Presence is meaningful: a value is the complete available inventory at
/// `updatedAt`, and an empty `expirations` array means the Mac confirmed that
/// none are available. A missing value means the inventory is unknown (older
/// Mac, a source that cannot read it, or a failed read). Redemption grant or
/// token identifiers never enter this payload.
public struct SyncResetCreditInventory: Codable, Sendable, Equatable {
    /// Expiry of each available reset, soonest first. `nil` means the reset has
    /// no expiry; a grant with several resets contributes one entry per reset.
    public let expirations: [Date?]
    public let updatedAt: Date
    /// False when the Mac knows the list may omit an available reset (a malformed grant was dropped). The iPhone
    /// may add reminders from it but never removes one. Encoded only when false; absent means complete.
    public let isComplete: Bool

    /// Upper bound on decoded entries; larger inventories are treated as malformed.
    public static let maximumExpirations = 50

    private enum CodingKeys: String, CodingKey {
        case expirations
        case updatedAt
        case isComplete
    }

    public init(expirations: [Date?], updatedAt: Date, isComplete: Bool = true) {
        self.expirations = Self.sorted(expirations)
        self.updatedAt = updatedAt
        self.isComplete = isComplete
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let expirations = try container.decode([Date?].self, forKey: .expirations)
        guard expirations.count <= Self.maximumExpirations else {
            throw DecodingError.dataCorruptedError(
                forKey: .expirations,
                in: container,
                debugDescription: "Too many reset credits")
        }
        self.expirations = Self.sorted(expirations)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.isComplete = try container.decodeIfPresent(Bool.self, forKey: .isComplete) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.expirations, forKey: .expirations)
        try container.encode(self.updatedAt, forKey: .updatedAt)
        if !self.isComplete {
            try container.encode(false, forKey: .isComplete)
        }
    }

    /// Resets still available at `date`, soonest first; resets without an expiry sort last.
    public func availableExpirations(at date: Date) -> [Date?] {
        self.expirations.filter { expiresAt in expiresAt.map { $0 > date } ?? true }
    }

    private static func sorted(_ expirations: [Date?]) -> [Date?] {
        expirations.sorted { lhs, rhs in
            switch (lhs, rhs) {
            case let (lhs?, rhs?): lhs < rhs
            case (_?, nil): true
            default: false
            }
        }
    }
}
