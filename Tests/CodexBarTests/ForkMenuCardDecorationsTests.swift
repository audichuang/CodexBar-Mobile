import Testing
@testable import CodexBar

struct ForkMenuCardDecorationsTests {
    private static func metric(
        percent: Double,
        style: UsageMenuCardView.Model.PercentStyle = .left,
        pace: Double?,
        onTop: Bool) -> UsageMenuCardView.Model.Metric
    {
        UsageMenuCardView.Model.Metric(
            id: "session",
            title: "Session",
            percent: percent,
            percentStyle: style,
            resetText: nil,
            detailText: nil,
            detailLeftText: nil,
            detailRightText: nil,
            pacePercent: pace,
            paceOnTop: onTop)
    }

    @Test
    func `pace status follows the clock tick`() {
        #expect(ForkPaceStatus(metric: Self.metric(percent: 50, pace: nil, onTop: true)) == nil)
        #expect(ForkPaceStatus(metric: Self.metric(percent: 88, pace: 40, onTop: true)) == .onTrack)
        // 9 points ahead with 24% left: burning fast, not yet running out.
        #expect(ForkPaceStatus(metric: Self.metric(percent: 24, pace: 33, onTop: false)) == .burningFast)
        // 15+ points ahead, or under 20% left while ahead: running out.
        #expect(ForkPaceStatus(metric: Self.metric(percent: 40, pace: 55, onTop: false)) == .runningOut)
        #expect(ForkPaceStatus(metric: Self.metric(percent: 18, pace: 22, onTop: false)) == .runningOut)
        // Used-percent bars measure remaining from the other end.
        #expect(ForkPaceStatus(metric: Self.metric(percent: 85, style: .used, pace: 80, onTop: false)) == .runningOut)
        #expect(ForkPaceStatus(metric: Self.metric(percent: 60, style: .used, pace: 55, onTop: false)) == .burningFast)
    }

    @Test
    func `segmented meter lights cells consistently with the rounded label`() {
        #expect(UsageProgressBar.forkFilledCells(percent: 0, count: 30) == 0)
        #expect(UsageProgressBar.forkFilledCells(percent: 0.4, count: 30) == 0)
        #expect(UsageProgressBar.forkFilledCells(percent: 0.6, count: 30) == 1)
        #expect(UsageProgressBar.forkFilledCells(percent: 99.4, count: 30) == 29)
        #expect(UsageProgressBar.forkFilledCells(percent: 99.6, count: 30) == 30)
        #expect(UsageProgressBar.forkFilledCells(percent: 100, count: 30) == 30)
    }

    @Test
    func `segmented meter fills the available width`() {
        let layout = UsageProgressBar.forkCellLayout(width: 280)
        #expect(layout.count == 31)
        let right = layout.minX(of: layout.count - 1) + layout.cellWidth
        #expect(abs(right - 280) < 0.001)
    }
}
