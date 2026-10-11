import Foundation
import UniformTypeIdentifiers

public enum ItemKind: String, Codable {
    /// 照片：已搬进应用自己的 Images 文件夹。
    case image
    /// 文件：只记住原位置。
    case file

    /// 普通图片按照片处理，其余（含文件夹、包）按文件引用。
    public static func classify(_ url: URL) -> ItemKind {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        if values?.isDirectory == true { return .file }
        guard let type = UTType(filenameExtension: url.pathExtension) else { return .file }
        return type.conforms(to: .image) ? .image : .file
    }
}

public struct ClotheslineItem: Codable, Identifiable, Equatable {
    public let id: UUID
    public let kind: ItemKind
    public let path: String
    public let addedAt: Date

    public init(id: UUID = UUID(), kind: ItemKind, path: String, addedAt: Date) {
        self.id = id
        self.kind = kind
        self.path = path
        self.addedAt = addedAt
    }

    public var url: URL { URL(fileURLWithPath: path) }
    public var isMissing: Bool { !FileManager.default.fileExists(atPath: path) }
}
