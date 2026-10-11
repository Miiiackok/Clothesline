import AppKit
import ClotheslineCore

/// 贴在屏幕右侧的透明面板。每 0.1 秒看一次鼠标位置，决定绳子掉下来还是收回去
/// （轮询不需要辅助功能权限）；收起时面板对鼠标透明，不挡下面的窗口。
final class RopeWindowController {
    let ropeView: RopeView
    private let panel: NSPanel
    private var hoverStart: Date?
    private var holdUntil = Date()
    private var timer: Timer?

    var keepOpen = false {
        didSet { keepOpen ? expand() : hold(for: 1.5) }
    }

    init(store: ClotheslineStore) {
        ropeView = RopeView(store: store)
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.ignoresMouseEvents = true
        panel.contentView = ropeView
        positionPanel()
        panel.orderFrontRegardless()
        ropeView.reload()

        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.positionPanel() }
        let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// 新截图：绳子掉下来，截图飞上去，多挂一会儿再收。
    func showScreenshot(_ id: UUID) {
        expand()
        hold(for: 3)
        ropeView.flyIn(id)
    }

    private func positionPanel() {
        guard let screen = NSScreen.screens.first else { return }
        panel.setFrame(Layout.panelFrame(on: screen), display: true)
    }

    private func expand() {
        hoverStart = nil
        hold(for: 1.5)
        ropeView.setExpanded(true)
    }

    private func hold(for seconds: TimeInterval) {
        holdUntil = max(holdUntil, Date().addingTimeInterval(seconds))
    }

    private func poll() {
        let mouse = NSEvent.mouseLocation
        let point = CGPoint(x: mouse.x - panel.frame.minX, y: mouse.y - panel.frame.minY)
        let buttonDown = NSEvent.pressedMouseButtons & 1 != 0

        guard ropeView.isExpanded else {
            if ropeView.stubRect.contains(point) {
                let since = hoverStart ?? Date()
                hoverStart = since
                // 拖着文件经过立刻掉下来；只是停留则等 0.2 秒
                if buttonDown || Date().timeIntervalSince(since) >= 0.2 { expand() }
            } else {
                hoverStart = nil
            }
            return
        }

        let inside = ropeView.contentRect.contains(point) || (buttonDown && panel.frame.contains(mouse))
        panel.ignoresMouseEvents = !inside
        if inside || keepOpen {
            hold(for: 1.5)
        } else if Date() >= holdUntil {
            ropeView.setExpanded(false)
            panel.ignoresMouseEvents = true
        }
    }
}
