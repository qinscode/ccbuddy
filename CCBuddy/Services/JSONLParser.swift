import Foundation

class JSONLParser {
    private let fileManager = FileManager.default
    private let decoder = JSONDecoder()

    // Claude data directory
    var claudeDataPath: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("projects")
    }

    // MARK: - Parse all sessions

    func parseAllSessions() -> [ParsedSession] {
        var sessions: [ParsedSession] = []

        guard fileManager.fileExists(atPath: claudeDataPath.path) else {
            print("Claude data directory not found: \(claudeDataPath.path)")
            return sessions
        }

        do {
            let projectDirs = try fileManager.contentsOfDirectory(
                at: claudeDataPath,
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

        return sessions
    }

    // MARK: - Parse sessions in a project

    private func parseProjectSessions(at projectDir: URL) -> [ParsedSession] {
        var sessions: [ParsedSession] = []

        do {
            let files = try fileManager.contentsOfDirectory(
                at: projectDir,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            let jsonlFiles = files.filter { $0.pathExtension == "jsonl" }

            for file in jsonlFiles {
                if let session = parseSessionFile(at: file, projectPath: projectDir.lastPathComponent) {
                    sessions.append(session)
                }
            }
        } catch {
            print("Error reading project directory \(projectDir): \(error)")
        }

        return sessions
    }

    // MARK: - Parse a single session file

    func parseSessionFile(at url: URL, projectPath: String) -> ParsedSession? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        // Deduplicate by messageId:requestId (matches ccusage)
        // Keep the first record (contains accurate usage)
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
                let claudeMessage = try decoder.decode(ClaudeMessage.self, from: data)

                // Update sessionId when present
                if let sid = claudeMessage.sessionId {
                    sessionId = sid
                }

                // Only handle assistant messages (carry usage info)
                guard claudeMessage.type == "assistant",
                      let messageContent = claudeMessage.message,
                      let usage = messageContent.usage,
                      let messageId = messageContent.id else {
                    continue
                }

                // Dedup logic (same as ccusage)
                // Dedup only when both messageId and requestId exist
                // If requestId is missing, do not dedup
                if let requestId = claudeMessage.requestId {
                    let uniqueHash = "\(messageId):\(requestId)"
                    if processedHashes.contains(uniqueHash) {
                        continue
                    }
                    processedHashes.insert(uniqueHash)
                }
                // If no requestId, add directly (no dedup)

                // Parse timestamp
                var timestamp = Date()
                if let ts = claudeMessage.timestamp {
                    // Try multiple formats
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

                let parsedMessage = ParsedMessage(
                    uuid: claudeMessage.uuid ?? UUID().uuidString,
                    timestamp: timestamp,
                    model: messageContent.model,
                    inputTokens: usage.inputTokens ?? 0,
                    outputTokens: usage.outputTokens ?? 0,
                    cacheCreationTokens: usage.cacheCreationInputTokens ?? 0,
                    cacheReadTokens: usage.cacheReadInputTokens ?? 0
                )

                messages.append(parsedMessage)

            } catch {
                // Ignore parse errors and continue
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

    // MARK: - Get today's data

    func getTodayMessages() -> [ParsedMessage] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let sessions = parseAllSessions()

        return sessions
            .flatMap { $0.messages }
            .filter { $0.timestamp >= startOfDay }
            .sorted { $0.timestamp < $1.timestamp }
    }
}
