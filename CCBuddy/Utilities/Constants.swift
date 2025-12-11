import Foundation

enum Constants {
    // MARK: - App Info

    static let appName = "CCBuddy"
    static let appVersion = "1.0.0"
    static let appBundleIdentifier = "com.ccusage.app"

    // MARK: - Claude Code

    static let claudeDataDirectoryName = ".claude"
    static let claudeProjectsDirectoryName = "projects"

    static var claudeDataPath: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(claudeDataDirectoryName)
    }

    static var claudeProjectsPath: URL {
        claudeDataPath.appendingPathComponent(claudeProjectsDirectoryName)
    }

    // MARK: - Time Windows

    static let rollingWindowHours: Double = 5
    static let rollingWindowSeconds: TimeInterval = 5 * 60 * 60

    // MARK: - Refresh Intervals

    static let defaultRefreshInterval: Int = 10
    static let minRefreshInterval: Int = 1
    static let maxRefreshInterval: Int = 300

    // MARK: - Usage Limits (Estimated)

    // 这些是估计值，实际限制取决于订阅计划
    static let estimatedFiveHourTokenLimit = 20_000_000

    // MARK: - Notification Thresholds

    static let defaultNotificationThreshold = 75
    static let warningThresholds = [50, 75, 90, 95]

    // MARK: - UI

    static let popoverWidth: CGFloat = 320
    static let settingsWidth: CGFloat = 450
    static let settingsHeight: CGFloat = 300

    // MARK: - UserDefaults Keys

    enum UserDefaultsKeys {
        static let refreshInterval = "refreshInterval"
        static let showInMenuBar = "showInMenuBar"
        static let launchAtLogin = "launchAtLogin"
        static let showNotifications = "showNotifications"
        static let notificationThreshold = "notificationThreshold"
    }
}
