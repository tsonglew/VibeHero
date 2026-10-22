import Foundation
import XCTest
@testable import VibeHero

final class UsageMonitoringTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testPollRunsBeforeActivityAndComboExpire() {
        XCTAssertLessThan(TokenActivity.refreshInterval, TokenActivity.activeDuration)
        XCTAssertLessThan(TokenActivity.refreshInterval, CombatTiming.comboWindow)
    }

    func testDailyTotalsNeverReplayStartupAndKeepFirstMidnightBatch() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let day = calendar.startOfDay(for: now)
        var cursor = TokenUsageCursor()
        XCTAssertEqual(cursor.consume(total: 10_000, at: day, calendar: calendar), 0)
        XCTAssertEqual(cursor.consume(total: 10_100, at: day, calendar: calendar), 100)
        XCTAssertEqual(cursor.consume(total: 9_000, at: day, calendar: calendar), 0)
        XCTAssertEqual(cursor.consume(total: 10_100, at: day, calendar: calendar), 0)
        XCTAssertEqual(cursor.consume(total: 75, at: day.addingTimeInterval(86_400), calendar: calendar), 75)
        XCTAssertEqual(cursor.consume(total: 100, at: day.addingTimeInterval(86_400), calendar: calendar), 25)
    }

    func testFirstSnapshotRecognizesRecentRealActivity() {
        XCTAssertEqual(
            TokenActivity.expiration(now: now, previous: nil, didSpendTokens: false, latestEventAt: now.addingTimeInterval(-3)),
            now.addingTimeInterval(12)
        )
    }

    func testRepeatedSnapshotsDoNotExtendActivity() {
        let expiry = now.addingTimeInterval(3)
        XCTAssertEqual(TokenActivity.expiration(now: now, previous: expiry, didSpendTokens: false, latestEventAt: now.addingTimeInterval(-12)), expiry)
        XCTAssertNil(TokenActivity.expiration(now: now.addingTimeInterval(3), previous: expiry, didSpendTokens: false, latestEventAt: now.addingTimeInterval(-12)))
    }

    func testNewSpendRefreshesActivityEvenWhenLogTimestampLags() {
        XCTAssertEqual(TokenActivity.expiration(now: now, previous: nil, didSpendTokens: true, latestEventAt: now.addingTimeInterval(-30)), now.addingTimeInterval(15))
    }

    func testOldMissingAndFutureTimestampsDoNotInventActivity() {
        for timestamp in [nil, now.addingTimeInterval(-60), now.addingTimeInterval(1)] {
            XCTAssertNil(TokenActivity.expiration(now: now, previous: nil, didSpendTokens: false, latestEventAt: timestamp))
        }
    }
}
