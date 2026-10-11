import AppKit
import ClotheslineCore

/// 卡片上的点击、双击、拖出、右键菜单、滚动，以及从访达拖进来。
extension RopeView: NSDraggingSource {
    func card(at point: CGPoint) -> CardLayer? {
        layer?.hitTest(point) as? CardLayer
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: - 点击

    override func mouseDown(with event: NSEvent) {
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        pressed = card(at: mouseDownPoint)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard let card = pressed, hypot(point.x - mouseDownPoint.x, point.y - mouseDownPoint.y) > 4 else { return }
        pressed = nil
        beginDrag(card, event: event)
    }

    override func mouseUp(with event: NSEvent) {
        guard let card = pressed else { return }
        pressed = nil
        pendingPreview?.cancel()
        if event.clickCount >= 2 {
            open(card.item)
        } else {
            // 等一下再弹快速预览，好和双击区分
            let item = card.item
            let work = DispatchWorkItem { QuickLook.shared.show(item.url) }
            pendingPreview = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
        }
    }

    override func scrollWheel(with event: NSEvent) {
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 10
        scroll = min(max(scroll - delta, 0), maxScroll)
    }

    func open(_ item: ClotheslineItem) {
        guard !item.isMissing else { return NSSound.beep() }
        if item.kind == .image,
           let preview = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") {
            NSWorkspace.shared.open([item.url], withApplicationAt: preview, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.open(item.url)
        }
    }

    // MARK: - 右键菜单

    override func menu(for event: NSEvent) -> NSMenu? {
        guard let card = card(at: convert(event.locationInWindow, from: nil)) else { return nil }
        let item = card.item
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(ClosureMenuItem(item.kind == .image ? "用预览标注" : "打开") { [weak self] in self?.open(item) })
        menu.addItem(ClosureMenuItem("共享…") { [weak self] in self?.share(item, from: card) })
        menu.addItem(ClosureMenuItem("在访达中显示") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) })
        menu.addItem(ClosureMenuItem("拷贝") { Self.copy(item.url) })
        menu.items.forEach { $0.isEnabled = !item.isMissing }
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem("从绳子上摘掉") { [weak self] in self?.store.remove(item.id, trashing: true) })
        return menu
    }

    private func share(_ item: ClotheslineItem, from card: CardLayer) {
        NSApp.activate(ignoringOtherApps: true)
        NSSharingServicePicker(items: [item.url]).show(relativeTo: card.frame, of: self, preferredEdge: .minX)
    }

    /// 和访达拷贝文件的写法一致，微信等应用能直接粘贴。
    private static func copy(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.declareTypes([.fileURL, NSPasteboard.PasteboardType("NSFilenamesPboardType"), .string], owner: nil)
        pasteboard.setString(url.absoluteString, forType: .fileURL)
        pasteboard.setPropertyList([url.path], forType: NSPasteboard.PasteboardType("NSFilenamesPboardType"))
        pasteboard.setString(url.lastPathComponent, forType: .string)
    }

    // MARK: - 拖出去

    private func beginDrag(_ card: CardLayer, event: NSEvent) {
        guard !card.item.isMissing, let image = card.contents else { return }
        let draggingItem = NSDraggingItem(pasteboardWriter: card.item.url as NSURL)
        let size = card.bounds.size
        let frame = card.frame
        draggingItem.setDraggingFrame(CGRect(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2,
                                             width: size.width, height: size.height),
                                      contents: NSImage(cgImage: image as! CGImage, size: size))
        draggedCard = card
        card.opacity = 0.3
        beginDraggingSession(with: [draggingItem], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .outsideApplication ? .copy : []
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        guard let card = draggedCard else { return }
        draggedCard = nil
        card.opacity = 1
        // 对方收下了：照片原地留 24 小时再清理（对方可能稍后才读文件），文件原地不动
        if operation != [] { store.remove(card.item.id) }
    }

    // MARK: - 拖进来

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        sender.draggingSource as? RopeView === self ? [] : .copy
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = sender.draggingPasteboard.readObjects(
            forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] ?? []
        for url in urls.reversed() { _ = try? store.add(url) } // 拖进来的第一个挂在最上面
        return !urls.isEmpty
    }
}

/// 用闭包当动作的菜单项。
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func fire() { handler() }
}
