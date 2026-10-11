import AppKit
import ClotheslineCore

enum Side { case left, right }

/// 绳子上的一张卡片。画好的图放在 contents 里，位置和角度每帧由 RopeView 更新。
final class CardLayer: CALayer {
    struct Flight {
        let from: CGPoint
        let start: CFTimeInterval
        static let duration: CFTimeInterval = 0.9
        static let startScale: CGFloat = 1.4
    }

    struct RenderState: Equatable {
        var side: Side
        var missing: Bool
        var thumbnail: CGImage?
    }

    var item: ClotheslineItem
    var side: Side = .left
    /// 夹子在绳子上的目标位置（距顶端），以及平滑追随它的当前位置。
    var targetDistance: CGFloat = 0
    var distance: CGFloat = 0
    var swing = Spring(value: 0, stiffness: 90, damping: 3.2, epsilon: 0.002)
    var flight: Flight?
    var rendered: RenderState?

    init(item: ClotheslineItem) {
        self.item = item
        super.init()
        isHidden = true
    }

    override init(layer: Any) {
        let other = layer as! CardLayer
        item = other.item
        super.init(layer: layer)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    /// 静止时的倾斜：16°–22°，往外侧斜。
    var restAngle: CGFloat {
        let degrees = 16 + CGFloat(item.seed % 7)
        return (side == .left ? degrees : -degrees) * .pi / 180
    }

    func setPose(position: CGPoint, angle: CGFloat, scale: CGFloat = 1) {
        self.position = position
        transform = CATransform3DScale(CATransform3DMakeRotation(angle, 0, 0, 1), scale, scale, 1)
    }

    func apply(_ art: CardArt.Output, scale: CGFloat) {
        contents = art.image
        contentsScale = scale
        bounds = CGRect(origin: .zero, size: art.size)
        anchorPoint = art.anchor
    }
}

extension ClotheslineItem {
    /// 每张卡片固定的随机种子（倾斜角、夹子颜色、纤维点）。
    var seed: UInt64 { withUnsafeBytes(of: id.uuid) { $0.load(as: UInt64.self) } }
}
