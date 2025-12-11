import Foundation

struct UsageStats {
    // Token 统计
    var totalInputTokens: Int = 0
    var totalOutputTokens: Int = 0
    var totalCacheCreationTokens: Int = 0
    var totalCacheReadTokens: Int = 0

    // 会话信息
    var sessionStartTime: Date?
    var lastActivityTime: Date?
    var modelsUsed: Set<String> = []
    var sessionCount: Int = 0

    // 计算属性
    var totalTokens: Int {
        totalInputTokens + totalOutputTokens + totalCacheCreationTokens + totalCacheReadTokens
    }

    var formattedTotalTokens: String {
        formatTokenCount(totalTokens)
    }

    // 费用
    var estimatedCost: Double = 0

    // 5小时窗口剩余时间
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

    // 消耗速率 (tokens per minute)
    var burnRate: Double {
        guard let startTime = sessionStartTime else { return 0 }
        let elapsed = Date().timeIntervalSince(startTime)
        guard elapsed > 60 else { return 0 } // 至少1分钟才计算
        return Double(totalTokens) / (elapsed / 60)
    }

    var formattedBurnRate: String {
        formatTokenCount(Int(burnRate)) + "/min"
    }

    // 预计总费用 (按当前速率计算5小时)
    var projectedCost: Double {
        guard let startTime = sessionStartTime else { return estimatedCost }
        let elapsed = Date().timeIntervalSince(startTime)
        guard elapsed > 60 else { return estimatedCost }
        let costPerSecond = estimatedCost / elapsed
        return costPerSecond * 5 * 60 * 60
    }

    // 使用百分比 (基于典型限额估算)
    // 注意：实际限额取决于订阅计划，这里使用估计值
    var usagePercentage: Double {
        // 假设5小时窗口限额约为 20M tokens (这个值需要根据实际情况调整)
        let estimatedLimit = 20_000_000.0
        return min(100, Double(totalTokens) / estimatedLimit * 100)
    }

    // 格式化 token 数量
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

// MARK: - 今日统计

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

// MARK: - 汇总统计

struct AggregatedStats {
    var fiveHourWindow: UsageStats
    var today: DailyStats
    var thisWeek: Double // 本周费用
    var thisMonth: Double // 本月费用
    var allTime: Double // 总费用
}

// MARK: - 历史数据点（用于图表）

struct UsageHistoryPoint: Identifiable {
    let periodStart: Date
    let totalTokens: Int
    let totalCost: Double

    var id: Date { periodStart }
    var formattedTokens: String { totalTokens.formattedCompact }
    var formattedCost: String { totalCost.formattedAsCurrency }
}
