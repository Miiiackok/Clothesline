import AppKit

/// 黄麻细绳：深色描边 + 本色 + 斜向捻纹 + 高光，末端一个绳结和几缕纤维。
final class RopeLayer: CALayer {
    var geometry = RopeGeometry(top: .zero, length: 0, sway: 0) {
        didSet { setNeedsDisplay() }
    }

    static let jute = CGColor(srgbRed: 0.75, green: 0.60, blue: 0.38, alpha: 1)
    static let juteDark = CGColor(srgbRed: 0.45, green: 0.33, blue: 0.18, alpha: 1)
    static let juteLight = CGColor(srgbRed: 0.93, green: 0.82, blue: 0.62, alpha: 0.6)

    override func draw(in ctx: CGContext) {
        let g = geometry
        guard g.length > 0 else { return }
        let points = stride(from: 0, through: g.length, by: 3).map(g.point(at:)) + [g.end]
        let path = CGMutablePath()
        path.addLines(between: points)

        ctx.setLineCap(.round)
        ctx.setShadow(offset: CGSize(width: 1, height: -1), blur: 2, color: CGColor(gray: 0, alpha: 0.3))
        stroke(path, Self.juteDark, 4, in: ctx)
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        stroke(path, Self.jute, 3, in: ctx)

        // 捻纹
        let twist = CGMutablePath()
        for p in points.dropFirst() {
            twist.move(to: CGPoint(x: p.x - 1.5, y: p.y + 1.1))
            twist.addLine(to: CGPoint(x: p.x + 1.5, y: p.y - 1.1))
        }
        stroke(twist, Self.juteDark.copy(alpha: 0.55)!, 0.8, in: ctx)
        stroke(path.copy(using: [CGAffineTransform(translationX: -0.7, y: 0)])!, Self.juteLight, 0.6, in: ctx)

        drawKnot(at: g.end, in: ctx)
    }

    private func drawKnot(at end: CGPoint, in ctx: CGContext) {
        let fibers = CGMutablePath()
        for (degrees, len) in [(-38.0, 7.0), (-16, 10), (2, 11), (20, 9), (40, 6)] {
            let a = CGFloat(degrees) * .pi / 180, l = CGFloat(len)
            fibers.move(to: end)
            fibers.addQuadCurve(to: CGPoint(x: end.x + sin(a) * l, y: end.y - cos(a) * l),
                                control: CGPoint(x: end.x + sin(a) * l * 0.3, y: end.y - l * 0.7))
        }
        stroke(fibers, Self.jute, 0.9, in: ctx)
        let knot = CGRect(x: end.x - 3.5, y: end.y - 3, width: 7, height: 6.5)
        ctx.setFillColor(Self.jute)
        ctx.fillEllipse(in: knot)
        ctx.setStrokeColor(Self.juteDark)
        ctx.setLineWidth(0.8)
        ctx.strokeEllipse(in: knot)
    }

    private func stroke(_ path: CGPath, _ color: CGColor, _ width: CGFloat, in ctx: CGContext) {
        ctx.addPath(path)
        ctx.setStrokeColor(color)
        ctx.setLineWidth(width)
        ctx.strokePath()
    }
}
