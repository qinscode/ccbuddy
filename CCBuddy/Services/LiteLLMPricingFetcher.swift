import Foundation

/// LiteLLM pricing data structure
struct LiteLLMModelPricing: Codable {
    let inputCostPerToken: Double?
    let outputCostPerToken: Double?
    let cacheCreationInputTokenCost: Double?
    let cacheReadInputTokenCost: Double?

    // Tiered pricing (above 200k tokens)
    let inputCostPerTokenAbove200kTokens: Double?
    let outputCostPerTokenAbove200kTokens: Double?
    let cacheCreationInputTokenCostAbove200kTokens: Double?
    let cacheReadInputTokenCostAbove200kTokens: Double?

    enum CodingKeys: String, CodingKey {
        case inputCostPerToken = "input_cost_per_token"
        case outputCostPerToken = "output_cost_per_token"
        case cacheCreationInputTokenCost = "cache_creation_input_token_cost"
        case cacheReadInputTokenCost = "cache_read_input_token_cost"
        case inputCostPerTokenAbove200kTokens = "input_cost_per_token_above_200k_tokens"
        case outputCostPerTokenAbove200kTokens = "output_cost_per_token_above_200k_tokens"
        case cacheCreationInputTokenCostAbove200kTokens = "cache_creation_input_token_cost_above_200k_tokens"
        case cacheReadInputTokenCostAbove200kTokens = "cache_read_input_token_cost_above_200k_tokens"
    }

    /// Convert to ModelPricing (prices per million tokens)
    func toModelPricing() -> ModelPricing {
        ModelPricing(
            inputPricePerMillion: (inputCostPerToken ?? 0) * 1_000_000,
            outputPricePerMillion: (outputCostPerToken ?? 0) * 1_000_000,
            cacheCreationPricePerMillion: (cacheCreationInputTokenCost ?? 0) * 1_000_000,
            cacheReadPricePerMillion: (cacheReadInputTokenCost ?? 0) * 1_000_000,
            tieredInputPricePerMillion: inputCostPerTokenAbove200kTokens.map { $0 * 1_000_000 },
            tieredOutputPricePerMillion: outputCostPerTokenAbove200kTokens.map { $0 * 1_000_000 },
            tieredCacheCreationPricePerMillion: cacheCreationInputTokenCostAbove200kTokens.map { $0 * 1_000_000 },
            tieredCacheReadPricePerMillion: cacheReadInputTokenCostAbove200kTokens.map { $0 * 1_000_000 }
        )
    }
}

/// Fetches pricing data from LiteLLM's public pricing database
class LiteLLMPricingFetcher {
    static let shared = LiteLLMPricingFetcher()

    private let liteLLMURL = URL(string: "https://raw.githubusercontent.com/BerriAI/litellm/main/model_prices_and_context_window.json")!

    /// Cached pricing data
    private var cachedPricing: [String: LiteLLMModelPricing]?
    private var lastFetchTime: Date?
    private let cacheExpiration: TimeInterval = 3600 // 1 hour

    /// Provider prefixes to try when matching model names
    private let providerPrefixes = [
        "anthropic/",
        "claude-",
        ""
    ]

    private init() {}

    /// Fetch pricing data from LiteLLM (with caching)
    func fetchPricing() async throws -> [String: LiteLLMModelPricing] {
        // Return cached data if still valid
        if let cached = cachedPricing,
           let lastFetch = lastFetchTime,
           Date().timeIntervalSince(lastFetch) < cacheExpiration {
            return cached
        }

        let (data, _) = try await URLSession.shared.data(from: liteLLMURL)

        // Parse JSON manually since it's a dictionary with dynamic keys
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "LiteLLMPricingFetcher", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid JSON format"])
        }

        var pricing: [String: LiteLLMModelPricing] = [:]
        let decoder = JSONDecoder()

        for (modelName, modelData) in json {
            guard let modelDict = modelData as? [String: Any] else { continue }

            // Re-encode to JSON data for decoding
            if let modelJsonData = try? JSONSerialization.data(withJSONObject: modelDict) {
                if let modelPricing = try? decoder.decode(LiteLLMModelPricing.self, from: modelJsonData) {
                    pricing[modelName] = modelPricing
                }
            }
        }

        cachedPricing = pricing
        lastFetchTime = Date()

        print("LiteLLMPricingFetcher: Loaded pricing for \(pricing.count) models")

        return pricing
    }

    /// Get pricing for a specific model
    func getModelPricing(_ modelName: String) async -> ModelPricing? {
        do {
            let pricing = try await fetchPricing()

            // Try exact match first
            if let liteLLMPricing = pricing[modelName] {
                return liteLLMPricing.toModelPricing()
            }

            // Try with provider prefixes
            for prefix in providerPrefixes {
                let candidate = "\(prefix)\(modelName)"
                if let liteLLMPricing = pricing[candidate] {
                    return liteLLMPricing.toModelPricing()
                }
            }

            // Try fuzzy matching (case-insensitive contains)
            let lowercased = modelName.lowercased()
            for (key, value) in pricing {
                let keyLower = key.lowercased()
                if keyLower.contains(lowercased) || lowercased.contains(keyLower) {
                    return value.toModelPricing()
                }
            }

            // Try matching by model family
            if let familyPricing = findByModelFamily(modelName, in: pricing) {
                return familyPricing.toModelPricing()
            }

            return nil
        } catch {
            print("LiteLLMPricingFetcher: Error fetching pricing: \(error)")
            return nil
        }
    }

    /// Find pricing by model family (opus, sonnet, haiku)
    private func findByModelFamily(_ modelName: String, in pricing: [String: LiteLLMModelPricing]) -> LiteLLMModelPricing? {
        let lowercased = modelName.lowercased()

        // Determine model family and version
        let isOpus = lowercased.contains("opus")
        let isSonnet = lowercased.contains("sonnet")
        let isHaiku = lowercased.contains("haiku")
        let is45 = lowercased.contains("4-5") || lowercased.contains("45")
        let is4 = lowercased.contains("-4") || lowercased.contains("4-")

        // Build search patterns
        var searchPatterns: [String] = []

        if isOpus && is45 {
            searchPatterns = ["claude-opus-4-5", "opus-4-5"]
        } else if isOpus && is4 {
            searchPatterns = ["claude-opus-4", "opus-4"]
        } else if isSonnet && is45 {
            searchPatterns = ["claude-sonnet-4-5", "sonnet-4-5"]
        } else if isSonnet && is4 {
            searchPatterns = ["claude-sonnet-4", "sonnet-4"]
        } else if isHaiku && is45 {
            searchPatterns = ["claude-haiku-4-5", "haiku-4-5"]
        } else if isHaiku {
            searchPatterns = ["claude-haiku", "haiku-3-5"]
        }

        for pattern in searchPatterns {
            for (key, value) in pricing {
                if key.lowercased().contains(pattern) {
                    return value
                }
            }
        }

        return nil
    }

    /// Clear cached pricing data
    func clearCache() {
        cachedPricing = nil
        lastFetchTime = nil
    }
}
