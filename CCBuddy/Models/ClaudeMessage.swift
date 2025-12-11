import Foundation

// MARK: - Claude JSONL Message Structure

struct ClaudeMessage: Codable {
    let type: String
    let sessionId: String?
    let timestamp: String?
    let message: MessageContent?
    let uuid: String?
    let parentUuid: String?
    let cwd: String?
    let version: String?
    let gitBranch: String?
    let requestId: String?

    enum CodingKeys: String, CodingKey {
        case type
        case sessionId
        case timestamp
        case message
        case uuid
        case parentUuid
        case cwd
        case version
        case gitBranch
        case requestId
    }
}

struct MessageContent: Codable {
    let role: String?
    let model: String?
    let id: String?
    let content: [ContentBlock]?
    let usage: TokenUsage?
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case role
        case model
        case id
        case content
        case usage
        case stopReason = "stop_reason"
    }
}

struct ContentBlock: Codable {
    let type: String
    let text: String?
    let thinking: String?
}

struct TokenUsage: Codable {
    let inputTokens: Int?
    let cacheCreationInputTokens: Int?
    let cacheReadInputTokens: Int?
    let outputTokens: Int?
    let serviceTier: String?

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case cacheCreationInputTokens = "cache_creation_input_tokens"
        case cacheReadInputTokens = "cache_read_input_tokens"
        case outputTokens = "output_tokens"
        case serviceTier = "service_tier"
    }

    var totalTokens: Int {
        (inputTokens ?? 0) +
        (cacheCreationInputTokens ?? 0) +
        (cacheReadInputTokens ?? 0) +
        (outputTokens ?? 0)
    }
}

// MARK: - Parsed Session

struct ParsedSession {
    let sessionId: String
    let projectPath: String
    let messages: [ParsedMessage]
    let startTime: Date?
    let endTime: Date?

    var totalTokens: Int {
        messages.reduce(0) { $0 + $1.totalTokens }
    }

    var totalCost: Double {
        messages.reduce(0) { $0 + $1.cost }
    }
}

struct ParsedMessage {
    let uuid: String
    let timestamp: Date
    let model: String?
    let inputTokens: Int
    let outputTokens: Int
    let cacheCreationTokens: Int
    let cacheReadTokens: Int

    var totalTokens: Int {
        inputTokens + outputTokens + cacheCreationTokens + cacheReadTokens
    }

    var cost: Double {
        guard let model = model else { return 0 }
        let pricing = ModelPricing.forModel(model)

        return pricing.calculateCost(
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            cacheCreationTokens: cacheCreationTokens,
            cacheReadTokens: cacheReadTokens
        )
    }
}
