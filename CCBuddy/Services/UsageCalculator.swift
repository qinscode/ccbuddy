import Foundation

class UsageCalculator {
    private let parser = JSONLParser()

    // MARK: - 5-hour rolling window

    func calculateRollingWindowUsage(preloadedSessions: [ParsedSession]? = nil) -> UsageStats {
        let sessions = preloadedSessions ?? parser.parseAllSessions()
        let cutoffTime = Date().addingTimeInterval(-5 * 60 * 60)
        let messages = sessions
            .flatMap { $0.messages }
            .filter { $0.timestamp >= cutoffTime }
            .sorted { $0.timestamp < $1.timestamp }

        var stats = UsageStats()

        for message in messages {
            stats.totalInputTokens += message.inputTokens
            stats.totalOutputTokens += message.outputTokens
            stats.totalCacheCreationTokens += message.cacheCreationTokens
            stats.totalCacheReadTokens += message.cacheReadTokens
            stats.estimatedCost += message.cost

            // Track models used
            if let model = message.model {
                stats.modelsUsed.insert(model)
            }
        }

        // Set time metadata
        if let firstMessage = messages.first {
            stats.sessionStartTime = firstMessage.timestamp
        }
        if let lastMessage = messages.last {
            stats.lastActivityTime = lastMessage.timestamp
        }

        stats.sessionCount = Set(messages.map { $0.uuid }).count

        return stats
    }

    // MARK: - Today stats

    func calculateTodayStats(preloadedSessions: [ParsedSession]? = nil) -> DailyStats {
        let sessions = preloadedSessions ?? parser.parseAllSessions()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let messages = sessions
            .flatMap { $0.messages }
            .filter { $0.timestamp >= startOfDay }
            .sorted { $0.timestamp < $1.timestamp }

        var totalTokens = 0
        var totalCost = 0.0
        var models = Set<String>()

        for message in messages {
            totalTokens += message.totalTokens
            totalCost += message.cost
            if let model = message.model {
                models.insert(model)
            }
        }

        return DailyStats(
            date: Date(),
            totalTokens: totalTokens,
            totalCost: totalCost,
            sessionCount: messages.count,
            models: models
        )
    }

    // MARK: - 计算汇总统计

    func calculateAggregatedStats(
        preloadedSessions: [ParsedSession]? = nil,
        fiveHourWindow: UsageStats? = nil,
        todayStats: DailyStats? = nil
    ) -> AggregatedStats {
        let sessions = preloadedSessions ?? parser.parseAllSessions()
        let fiveHourWindow = fiveHourWindow ?? calculateRollingWindowUsage(preloadedSessions: sessions)
        let today = todayStats ?? calculateTodayStats(preloadedSessions: sessions)

        // Use local calendar with Monday as first weekday
        var calendar = Calendar.current
        calendar.firstWeekday = 2  // Monday as first day (aligns with ccusage)
        let now = Date()

        // Start of week (Mon 00:00:00)
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!

        // Start of month (1st 00:00:00)
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        var weekCost = 0.0
        var monthCost = 0.0
        var allTimeCost = 0.0

        for session in sessions {
            for message in session.messages {
                allTimeCost += message.cost

                if message.timestamp >= monthStart {
                    monthCost += message.cost
                }

                if message.timestamp >= weekStart {
                    weekCost += message.cost
                }
            }
        }

        return AggregatedStats(
            fiveHourWindow: fiveHourWindow,
            today: today,
            thisWeek: weekCost,
            thisMonth: monthCost,
            allTime: allTimeCost
        )
    }

    // MARK: - Daily breakdown

    func calculateDailyBreakdown(days: Int = 7, preloadedSessions: [ParsedSession]? = nil) -> [DailyStats] {
        let calendar = Calendar.current
        let allSessions = preloadedSessions ?? parser.parseAllSessions()
        var dailyStats: [Date: (tokens: Int, cost: Double, count: Int, models: Set<String>)] = [:]

        for session in allSessions {
            for message in session.messages {
                let dayStart = calendar.startOfDay(for: message.timestamp)

                var existing = dailyStats[dayStart] ?? (0, 0, 0, Set<String>())
                existing.tokens += message.totalTokens
                existing.cost += message.cost
                existing.count += 1
                if let model = message.model {
                    existing.models.insert(model)
                }
                dailyStats[dayStart] = existing
            }
        }

        // Convert to array and sort
        let cutoffDate = calendar.date(byAdding: .day, value: -days, to: Date())!

        return dailyStats
            .filter { $0.key >= cutoffDate }
            .map { date, data in
                DailyStats(
                    date: date,
                    totalTokens: data.tokens,
                    totalCost: data.cost,
                    sessionCount: data.count,
                    models: data.models
                )
            }
            .sorted { $0.date > $1.date }
    }

    // MARK: - History for charts

    func calculateDailyHistory(days: Int = 7, preloadedSessions: [ParsedSession]? = nil) -> [UsageHistoryPoint] {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: Date()))!
        return aggregateHistory(grouping: .day, startDate: startDate, preloadedSessions: preloadedSessions)
    }

    func calculateWeeklyHistory(weeks: Int = 8, preloadedSessions: [ParsedSession]? = nil) -> [UsageHistoryPoint] {
        let calendar = Calendar.current
        let startOfCurrentWeek = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) ?? Date()
        let startDate = calendar.date(byAdding: .weekOfYear, value: -(weeks - 1), to: startOfCurrentWeek) ?? startOfCurrentWeek
        return aggregateHistory(grouping: .weekOfYear, startDate: startDate, preloadedSessions: preloadedSessions)
    }

    func calculateMonthlyHistory(months: Int = 6, preloadedSessions: [ParsedSession]? = nil) -> [UsageHistoryPoint] {
        let calendar = Calendar.current
        let startOfCurrentMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date())) ?? Date()
        let startDate = calendar.date(byAdding: .month, value: -(months - 1), to: startOfCurrentMonth) ?? startOfCurrentMonth
        return aggregateHistory(grouping: .month, startDate: startDate, preloadedSessions: preloadedSessions)
    }

    private func aggregateHistory(grouping: Calendar.Component, startDate: Date, preloadedSessions: [ParsedSession]? = nil) -> [UsageHistoryPoint] {
        let calendar = Calendar.current
        let allSessions = preloadedSessions ?? parser.parseAllSessions()
        var buckets: [Date: (tokens: Int, cost: Double)] = [:]

        for session in allSessions {
            for message in session.messages {
                let key = bucketKey(for: message.timestamp, grouping: grouping, calendar: calendar)
                guard key >= startDate else { continue }

                var bucket = buckets[key] ?? (0, 0)
                bucket.tokens += message.totalTokens
                bucket.cost += message.cost
                buckets[key] = bucket
            }
        }

        return buckets
            .map { date, data in
                UsageHistoryPoint(periodStart: date, totalTokens: data.tokens, totalCost: data.cost)
            }
            .sorted { $0.periodStart < $1.periodStart }
    }

    private func bucketKey(for date: Date, grouping: Calendar.Component, calendar: Calendar) -> Date {
        switch grouping {
        case .weekOfYear:
            return calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? calendar.startOfDay(for: date)
        case .month:
            return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? calendar.startOfDay(for: date)
        default:
            return calendar.startOfDay(for: date)
        }
    }
}
