import Foundation

struct UsageStats {
    // Token counters
    var totalInputTokens: Int = 0
    var totalOutputTokens: Int = 0
    var totalCacheCreationTokens: Int = 0
    var totalCacheReadTokens: Int = 0

    // Session info
    var sessionStartTime: Date?
    var lastActivityTime: Date?
    var modelsUsed: Set<String> = []
    var sessionCount: Int = 0

    // Computed properties
    var totalTokens: Int {
        totalInputTokens + totalOutputTokens + totalCacheCreationTokens + totalCacheReadTokens
    }

    var formattedTotalTokens: String {
        formatTokenCount(totalTokens)
    }

    // Costs
    var estimatedCost: Double = 0

    // Remaining time in the 5-hour window
    var timeRemaining: TimeInterval {
        guard let startTime = sessionStartTime else { return 5 * 60 * 60 }
        let elapsed = Date().timeIntervalSince(startTime)
        return max(0, 5 * 60 * 60 - elapsed)
    }

    var formattedTimeRemaining: String {
        let hours = Int(timeRemaining) / 3600
        let minutes = (Int(timeRemaining) % 3600) / 60
        if hours > 0 {
            return String(format: "%d:%02d", hours, minutes)
        } else {
            return String(format: "%d:%02d", minutes, Int(timeRemaining) % 60)
        }
    }

    // Burn rate (tokens per minute)
    var burnRate: Double {
        guard let startTime = sessionStartTime else { return 0 }
        let elapsed = Date().timeIntervalSince(startTime)
        guard elapsed > 60 else { return 0 } // Require at least 1 minute
        return Double(totalTokens) / (elapsed / 60)
    }

    var formattedBurnRate: String {
        formatTokenCount(Int(burnRate)) + "/min"
    }

    // Projected total cost (extend current rate over 5 hours)
    var projectedCost: Double {
        guard let startTime = sessionStartTime else { return estimatedCost }
        let elapsed = Date().timeIntervalSince(startTime)
        guard elapsed > 60 else { return estimatedCost }
        let costPerSecond = estimatedCost / elapsed
        return costPerSecond * 5 * 60 * 60
    }

    // Usage percentage (approximate, depends on plan limits)
    // Note: real limits depend on the subscription plan; this is an estimate
    var usagePercentage: Double {
        // Assume ~20M tokens allowed per 5-hour window (adjust as needed)
        let estimatedLimit = 20_000_000.0
        return min(100, Double(totalTokens) / estimatedLimit * 100)
    }

    // Format token counts
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Daily stats

struct DailyStats {
    var date: Date
    var totalTokens: Int
    var totalCost: Double
    var sessionCount: Int
    var models: Set<String>

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Aggregated stats

struct AggregatedStats {
    var fiveHourWindow: UsageStats
    var today: DailyStats
    var thisWeek: Double // Weekly cost
    var thisMonth: Double // Monthly cost
    var allTime: Double // All-time cost
}

// MARK: - History point (for charts)

struct UsageHistoryPoint: Identifiable {
    let periodStart: Date
    let totalTokens: Int
    let totalCost: Double

    var id: Date { periodStart }
    var formattedTokens: String { totalTokens.formattedCompact }
    var formattedCost: String { totalCost.formattedAsCurrency }
}
