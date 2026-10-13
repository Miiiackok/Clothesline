import AppKit
import ClotheslineCore
import ImageIO
import QuickLookThumbnailing

/// 缩略图缓存（照片，以及透明文件袋里看到的文件第一页）。文件改过（比如「预览」标注保存后）会重新生成。
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

    /// 同步生成照片缩略图（截图飞入前要立刻有图）。
    func load(_ url: URL) {
        if let image = Self.make(url) { cache[url.path] = (Self.modificationDate(url), image) }
    }

    private static func modificationDate(_ url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private static func make(_ url: URL) -> CGImage? {
        ItemKind.classify(url) == .image ? imageThumbnail(url) : fileThumbnail(url)
    }

    private static func imageThumbnail(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 600, // 长截图最长 220pt，2x 屏要 440px
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// 文档内容缩略图（PDF/Word 第一页、表格……）；没有内容可看的（压缩包等）返回 nil。
    /// 只在后台队列调用，所以可以同步等待。
    private static func fileThumbnail(_ url: URL) -> CGImage? {
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 160, height: 200),
                                                   scale: 2, representationTypes: .thumbnail)
        var image: CGImage?
        let done = DispatchSemaphore(value: 0)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            image = representation?.cgImage
            done.signal()
        }
        _ = done.wait(timeout: .now() + 5)
        return image
    }
}
