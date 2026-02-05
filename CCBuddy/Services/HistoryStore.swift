import Foundation
import SwiftData

/// 历史数据持久化存储服务 (SwiftData)
@MainActor
class HistoryStore {
    static let shared = HistoryStore()

    private var modelContainer: ModelContainer?
    private var modelContext: ModelContext?

    private init() {
        do {
            let schema = Schema([DailyUsageRecord.self])

            // Use app-specific storage location to avoid conflicts with other apps
            let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDirectory = appSupportURL.appendingPathComponent("com.ccusage.app", isDirectory: true)

            // Create directory if it doesn't exist
            try FileManager.default.createDirectory(at: appDirectory, withIntermediateDirectories: true)

            let storeURL = appDirectory.appendingPathComponent("CCBuddy.store")

            let modelConfiguration = ModelConfiguration(
                "CCBuddyStore",
                schema: schema,
                url: storeURL,
                allowsSave: true,
                cloudKitDatabase: .none
            )
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            modelContext = modelContainer?.mainContext

            print("📚 SwiftData HistoryStore initialized at: \(storeURL.path)")
        } catch {
            print("❌ Failed to initialize SwiftData: \(error)")
        }
    }

    // MARK: - Public Methods

    /// 获取所有历史记录
    var allRecords: [DailyUsageRecord] {
        guard let context = modelContext else { return [] }
        let descriptor = FetchDescriptor<DailyUsageRecord>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// 获取指定日期的记录
    func record(for dateKey: String) -> DailyUsageRecord? {
        guard let context = modelContext else { return nil }
        let predicate = #Predicate<DailyUsageRecord> { $0.date == dateKey }
        var descriptor = FetchDescriptor<DailyUsageRecord>(predicate: predicate)
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// 保存或更新记录
    func upsert(date: String, inputTokens: Int, outputTokens: Int,
                cacheCreationTokens: Int, cacheReadTokens: Int,
                cost: Double, sessionCount: Int, models: [String]) {
        guard let context = modelContext else { return }

        if let existing = record(for: date) {
            existing.update(
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheCreationTokens: cacheCreationTokens,
                cacheReadTokens: cacheReadTokens,
                cost: cost,
                sessionCount: sessionCount,
                models: models
            )
        } else {
            let newRecord = DailyUsageRecord(
                date: date,
                inputTokens: inputTokens,
                outputTokens: outputTokens,
                cacheCreationTokens: cacheCreationTokens,
                cacheReadTokens: cacheReadTokens,
                cost: cost,
                sessionCount: sessionCount,
                models: models
            )
            context.insert(newRecord)
        }

        try? context.save()
    }

    /// 获取历史数据点（用于图表）
    func getHistoryPoints(days: Int) -> [UsageHistoryPoint] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var points: [UsageHistoryPoint] = []
        let today = calendar.startOfDay(for: Date())

        // 预先获取所有记录到字典中
        let recordsDict = Dictionary(uniqueKeysWithValues: allRecords.map { ($0.date, $0) })

        for i in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            let dateKey = formatter.string(from: date)

            if let record = recordsDict[dateKey] {
                points.append(UsageHistoryPoint(
                    periodStart: date,
                    totalTokens: record.totalTokens,
                    totalCost: record.totalCost
                ))
            } else {
                points.append(UsageHistoryPoint(
                    periodStart: date,
                    totalTokens: 0,
                    totalCost: 0
                ))
            }
        }

        return points
    }

    /// 获取周历史数据点
    func getWeeklyHistoryPoints(weeks: Int) -> [UsageHistoryPoint] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2  // Monday

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var points: [UsageHistoryPoint] = []
        let now = Date()

        let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!

        // 预先获取所有记录到字典中
        let recordsDict = Dictionary(uniqueKeysWithValues: allRecords.map { ($0.date, $0) })

        for i in (0..<weeks).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -i, to: currentWeekStart) else { continue }
            guard calendar.date(byAdding: .day, value: 6, to: weekStart) != nil else { continue }

            var totalTokens = 0
            var totalCost = 0.0

            for dayOffset in 0...6 {
                guard let day = calendar.date(byAdding: .day, value: dayOffset, to: weekStart) else { continue }
                let dateKey = formatter.string(from: day)
                if let record = recordsDict[dateKey] {
                    totalTokens += record.totalTokens
                    totalCost += record.totalCost
                }
            }

            points.append(UsageHistoryPoint(
                periodStart: weekStart,
                totalTokens: totalTokens,
                totalCost: totalCost
            ))
        }

        return points
    }

    /// 获取月历史数据点
    func getMonthlyHistoryPoints(months: Int) -> [UsageHistoryPoint] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        var points: [UsageHistoryPoint] = []
        let now = Date()

        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!

        // 预先获取所有记录到字典中
        let recordsDict = Dictionary(uniqueKeysWithValues: allRecords.map { ($0.date, $0) })

        for i in (0..<months).reversed() {
            guard let monthStart = calendar.date(byAdding: .month, value: -i, to: currentMonthStart) else { continue }
            guard let range = calendar.range(of: .day, in: .month, for: monthStart) else { continue }

            var totalTokens = 0
            var totalCost = 0.0

            for day in range {
                guard let date = calendar.date(bySetting: .day, value: day, of: monthStart) else { continue }
                let dateKey = formatter.string(from: date)
                if let record = recordsDict[dateKey] {
                    totalTokens += record.totalTokens
                    totalCost += record.totalCost
                }
            }

            points.append(UsageHistoryPoint(
                periodStart: monthStart,
                totalTokens: totalTokens,
                totalCost: totalCost
            ))
        }

        return points
    }

    /// 获取总计统计
    func getTotalStats() -> (tokens: Int, cost: Double) {
        let records = allRecords
        var totalTokens = 0
        var totalCost = 0.0

        for record in records {
            totalTokens += record.totalTokens
            totalCost += record.totalCost
        }

        return (totalTokens, totalCost)
    }
}
