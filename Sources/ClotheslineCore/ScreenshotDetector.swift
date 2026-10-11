import Foundation

public enum ScreenshotDetector {
    static let namePrefixes = ["Screenshot", "Screen Shot", "截屏", "屏幕快照"]
    static let screenCaptureAttribute = "com.apple.metadata:kMDItemIsScreenCapture"

    /// 可见的图片文件，且带截图扩展属性或截图文件名前缀。
    public static func isScreenshot(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        guard !name.hasPrefix("."), ItemKind.classify(url) == .image else { return false }
        return getxattr(url.path, screenCaptureAttribute, nil, 0, 0, 0) > 0
            || namePrefixes.contains { name.hasPrefix($0) }
    }

    /// 系统截图保存位置（`com.apple.screencapture` 的 `location`），没设置或不存在时是桌面。
    public static func screenshotDirectory(
        defaults: UserDefaults? = UserDefaults(suiteName: "com.apple.screencapture")
    ) -> URL {
        if let location = defaults?.string(forKey: "location"), !location.isEmpty {
            let url = URL(fileURLWithPath: (location as NSString).expandingTildeInPath, isDirectory: true)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                return url
            }
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
    }
}
