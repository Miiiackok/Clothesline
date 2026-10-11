import AppKit
import ImageIO

/// 照片缩略图缓存：文件改过（「预览」标注保存后）会重新生成。
final class Thumbnails {
    private var cache: [String: (modified: Date?, image: CGImage)] = [:]
    private var inFlight: Set<String> = []
    private let queue = DispatchQueue(label: "Clothesline.thumbnails", qos: .userInitiated)

    /// 有新鲜缓存直接返回；否则后台生成，好了回调 `ready`，期间先返回旧图（如果有）。
    func thumbnail(for url: URL, ready: @escaping () -> Void) -> CGImage? {
        let modified = Self.modificationDate(url)
        if let hit = cache[url.path], hit.modified == modified { return hit.image }
        if inFlight.insert(url.path).inserted {
            queue.async {
                let image = Self.make(url)
                DispatchQueue.main.async {
                    self.inFlight.remove(url.path)
                    guard let image else { return }
                    self.cache[url.path] = (modified, image)
                    ready()
                }
            }
        }
        return cache[url.path]?.image
    }

    /// 同步生成（截图飞入前要立刻有图）。
    func load(_ url: URL) {
        if let image = Self.make(url) { cache[url.path] = (Self.modificationDate(url), image) }
    }

    private static func modificationDate(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private static func make(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 360,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
