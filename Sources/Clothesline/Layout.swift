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
    static let clipSpacing: CGFloat = 112
    static let ropeTail: CGFloat = 70

    static let polaroidSize = CGSize(width: 116, height: 138)
    static let envelopeSize = CGSize(width: 112, height: 140)

    /// 主显示器（带菜单栏的那块）右侧，菜单栏正下方。
    static func panelFrame(on screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        return NSRect(x: screen.frame.maxX - panelWidth, y: visible.minY,
                      width: panelWidth, height: visible.maxY - visible.minY)
    }
}
