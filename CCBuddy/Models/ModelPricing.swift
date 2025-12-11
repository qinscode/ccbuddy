import Foundation

struct ModelPricing {
    let inputPricePerMillion: Double
    let outputPricePerMillion: Double
    let cacheCreationPricePerMillion: Double
    let cacheReadPricePerMillion: Double

    // 分层定价 (超过200k tokens时的价格)
    let tieredInputPricePerMillion: Double?
    let tieredOutputPricePerMillion: Double?

    // 分层阈值 (200k tokens)
    static let tieredThreshold = 200_000

    init(
        inputPricePerMillion: Double,
        outputPricePerMillion: Double,
        cacheCreationPricePerMillion: Double,
        cacheReadPricePerMillion: Double,
        tieredInputPricePerMillion: Double? = nil,
        tieredOutputPricePerMillion: Double? = nil
    ) {
        self.inputPricePerMillion = inputPricePerMillion
        self.outputPricePerMillion = outputPricePerMillion
        self.cacheCreationPricePerMillion = cacheCreationPricePerMillion
        self.cacheReadPricePerMillion = cacheReadPricePerMillion
        self.tieredInputPricePerMillion = tieredInputPricePerMillion
        self.tieredOutputPricePerMillion = tieredOutputPricePerMillion
    }

    // 计算分层费用
    private func calculateTieredCost(tokens: Int, basePrice: Double, tieredPrice: Double?) -> Double {
        guard let tieredPrice = tieredPrice, tokens > Self.tieredThreshold else {
            return Double(tokens) * basePrice / 1_000_000
        }

        let baseTokens = Self.tieredThreshold
        let tieredTokens = tokens - Self.tieredThreshold

        let baseCost = Double(baseTokens) * basePrice / 1_000_000
        let tieredCost = Double(tieredTokens) * tieredPrice / 1_000_000

        return baseCost + tieredCost
    }

    // 计算费用 (支持分层定价)
    func calculateCost(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int
    ) -> Double {
        let inputCost = calculateTieredCost(tokens: inputTokens, basePrice: inputPricePerMillion, tieredPrice: tieredInputPricePerMillion)
        let outputCost = calculateTieredCost(tokens: outputTokens, basePrice: outputPricePerMillion, tieredPrice: tieredOutputPricePerMillion)
        let cacheCreationCost = Double(cacheCreationTokens) * cacheCreationPricePerMillion / 1_000_000
        let cacheReadCost = Double(cacheReadTokens) * cacheReadPricePerMillion / 1_000_000

        return inputCost + outputCost + cacheCreationCost + cacheReadCost
    }

    // MARK: - 预定义模型价格 (基于 LiteLLM 2025年)

    static let claudeOpus4 = ModelPricing(
        inputPricePerMillion: 15.0,
        outputPricePerMillion: 75.0,
        cacheCreationPricePerMillion: 18.75,
        cacheReadPricePerMillion: 1.50
    )

    // Opus 4.5 使用新价格: $5/$25 per million
    static let claudeOpus45 = ModelPricing(
        inputPricePerMillion: 5.0,
        outputPricePerMillion: 25.0,
        cacheCreationPricePerMillion: 6.25,
        cacheReadPricePerMillion: 0.50
    )

    // Sonnet 4 支持分层定价
    static let claudeSonnet4 = ModelPricing(
        inputPricePerMillion: 3.0,
        outputPricePerMillion: 15.0,
        cacheCreationPricePerMillion: 3.75,
        cacheReadPricePerMillion: 0.30,
        tieredInputPricePerMillion: 6.0,
        tieredOutputPricePerMillion: 22.5
    )

    // Sonnet 4.5 支持分层定价
    static let claudeSonnet45 = ModelPricing(
        inputPricePerMillion: 3.0,
        outputPricePerMillion: 15.0,
        cacheCreationPricePerMillion: 3.75,
        cacheReadPricePerMillion: 0.30,
        tieredInputPricePerMillion: 6.0,
        tieredOutputPricePerMillion: 22.5
    )

    static let claudeHaiku35 = ModelPricing(
        inputPricePerMillion: 0.80,
        outputPricePerMillion: 4.0,
        cacheCreationPricePerMillion: 1.0,
        cacheReadPricePerMillion: 0.08
    )

    static let claudeHaiku45 = ModelPricing(
        inputPricePerMillion: 1.0,
        outputPricePerMillion: 5.0,
        cacheCreationPricePerMillion: 1.25,
        cacheReadPricePerMillion: 0.10
    )

    // 默认价格 (使用 Sonnet 价格)
    static let `default` = claudeSonnet4

    // 根据模型名称获取价格
    static func forModel(_ modelName: String) -> ModelPricing {
        let lowercased = modelName.lowercased()

        if lowercased.contains("opus-4-5") || lowercased.contains("opus-45") || lowercased.contains("opus45") {
            return claudeOpus45
        } else if lowercased.contains("opus-4") || lowercased.contains("opus4") {
            return claudeOpus4
        } else if lowercased.contains("sonnet-4-5") || lowercased.contains("sonnet-45") || lowercased.contains("sonnet45") {
            return claudeSonnet45
        } else if lowercased.contains("sonnet-4") || lowercased.contains("sonnet4") {
            return claudeSonnet4
        } else if lowercased.contains("haiku-4-5") || lowercased.contains("haiku-45") || lowercased.contains("haiku45") {
            return claudeHaiku45
        } else if lowercased.contains("haiku-3-5") || lowercased.contains("haiku-35") || lowercased.contains("haiku") {
            return claudeHaiku35
        }

        return .default
    }
}

// MARK: - 模型显示名称

extension ModelPricing {
    static func displayName(for modelId: String) -> String {
        let lowercased = modelId.lowercased()

        if lowercased.contains("opus-4-5") || lowercased.contains("opus-45") {
            return "Claude Opus 4.5"
        } else if lowercased.contains("opus-4") || lowercased.contains("opus4") {
            return "Claude Opus 4"
        } else if lowercased.contains("sonnet-4-5") || lowercased.contains("sonnet-45") {
            return "Claude Sonnet 4.5"
        } else if lowercased.contains("sonnet-4") || lowercased.contains("sonnet4") {
            return "Claude Sonnet 4"
        } else if lowercased.contains("haiku-4-5") || lowercased.contains("haiku-45") {
            return "Claude Haiku 4.5"
        } else if lowercased.contains("haiku-3-5") || lowercased.contains("haiku-35") {
            return "Claude Haiku 3.5"
        } else if lowercased.contains("haiku") {
            return "Claude Haiku"
        }

        return modelId
    }

    static func displayNames(for models: Set<String>) -> String {
        if models.isEmpty {
            return "Unknown"
        }

        // 获取唯一的显示名称（避免重复）
        let uniqueNames = Set(models.map { displayName(for: $0) })
        return uniqueNames.sorted().joined(separator: ", ")
    }
}
