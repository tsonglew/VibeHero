import Foundation

/// Converts daily totals into new spending without replaying startup history or
/// losing the first batch after midnight. Corrections cannot replay old tokens.
struct TokenUsageCursor {
    private var day: Date?
    private var highestTotal = 0

    mutating func consume(total: Int, at date: Date, calendar: Calendar = .current) -> Int {
        let currentDay = calendar.startOfDay(for: date)
        let total = max(0, total)
        guard let day else {
            self.day = currentDay
            highestTotal = total
            return 0
        }
        if day != currentDay {
            self.day = currentDay
            highestTotal = 0
        }
        let delta = max(0, total - highestTotal)
        highestTotal = max(highestTotal, total)
        return delta
    }
}
