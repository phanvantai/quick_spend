import Foundation

/// Tracks daily Gemini API usage with limits
/// Resets automatically each new day
@Observable
final class UsageLimitService {
    private let usageCountKey = "gemini_daily_usage_count"
    private let lastResetDateKey = "gemini_last_reset_date"
    private let defaults = UserDefaults.standard

    private(set) var usageCount: Int = 0

    var dailyLimit: Int { AppConstants.freeTierGeminiLimit }

    var remainingCount: Int {
        max(dailyLimit - usageCount, 0)
    }

    var hasReachedLimit: Bool {
        usageCount >= dailyLimit
    }

    var canParse: Bool {
        !hasReachedLimit
    }

    init() {
        checkAndResetIfNewDay()
    }

    /// Increment usage after a successful parse
    func incrementUsage() {
        checkAndResetIfNewDay()
        usageCount += 1
        defaults.set(usageCount, forKey: usageCountKey)
        print("[UsageLimit] Usage: \(usageCount)/\(dailyLimit) (\(remainingCount) remaining)")
    }

    /// Reset counter (for testing)
    func resetCounter() {
        usageCount = 0
        defaults.set(0, forKey: usageCountKey)
        defaults.set(todayString, forKey: lastResetDateKey)
    }

    // MARK: - Private

    private func checkAndResetIfNewDay() {
        let lastReset = defaults.string(forKey: lastResetDateKey)
        let today = todayString

        if lastReset != today {
            defaults.set(0, forKey: usageCountKey)
            defaults.set(today, forKey: lastResetDateKey)
            usageCount = 0
        } else {
            usageCount = defaults.integer(forKey: usageCountKey)
        }
    }

    private var todayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: .now)
    }
}
