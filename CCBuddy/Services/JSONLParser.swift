import Foundation

class JSONLParser {
    private let fileManager = FileManager.default
    private let decoder = JSONDecoder()

    // Claude data directories (matches ccusage: both ~/.claude and ~/.config/claude)
    var claudeDataPaths: [URL] {
        var paths: [URL] = []
        let home = fileManager.homeDirectoryForCurrentUser

        // New default: ~/.config/claude/projects
        let configPath = home
            .appendingPathComponent(".config")
            .appendingPathComponent("claude")
            .appendingPathComponent("projects")
        if fileManager.fileExists(atPath: configPath.path) {
            paths.append(configPath)
        }

        // Old default: ~/.claude/projects
        let claudePath = home
            .appendingPathComponent(".claude")
            .appendingPathComponent("projects")
        if fileManager.fileExists(atPath: claudePath.path) {
            paths.append(claudePath)
        }

        return paths
    }

    // For backward compatibility
    var claudeDataPath: URL {
        claudeDataPaths.first ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("projects")
    }

    // MARK: - Parse all sessions

    func parseAllSessions() -> [ParsedSession] {
        var sessions: [ParsedSession] = []

        for dataPath in claudeDataPaths {
            guard fileManager.fileExists(atPath: dataPath.path) else {
                continue
            }

            do {
                let projectDirs = try fileManager.contentsOfDirectory(
                    at: dataPath,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )

                for projectDir in projectDirs {
                    var isDirectory: ObjCBool = false
                    if fileManager.fileExists(atPath: projectDir.path, isDirectory: &isDirectory),
                       isDirectory.boolValue {
                        let projectSessions = parseProjectSessions(at: projectDir)
                        sessions.append(contentsOf: projectSessions)
                    }
                }
            } catch {
                print("Error reading projects directory: \(error)")
            }
        }

        return sessions
    }

    // MARK: - Parse sessions in a project (recursively including subagents)

    private func parseProjectSessions(at projectDir: URL) -> [ParsedSession] {
        var sessions: [ParsedSession] = []
        let projectPath = projectDir.lastPathComponent

        // Recursively find all .jsonl files (matches ccusage's glob pattern: **/*.jsonl)
        let jsonlFiles = findAllJsonlFiles(in: projectDir)

        for file in jsonlFiles {
            if let session = parseSessionFile(at: file, projectPath: projectPath) {
                sessions.append(session)
            }
        }

        return sessions
    }

    // MARK: - Recursively find all JSONL files (matches ccusage's **/*.jsonl glob)

    private func findAllJsonlFiles(in directory: URL) -> [URL] {
        var result: [URL] = []

        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return result
        }

        for case let fileURL as URL in enumerator {
            if fileURL.pathExtension == "jsonl" {
                result.append(fileURL)
            }
        }

        return result
    }

    // MARK: - Parse a single session file (matches ccusage logic exactly)

    func parseSessionFile(at url: URL, projectPath: String) -> ParsedSession? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

        // Deduplication: messageId:requestId (matches ccusage)
        // Only dedup when BOTH messageId AND requestId exist
        // If either is missing, do NOT dedup (add all records)
        var processedHashes = Set<String>()
        var messages: [ParsedMessage] = []
        var sessionId = url.deletingPathExtension().lastPathComponent
        var startTime: Date?
        var endTime: Date?

        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for line in lines {
            guard let data = line.data(using: .utf8) else { continue }

            do {
                // Parse as generic JSON first (matches ccusage's JSON.parse)
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    continue
                }

                // Extract message object
                guard let messageObj = json["message"] as? [String: Any] else {
                    continue
                }

                // Extract usage object (REQUIRED - matches ccusage schema)
                guard let usageObj = messageObj["usage"] as? [String: Any] else {
                    continue
                }

                // input_tokens and output_tokens are REQUIRED (matches ccusage schema)
                guard let inputTokens = usageObj["input_tokens"] as? Int else {
                    continue
                }
                guard let outputTokens = usageObj["output_tokens"] as? Int else {
                    continue
                }

                // Update sessionId when present
                if let sid = json["sessionId"] as? String {
                    sessionId = sid
                }

                // Dedup logic (EXACTLY matches ccusage)
                // Only dedup when BOTH messageId AND requestId exist
                let messageId = messageObj["id"] as? String
                let requestId = json["requestId"] as? String

                if let msgId = messageId, let reqId = requestId {
                    let uniqueHash = "\(msgId):\(reqId)"
                    if processedHashes.contains(uniqueHash) {
                        continue
                    }
                    processedHashes.insert(uniqueHash)
                }
                // If either is nil, do NOT dedup - add the record

                // Parse timestamp
                var timestamp = Date()
                if let ts = json["timestamp"] as? String {
                    if let date = dateFormatter.date(from: ts) {
                        timestamp = date
                    } else {
                        // Fallback: no fractional seconds
                        let fallbackFormatter = ISO8601DateFormatter()
                        if let date = fallbackFormatter.date(from: ts) {
                            timestamp = date
                        }
                    }
                }

                // Update time bounds
                if startTime == nil || timestamp < startTime! {
                    startTime = timestamp
                }
                if endTime == nil || timestamp > endTime! {
                    endTime = timestamp
                }

                // Extract optional fields
                let model = messageObj["model"] as? String
                let cacheCreationTokens = usageObj["cache_creation_input_tokens"] as? Int ?? 0
                let cacheReadTokens = usageObj["cache_read_input_tokens"] as? Int ?? 0
                let uuid = json["uuid"] as? String ?? UUID().uuidString

                let parsedMessage = ParsedMessage(
                    uuid: uuid,
                    timestamp: timestamp,
                    model: model,
                    inputTokens: inputTokens,
                    outputTokens: outputTokens,
                    cacheCreationTokens: cacheCreationTokens,
                    cacheReadTokens: cacheReadTokens
                )

                messages.append(parsedMessage)

            } catch {
                // Skip invalid JSON lines (matches ccusage)
                continue
            }
        }

        guard !messages.isEmpty else { return nil }

        return ParsedSession(
            sessionId: sessionId,
            projectPath: projectPath,
            messages: messages,
            startTime: startTime,
            endTime: endTime
        )
    }

    // MARK: - Get data in rolling window

    func getMessagesInRollingWindow(hours: Double = 5) -> [ParsedMessage] {
        let cutoffTime = Date().addingTimeInterval(-hours * 60 * 60)
        let sessions = parseAllSessions()

        return sessions
            .flatMap { $0.messages }
            .filter { $0.timestamp >= cutoffTime }
            .sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Get today's data (matches ccusage: group by formatted date string in local timezone)

    func getTodayMessages() -> [ParsedMessage] {
        // ccusage uses Intl.DateTimeFormat with local timezone to format dates
        // Then groups by the formatted date string (YYYY-MM-DD)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current  // Local timezone (matches ccusage)

        let todayString = dateFormatter.string(from: Date())
        let sessions = parseAllSessions()

        return sessions
            .flatMap { $0.messages }
            .filter { dateFormatter.string(from: $0.timestamp) == todayString }
            .sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - Get messages for a specific date (matches ccusage date grouping)

    func getMessagesForDate(_ date: Date) -> [ParsedMessage] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        dateFormatter.timeZone = TimeZone.current

        let targetDateString = dateFormatter.string(from: date)
        let sessions = parseAllSessions()

        return sessions
            .flatMap { $0.messages }
            .filter { dateFormatter.string(from: $0.timestamp) == targetDateString }
            .sorted { $0.timestamp < $1.timestamp }
    }
}
