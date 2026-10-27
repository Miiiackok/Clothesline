// Native preview renderer. Uses the application's CardArt, RopeLayer, and spring physics.
// Demo artwork is generated locally; no desktop capture or user files are read.
import AppKit
import ClotheslineCore
import ImageIO
import UniformTypeIdentifiers

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
let destination = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "docs/images", isDirectory: true)
try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
let scratch = FileManager.default.temporaryDirectory.appendingPathComponent("ClotheslinePreview-\(UUID())")
try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: scratch) }

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: alpha)
}
func bitmap(_ size: CGSize, draw: (CGContext) -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
    draw(ctx)
    NSGraphicsContext.restoreGraphicsState()
    return ctx.makeImage()!
}
func text(_ value: String, at point: CGPoint, font: NSFont, ink: NSColor) {
    (value as NSString).draw(at: point, withAttributes: [.font: font, .foregroundColor: ink])
}
func rounded(_ rect: CGRect, radius: CGFloat, fill: NSColor) {
    fill.setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
}
func landscape(_ vertical: Bool) -> CGImage {
    let size = vertical ? CGSize(width: 360, height: 750) : CGSize(width: 720, height: 480)
    return bitmap(size) { ctx in
        let rect = CGRect(origin: .zero, size: size)
        NSGradient(starting: color(vertical ? 0xDDE2CE : 0xF3D7AE), ending: color(vertical ? 0x89A6A1 : 0xB5CACC))!
            .draw(in: rect, angle: 90)
        color(0xFFEDBE).setFill()
        let sun = vertical ? CGRect(x: 225, y: 590, width: 62, height: 62) : CGRect(x: 500, y: 330, width: 64, height: 64)
        NSBezierPath(ovalIn: sun).fill()
        for layer in 0..<4 {
            let path = NSBezierPath()
            let baseline = size.height * (0.27 + CGFloat(layer) * 0.1)
            path.move(to: CGPoint(x: -20, y: baseline))
            path.curve(to: CGPoint(x: size.width + 20, y: baseline + 40),
                       controlPoint1: CGPoint(x: size.width * 0.3, y: baseline + 180 - CGFloat(layer) * 12),
                       controlPoint2: CGPoint(x: size.width * 0.65, y: baseline - 150))
            path.line(to: CGPoint(x: size.width + 20, y: -20))
            path.line(to: CGPoint(x: -20, y: -20))
            path.close()
            color([0x83998C, 0x6F8A7E, 0x476D64, 0x244D4B][layer]).setFill()
            path.fill()
        }
        let line = NSBezierPath()
        line.move(to: CGPoint(x: size.width * 0.4, y: 0))
        line.curve(to: CGPoint(x: size.width * 0.58, y: size.height * 0.4),
                   controlPoint1: CGPoint(x: size.width * 0.8, y: size.height * 0.2),
                   controlPoint2: CGPoint(x: size.width * 0.4, y: size.height * 0.3))
        color(0xE7CF9D, 0.7).setStroke()
        line.lineWidth = vertical ? 9 : 13
        line.stroke()
    }
}
let photo = landscape(false)
let tallPhoto = landscape(true)
let document = bitmap(CGSize(width: 300, height: 400)) { _ in
    color(0xFFFDF5).setFill(); NSRect(x: 0, y: 0, width: 300, height: 400).fill()
    text("FIELD NOTES", at: CGPoint(x: 28, y: 327), font: .systemFont(ofSize: 25, weight: .bold), ink: color(0x335849))
    for i in 0..<9 {
        rounded(CGRect(x: 28, y: 290 - i * 23, width: i % 3 == 0 ? 155 : 238, height: 5), radius: 2, fill: color(0xB7C3AD))
    }
    rounded(CGRect(x: 28, y: 43, width: 244, height: 44), radius: 5, fill: color(0xE4E8D6))
}
struct DemoCard {
    let item: ClotheslineItem
    let layer: CardLayer
    let distance: CGFloat
}
let names = ["quiet-morning.png", "field-notes.txt", "summer-walk.png", "Weekend ideas"]
let thumbnails: [CGImage?] = [photo, document, tallPhoto, nil]
let distances: [CGFloat] = [65, 210, 355, 570]
let date = ISO8601DateFormatter().date(from: "2026-10-27T08:30:00Z")!
var cards: [DemoCard] = []
for i in names.indices {
    let url = scratch.appendingPathComponent(names[i])
    if i == 3 { try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true) }
    else { try Data("Demo content".utf8).write(to: url) }
    try FileManager.default.setAttributes([.creationDate: date], ofItemAtPath: url.path)
    let id = UUID(uuidString: ["11223344-5566-7788-99AA-BBCCDDEEFF01", "22334455-6677-8899-AABB-CCDDEEFF0012", "33445566-7788-99AA-BBCC-DDEEFF001123", "44556677-8899-AABB-CCDD-EEFF00112234"][i])!
    let item = ClotheslineItem(id: id, kind: i == 0 || i == 2 ? .image : .file, path: url.path, addedAt: date)
    let layer = CardLayer(item: item)
    layer.side = i % 2 == 0 ? .left : .right
    layer.apply(CardArt.render(item, side: layer.side, thumbnail: thumbnails[i], missing: false, scale: 3), scale: 3)
    cards.append(DemoCard(item: item, layer: layer, distance: distances[i]))
}
let size = CGSize(width: 1440, height: 960)
let ink = color(0x263E35)
let muted = color(0x718078)
let rope = RopeLayer()
rope.frame = CGRect(x: 0, y: 0, width: 520, height: 840)
let background = bitmap(size) { ctx in
    color(0xF4F3E9).setFill(); NSRect(origin: .zero, size: size).fill()
    // Editorial background with a quiet green corner behind the native rope.
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                              colors: [color(0xDCE4D4, 0.9).cgColor, color(0xF4F3E9, 0).cgColor] as CFArray,
                              locations: [0, 1])!
    ctx.drawRadialGradient(gradient, startCenter: CGPoint(x: 1300, y: 560), startRadius: 0,
                           endCenter: CGPoint(x: 1300, y: 560), endRadius: 650, options: [])
    rounded(CGRect(x: 80, y: 830, width: 122, height: 30), radius: 15, fill: color(0xE4E7D8))
    text("MADE FOR macOS", at: CGPoint(x: 94, y: 838), font: .monospacedSystemFont(ofSize: 11, weight: .medium), ink: color(0x4F6655))
    text("Clothesline", at: CGPoint(x: 78, y: 737), font: .systemFont(ofSize: 72, weight: .semibold), ink: ink)
    text("桌面晾衣绳", at: CGPoint(x: 83, y: 683), font: .systemFont(ofSize: 29, weight: .regular), ink: color(0x52685A))
    let serif = NSFont(name: "Georgia", size: 57) ?? .systemFont(ofSize: 57, weight: .regular)
    text("A place for", at: CGPoint(x: 80, y: 537), font: serif, ink: ink)
    text("the little things.", at: CGPoint(x: 80, y: 466), font: serif, ink: ink)
    text("把截图、照片和随手要用的文件，", at: CGPoint(x: 83, y: 390), font: .systemFont(ofSize: 22), ink: color(0x64756A))
    text("夹在屏幕边的一小截绳子上。", at: CGPoint(x: 83, y: 353), font: .systemFont(ofSize: 22), ink: color(0x64756A))
    var x: CGFloat = 83
    for (label, width) in [("原生 Swift", CGFloat(113)), ("截图自动收纳", CGFloat(140)), ("拖入 · 拖出", CGFloat(128))] {
        rounded(CGRect(x: x, y: 252, width: width, height: 39), radius: 19.5, fill: color(0xE6E9DC))
        text(label, at: CGPoint(x: x + 16, y: 264), font: .systemFont(ofSize: 15, weight: .medium), ink: color(0x53684F))
        x += width + 12
    }
    color(0xD9DFCF).setFill(); NSRect(x: 83, y: 177, width: 570, height: 1).fill()
    text("Screenshots. Photos. Files. A little room to breathe.", at: CGPoint(x: 83, y: 137),
         font: .systemFont(ofSize: 15), ink: muted)
    text("NATIVE RENDER · DEMO CONTENT", at: CGPoint(x: 83, y: 50),
         font: .monospacedSystemFont(ofSize: 10, weight: .regular), ink: color(0x8A978A))
    text("macOS 13+  /  OPEN SOURCE", at: CGPoint(x: 1100, y: 50),
         font: .monospacedSystemFont(ofSize: 10, weight: .regular), ink: color(0x8A978A))
}
func scene(length: CGFloat, sway: CGFloat, time: CGFloat) -> CGImage {
    bitmap(size) { ctx in
        ctx.draw(background, in: CGRect(origin: .zero, size: size))
        ctx.saveGState()
        ctx.translateBy(x: 770, y: 45)
        ctx.scaleBy(x: 1.06, y: 1.06)
        let geometry = RopeGeometry(top: CGPoint(x: 350, y: 870), length: length, sway: sway)
        rope.geometry = geometry
        rope.draw(in: ctx)
        for (i, card) in cards.enumerated() where card.distance <= length {
            let layer = card.layer
            let point = geometry.point(at: card.distance)
            let swing = sin(time * 8 + CGFloat(i)) * 0.11 * exp(-max(0, time - 0.3) * 2)
            ctx.saveGState()
            ctx.translateBy(x: point.x, y: point.y)
            ctx.rotate(by: layer.restAngle + swing)
            ctx.draw(layer.contents as! CGImage, in: CGRect(x: -layer.anchorPoint.x * layer.bounds.width,
                                                           y: -layer.anchorPoint.y * layer.bounds.height,
                                                           width: layer.bounds.width, height: layer.bounds.height))
            ctx.restoreGState()
        }
        ctx.restoreGState()
    }
}
func writePNG(_ image: CGImage, name: String) {
    let writer = CGImageDestinationCreateWithURL(destination.appendingPathComponent(name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(writer, image, nil)
    precondition(CGImageDestinationFinalize(writer))
}
writePNG(scene(length: 730, sway: 0, time: 5), name: "hero.png")
let gif = CGImageDestinationCreateWithURL(destination.appendingPathComponent("demo.gif") as CFURL, UTType.gif.identifier as CFString, 100, nil)!
CGImageDestinationSetProperties(gif, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
var length = Spring(value: Layout.stubLength, stiffness: 170, damping: 17)
var sway = Spring(value: 0, stiffness: 55, damping: 2.8)
sway.velocity = 110
for frame in 0..<100 {
    let t = CGFloat(frame) / 20
    length.target = t > 0.5 && t < 3.6 ? 730 : Layout.stubLength
    length.damping = t < 3.6 ? 17 : 2 * length.stiffness.squareRoot()
    for _ in 0..<3 { _ = length.step(1.0 / 60); _ = sway.step(1.0 / 60) }
    let full = scene(length: max(0, length.value), sway: sway.value, time: max(0, t - 0.5))
    let reduced = bitmap(CGSize(width: 960, height: 640)) { ctx in
        ctx.interpolationQuality = .high
        ctx.draw(full, in: CGRect(x: 0, y: 0, width: 960, height: 640))
    }
    CGImageDestinationAddImage(gif, reduced, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 0.05]] as CFDictionary)
}
precondition(CGImageDestinationFinalize(gif))
print("Rendered hero.png and demo.gif using Clothesline's native drawing code.")
