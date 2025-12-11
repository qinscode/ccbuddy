import Foundation

class JSONLParser {
    private let fileManager = FileManager.default
    private let decoder = JSONDecoder()

    // Claude 数据目录
    var claudeDataPath: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
            .appendingPathComponent("projects")
    }

    // MARK: - 解析所有会话

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

    // MARK: - 解析项目会话

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

    // MARK: - 解析单个会话文件

    func parseSessionFile(at url: URL, projectPath: String) -> ParsedSession? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        // 使用 messageId:requestId 组合去重（与 ccusage 保持一致）
        // 保留第一条记录（第一条包含准确的 usage 数据）
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

                // 更新 sessionId
                if let sid = claudeMessage.sessionId {
                    sessionId = sid
                }

                // 只处理 assistant 类型的消息（包含 usage 信息）
                guard claudeMessage.type == "assistant",
                      let messageContent = claudeMessage.message,
                      let usage = messageContent.usage,
                      let messageId = messageContent.id else {
                    continue
                }

                // 去重逻辑（与 ccusage 保持一致）
                // 只有当 messageId 和 requestId 都存在时才进行去重
                // 如果 requestId 缺失，则不去重（所有条目都计算）
                if let requestId = claudeMessage.requestId {
                    let uniqueHash = "\(messageId):\(requestId)"
                    if processedHashes.contains(uniqueHash) {
                        continue
                    }
                    processedHashes.insert(uniqueHash)
                }
                // 如果没有 requestId，不进行去重，直接添加

                // 解析时间戳
                var timestamp = Date()
                if let ts = claudeMessage.timestamp {
                    // 尝试多种格式
                    if let date = dateFormatter.date(from: ts) {
                        timestamp = date
                    } else {
                        // 尝试不带毫秒的格式
                        let fallbackFormatter = ISO8601DateFormatter()
                        if let date = fallbackFormatter.date(from: ts) {
                            timestamp = date
                        }
                    }
                }

                // 更新时间范围
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
                // 静默忽略解析错误，继续处理下一行
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

    // MARK: - 获取5小时窗口内的数据

    func getMessagesInRollingWindow(hours: Double = 5) -> [ParsedMessage] {
        let cutoffTime = Date().addingTimeInterval(-hours * 60 * 60)
        let sessions = parseAllSessions()

        return sessions
            .flatMap { $0.messages }
            .filter { $0.timestamp >= cutoffTime }
            .sorted { $0.timestamp < $1.timestamp }
    }

    // MARK: - 获取今日数据

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
