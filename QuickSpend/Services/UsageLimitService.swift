import Foundation

/// Tracks daily Gemini API usage with limits
/// Resets automatically each new day. Subscription-aware: Premium users get unlimited parses.
@Observable
final class UsageLimitService {
    private let usageCountKey = "gemini_daily_usage_count"
    private let lastResetDateKey = "gemini_last_reset_date"
    private let defaults: UserDefaults

    private(set) var usageCount: Int = 0

    /// Set to true when user has Premium subscription — bypasses daily limit
    var isPremium: Bool = false

    var dailyLimit: Int {
        isPremium ? 999 : AppConstants.freeTierGeminiLimit
    }

    var remainingCount: Int {
        isPremium ? 999 : max(dailyLimit - usageCount, 0)
    }

    var hasReachedLimit: Bool {
        isPremium ? false : usageCount >= dailyLimit
    }

    var canParse: Bool {
        !hasReachedLimit
    }

    convenience init() {
        self.init(defaults: .standard)
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
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
