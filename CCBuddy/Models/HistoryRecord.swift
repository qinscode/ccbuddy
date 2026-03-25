import Foundation
import SwiftData

/// SwiftData 每日用量历史记录模型
@Model
final class DailyUsageRecord {
    @Attribute(.unique) var date: String  // 格式: "yyyy-MM-dd"
    var totalInputTokens: Int
    var totalOutputTokens: Int
    var totalCacheCreationTokens: Int
    var totalCacheReadTokens: Int
    var totalCost: Double
    var sessionCount: Int
    var models: [String]
    var lastUpdated: Date

    var totalTokens: Int {
        totalInputTokens + totalOutputTokens + totalCacheCreationTokens + totalCacheReadTokens
    }

    var dateValue: Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: date)
    }

    init(date: String, inputTokens: Int = 0, outputTokens: Int = 0,
         cacheCreationTokens: Int = 0, cacheReadTokens: Int = 0,
         cost: Double = 0, sessionCount: Int = 0, models: [String] = []) {
        self.date = date
        self.totalInputTokens = inputTokens
        self.totalOutputTokens = outputTokens
        self.totalCacheCreationTokens = cacheCreationTokens
        self.totalCacheReadTokens = cacheReadTokens
        self.totalCost = cost
        self.sessionCount = sessionCount
        self.models = models
        self.lastUpdated = Date()
    }

    /// 更新记录（取较大值，防止 JSONL 文件删除或定价失败导致数据丢失）
    func update(inputTokens: Int, outputTokens: Int, cacheCreationTokens: Int,
                cacheReadTokens: Int, cost: Double, sessionCount: Int, models: [String]) {
        self.totalInputTokens = max(self.totalInputTokens, inputTokens)
        self.totalOutputTokens = max(self.totalOutputTokens, outputTokens)
        self.totalCacheCreationTokens = max(self.totalCacheCreationTokens, cacheCreationTokens)
        self.totalCacheReadTokens = max(self.totalCacheReadTokens, cacheReadTokens)
        self.totalCost = max(self.totalCost, cost)
        self.sessionCount = max(self.sessionCount, sessionCount)
        let allModels = Set(self.models).union(Set(models))
        self.models = Array(allModels)
        self.lastUpdated = Date()
    }
}
