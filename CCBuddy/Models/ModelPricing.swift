import Foundation

struct ModelPricing {
    let inputPricePerMillion: Double
    let outputPricePerMillion: Double
    let cacheCreationPricePerMillion: Double
    let cacheReadPricePerMillion: Double

    // Tiered pricing (applies above 200k tokens)
    let tieredInputPricePerMillion: Double?
    let tieredOutputPricePerMillion: Double?
    let tieredCacheCreationPricePerMillion: Double?
    let tieredCacheReadPricePerMillion: Double?

    // Tiered threshold (200k tokens)
    static let tieredThreshold = 200_000

    init(
        inputPricePerMillion: Double,
        outputPricePerMillion: Double,
        cacheCreationPricePerMillion: Double,
        cacheReadPricePerMillion: Double,
        tieredInputPricePerMillion: Double? = nil,
        tieredOutputPricePerMillion: Double? = nil,
        tieredCacheCreationPricePerMillion: Double? = nil,
        tieredCacheReadPricePerMillion: Double? = nil
    ) {
        self.inputPricePerMillion = inputPricePerMillion
        self.outputPricePerMillion = outputPricePerMillion
        self.cacheCreationPricePerMillion = cacheCreationPricePerMillion
        self.cacheReadPricePerMillion = cacheReadPricePerMillion
        self.tieredInputPricePerMillion = tieredInputPricePerMillion
        self.tieredOutputPricePerMillion = tieredOutputPricePerMillion
        self.tieredCacheCreationPricePerMillion = tieredCacheCreationPricePerMillion
        self.tieredCacheReadPricePerMillion = tieredCacheReadPricePerMillion
    }

    // Calculate tiered cost
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

    // Calculate cost (supports tiered pricing for all token types)
    func calculateCost(
        inputTokens: Int,
        outputTokens: Int,
        cacheCreationTokens: Int,
        cacheReadTokens: Int
    ) -> Double {
        let inputCost = calculateTieredCost(tokens: inputTokens, basePrice: inputPricePerMillion, tieredPrice: tieredInputPricePerMillion)
        let outputCost = calculateTieredCost(tokens: outputTokens, basePrice: outputPricePerMillion, tieredPrice: tieredOutputPricePerMillion)
        let cacheCreationCost = calculateTieredCost(tokens: cacheCreationTokens, basePrice: cacheCreationPricePerMillion, tieredPrice: tieredCacheCreationPricePerMillion)
        let cacheReadCost = calculateTieredCost(tokens: cacheReadTokens, basePrice: cacheReadPricePerMillion, tieredPrice: tieredCacheReadPricePerMillion)

        return inputCost + outputCost + cacheCreationCost + cacheReadCost
    }

    // MARK: - Predefined model pricing (LiteLLM 2025 - fallback when offline)

    static let claudeOpus4 = ModelPricing(
        inputPricePerMillion: 15.0,
        outputPricePerMillion: 75.0,
        cacheCreationPricePerMillion: 18.75,
        cacheReadPricePerMillion: 1.50
    )

    // Opus 4.5 uses new pricing: $5/$25 per million
    static let claudeOpus45 = ModelPricing(
        inputPricePerMillion: 5.0,
        outputPricePerMillion: 25.0,
        cacheCreationPricePerMillion: 6.25,
        cacheReadPricePerMillion: 0.50
    )

    // Sonnet 4 supports tiered pricing (including cache tokens)
    static let claudeSonnet4 = ModelPricing(
        inputPricePerMillion: 3.0,
        outputPricePerMillion: 15.0,
        cacheCreationPricePerMillion: 3.75,
        cacheReadPricePerMillion: 0.30,
        tieredInputPricePerMillion: 6.0,
        tieredOutputPricePerMillion: 22.5,
        tieredCacheCreationPricePerMillion: 7.5,
        tieredCacheReadPricePerMillion: 0.6
    )

    // Sonnet 4.5 supports tiered pricing (including cache tokens)
    static let claudeSonnet45 = ModelPricing(
        inputPricePerMillion: 3.0,
        outputPricePerMillion: 15.0,
        cacheCreationPricePerMillion: 3.75,
        cacheReadPricePerMillion: 0.30,
        tieredInputPricePerMillion: 6.0,
        tieredOutputPricePerMillion: 22.5,
        tieredCacheCreationPricePerMillion: 7.5,
        tieredCacheReadPricePerMillion: 0.6
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

    // Default pricing (Sonnet)
    static let `default` = claudeSonnet4

    // MARK: - Dynamic pricing from LiteLLM

    /// Cache for dynamically fetched pricing
    private static var dynamicPricingCache: [String: ModelPricing?] = [:]

    /// Get pricing for a model (async, fetches from LiteLLM)
    /// Returns nil if model not found in LiteLLM (to match ccusage behavior)
    static func forModelAsync(_ modelName: String) async -> ModelPricing? {
        // Check cache first
        if let cached = dynamicPricingCache[modelName] {
            return cached
        }

        // Try to fetch from LiteLLM
        let liteLLMPricing = await LiteLLMPricingFetcher.shared.getModelPricing(modelName)
        dynamicPricingCache[modelName] = liteLLMPricing
        return liteLLMPricing
    }

    /// Lookup pricing by model name (synchronous fallback - uses static pricing)
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

    /// Clear the dynamic pricing cache
    static func clearCache() {
        dynamicPricingCache.removeAll()
        LiteLLMPricingFetcher.shared.clearCache()
    }
}

// MARK: - Model display names

extension ModelPricing {
    /// Extract a display name like "Claude Opus 4.6" from model IDs such as
    /// "claude-opus-4-6-20260301", "claude-opus-46", "claude-opus-4", etc.
    static func displayName(for modelId: String) -> String {
        let lowercased = modelId.lowercased()

        // Model families ordered by priority
        let families = ["opus", "sonnet", "haiku"]

        for family in families {
            guard let familyRange = lowercased.range(of: family) else { continue }

            let afterFamily = String(lowercased[familyRange.upperBound...])

            // Try to extract version from the suffix after the family name.
            // Patterns: "-4-6...", "-45...", "45...", "-4...", "4..."
            let version = parseVersion(from: afterFamily)
            if let version = version {
                return "Claude \(family.capitalized) \(version)"
            } else {
                return "Claude \(family.capitalized)"
            }
        }

        return modelId
    }

    /// Parse a version string from a suffix like "-4-6-20260301", "-45", "4", etc.
    /// Returns e.g. "4.6", "4.5", "4", or nil if no digits found.
    private static func parseVersion(from suffix: String) -> String? {
        // Strip leading separator
        var s = suffix
        if s.hasPrefix("-") || s.hasPrefix("_") {
            s = String(s.dropFirst())
        }

        guard let firstDigit = s.first, firstDigit.isNumber else {
            return nil
        }

        // Collect all leading digits
        var digits = ""
        var rest = s[s.startIndex...]
        while let c = rest.first, c.isNumber {
            digits.append(c)
            rest = rest[rest.index(after: rest.startIndex)...]
        }

        // Case 1: Exactly 2 digits with no separator (e.g. "45" → "4.5")
        if digits.count == 2 && (rest.isEmpty || rest.first == "-" || rest.first == "_") {
            return "\(digits.first!).\(digits.last!)"
        }

        let major = digits

        // Case 2: Separator follows (e.g. "4-6-20260301")
        if let sep = rest.first, sep == "-" || sep == "_" {
            let afterSep = rest[rest.index(after: rest.startIndex)...]
            if let minorDigit = afterSep.first, minorDigit.isNumber {
                let afterMinor = afterSep[afterSep.index(after: afterSep.startIndex)...]
                // If minor digit is followed by another digit (not a separator), it's likely a date
                if let nextChar = afterMinor.first, nextChar.isNumber {
                    // "4-6-..." where next is separator → minor version; "4-20260301" → date, major only
                    return major
                } else {
                    return "\(major).\(minorDigit)"
                }
            }
            return major
        }

        // Case 3: Single digit or end of string
        return major
    }

    static func displayNames(for models: Set<String>) -> String {
        if models.isEmpty {
            return "Unknown"
        }

        // Unique display names to avoid duplicates
        let uniqueNames = Set(models.map { displayName(for: $0) })
        return uniqueNames.sorted().joined(separator: ", ")
    }
}
