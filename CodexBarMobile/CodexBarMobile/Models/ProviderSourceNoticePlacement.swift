import Foundation

/// Fresh fallback data is an explanation; missing or stale data changes how the quota must be read.
enum ProviderSourceNoticePlacement: Equatable {
    case hidden, nearUsage, footer

    static func resolve(status: ProviderSourceStatus, now: Date) -> Self {
        guard status.needsNotice(at: now) else { return .hidden }
        return status.allFailed || status.isStale(at: now) ? .nearUsage : .footer
    }
}
