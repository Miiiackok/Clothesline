import AppKit
import ClotheslineCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// `CLOTHESLINE_ROOT` 可以换一个数据目录（调试用，不碰真实数据）。
    private let store = ClotheslineStore(
        root: ProcessInfo.processInfo.environment["CLOTHESLINE_ROOT"].map { URL(fileURLWithPath: $0) }
            ?? ClotheslineStore.defaultRoot)
    private let defaults = UserDefaults.standard
    private var rope: RopeWindowController!
    private var menuBar: MenuBarController!
    private var screenshots: ScreenshotWatcher?
    private var imagesMonitor: DirectoryMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        store.cleanUpRetired()
        rope = RopeWindowController(store: store)
        rope.keepOpen = defaults.bool(forKey: "keepRopeOpen")
        store.onChange = { [weak self] in self?.rope.ropeView.reload() }

        imagesMonitor = try? DirectoryMonitor(url: store.imagesDir) { [weak self] in
            self?.rope.ropeView.refreshThumbnails()
        }
        screenshots = try? ScreenshotWatcher(directory: ScreenshotDetector.screenshotDirectory()) { [weak self] url in
            self?.clipScreenshot(url)
        }

        menuBar = MenuBarController(toggles: [
            .init(title: "暂停自动夹截图",
                  get: { [defaults] in defaults.bool(forKey: "pauseScreenshots") },
                  set: { [defaults] in defaults.set($0, forKey: "pauseScreenshots") }),
            .init(title: "保持绳子展开",
                  get: { [defaults] in defaults.bool(forKey: "keepRopeOpen") },
                  set: { [weak self] in
                      self?.defaults.set($0, forKey: "keepRopeOpen")
                      self?.rope.keepOpen = $0
                  }),
            .init(title: "开机自动启动",
                  get: { SMAppService.mainApp.status == .enabled },
                  set: { Self.setLaunchAtLogin($0) }),
        ])
    }

    /// 暂停期间的截图留在桌面，不会补夹。
    private func clipScreenshot(_ url: URL) {
        guard !defaults.bool(forKey: "pauseScreenshots"), let item = try? store.add(url) else { return }
        rope.showScreenshot(item.id)
    }

    private static func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "没能设置开机自动启动"
            alert.informativeText = "需要先打包成 .app 才能生效。\n\(error.localizedDescription)"
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        }
    }
}
