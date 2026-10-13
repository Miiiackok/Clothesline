import AppKit
import ClotheslineCore

/// 拍立得（照片）、牛皮纸档案袋（文件夹）、透明按扣文件袋（单个文件）和彩色木夹的绘制。
enum CardArt {
    struct Output {
        let image: CGImage
        let size: CGSize
        /// 夹子咬住绳子的点（单位坐标），卡片绕它旋转。
        let anchor: CGPoint
        let bodyHeight: CGFloat
    }

    enum Style {
        case polaroid(photo: CGSize)
        case envelope
        case pocket

        init(_ item: ClotheslineItem, thumbnail: CGImage?, missing: Bool) {
            if item.kind == .image {
                let aspect = thumbnail.map { CGFloat($0.width) / CGFloat($0.height) } ?? 1
                self = .polaroid(photo: Self.photoSize(aspect: aspect))
            } else if FileBadge.isFolder(item.url) || (missing && item.url.pathExtension.isEmpty) {
                self = .envelope // 文件夹丢了就判断不了，没扩展名的按文件夹算
            } else {
                self = .pocket
            }
        }

        /// 照片按原图比例：面积大致固定，超出最大宽高就整体等比缩小，保证完整显示。
        static func photoSize(aspect: CGFloat) -> CGSize {
            let w = (Layout.photoArea * aspect).squareRoot(), h = (Layout.photoArea / aspect).squareRoot()
            let fit = min(1, Layout.maxPhotoSize.width / w, Layout.maxPhotoSize.height / h)
            return CGSize(width: w * fit, height: h * fit)
        }

        static func isTall(_ photo: CGSize) -> Bool { photo.height > Layout.tallPhotoRatio * photo.width }

        var bodySize: CGSize {
            switch self {
            case .polaroid(let photo) where Self.isTall(photo):
                return CGSize(width: photo.width + 34, height: photo.height + 16) // 右边白边加宽写日期
            case .polaroid(let photo):
                return CGSize(width: max(photo.width + 16, Layout.minPolaroidWidth), height: photo.height + 38)
            case .envelope: return Layout.envelopeSize
            case .pocket: return Layout.pocketSize
            }
        }
    }

    static let padding: CGFloat = 14
    static let clipRoom: CGFloat = 20

    static func render(_ item: ClotheslineItem, side: Side, thumbnail: CGImage?, missing: Bool,
                       scale: CGFloat) -> Output {
        let style = Style(item, thumbnail: thumbnail, missing: missing)
        let bodySize = style.bodySize
        let size = CGSize(width: bodySize.width + 2 * padding, height: bodySize.height + 2 * padding + clipRoom)
        let body = CGRect(origin: CGPoint(x: padding, y: padding), size: bodySize)
        let clipX = side == .left ? body.maxX - 13 : body.minX + 13

        let image = draw(size: size, scale: scale) { ctx in
            switch style {
            case .polaroid(let photo):
                drawPolaroid(item, in: body, photo: photo, side: side, thumbnail: thumbnail, missing: missing, ctx: ctx)
            case .envelope:
                drawEnvelope(item, in: body, missing: missing, ctx: ctx)
            case .pocket:
                drawPocket(item, in: body, thumbnail: thumbnail, missing: missing, ctx: ctx)
            }
            drawClip(at: CGPoint(x: clipX, y: body.maxY), color: clipColors[Int((item.seed >> 8) % 6)], ctx: ctx)
        }
        return Output(image: image, size: size,
                      anchor: CGPoint(x: clipX / size.width, y: (body.maxY + 8) / size.height),
                      bodyHeight: bodySize.height)
    }

    // MARK: - 拍立得

    private static let paper = NSColor(srgbRed: 0.97, green: 0.95, blue: 0.91, alpha: 1)
    private static let ink = NSColor(srgbRed: 0.22, green: 0.24, blue: 0.34, alpha: 0.9)

    private static func drawPolaroid(_ item: ClotheslineItem, in b: CGRect, photo photoSize: CGSize, side: Side,
                                     thumbnail: CGImage?, missing: Bool, ctx: CGContext) {
        dropShadow(for: b, ctx: ctx)
        ctx.setFillColor(paper.cgColor)
        ctx.fill(b)
        grain(b, ctx: ctx)
        curledCorners(b, ctx: ctx)

        let tall = Style.isTall(photoSize)
        let photo = tall
            ? CGRect(origin: CGPoint(x: b.minX + 8, y: b.minY + 8), size: photoSize)
            : CGRect(x: b.midX - photoSize.width / 2, y: b.maxY - 8 - photoSize.height,
                     width: photoSize.width, height: photoSize.height)
        ctx.saveGState()
        ctx.clip(to: photo)
        if let thumbnail, !missing {
            ctx.interpolationQuality = .high
            ctx.draw(thumbnail, in: photo) // 相框和原图同比例，整张图完整显示
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

        // 手写日期：长图竖着写在右边（从下往上），其余写在底边靠外侧
        let text = missing ? "已丢失" : dateFormatter.string(from: takenDate(item))
        let color = missing ? NSColor.systemRed : ink
        if tall {
            ctx.saveGState()
            ctx.translateBy(x: b.maxX - 6, y: photo.minY)
            ctx.rotate(by: .pi / 2)
            handwrite(text, in: CGRect(x: 0, y: 0, width: photo.height, height: 18), size: 12, color: color,
                      alignment: .left)
            ctx.restoreGState()
        } else {
            handwrite(text, in: CGRect(x: b.minX + 9, y: b.minY + 5, width: b.width - 18, height: 18),
                      size: 12, color: color, alignment: side == .left ? .left : .right)
        }
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

    // MARK: - 透明按扣文件袋

    private static func drawPocket(_ item: ClotheslineItem, in b: CGRect, thumbnail: CGImage?, missing: Bool,
                                   ctx: CGContext) {
        let badge = FileBadge.badge(for: item.url)
        let color = missing ? NSColor.gray : tint(badge.tint)
        let pocket = CGPath(roundedRect: b, cornerWidth: 4, cornerHeight: 4, transform: nil)
        let flap = CGRect(x: b.minX, y: b.maxY - 22, width: b.width, height: 22)
        let sheet = CGRect(x: b.minX + 7, y: b.minY + 22, width: b.width - 14, height: b.height - 34)

        // 塑料袋本身：很淡，影子也淡
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -2), blur: 4, color: CGColor(gray: 0, alpha: 0.6))
        ctx.addPath(pocket)
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.3).cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        // 袋里的那页纸：文件第一页的缩略图，靠上对齐
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -0.5), blur: 1.5, color: CGColor(gray: 0, alpha: 0.3))
        ctx.setFillColor(NSColor(white: missing ? 0.82 : 1, alpha: 1).cgColor)
        ctx.fill(sheet)
        ctx.restoreGState()
        ctx.saveGState()
        ctx.clip(to: sheet)
        if let thumbnail, !missing {
            let s = max(sheet.width / CGFloat(thumbnail.width), sheet.height / CGFloat(thumbnail.height))
            let w = CGFloat(thumbnail.width) * s, h = CGFloat(thumbnail.height) * s
            ctx.interpolationQuality = .high
            ctx.draw(thumbnail, in: CGRect(x: sheet.midX - w / 2, y: sheet.maxY - h, width: w, height: h))
        } else {
            // 没有内容可看（压缩包等）：画几行浅灰"字"
            ctx.setFillColor(CGColor(gray: 0.6, alpha: 0.35))
            var rng = SeededRandom(state: item.seed)
            for y in stride(from: sheet.maxY - 18, to: sheet.minY + 6, by: -7) {
                ctx.fill(CGRect(x: sheet.minX + 6, y: y, width: .random(in: 0.4...0.85, using: &rng) * (sheet.width - 12), height: 2.5))
            }
        }
        ctx.restoreGState()

        // 磨砂塑料 + 两道斜向反光
        ctx.saveGState()
        ctx.addPath(pocket)
        ctx.clip()
        ctx.setFillColor(color.withAlphaComponent(0.07).cgColor)
        ctx.fill(b)
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.12).cgColor)
        ctx.fill(b)
        let shine = CGGradient(colorsSpace: nil, colors: [
            CGColor(gray: 1, alpha: 0), CGColor(gray: 1, alpha: 0.4), CGColor(gray: 1, alpha: 0),
            CGColor(gray: 1, alpha: 0), CGColor(gray: 1, alpha: 0.25), CGColor(gray: 1, alpha: 0),
        ] as CFArray, locations: [0.22, 0.3, 0.38, 0.5, 0.54, 0.58])!
        ctx.drawLinearGradient(shine, start: CGPoint(x: b.minX, y: b.maxY), end: CGPoint(x: b.maxX, y: b.minY), options: [])

        // 翻盖：比袋身更不透明一点，下沿压一道影子
        ctx.setShadow(offset: CGSize(width: 0, height: -1), blur: 2, color: CGColor(gray: 0, alpha: 0.25))
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.45).blended(withFraction: 0.12, of: color)!.cgColor)
        ctx.fill(flap)
        ctx.restoreGState()
        ctx.setStrokeColor(color.withAlphaComponent(0.45).cgColor)
        ctx.setLineWidth(0.8)
        ctx.strokeLineSegments(between: [CGPoint(x: b.minX, y: flap.minY), CGPoint(x: b.maxX, y: flap.minY)])

        // 袋边按类型颜色微微着色，内侧一道热压封边
        ctx.addPath(pocket)
        ctx.setStrokeColor(color.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(1.2)
        ctx.strokePath()
        ctx.addPath(CGPath(roundedRect: b.insetBy(dx: 2.5, dy: 2.5), cornerWidth: 2.5, cornerHeight: 2.5, transform: nil))
        ctx.setStrokeColor(color.withAlphaComponent(0.25).cgColor)
        ctx.setLineWidth(0.6)
        ctx.strokePath()

        // 按扣
        let snap = CGRect(x: b.midX - 5.5, y: flap.midY - 6.5, width: 11, height: 11)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -1), blur: 1.5, color: CGColor(gray: 0, alpha: 0.35))
        ctx.setFillColor(color.cgColor)
        ctx.fillEllipse(in: snap)
        ctx.restoreGState()
        let gloss = CGGradient(colorsSpace: nil, colors: [CGColor(gray: 1, alpha: 0.7), CGColor(gray: 1, alpha: 0)] as CFArray,
                               locations: [0, 1])!
        ctx.drawRadialGradient(gloss, startCenter: CGPoint(x: snap.midX - 1.5, y: snap.midY + 1.5), startRadius: 0,
                               endCenter: CGPoint(x: snap.midX - 1.5, y: snap.midY + 1.5), endRadius: 4, options: [])
        ctx.setStrokeColor(color.blended(withFraction: 0.35, of: .black)!.cgColor)
        ctx.setLineWidth(0.7)
        ctx.strokeEllipse(in: snap.insetBy(dx: 2.5, dy: 2.5))

        // 类型小标签 / 丢失印章
        if missing {
            stamp("已丢失", color: .systemRed, center: CGPoint(x: sheet.midX, y: sheet.midY), angle: 0.2, ctx: ctx)
        } else {
            label(badge.text, color: color, at: CGPoint(x: sheet.minX - 2, y: sheet.minY + 4), ctx: ctx)
        }

        handwrite(item.url.lastPathComponent, in: CGRect(x: b.minX + 6, y: b.minY + 4, width: b.width - 12, height: 16),
                  size: 10.5, color: NSColor(white: 0.2, alpha: 0.9), alignment: .center)
    }

    /// 贴在袋子上的彩色小标签，略歪。
    private static func label(_ text: String, color: NSColor, at origin: CGPoint, ctx: CGContext) {
        let font = NSFont(name: "AmericanTypewriter-Bold", size: 9) ?? .boldSystemFont(ofSize: 9)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let size = (text as NSString).size(withAttributes: attrs)
        let tag = CGRect(x: 0, y: 0, width: size.width + 10, height: size.height + 3)
        ctx.saveGState()
        ctx.translateBy(x: origin.x, y: origin.y)
        ctx.rotate(by: -0.07)
        ctx.setShadow(offset: CGSize(width: 0, height: -0.5), blur: 1, color: CGColor(gray: 0, alpha: 0.3))
        ctx.addPath(CGPath(roundedRect: tag, cornerWidth: 2, cornerHeight: 2, transform: nil))
        ctx.setFillColor(color.withAlphaComponent(0.92).cgColor)
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0, color: nil)
        (text as NSString).draw(at: CGPoint(x: 5, y: 1.5), withAttributes: attrs)
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
