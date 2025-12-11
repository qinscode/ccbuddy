import Foundation
import SwiftUI
import Combine

@MainActor
class UsageViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var currentStats: UsageStats = UsageStats()
    @Published var aggregatedStats: AggregatedStats?
    @Published var dailyBreakdown: [DailyStats] = []
    @Published var dailyHistory: [UsageHistoryPoint] = []
    @Published var weeklyHistory: [UsageHistoryPoint] = []
    @Published var monthlyHistory: [UsageHistoryPoint] = []
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    @Published var error: String?

    // MARK: - Settings

    @AppStorage("refreshInterval") var refreshInterval: Int = Constants.defaultRefreshInterval {
        didSet {
            startAutoRefresh()
            objectWillChange.send()
        }
    }
    @AppStorage("showInMenuBar") var showInMenuBar: MenuBarDisplay = .cost {
        didSet { objectWillChange.send() }
    }
    @AppStorage("glassOpacity") var glassOpacity: Double = 0.8 {
        didSet { objectWillChange.send() }
    }
    @AppStorage("materialStyle") var materialStyle: GlassMaterialStyle = .ultraThin {
        didSet { objectWillChange.send() }
    }
    @AppStorage("usageMode") var usageMode: UsageMode = .proMax {
        didSet { objectWillChange.send() }
    }
    @AppStorage("fontSize") var fontSize: FontSizeOption = .medium {
        didSet { objectWillChange.send() }
    }

    // MARK: - Private Properties

    private let calculator = UsageCalculator()
    private let parser = JSONLParser()
    private var fileWatcher: MultiDirectoryWatcher?
    private var refreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var refreshTask: Task<Void, Never>?
    private var cachedSessions: [ParsedSession] = []
    private var dataDirty = true
    private var lastFullRefresh: Date?
    private var lastModificationCheck: Date?

    // MARK: - Init

    init() {
        setupFileWatcher()
        refresh()
        startAutoRefresh()
    }

    deinit {
        refreshTimer?.invalidate()
        fileWatcher?.stopAll()
    }

    // MARK: - Public Methods

    func refresh(force: Bool = false) {
        // prevent overlapping refreshes
        guard refreshTask == nil else {
            print("⚠️ [\(timeStamp())] Refresh skipped - already in progress")
            return
        }

        let startTime = Date()
        print("🔄 [\(timeStamp())] Refresh started (force: \(force))")

        refreshTask = Task { [weak self] in
            guard let self else { return }

            self.error = nil
            self.isLoading = true

            // Check if we should reparse based on data dirty flag or periodic check
            let shouldCheckFiles = !self.dataDirty && !force && !self.cachedSessions.isEmpty
            var filesChanged = false

            if shouldCheckFiles {
                // Only do periodic file check if not already dirty (to avoid redundant work)
                let now = Date()
                if let lastCheck = self.lastModificationCheck {
                    // Check files at most once per refresh interval
                    if now.timeIntervalSince(lastCheck) >= Double(refreshInterval) {
                        filesChanged = await self.quickCheckFilesModified()
                        self.lastModificationCheck = now
                    }
                } else {
                    filesChanged = await self.quickCheckFilesModified()
                    self.lastModificationCheck = now
                }
            }

            // Parse sessions when data is marked dirty, cache is empty, files changed, or forced
            let sessions: [ParsedSession]
            let shouldReparse = force || self.dataDirty || self.cachedSessions.isEmpty || filesChanged
            print("📁 [\(self.timeStamp())] Using cached sessions: \(!shouldReparse), dirty: \(self.dataDirty), filesChanged: \(filesChanged)")

            if shouldReparse {
                sessions = await Task.detached { [parser = self.parser] in
                    parser.parseAllSessions()
                }.value
                self.cachedSessions = sessions
                self.dataDirty = false
                self.lastFullRefresh = Date()
                print("✅ [\(self.timeStamp())] Parsed \(sessions.count) sessions")
            } else {
                sessions = self.cachedSessions
                print("♻️ [\(self.timeStamp())] Reusing \(sessions.count) cached sessions")
            }

            async let statsTask: UsageStats = Task.detached { [calculator] in
                calculator.calculateRollingWindowUsage(preloadedSessions: sessions)
            }.value

            async let todayTask: DailyStats = Task.detached { [calculator] in
                calculator.calculateTodayStats(preloadedSessions: sessions)
            }.value

            async let dailyBreakdownTask: [DailyStats] = Task.detached { [calculator] in
                calculator.calculateDailyBreakdown(days: 7, preloadedSessions: sessions)
            }.value

            async let historyTask = Task.detached { [calculator] in
                (
                    daily: calculator.calculateDailyHistory(days: 7, preloadedSessions: sessions),
                    weekly: calculator.calculateWeeklyHistory(weeks: 8, preloadedSessions: sessions),
                    monthly: calculator.calculateMonthlyHistory(months: 6, preloadedSessions: sessions)
                )
            }.value

            let stats = await statsTask
            let today = await todayTask
            self.currentStats = stats

            self.aggregatedStats = await Task.detached { [calculator] in
                calculator.calculateAggregatedStats(
                    preloadedSessions: sessions,
                    fiveHourWindow: stats,
                    todayStats: today
                )
            }.value
            self.dailyBreakdown = await dailyBreakdownTask
            let history = await historyTask
            self.dailyHistory = history.daily
            self.weeklyHistory = history.weekly
            self.monthlyHistory = history.monthly
            self.lastUpdated = Date()
            self.isLoading = false
            self.refreshTask = nil

            let duration = Date().timeIntervalSince(startTime)
            print("✅ [\(self.timeStamp())] Refresh completed in \(String(format: "%.2f", duration))s")
        }
    }

    func setRefreshInterval(_ seconds: Int) {
        refreshInterval = seconds
        startAutoRefresh()
    }

    // MARK: - Private Methods

    private func setupFileWatcher() {
        fileWatcher = MultiDirectoryWatcher()
        fileWatcher?.onChange = { [weak self] in
            Task { @MainActor in
                self?.dataDirty = true
                self?.refresh()
            }
        }

        // Watch Claude data directories
        let claudePath = parser.claudeDataPath
        if FileManager.default.fileExists(atPath: claudePath.path) {
            // 获取所有项目目录
            if let projectDirs = try? FileManager.default.contentsOfDirectory(
                at: claudePath,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            ) {
                fileWatcher?.watch(directories: projectDirs)
            }
        }
    }

    private func startAutoRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil

        guard refreshInterval > 0 else {
            print("⏸️ [\(timeStamp())] Auto-refresh disabled (interval: 0)")
            return
        }

        print("⏱️ [\(timeStamp())] Starting auto-refresh with interval: \(refreshInterval)s")

        let timer = Timer(timeInterval: TimeInterval(refreshInterval), repeats: true) { [weak self] _ in
            let timestamp = Self.formatTime(Date())
            print("🔄 [\(timestamp)] Timer fired - triggering refresh")
            Task { @MainActor in
                self?.refresh()
            }
        }

        // Add timer to main RunLoop with .common mode so it works during UI tracking
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    // MARK: - File Checking

    private func quickCheckFilesModified() async -> Bool {
        return await Task.detached { [parser = self.parser, lastRefresh = self.lastFullRefresh] in
            guard let lastRefresh = lastRefresh else { return true }

            let claudePath = parser.claudeDataPath
            guard FileManager.default.fileExists(atPath: claudePath.path) else {
                return false
            }

            do {
                let projectDirs = try FileManager.default.contentsOfDirectory(
                    at: claudePath,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: [.skipsHiddenFiles]
                )

                for projectDir in projectDirs {
                    var isDirectory: ObjCBool = false
                    guard FileManager.default.fileExists(atPath: projectDir.path, isDirectory: &isDirectory),
                          isDirectory.boolValue else {
                        continue
                    }

                    let files = try FileManager.default.contentsOfDirectory(
                        at: projectDir,
                        includingPropertiesForKeys: [.contentModificationDateKey],
                        options: [.skipsHiddenFiles]
                    )

                    let jsonlFiles = files.filter { $0.pathExtension == "jsonl" }

                    for file in jsonlFiles {
                        let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                        if let modDate = attributes[.modificationDate] as? Date {
                            if modDate > lastRefresh {
                                return true
                            }
                        }
                    }
                }

                return false
            } catch {
                return false
            }
        }.value
    }

    // MARK: - Helper Methods

    private func timeStamp() -> String {
        Self.formatTime(Date())
    }

    nonisolated private static func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }
}

// MARK: - Menu Bar Display Options

enum MenuBarDisplay: String, CaseIterable {
    case percentage = "percentage"
    case tokens = "tokens"
    case cost = "cost"
    case icon = "icon"

    var displayName: String {
        switch self {
        case .percentage: return "Percentage"
        case .tokens: return "Tokens"
        case .cost: return "Cost"
        case .icon: return "Icon Only"
        }
    }
}

// MARK: - Glass Material Style

enum GlassMaterialStyle: String, CaseIterable {
    case ultraThin = "ultraThin"
    case thin = "thin"
    case regular = "regular"
    case thick = "thick"
    case ultraThick = "ultraThick"

    var displayName: String {
        switch self {
        case .ultraThin: return "Ultra Thin"
        case .thin: return "Thin"
        case .regular: return "Regular"
        case .thick: return "Thick"
        case .ultraThick: return "Ultra Thick"
        }
    }
}

// MARK: - Usage Mode

enum UsageMode: String, CaseIterable {
    case proMax = "proMax"
    case api = "api"

    var displayName: String {
        switch self {
        case .proMax: return "Pro / Max Plan"
        case .api: return "API (Pay-as-you-go)"
        }
    }

    var description: String {
        switch self {
        case .proMax: return "5-hour rolling window with weekly limits"
        case .api: return "Pay per token, no time limits"
        }
    }
}

// MARK: - Font Size Option

enum FontSizeOption: String, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"

    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    var titleSize: CGFloat {
        switch self {
        case .small: return 11
        case .medium: return 12
        case .large: return 13
        }
    }

    var valueSize: CGFloat {
        switch self {
        case .small: return 11
        case .medium: return 12
        case .large: return 13
        }
    }

    var iconSize: CGFloat {
        switch self {
        case .small: return 10
        case .medium: return 11
        case .large: return 12
        }
    }

    var iconContainerSize: CGFloat {
        switch self {
        case .small: return 22
        case .medium: return 24
        case .large: return 26
        }
    }
}

// MARK: - Formatted Output

extension UsageViewModel {
    var menuBarText: String {
        switch showInMenuBar {
        case .percentage:
            if usageMode == .proMax {
                return String(format: "%.0f%%", currentStats.usagePercentage)
            } else {
                return formattedTodayCost
            }
        case .tokens:
            return currentStats.formattedTotalTokens
        case .cost:
            // In API mode show today's cost; in Pro/Max show current window cost
            if usageMode == .api {
                return formattedTodayCost
            } else {
                return String(format: "$%.2f", currentStats.estimatedCost)
            }
        case .icon:
            return ""
        }
    }

    var formattedCost: String {
        String(format: "$%.4f", currentStats.estimatedCost)
    }

    var formattedProjectedCost: String {
        String(format: "$%.2f", currentStats.projectedCost)
    }

    var formattedLastUpdated: String {
        guard let lastUpdated = lastUpdated else { return "Never" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdated, relativeTo: Date())
    }

    // MARK: - API Mode Costs

    var formattedTodayCost: String {
        guard let stats = aggregatedStats else { return "$0.00" }
        return String(format: "$%.2f", stats.today.totalCost)
    }

    var formattedWeekCost: String {
        guard let stats = aggregatedStats else { return "$0.00" }
        return String(format: "$%.2f", stats.thisWeek)
    }

    var formattedMonthCost: String {
        guard let stats = aggregatedStats else { return "$0.00" }
        return String(format: "$%.2f", stats.thisMonth)
    }

    var formattedAllTimeCost: String {
        guard let stats = aggregatedStats else { return "$0.00" }
        return String(format: "$%.2f", stats.allTime)
    }
}
