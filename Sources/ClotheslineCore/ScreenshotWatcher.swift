import Foundation

/// 监听截图目录，每张新截图只报告一次；启动前已有的文件不算。
public final class ScreenshotWatcher {
    public let directory: URL
    private let onScreenshot: (URL) -> Void
    private var known: Set<String>
    private var retries: [String: Int] = [:]
    private var monitor: DirectoryMonitor?

    /// 截图扩展属性可能比文件晚一点写上，所以没认出来的图片会再看几次。
    static let maxRetries = 3
    static let retryDelay: TimeInterval = 0.5

    public init(directory: URL, onScreenshot: @escaping (URL) -> Void) throws {
        self.directory = directory
        self.onScreenshot = onScreenshot
        known = Self.listing(directory)
        monitor = try DirectoryMonitor(url: directory, debounce: 0.2) { [weak self] in self?.scan() }
    }

    public func scan() {
        let names = Self.listing(directory)
        for name in names.subtracting(known).sorted() {
            let url = directory.appendingPathComponent(name)
            if ScreenshotDetector.isScreenshot(url) {
                known.insert(name)
                retries[name] = nil
                onScreenshot(url)
            } else if !name.hasPrefix("."), ItemKind.classify(url) == .image,
                      retries[name, default: 0] < Self.maxRetries {
                retries[name, default: 0] += 1
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.retryDelay) { [weak self] in self?.scan() }
            } else {
                known.insert(name)
                retries[name] = nil
            }
        }
        known.formIntersection(names) // 搬走的截图不再记着
    }

    private static func listing(_ dir: URL) -> Set<String> {
        Set((try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? [])
    }
}
