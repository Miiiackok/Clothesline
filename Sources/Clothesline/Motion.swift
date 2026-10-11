import CoreGraphics

/// 阻尼弹簧，所有逐帧动画（绳长、绳摆、卡片晃动）都用它。
struct Spring {
    var value: CGFloat
    var velocity: CGFloat = 0
    var target: CGFloat
    var stiffness: CGFloat
    var damping: CGFloat
    var epsilon: CGFloat

    init(value: CGFloat, stiffness: CGFloat, damping: CGFloat, epsilon: CGFloat = 0.05) {
        self.value = value
        self.target = value
        self.stiffness = stiffness
        self.damping = damping
        self.epsilon = epsilon
    }

    var isSettled: Bool { abs(velocity) < epsilon && abs(target - value) < epsilon }

    /// 走一帧；停稳时吸附到目标并返回 false。
    mutating func step(_ dt: CGFloat) -> Bool {
        velocity += (stiffness * (target - value) - damping * velocity) * dt
        value += velocity * dt
        if isSettled {
            value = target
            velocity = 0
            return false
        }
        return true
    }
}

/// 绳子形状：顶端固定，末端水平偏移 `sway`，中段反向微弯。
struct RopeGeometry {
    var top: CGPoint
    var length: CGFloat
    var sway: CGFloat

    /// 沿绳子距顶端 `distance` 处的点；超出顶端时直接往上延伸（滚动时卡片滑出去）。
    func point(at distance: CGFloat) -> CGPoint {
        guard distance > 0, length > 0 else { return CGPoint(x: top.x, y: top.y - distance) }
        let s = min(distance / length, 1)
        let x = top.x + sway * s * s - sway * 0.25 * sin(.pi * s)
        return CGPoint(x: x, y: top.y - s * length)
    }

    var end: CGPoint { point(at: length) }
}

func easeInOut(_ t: CGFloat) -> CGFloat { t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2 }

/// 确定性随机数：同一张卡片每次画出来都一样。
struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
