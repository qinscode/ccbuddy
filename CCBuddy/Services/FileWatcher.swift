import Foundation

class FileWatcher {
    private var source: DispatchSourceFileSystemObject?
    private var fileDescriptor: Int32 = -1
    private var isWatching = false

    var onChange: (() -> Void)?

    deinit {
        stopWatching()
    }

    // MARK: - 开始监听

    func startWatching(directory: URL) {
        guard !isWatching else { return }

        fileDescriptor = open(directory.path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("Failed to open directory for watching: \(directory.path)")
            return
        }

        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .extend, .rename, .delete],
            queue: .main
        )

        source?.setEventHandler { [weak self] in
            self?.onChange?()
        }

        source?.setCancelHandler { [weak self] in
            if let fd = self?.fileDescriptor, fd >= 0 {
                close(fd)
            }
            self?.fileDescriptor = -1
        }

        source?.resume()
        isWatching = true

        print("Started watching: \(directory.path)")
    }

    // MARK: - 停止监听

    func stopWatching() {
        guard isWatching else { return }

        source?.cancel()
        source = nil
        isWatching = false

        print("Stopped watching")
    }

    // MARK: - 重启监听

    func restartWatching(directory: URL) {
        stopWatching()
        startWatching(directory: directory)
    }
}

// MARK: - 多目录监听器

class MultiDirectoryWatcher {
    private var watchers: [FileWatcher] = []
    private var debounceTimer: Timer?
    private let debounceInterval: TimeInterval = 0.5

    var onChange: (() -> Void)?

    func watch(directories: [URL]) {
        stopAll()

        for directory in directories {
            let watcher = FileWatcher()
            watcher.onChange = { [weak self] in
                self?.handleChange()
            }
            watcher.startWatching(directory: directory)
            watchers.append(watcher)
        }
    }

    func stopAll() {
        watchers.forEach { $0.stopWatching() }
        watchers.removeAll()
        debounceTimer?.invalidate()
    }

    private func handleChange() {
        // 防抖处理
        debounceTimer?.invalidate()
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
            print("📂 [\(timestamp)] File change detected - triggering refresh")
            self?.onChange?()
        }
    }

    deinit {
        stopAll()
    }
}
