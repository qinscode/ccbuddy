import SwiftUI
import AppKit

// 共享的 ViewModel
@MainActor
class SharedState: ObservableObject {
    static let shared = SharedState()
    let viewModel = UsageViewModel()
}

@main
struct CCBuddyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Settings Window
        Settings {
            SettingsView(viewModel: SharedState.shared.viewModel)
        }
    }
}

// MARK: - App Delegate with Custom Menu Bar

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    private var statusItem: NSStatusItem?
    private var dropdownWindow: NSPanel?
    private var settingsWindow: NSWindow?
    private var eventMonitor: Any?
    private let settingsDefaultSize = NSSize(width: 560, height: 480)

    // 使用共享的 ViewModel
    private var viewModel: UsageViewModel {
        SharedState.shared.viewModel
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // 设置应用为 accessory 模式 (不显示在 Dock)
        NSApp.setActivationPolicy(.accessory)

        // 设置状态栏
        setupStatusItem()

        // 监听点击外部关闭
        setupEventMonitor()

        // 监听打开设置的通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettings),
            name: .openSettings,
            object: nil
        )
    }

    @objc private func handleOpenSettings() {
        openSettings()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Setup Status Item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            updateStatusButton(button)

            button.action = #selector(toggleDropdown)
            button.target = self

            // 监听 ViewModel 变化更新按钮
            viewModel.objectWillChange.sink { [weak self] _ in
                DispatchQueue.main.async {
                    if let button = self?.statusItem?.button {
                        self?.updateStatusButton(button)
                    }
                }
            }.store(in: &cancellables)
        }
    }

    private var cancellables = Set<AnyCancellable>()

    private func updateStatusButton(_ button: NSStatusBarButton) {
        let icon = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "CCBuddy")
        icon?.isTemplate = true
        button.image = icon

        if viewModel.showInMenuBar != .icon {
            button.title = " " + viewModel.menuBarText
            button.imagePosition = .imageLeading
        } else {
            button.title = ""
            button.imagePosition = .imageOnly
        }
    }

    // MARK: - Event Monitor

    private func setupEventMonitor() {
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self else { return }
            if let window = self.dropdownWindow {
                let location = event.locationInWindow
                if window.frame.contains(location) {
                    return
                }
            }
            self.closeDropdown()
        }
    }

    // MARK: - Toggle Dropdown

    @objc private func toggleDropdown() {
        if dropdownWindow != nil {
            closeDropdown()
        } else {
            openDropdown()
        }
    }

    private func openDropdown() {
        guard let button = statusItem?.button else { return }

        let contentView = PopoverView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: contentView)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = .clear

        let panel = NSPanel(contentViewController: hostingController)
        panel.styleMask = [.nonactivatingPanel, .borderless]
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false

        hostingController.view.layoutSubtreeIfNeeded()
        let fittingSize = hostingController.view.fittingSize
        panel.setContentSize(fittingSize)

        if let buttonWindow = button.window {
            let buttonRect = button.convert(button.bounds, to: nil)
            let screenRect = buttonWindow.convertToScreen(buttonRect)
            positionDropdown(panel, under: screenRect, screen: buttonWindow.screen)
        }

        panel.orderFrontRegardless()
        dropdownWindow = panel
    }

    private func positionDropdown(_ panel: NSWindow, under anchorRect: NSRect, screen: NSScreen?) {
        let size = panel.frame.size
        let screenFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        var x = anchorRect.midX - size.width / 2
        x = max(screenFrame.minX + 8, min(x, screenFrame.maxX - size.width - 8))
        let y = anchorRect.minY - size.height - 4
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
    }

    private func closeDropdown() {
        dropdownWindow?.orderOut(nil)
        dropdownWindow = nil
    }

    // MARK: - Open Settings

    func openSettings() {
        // 关闭下拉
        closeDropdown()

        // 如果设置窗口已存在且有效，直接显示
        if let window = settingsWindow {
            ensureSettingsWindowVisible(window)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        // 创建设置窗口
        let settingsView = SettingsView(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "CCBuddy Settings"
        window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isOpaque = false
        window.backgroundColor = .clear
        window.isReleasedWhenClosed = false  // 防止窗口关闭后被释放
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.setContentSize(settingsDefaultSize)
        centerSettingsWindow(window)
        ensureSettingsWindowVisible(window)

        // 设置窗口代理来处理关闭事件
        window.delegate = self

        settingsWindow = window

        // 显示窗口并激活应用
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func centerSettingsWindow(_ window: NSWindow) {
        let screen = statusItem?.button?.window?.screen ?? NSScreen.main
        let screenFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        var frame = window.frame
        frame.origin.x = screenFrame.midX - frame.width / 2
        frame.origin.y = screenFrame.midY - frame.height / 2
        window.setFrame(frame, display: true)
    }

    private func ensureSettingsWindowVisible(_ window: NSWindow) {
        let screenFrame = window.screen?.visibleFrame ?? statusItem?.button?.window?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        var frame = window.frame
        if frame.maxX < screenFrame.minX || frame.minX > screenFrame.maxX ||
            frame.maxY < screenFrame.minY || frame.minY > screenFrame.maxY {
            centerSettingsWindow(window)
            return
        }
        // Clamp if partially off-screen
        frame.origin.x = max(screenFrame.minX, min(frame.origin.x, screenFrame.maxX - frame.width))
        frame.origin.y = max(screenFrame.minY, min(frame.origin.y, screenFrame.maxY - frame.height))
        window.setFrame(frame, display: true)
    }

    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === settingsWindow {
            settingsWindow = nil
        }
    }
}

import Combine

// MARK: - Notification Names

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}
