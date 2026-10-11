import AppKit
import ClotheslineCore

/// 拍立得、牛皮纸档案袋和彩色木夹的绘制。
enum CardArt {
    struct Output {
        let image: CGImage
        let size: CGSize
        /// 夹子咬住绳子的点（单位坐标），卡片绕它旋转。
        let anchor: CGPoint
    }

    static let padding: CGFloat = 14
    static let clipRoom: CGFloat = 20

    static func render(_ item: ClotheslineItem, side: Side, thumbnail: CGImage?, missing: Bool,
                       scale: CGFloat) -> Output {
        let bodySize = item.kind == .image ? Layout.polaroidSize : Layout.envelopeSize
        let size = CGSize(width: bodySize.width + 2 * padding, height: bodySize.height + 2 * padding + clipRoom)
        let body = CGRect(origin: CGPoint(x: padding, y: padding), size: bodySize)
        let clipX = side == .left ? body.maxX - 13 : body.minX + 13

        let image = draw(size: size, scale: scale) { ctx in
            if item.kind == .image {
                drawPolaroid(item, in: body, side: side, thumbnail: thumbnail, missing: missing, ctx: ctx)
            } else {
                drawEnvelope(item, in: body, missing: missing, ctx: ctx)
            }
            drawClip(at: CGPoint(x: clipX, y: body.maxY), color: clipColors[Int((item.seed >> 8) % 6)], ctx: ctx)
        }
        return Output(image: image, size: size,
                      anchor: CGPoint(x: clipX / size.width, y: (body.maxY + 8) / size.height))
    }

    // MARK: - 拍立得

    private static let paper = NSColor(srgbRed: 0.97, green: 0.95, blue: 0.91, alpha: 1)
    private static let ink = NSColor(srgbRed: 0.22, green: 0.24, blue: 0.34, alpha: 0.9)

    private static func drawPolaroid(_ item: ClotheslineItem, in b: CGRect, side: Side, thumbnail: CGImage?,
                                     missing: Bool, ctx: CGContext) {
        dropShadow(for: b, ctx: ctx)
        ctx.setFillColor(paper.cgColor)
        ctx.fill(b)
        grain(b, ctx: ctx)
        curledCorners(b, ctx: ctx)

        let photoSide = b.width - 16
        let photo = CGRect(x: b.minX + 8, y: b.maxY - 8 - photoSide, width: photoSide, height: photoSide)
        ctx.saveGState()
        ctx.clip(to: photo)
        if let thumbnail, !missing {
            let s = max(photo.width / CGFloat(thumbnail.width), photo.height / CGFloat(thumbnail.height))
            let w = CGFloat(thumbnail.width) * s, h = CGFloat(thumbnail.height) * s
            ctx.interpolationQuality = .high
            ctx.draw(thumbnail, in: CGRect(x: photo.midX - w / 2, y: photo.midY - h / 2, width: w, height: h))
        } else {
            ctx.setFillColor(NSColor(white: missing ? 0.7 : 0.82, alpha: 1).cgColor)
            ctx.fill(photo)
        }
        // 斜向光泽
        let gloss = CGGradient(colorsSpace: nil, colors: [
            CGColor(gray: 1, alpha: 0), CGColor(gray: 1, alpha: 0.26), CGColor(gray: 1, alpha: 0),
        ] as CFArray, locations: [0.32, 0.46, 0.6])!
        ctx.drawLinearGradient(gloss, start: CGPoint(x: photo.minX, y: photo.maxY),
                               end: CGPoint(x: photo.maxX, y: photo.minY), options: [])
        // 内边压印阴影
        ctx.setShadow(offset: CGSize(width: 0, height: -1), blur: 3, color: CGColor(gray: 0, alpha: 0.55))
        ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
        ctx.setLineWidth(4)
        ctx.stroke(photo.insetBy(dx: -2, dy: -2))
        ctx.restoreGState()

        // 白边外侧手写日期
        let text = missing ? "已丢失" : dateFormatter.string(from: takenDate(item))
        handwrite(text, in: CGRect(x: b.minX + 9, y: b.minY + 5, width: b.width - 18, height: 18),
                  size: 12, color: missing ? .systemRed : ink, alignment: side == .left ? .left : .right)
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M.d  HH:mm"
        return f
    }()

    private static func takenDate(_ item: ClotheslineItem) -> Date {
        (try? item.url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? item.addedAt
    }

    // MARK: - 牛皮纸档案袋

    private static let kraft = NSColor(srgbRed: 0.79, green: 0.63, blue: 0.42, alpha: 1)
    private static let kraftDark = NSColor(srgbRed: 0.36, green: 0.25, blue: 0.13, alpha: 1)

    private static func drawEnvelope(_ item: ClotheslineItem, in b: CGRect, missing: Bool, ctx: CGContext) {
        let base = missing ? NSColor(white: 0.72, alpha: 1) : kraft
        dropShadow(for: b, ctx: ctx)
        ctx.setFillColor(base.cgColor)
        ctx.fill(b)

        // 纸浆里的深色纤维点
        var rng = SeededRandom(state: item.seed)
        ctx.setLineWidth(0.6)
        for _ in 0..<70 {
            let p = CGPoint(x: .random(in: b.minX...b.maxX, using: &rng), y: .random(in: b.minY...b.maxY, using: &rng))
            let a = CGFloat.random(in: 0...(.pi), using: &rng), l = CGFloat.random(in: 0.8...3, using: &rng)
            ctx.setStrokeColor(kraftDark.withAlphaComponent(.random(in: 0.2...0.5, using: &rng)).cgColor)
            ctx.move(to: p)
            ctx.addLine(to: CGPoint(x: p.x + cos(a) * l, y: p.y + sin(a) * l))
            ctx.strokePath()
        }
        grain(b, ctx: ctx)

        // 封口盖
        let flap = CGMutablePath()
        flap.addLines(between: [
            CGPoint(x: b.minX, y: b.maxY), CGPoint(x: b.maxX, y: b.maxY), CGPoint(x: b.maxX, y: b.maxY - 16),
            CGPoint(x: b.midX + 12, y: b.maxY - 32), CGPoint(x: b.midX - 12, y: b.maxY - 32),
            CGPoint(x: b.minX, y: b.maxY - 16),
        ])
        flap.closeSubpath()
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -1.5), blur: 2, color: CGColor(gray: 0, alpha: 0.3))
        ctx.addPath(flap)
        ctx.setFillColor(base.blended(withFraction: 0.08, of: .black)!.cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        // 两颗纽扣绕白棉线
        let top = CGPoint(x: b.midX, y: b.maxY - 25), low = CGPoint(x: b.midX, y: b.maxY - 48)
        for p in [top, low] {
            let r = CGRect(x: p.x - 4.5, y: p.y - 4.5, width: 9, height: 9)
            ctx.setFillColor(base.blended(withFraction: 0.35, of: .black)!.cgColor)
            ctx.fillEllipse(in: r)
            ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.25))
            ctx.setLineWidth(0.8)
            ctx.strokeEllipse(in: r.insetBy(dx: 1, dy: 1))
        }
        let thread = CGMutablePath()
        thread.addEllipse(in: CGRect(x: top.x - 5.5, y: top.y - 5.5, width: 11, height: 11))
        thread.move(to: CGPoint(x: top.x - 4, y: top.y - 3))
        thread.addLine(to: CGPoint(x: low.x + 4, y: low.y + 3))
        thread.move(to: CGPoint(x: top.x + 4, y: top.y - 3))
        thread.addLine(to: CGPoint(x: low.x - 4, y: low.y + 3))
        thread.addEllipse(in: CGRect(x: low.x - 5.5, y: low.y - 5.5, width: 11, height: 11))
        thread.move(to: CGPoint(x: low.x + 4, y: low.y - 4))
        thread.addQuadCurve(to: CGPoint(x: low.x + 10, y: low.y - 16), control: CGPoint(x: low.x + 12, y: low.y - 6))
        ctx.addPath(thread)
        ctx.setStrokeColor(CGColor(gray: 0.98, alpha: 0.95))
        ctx.setLineWidth(0.9)
        ctx.strokePath()

        // 类型印章 / 丢失印章
        let badge = FileBadge.badge(for: item.url)
        let tilt = CGFloat(Int(item.seed % 9) - 10) * .pi / 180 // -10°…-2°
        let center = CGPoint(x: b.midX, y: b.minY + 58)
        if missing {
            stamp("已丢失", color: .systemRed, center: center, angle: -tilt, ctx: ctx)
        } else {
            stamp(badge.text, color: tint(badge.tint), center: center, angle: tilt, ctx: ctx)
        }

        handwrite(item.url.lastPathComponent, in: CGRect(x: b.minX + 8, y: b.minY + 6, width: b.width - 16, height: 17),
                  size: 11, color: kraftDark, alignment: .center)
    }

    private static func tint(_ tint: FileBadge.Tint) -> NSColor {
        switch tint {
        case .red: return NSColor(srgbRed: 0.80, green: 0.15, blue: 0.13, alpha: 1)
        case .blue: return NSColor(srgbRed: 0.15, green: 0.35, blue: 0.75, alpha: 1)
        case .green: return NSColor(srgbRed: 0.13, green: 0.52, blue: 0.27, alpha: 1)
        case .orange: return NSColor(srgbRed: 0.90, green: 0.45, blue: 0.08, alpha: 1)
        case .purple: return NSColor(srgbRed: 0.50, green: 0.25, blue: 0.70, alpha: 1)
        case .pink: return NSColor(srgbRed: 0.88, green: 0.30, blue: 0.55, alpha: 1)
        case .indigo: return NSColor(srgbRed: 0.28, green: 0.25, blue: 0.68, alpha: 1)
        case .brown: return NSColor(srgbRed: 0.50, green: 0.32, blue: 0.16, alpha: 1)
        case .teal: return NSColor(srgbRed: 0.08, green: 0.52, blue: 0.55, alpha: 1)
        case .darkBrown: return NSColor(srgbRed: 0.32, green: 0.20, blue: 0.10, alpha: 1)
        }
    }

    private static func stamp(_ text: String, color: NSColor, center: CGPoint, angle: CGFloat, ctx: CGContext) {
        var fontSize: CGFloat = 18
        var attrs: [NSAttributedString.Key: Any] = [:]
        var textSize = CGSize.zero
        repeat {
            let font = NSFont(name: "AmericanTypewriter-Bold", size: fontSize) ?? .boldSystemFont(ofSize: fontSize)
            attrs = [.font: font, .foregroundColor: color.withAlphaComponent(0.85)]
            textSize = (text as NSString).size(withAttributes: attrs)
            fontSize -= 1
        } while textSize.width > 62 && fontSize > 8

        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: angle)
        ctx.setBlendMode(.multiply)
        let box = CGRect(x: -textSize.width / 2 - 7, y: -textSize.height / 2 - 3,
                         width: textSize.width + 14, height: textSize.height + 6)
        color.withAlphaComponent(0.8).setStroke()
        let outer = NSBezierPath(roundedRect: box, xRadius: 3, yRadius: 3)
        outer.lineWidth = 1.8
        outer.stroke()
        let inner = NSBezierPath(roundedRect: box.insetBy(dx: 2.5, dy: 2.5), xRadius: 2, yRadius: 2)
        inner.lineWidth = 0.7
        inner.stroke()
        (text as NSString).draw(at: CGPoint(x: -textSize.width / 2, y: -textSize.height / 2), withAttributes: attrs)
        ctx.restoreGState()
    }

    // MARK: - 彩漆木夹

    private static let clipColors: [NSColor] = [
        NSColor(srgbRed: 0.98, green: 0.45, blue: 0.40, alpha: 1), // 珊瑚红
        NSColor(srgbRed: 0.49, green: 0.84, blue: 0.70, alpha: 1), // 薄荷绿
        NSColor(srgbRed: 0.88, green: 0.70, blue: 0.15, alpha: 1), // 芥末黄
        NSColor(srgbRed: 0.43, green: 0.73, blue: 0.92, alpha: 1), // 天蓝
        NSColor(srgbRed: 0.96, green: 0.62, blue: 0.76, alpha: 1), // 粉
        NSColor(srgbRed: 0.70, green: 0.62, blue: 0.86, alpha: 1), // 淡紫
    ]

    /// `p` 是卡片上沿与夹子中线的交点。
    private static func drawClip(at p: CGPoint, color: NSColor, ctx: CGContext) {
        let clip = CGRect(x: p.x - 5, y: p.y - 13, width: 10, height: 30)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0.5, height: -1.5), blur: 2, color: CGColor(gray: 0, alpha: 0.4))
        ctx.addPath(CGPath(roundedRect: clip, cornerWidth: 2, cornerHeight: 2, transform: nil))
        ctx.setFillColor(color.cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.setLineWidth(0.7)
        ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.25))
        ctx.strokeLineSegments(between: [CGPoint(x: clip.midX, y: clip.minY + 1), CGPoint(x: clip.midX, y: clip.maxY - 1)])
        ctx.setLineWidth(1.2)
        ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.5))
        ctx.strokeLineSegments(between: [CGPoint(x: clip.minX + 2, y: clip.minY + 2), CGPoint(x: clip.minX + 2, y: clip.maxY - 2)])

        // 金属弹簧
        let spring = CGRect(x: clip.minX - 1.5, y: p.y + 2, width: clip.width + 3, height: 5)
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: spring, cornerWidth: 1.5, cornerHeight: 1.5, transform: nil))
        ctx.clip()
        let metal = CGGradient(colorsSpace: nil, colors: [
            CGColor(srgbRed: 0.55, green: 0.58, blue: 0.62, alpha: 1),
            CGColor(srgbRed: 0.90, green: 0.92, blue: 0.94, alpha: 1),
            CGColor(srgbRed: 0.50, green: 0.53, blue: 0.57, alpha: 1),
        ] as CFArray, locations: [0, 0.45, 1])!
        ctx.drawLinearGradient(metal, start: CGPoint(x: 0, y: spring.maxY), end: CGPoint(x: 0, y: spring.minY), options: [])
        ctx.setStrokeColor(CGColor(gray: 0.2, alpha: 0.45))
        ctx.setLineWidth(0.6)
        for x in stride(from: spring.minX + 2.5, to: spring.maxX - 1, by: 2.5) {
            ctx.strokeLineSegments(between: [CGPoint(x: x, y: spring.minY), CGPoint(x: x + 0.8, y: spring.maxY)])
        }
        ctx.restoreGState()
    }

    // MARK: - 共用

    private static func dropShadow(for b: CGRect, ctx: CGContext) {
        // 底部两角往下拉一点的阴影形状：看起来像两角微微翘起
        let shape = CGMutablePath()
        shape.move(to: CGPoint(x: b.minX, y: b.maxY))
        shape.addLine(to: CGPoint(x: b.maxX, y: b.maxY))
        shape.addLine(to: CGPoint(x: b.maxX + 1, y: b.minY - 3))
        shape.addQuadCurve(to: CGPoint(x: b.minX - 1, y: b.minY - 3), control: CGPoint(x: b.midX, y: b.minY + 5))
        shape.closeSubpath()
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 5, color: CGColor(gray: 0, alpha: 0.45))
        ctx.addPath(shape)
        ctx.setFillColor(CGColor(gray: 0, alpha: 0.2))
        ctx.fillPath()
        ctx.restoreGState()
    }

    private static func curledCorners(_ b: CGRect, ctx: CGContext) {
        let shade = CGGradient(colorsSpace: nil, colors: [CGColor(gray: 0, alpha: 0.12), CGColor(gray: 0, alpha: 0)] as CFArray,
                               locations: [0, 1])!
        for corner in [CGPoint(x: b.minX, y: b.minY), CGPoint(x: b.maxX, y: b.minY)] {
            ctx.drawRadialGradient(shade, startCenter: corner, startRadius: 0, endCenter: corner, endRadius: 14, options: [])
        }
    }

    private static func grain(_ rect: CGRect, ctx: CGContext) {
        ctx.saveGState()
        ctx.clip(to: rect)
        ctx.setBlendMode(.multiply)
        ctx.setAlpha(0.22)
        ctx.draw(noise, in: CGRect(x: rect.minX, y: rect.minY, width: 64, height: 64), byTiling: true)
        ctx.restoreGState()
    }

    private static let noise: CGImage = {
        let size = 64
        var rng = SeededRandom(state: 42)
        var pixels = (0..<size * size).map { _ in UInt8.random(in: 200...255, using: &rng) }
        let ctx = CGContext(data: &pixels, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size,
                            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        return ctx.makeImage()!
    }()

    private static func handwrite(_ text: String, in rect: CGRect, size: CGFloat, color: NSColor,
                                  alignment: NSTextAlignment) {
        let style = NSMutableParagraphStyle()
        style.alignment = alignment
        style.lineBreakMode = .byTruncatingMiddle
        let font = NSFont(name: "Noteworthy-Light", size: size) ?? .systemFont(ofSize: size)
        (text as NSString).draw(in: rect, withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
    }

    private static func draw(size: CGSize, scale: CGFloat, _ body: (CGContext) -> Void) -> CGImage {
        let ctx = CGContext(data: nil, width: Int(size.width * scale), height: Int(size.height * scale),
                            bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.scaleBy(x: scale, y: scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        body(ctx)
        NSGraphicsContext.restoreGraphicsState()
        return ctx.makeImage()!
    }
}
