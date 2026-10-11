import AppKit
import ClotheslineCore

/// 绳子和卡片：布局、掉下/收回、晃动、截图飞入。交互见 RopeView+Interaction.swift。
final class RopeView: NSView {
    let store: ClotheslineStore
    private(set) var isExpanded = false
    var cards: [UUID: CardLayer] = [:]
    var scroll: CGFloat = 0 { didSet { startTicking() } }

    private let ropeLayer = RopeLayer()
    private let thumbnails = Thumbnails()
    private var length = Spring(value: Layout.stubLength, stiffness: 170, damping: 17)
    private var sway = Spring(value: 0, stiffness: 55, damping: 2.8)
    private var timer: Timer?

    // 交互状态（RopeView+Interaction）
    var pressed: CardLayer?
    var mouseDownPoint: CGPoint = .zero
    var pendingPreview: DispatchWorkItem?
    var draggedCard: CardLayer?

    init(store: ClotheslineStore) {
        self.store = store
        super.init(frame: .zero)
        layer = CALayer() // layer-hosting：所有内容都是我们自己的图层
        wantsLayer = true
        ropeLayer.needsDisplayOnBoundsChange = true
        layer!.addSublayer(ropeLayer)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - 几何

    private var scale: CGFloat { window?.backingScaleFactor ?? 2 }

    private var geometry: RopeGeometry {
        RopeGeometry(top: CGPoint(x: Layout.ropeX, y: bounds.maxY), length: max(length.value, 0), sway: sway.value)
    }

    /// 展开时绳子的长度：够挂下所有卡片，但不超出屏幕。
    private var fullLength: CGFloat {
        let needed = Layout.firstClip + CGFloat(max(store.items.count - 1, 0)) * Layout.clipSpacing + Layout.ropeTail
        return max(Layout.minRopeLength, min(needed, bounds.height - Layout.bottomRoom))
    }

    var maxScroll: CGFloat {
        max(0, Layout.firstClip + CGFloat(max(store.items.count - 1, 0)) * Layout.clipSpacing + Layout.ropeTail - fullLength)
    }

    /// 收起时露出的那一小截，鼠标停在这里会让绳子掉下来。
    var stubRect: CGRect {
        CGRect(x: Layout.ropeX - 14, y: bounds.maxY - Layout.stubLength - 12, width: 28, height: Layout.stubLength + 12)
    }

    /// 绳子和所有可见卡片占的区域，鼠标在这里面时面板才接收鼠标事件。
    var contentRect: CGRect {
        let end = geometry.end
        var rect = CGRect(x: Layout.ropeX - 24, y: end.y - 16, width: 48, height: bounds.maxY - end.y + 16)
        for card in cards.values where !card.isHidden { rect = rect.union(card.frame) }
        return rect
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        ropeLayer.frame = bounds
        startTicking()
    }

    override func viewDidChangeBackingProperties() {
        ropeLayer.contentsScale = scale
        cards.values.forEach { $0.rendered = nil }
        reload()
    }

    // MARK: - 数据

    /// 和 store 对齐：增删卡片、分左右、重画状态变了的卡片（丢失、缩略图更新）。
    func reload() {
        let items = store.items
        let ids = Set(items.map(\.id))
        for (id, card) in cards where !ids.contains(id) {
            card.removeFromSuperlayer()
            cards[id] = nil
        }
        for (index, item) in items.enumerated() {
            let target = Layout.firstClip + CGFloat(index) * Layout.clipSpacing
            let card = cards[item.id] ?? makeCard(item, at: target - scroll)
            // 从最旧的数起左右交错，新挂上的不会让旧的换边
            card.side = (items.count - 1 - index) % 2 == 0 ? .left : .right
            card.targetDistance = target
            render(card)
        }
        scroll = min(scroll, maxScroll)
        startTicking()
    }

    private func makeCard(_ item: ClotheslineItem, at distance: CGFloat) -> CardLayer {
        let card = CardLayer(item: item)
        card.distance = distance
        cards[item.id] = card
        layer!.addSublayer(card)
        return card
    }

    private func render(_ card: CardLayer) {
        let item = card.item
        let missing = item.isMissing
        var thumbnail: CGImage?
        if item.kind == .image, !missing {
            thumbnail = thumbnails.thumbnail(for: item.url) { [weak self, weak card] in
                if let self, let card { self.render(card) }
            }
        }
        let state = CardLayer.RenderState(side: card.side, missing: missing, thumbnail: thumbnail)
        guard state != card.rendered else { return }
        card.rendered = state
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        card.apply(CardArt.render(item, side: card.side, thumbnail: thumbnail, missing: missing, scale: scale),
                   scale: scale)
        CATransaction.commit()
    }

    // MARK: - 掉下 / 收回 / 飞入

    func setExpanded(_ expanded: Bool) {
        guard expanded != isExpanded else { return }
        isExpanded = expanded
        if expanded {
            length.damping = 17 // 欠阻尼：到底弹一下
            sway.velocity = Bool.random() ? 110 : -110
            reload() // 顺便重新检查有没有文件丢失
        } else {
            length.damping = 2 * length.stiffness.squareRoot() // 临界阻尼：干脆收回
            scroll = 0
        }
        startTicking()
    }

    /// 截图从屏幕右下角（系统浮动缩略图的位置）沿弧线飞到绳子最上面。
    func flyIn(_ id: UUID) {
        guard let card = cards[id] else { return }
        thumbnails.load(card.item.url)
        render(card)
        scroll = 0
        let s = CardLayer.Flight.startScale
        let start = CGPoint(x: bounds.maxX - 120, y: bounds.minY + 90)
        let offset = CGPoint(x: (card.anchorPoint.x - 0.5) * card.bounds.width * s,
                             y: (card.anchorPoint.y - 0.5) * card.bounds.height * s)
        card.flight = .init(from: CGPoint(x: start.x + offset.x, y: start.y + offset.y), start: CACurrentMediaTime())
        startTicking()
    }

    /// 「预览」保存标注后 Images 目录变了：重画缩略图有变化的照片。
    func refreshThumbnails() {
        cards.values.filter { $0.item.kind == .image }.forEach(render)
    }

    // MARK: - 逐帧

    /// 只在有东西在动时才跑的 60fps 定时器。
    func startTicking() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func tick() {
        let dt: CGFloat = 1.0 / 60
        length.target = isExpanded ? fullLength : Layout.stubLength
        var moving = length.step(dt)
        moving = sway.step(dt) || moving
        let g = geometry

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        ropeLayer.geometry = g
        for card in cards.values {
            moving = update(card, along: g, dt: dt) || moving
        }
        CATransaction.commit()

        if !moving {
            timer?.invalidate()
            timer = nil
        }
    }

    /// 返回这张卡片是否还在动。
    private func update(_ card: CardLayer, along g: RopeGeometry, dt: CGFloat) -> Bool {
        let target = card.targetDistance - scroll
        card.distance += (target - card.distance) * 0.25
        if abs(target - card.distance) < 0.3 { card.distance = target }
        var moving = card.distance != target

        if let flight = card.flight {
            let t = min((CACurrentMediaTime() - flight.start) / CardLayer.Flight.duration, 1)
            let e = easeInOut(t)
            let end = g.point(at: card.distance)
            let control = CGPoint(x: bounds.maxX - 20, y: (flight.from.y + end.y) / 2)
            let u = 1 - e
            let position = CGPoint(x: u * u * flight.from.x + 2 * u * e * control.x + e * e * end.x,
                                   y: u * u * flight.from.y + 2 * u * e * control.y + e * e * end.y)
            card.isHidden = false
            card.setPose(position: position, angle: card.restAngle * e,
                         scale: CardLayer.Flight.startScale + (1 - CardLayer.Flight.startScale) * e)
            if t >= 1 {
                card.flight = nil
                clipOn(card)
            }
            return true
        }

        // 绳子经过的地方才挂得住；刚露出来就"啪"地夹上晃一下
        let visible = card.distance <= g.length && card.distance > -Layout.polaroidSize.height
        if visible && card.isHidden { clipOn(card) }
        card.isHidden = !visible
        guard visible else {
            card.swing.value = 0
            card.swing.velocity = 0
            return moving
        }
        moving = card.swing.step(dt) || moving
        card.setPose(position: g.point(at: card.distance), angle: card.restAngle + card.swing.value)
        return moving
    }

    private func clipOn(_ card: CardLayer) {
        card.swing.velocity = card.side == .left ? 1.6 : -1.6
    }
}
