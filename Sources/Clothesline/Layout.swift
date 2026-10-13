import AppKit

enum Layout {
    /// 面板贴着屏幕右侧，宽度固定，高度与可用区域一致。
    static let panelWidth: CGFloat = 380
    /// 绳子离屏幕右边缘的距离。
    static let ropeX: CGFloat = panelWidth - 140

    static let stubLength: CGFloat = 34
    static let minRopeLength: CGFloat = 200
    /// 绳子最长时，下面留给最后一张卡片的空间。
    static let bottomRoom: CGFloat = 170
    static let firstClip: CGFloat = 54
    static let ropeTail: CGFloat = 70

    /// 一张卡片的夹子到下一张夹子的距离：卡片越长，下一张离得越远。
    static func clipGap(below bodyHeight: CGFloat) -> CGFloat { bodyHeight / 2 + 43 }

    /// 拍立得里的照片按原图比例完整显示：面积大致固定，最宽 120（右侧不出屏）、最长 220（约 1/4 屏高）。
    static let photoArea: CGFloat = 100 * 100
    static let maxPhotoSize = CGSize(width: 120, height: 220)
    static let minPolaroidWidth: CGFloat = 84
    /// 长度超过宽度这么多倍的照片，日期改写在加宽的右边白边上。
    static let tallPhotoRatio: CGFloat = 2.1

    static let envelopeSize = CGSize(width: 112, height: 140) // 文件夹：牛皮纸档案袋
    static let pocketSize = CGSize(width: 96, height: 120)    // 单个文件：透明按扣文件袋

    /// 主显示器（带菜单栏的那块）右侧，菜单栏正下方。
    static func panelFrame(on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        return NSRect(x: screen.frame.maxX - panelWidth, y: visible.minY,
                      width: panelWidth, height: visible.maxY - visible.minY)
    }
}
