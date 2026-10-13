import Foundation

/// 档案袋上的类型印章。
public struct FileBadge: Equatable {
    public enum Tint: Equatable { case red, blue, green, orange, purple, pink, indigo, brown, teal, darkBrown }

    public let text: String
    public let tint: Tint

    static let groups: [(Tint, Set<String>)] = [
        (.red, ["pdf"]),
        (.blue, ["doc", "docx", "pages", "rtf"]),
        (.green, ["xls", "xlsx", "numbers", "csv"]),
        (.orange, ["ppt", "pptx", "key"]),
        (.purple, ["zip", "rar", "7z", "tar", "gz", "tgz", "bz2", "xz", "dmg", "iso", "pkg"]),
        (.pink, ["mp3", "wav", "aac", "m4a", "flac", "aiff", "aif", "ogg"]),
        (.indigo, ["mov", "mp4", "m4v", "avi", "mkv", "webm"]),
        (.brown, ["txt", "md"]),
    ]
    /// 同组里写法不同的扩展名合并成一个印章。
    static let aliases = ["docx": "DOC", "xlsx": "XLS", "pptx": "PPT", "aif": "AIFF"]

    public static func badge(for url: URL) -> FileBadge {
        let ext = url.pathExtension.lowercased()
        if let tint = groups.first(where: { $0.1.contains(ext) })?.0 {
            return FileBadge(text: aliases[ext] ?? ext.uppercased(), tint: tint)
        }
        if isFolder(url) { return FileBadge(text: "文件夹", tint: .teal) }
        return FileBadge(text: ext.isEmpty ? "FILE" : String(ext.uppercased().prefix(5)), tint: .darkBrown)
    }

    /// 真正的文件夹；.app、.pages 这类包算单个文件。
    public static func isFolder(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey, .isPackageKey])
        return values?.isDirectory == true && values?.isPackage != true
    }
}
