import CodexBarSync
import Foundation

/// Display values for one synced provider detail row.
///
/// Rows stay canonical display strings on the wire; newer Macs also send optional numeric
/// progress and usage so iOS can draw a bar and re-render a few first-party rows in the
/// user's language. Older payloads without those fields keep their verbatim text.
struct ProviderDetailRowPresentation: Equatable {
    static let claudeCloudCreditsRowID = "claude-cloud-credits"

    let value: String
    let secondaryValue: String?
    /// Fraction of the total consumed, clamped to 0...1 for drawing.
    let progressFraction: Double?
    let isExpired: Bool

    init(
        providerID: String,
        row: SyncProviderDetailSection.Row,
        sectionTitle: String?,
        now: Date = Date(),
        locale: Locale = .current)
    {
        if providerID == "claude", row.id == Self.claudeCloudCreditsRowID {
            self = Self.claudeCloudCredits(row: row, now: now, locale: locale)
            return
        }
        if providerID == "kimi",
           sectionTitle == "Bonus credits" || ["kimi-monthly-code", "kimi-monthly-other"].contains(row.id ?? "")
        {
            self = Self.kimiUsage(row: row, gift: sectionTitle == "Bonus credits", now: now, locale: locale)
            return
        }
        self.value = ProviderDetailLocalization.localizedValue(
            row.value, providerID: providerID, rowLabel: row.label, sectionTitle: sectionTitle, locale: locale)
        self.secondaryValue = row.secondaryValue.map {
            ProviderDetailLocalization.localizedValue(
                $0, providerID: providerID, rowLabel: row.label, sectionTitle: sectionTitle, locale: locale)
        }
        self.progressFraction = row.progress.map(Self.fraction)
        self.isExpired = false
    }

    private init(value: String, secondaryValue: String?, progressFraction: Double?, isExpired: Bool) {
        self.value = value
        self.secondaryValue = secondaryValue
        self.progressFraction = progressFraction
        self.isExpired = isExpired
    }

    static func fraction(_ progress: SyncProviderDetailSection.Row.Progress) -> Double {
        min(1, max(0, progress.used / progress.total))
    }

    private static func kimiUsage(row: SyncProviderDetailSection.Row, gift: Bool, now: Date, locale: Locale) -> Self {
        let expired = gift && row.expiresAt.map { $0 <= now } == true
        let secondary = row.expiresAt.map { date in
            let key = expired ? "Expired %@" : "Expires %@"
            return String(
                format: MobileLocalizedString.value(key, defaultValue: key, locale: locale),
                locale: locale,
                arguments: [date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))])
        } ?? row.secondaryValue // Old payloads have no machine expiry; never parse a Mac-local date.
        if expired {
            return Self(
                value: MobileLocalizedString.value("Expired", defaultValue: "Expired", locale: locale),
                secondaryValue: secondary, progressFraction: nil, isExpired: true)
        }
        guard let progress = row.progress else {
            return Self(value: row.value, secondaryValue: secondary, progressFraction: nil, isExpired: false)
        }
        let ratio = gift ? max(0, 1 - progress.used / progress.total) : progress.used / progress.total
        let key = gift ? "%@ left" : "%@ used"
        return Self(
            value: String(
                format: MobileLocalizedString.value(key, defaultValue: key, locale: locale),
                locale: locale,
                arguments: [ratio.formatted(.percent.precision(.fractionLength(0...1)).locale(locale))]),
            secondaryValue: secondary, progressFraction: Self.fraction(progress), isExpired: false)
    }

    /// The Mac writes "Expires <ISO-8601>" or "Expired <ISO-8601>" and an English amount.
    /// The expiry observed by the Mac stays authoritative: once it passes, the cached balance
    /// is shown as expired instead of still spendable.
    private static func claudeCloudCredits(
        row: SyncProviderDetailSection.Row,
        now: Date,
        locale: Locale) -> Self
    {
        let expiry = row.secondaryValue.flatMap(Self.expiryDate)
        let expired = row.value == "Expired" || expiry.map { $0 <= now } == true
        let expiryText = expiry.map { date in
            let formatted = date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(locale))
            return String(
                format: MobileLocalizedString.value(
                    expired ? "Expired %@" : "Expires %@",
                    defaultValue: expired ? "Expired %@" : "Expires %@",
                    locale: locale),
                locale: locale,
                arguments: [formatted])
        } ?? row.secondaryValue
        if expired {
            return Self(
                value: MobileLocalizedString.value("Expired", defaultValue: "Expired", locale: locale),
                secondaryValue: expiryText,
                progressFraction: nil,
                isExpired: true)
        }
        if row.value == "Unavailable" {
            return Self(
                value: MobileLocalizedString.value("Unavailable", defaultValue: "Unavailable", locale: locale),
                secondaryValue: expiryText,
                progressFraction: nil,
                isExpired: false)
        }
        guard let progress = row.progress, let remaining = row.usageValue else {
            return Self(value: row.value, secondaryValue: expiryText, progressFraction: nil, isExpired: false)
        }
        let currency = FloatingPointFormatStyle<Double>.Currency(code: "USD").locale(locale)
        let format = MobileLocalizedString.value(
            "%@ of %@ remaining",
            defaultValue: "%@ of %@ remaining",
            locale: locale)
        return Self(
            value: String(
                format: format,
                locale: locale,
                arguments: [remaining.formatted(currency), progress.total.formatted(currency)]),
            secondaryValue: expiryText,
            progressFraction: Self.fraction(progress),
            isExpired: false)
    }

    private nonisolated(unsafe) static let isoFormatter = ISO8601DateFormatter()
    private nonisolated(unsafe) static let fractionalISOFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static func expiryDate(_ secondary: String) -> Date? {
        guard let raw = secondary.split(separator: " ").last.map(String.init) else { return nil }
        // ISO8601DateFormatter is thread-safe once configured.
        return self.isoFormatter.date(from: raw) ?? self.fractionalISOFormatter.date(from: raw)
    }
}
