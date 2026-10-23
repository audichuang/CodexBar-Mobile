import CodexBarSync
import Foundation
import Testing
@testable import CodexBarMobile

@Suite("Provider source notice placement")
struct ProviderSourceNoticePlacementTests {
    private static let now = Date(timeIntervalSince1970: 1_800_000_000)

    private static func status(
        age: TimeInterval? = 60,
        failures: Bool = true,
        isError: Bool = true,
        inactive: Bool = false) -> ProviderSourceStatus
    {
        ProviderSourceStatus(report: SyncProviderSourceReport(
            sourceDeviceID: age == nil ? nil : "fixture-studio",
            sourceDeviceName: age == nil ? nil : "Fixture Studio",
            sourceCapturedAt: age.map { Self.now.addingTimeInterval(-$0) },
            failures: failures ? [.init(
                deviceID: "fixture-laptop", deviceName: "Fixture Laptop", reportedAt: self.now,
                message: "Synthetic refresh status",
                deviceSyncedAt: self.now.addingTimeInterval(inactive ? -8 * 86400 : -60),
                isError: isError)] : [],
            deviceCount: 2))
    }

    @Test
    func `fresh data from a working Mac keeps the other Mac explanation in the footer`() {
        for isError in [true, false] {
            let status = Self.status(isError: isError)
            #expect(ProviderSourceNoticePlacement.resolve(status: status, now: Self.now) == .footer)
        }
    }

    @Test
    func `stale data stays near usage even without refresh errors`() {
        for hasFailures in [true, false] {
            let status = Self.status(age: ProviderSourceStatus.staleInterval + 1, failures: hasFailures, isError: false)
            #expect(ProviderSourceNoticePlacement.resolve(status: status, now: Self.now) == .nearUsage)
        }
    }

    @Test
    func `all Macs lacking data stays near usage regardless of error classification`() {
        for isError in [true, false] {
            let status = Self.status(age: nil, isError: isError)
            #expect(ProviderSourceNoticePlacement.resolve(status: status, now: Self.now) == .nearUsage)
        }
    }

    @Test
    func `a fresh healthy report and retired device failure need no notice`() {
        #expect(ProviderSourceNoticePlacement.resolve(status: Self.status(failures: false), now: Self.now) == .hidden)
        #expect(ProviderSourceNoticePlacement.resolve(status: Self.status(inactive: true), now: Self.now) == .hidden)
    }

    @Test
    func `an open detail moves the notice up when the observation becomes stale`() {
        let status = Self.status(age: ProviderSourceStatus.staleInterval)
        #expect(ProviderSourceNoticePlacement.resolve(status: status, now: Self.now) == .footer)
        #expect(ProviderSourceNoticePlacement
            .resolve(status: status, now: Self.now.addingTimeInterval(1)) == .nearUsage)
    }
}
