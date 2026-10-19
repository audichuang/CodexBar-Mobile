import Foundation

/// Claude usage-limit resets ("Reset for free" in Claude Settings > Usage), read from the `cedar_ember`
/// block of the Claude Web or OAuth usage response.
///
/// Display-safe, live-only inventory. Grant identifiers are redemption handles; they are never decoded, so
/// they never enter a UsageSnapshot, its persisted JSON, or CLI output. The usage request skips the URL cache,
/// so the raw response is not kept on disk either.
public struct ClaudeRateLimitResetCreditsSnapshot: Sendable, Equatable {
    static let detailLabel = "Limit Reset Credits"

    /// Expiry of each reset available at `updatedAt`; a grant with `resets_left: 2` contributes two entries.
    /// Nil means the reset has no expiry.
    public let expirations: [Date?]
    public let updatedAt: Date
    /// Fork (Research 077): false when a malformed grant was dropped, so the list may omit an available reset.
    /// Presentations are unchanged; the iPhone calendar treats an incomplete inventory as add-only.
    public let isComplete: Bool

    public init(expirations: [Date?], updatedAt: Date, isComplete: Bool = true) {
        self.expirations = expirations
        self.updatedAt = updatedAt
        self.isComplete = isComplete
    }

    /// Expiry of each reset still available at `date`, soonest first; resets without an expiry sort last.
    public func availableExpirations(at date: Date) -> [Date?] {
        self.expirations
            .filter { expiresAt in expiresAt.map { $0 > date } ?? true }
            .sorted { lhs, rhs in
                switch (lhs, rhs) {
                case let (lhs?, rhs?): lhs < rhs
                case (_?, nil): true
                default: false
                }
            }
    }

    /// CLI text, CLI JSON, and `codexbar serve` read reset inventory from the generic `usage.details`
    /// surface; the app renders the typed snapshot instead.
    func detailSections(now: Date) -> [ProviderDetailSection] {
        let expirations = self.availableExpirations(at: now)
        guard !expirations.isEmpty else { return [] }
        let value = expirations.count == 1 ? "1 available" : "\(expirations.count) available"
        let nextExpiry = expirations.first.flatMap(\.self)
        return [
            .makeSection(rows: [
                .makeRow(
                    label: Self.detailLabel,
                    value: value,
                    secondaryValue: nextExpiry.map {
                        "Expires \(UsageFormatter.resetDescription(from: $0, now: now))"
                    }),
            ]),
        ]
    }
}

/// Raw `cedar_ember` block. Only `eligible: true` yields an inventory. A malformed grant is dropped
/// without hiding the rest; an implausibly large inventory yields nothing.
struct ClaudeLimitResetStatusResponse: Decodable {
    /// Observed grants hold one reset each. Each reset renders as its own row, so a larger total is
    /// treated as malformed instead of allocated.
    static let maximumResets = 50
    /// Upper bound on grant records, checked before the block is decoded.
    static let maximumGrantRecords = 200

    let eligible: Bool
    let grants: [ClaudeLimitResetGrantResponse]
    /// Fork (Research 077): grant records dropped as malformed.
    let droppedGrantCount: Int

    private enum CodingKeys: String, CodingKey {
        case eligible
        case grants
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.eligible = try container.decode(Bool.self, forKey: .eligible)
        var records = try container.nestedUnkeyedContainer(forKey: .grants)
        var grants: [ClaudeLimitResetGrantResponse] = []
        var dropped = 0
        while !records.isAtEnd {
            guard records.currentIndex < Self.maximumGrantRecords else {
                throw DecodingError.dataCorruptedError(
                    forKey: .grants,
                    in: container,
                    debugDescription: "Too many reset grants")
            }
            if let grant = try records.decode(LossyGrant.self).grant {
                grants.append(grant)
            } else {
                dropped += 1
            }
        }
        self.grants = grants
        self.droppedGrantCount = dropped
    }

    /// `usable_now` is not consulted: a saved reset counts even while Claude gates redemption. A grant that has
    /// not started yet is left out until a refresh after its start.
    ///
    /// Fork (Research 077): an eligible block with no available reset yields an empty inventory rather than nil,
    /// so the iPhone calendar can tell "none left" from "not read". Every presentation already hides an empty
    /// inventory; an ineligible, absent, or implausible block remains nil.
    func snapshot(updatedAt: Date) -> ClaudeRateLimitResetCreditsSnapshot? {
        guard self.eligible else { return nil }
        var expirations: [Date?] = []
        for grant in self.grants where grant.isAvailable(at: updatedAt) {
            guard grant.resetsLeft <= Self.maximumResets - expirations.count else { return nil }
            expirations.append(contentsOf: repeatElement(grant.endsAt, count: grant.resetsLeft))
        }
        return ClaudeRateLimitResetCreditsSnapshot(
            expirations: expirations,
            updatedAt: updatedAt,
            isComplete: self.droppedGrantCount == 0)
    }

    private struct LossyGrant: Decodable {
        let grant: ClaudeLimitResetGrantResponse?

        init(from decoder: Decoder) throws {
            self.grant = try? ClaudeLimitResetGrantResponse(from: decoder)
        }
    }
}

struct ClaudeLimitResetGrantResponse: Decodable {
    let resetsLeft: Int
    let resetsTotal: Int?
    let startsAt: Date?
    let endsAt: Date?
    /// Required: a grant whose pause state is unknown is dropped rather than counted.
    let paused: Bool

    private enum CodingKeys: String, CodingKey {
        case resetsLeft = "resets_left"
        case resetsTotal = "resets_total"
        case startsAt = "starts_at"
        case endsAt = "ends_at"
        case paused
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.resetsLeft = try container.decode(Int.self, forKey: .resetsLeft)
        self.resetsTotal = try container.decodeIfPresent(Int.self, forKey: .resetsTotal)
        self.startsAt = try Self.decodeBound(container, forKey: .startsAt)
        self.endsAt = try Self.decodeBound(container, forKey: .endsAt)
        self.paused = try container.decode(Bool.self, forKey: .paused)
        guard self.resetsLeft >= 0, self.resetsTotal.map({ $0 >= self.resetsLeft }) ?? true else {
            throw DecodingError.dataCorruptedError(
                forKey: .resetsLeft,
                in: container,
                debugDescription: "resets_left must be between 0 and resets_total")
        }
    }

    /// True when the grant offers a reset at `date`: not paused, not used up, started, and not expired.
    func isAvailable(at date: Date) -> Bool {
        guard !self.paused, self.resetsLeft > 0 else { return false }
        if let startsAt = self.startsAt, startsAt > date { return false }
        if let endsAt = self.endsAt, endsAt <= date { return false }
        return true
    }

    /// An absent or null bound is open; a supplied but unreadable bound is malformed, never unbounded.
    private static func decodeBound(
        _ container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys) throws -> Date?
    {
        guard let raw = try container.decodeIfPresent(String.self, forKey: key) else { return nil }
        guard let date = ISO8601DateParser.parse(raw) else {
            throw DecodingError.dataCorruptedError(
                forKey: key,
                in: container,
                debugDescription: "Unreadable ISO-8601 bound")
        }
        return date
    }
}
