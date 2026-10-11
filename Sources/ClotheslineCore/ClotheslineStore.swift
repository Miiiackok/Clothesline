import Foundation

/// 绳子上的条目列表（最新在前）及其持久化。
/// 照片搬进 `Images/`，文件只记路径；取下的照片先记一笔，24 小时后再删。
public final class ClotheslineStore {
    public static let retireDelay: TimeInterval = 24 * 3600

    public static var defaultRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Clothesline", isDirectory: true)
    }

    struct Retired: Codable {
        let path: String
        let retiredAt: Date
    }

    public let root: URL
    public var imagesDir: URL { root.appendingPathComponent("Images", isDirectory: true) }
    public private(set) var items: [ClotheslineItem] = []
    public var onChange: (() -> Void)?

    private var retired: [Retired] = []
    private let now: () -> Date
    private let fm = FileManager.default
    private var indexURL: URL { root.appendingPathComponent("index.json") }
    private var retiredURL: URL { root.appendingPathComponent("retired.json") }

    public init(root: URL = ClotheslineStore.defaultRoot, now: @escaping () -> Date = Date.init) {
        self.root = root
        self.now = now
        try? fm.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        items = Self.load(indexURL) ?? []
        retired = Self.load(retiredURL) ?? []
    }

    // MARK: - 挂上 / 取下

    /// 挂到最上面。照片搬进来，文件只引用；已挂着的同一路径会被提到最上面。
    @discardableResult
    public func add(_ url: URL) throws -> ClotheslineItem {
        let kind = ItemKind.classify(url)
        let path = kind == .image ? try moveIn(url).path : url.standardizedFileURL.path
        items.removeAll { $0.path == path }
        retired.removeAll { $0.path == path }
        let item = ClotheslineItem(kind: kind, path: path, addedAt: now())
        items.insert(item, at: 0)
        changed()
        return item
    }

    /// 取下。`trashing` 为 true 时照片进废纸篓（「摘掉」）；否则照片原地保留 24 小时（拖出去给别的应用）。
    /// 文件只是从绳子上去掉，原文件不动。
    public func remove(_ id: UUID, trashing: Bool = false) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items.remove(at: index)
        if item.kind == .image {
            if trashing {
                try? fm.trashItem(at: item.url, resultingItemURL: nil)
            } else {
                retired.append(Retired(path: item.path, retiredAt: now()))
            }
        }
        changed()
    }

    /// 删掉取下超过 24 小时的照片，绝不碰仍挂在绳子上的路径。
    public func cleanUpRetired() {
        let live = Set(items.map(\.path))
        let cutoff = now().addingTimeInterval(-Self.retireDelay)
        retired.removeAll { entry in
            if live.contains(entry.path) { return true }
            guard entry.retiredAt <= cutoff else { return false }
            try? fm.removeItem(atPath: entry.path)
            return true
        }
        save()
    }

    // MARK: - 私有

    private func moveIn(_ url: URL) throws -> URL {
        if url.deletingLastPathComponent().resolvingSymlinksInPath() == imagesDir.resolvingSymlinksInPath() {
            return url
        }
        let dest = uniqueDestination(for: url.lastPathComponent)
        do {
            try fm.moveItem(at: url, to: dest)
        } catch {
            try fm.copyItem(at: url, to: dest) // 源只读时退而求其次
        }
        return dest
    }

    private func uniqueDestination(for name: String) -> URL {
        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var candidate = imagesDir.appendingPathComponent(name)
        var n = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = imagesDir.appendingPathComponent(ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)")
            n += 1
        }
        return candidate
    }

    private func changed() {
        save()
        onChange?()
    }

    private func save() {
        Self.write(items, to: indexURL)
        Self.write(retired, to: retiredURL)
    }

    private static func load<T: Decodable>(_ url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(T.self, from: data)
    }

    private static func write<T: Encodable>(_ value: T, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? encoder.encode(value).write(to: url, options: .atomic)
    }
}
