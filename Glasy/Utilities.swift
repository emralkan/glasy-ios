import SpriteKit
import UIKit

enum SceneFX {

    static func addBackground(to scene: SKScene) {
        let size = scene.size
        let tex = gradientTexture(size: size)
        let bg = SKSpriteNode(texture: tex, size: size)
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = -100
        scene.addChild(bg)

        for _ in 0..<8 {
            let r = CGFloat.random(in: 20...52)
            let b = SKShapeNode(circleOfRadius: r)
            let tint: [UIColor] = [UIColor(red: 1, green: 0.78, blue: 0.90, alpha: 0.18),
                                   UIColor(red: 0.75, green: 0.85, blue: 1, alpha: 0.18),
                                   UIColor(red: 0.85, green: 0.80, blue: 1, alpha: 0.18)]
            b.fillColor = tint.randomElement()!
            b.strokeColor = .clear
            b.position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                 y: CGFloat.random(in: 0...size.height))
            b.zPosition = -90
            let dy = CGFloat.random(in: 24...60)
            let dur = Double.random(in: 6...12)
            b.run(.repeatForever(.sequence([.moveBy(x: 0, y: dy, duration: dur),
                                            .moveBy(x: 0, y: -dy, duration: dur)])))
            scene.addChild(b)
        }
    }

    static func gradientTexture(size: CGSize) -> SKTexture {
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let colors = [UIColor(red: 0.95, green: 0.92, blue: 1.00, alpha: 1).cgColor,
                          UIColor(red: 0.99, green: 0.94, blue: 0.97, alpha: 1).cgColor,
                          UIColor(red: 0.91, green: 0.95, blue: 1.00, alpha: 1).cgColor] as CFArray
            let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1])!
            cg.drawLinearGradient(grad, start: .zero,
                                  end: CGPoint(x: size.width * 0.3, y: size.height),
                                  options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        return SKTexture(image: img)
    }
}

enum LivesGate {
    static func countdownText() -> String {
        if Wallet.lives >= Lives.maxLives { return "Canların dolu" }
        let s = Wallet.secondsToNextLife
        return s <= 0 ? "Birazdan +1 can" : String(format: "Sonraki can: %02d:%02d", s / 60, s % 60)
    }

    static func build(into overlay: SKNode, size: CGSize) {
        overlay.removeAllChildren()
        let cx = size.width / 2, cy = size.height / 2
        let k = Layout.scale(size)
        let pw = min(size.width - 120, 400 * k)

        let dim = SKSpriteNode(color: UIColor(white: 0.35, alpha: 0.4), size: size)
        dim.position = CGPoint(x: cx, y: cy)
        overlay.addChild(dim)

        let panel = SKShapeNode(rectOf: CGSize(width: min(size.width - 70, 460 * k), height: 364 * k), cornerRadius: 28)
        panel.fillColor = UIColor(white: 1, alpha: 0.97)
        panel.strokeColor = GamePalette.tileLine; panel.lineWidth = 1
        panel.position = CGPoint(x: cx, y: cy)
        overlay.addChild(panel)

        let heart = UIBuild.heart(filled: true, size: 50 * k)
        heart.position = CGPoint(x: cx, y: cy + 120 * k)
        overlay.addChild(heart)

        let title = UIBuild.label("Canın kalmadı", size: 26 * k, weight: Theme.heavy, color: GamePalette.textPlum)
        title.position = CGPoint(x: cx, y: cy + 72 * k)
        overlay.addChild(title)

        let count = UIBuild.label(countdownText(), size: 17 * k, weight: Theme.medium,
                                  color: GamePalette.textPlum.withAlphaComponent(0.7))
        count.name = "lg_count"
        count.position = CGPoint(x: cx, y: cy + 40 * k)
        overlay.addChild(count)

        let canAfford = Wallet.coins >= Costs.life
        let coin = UIBuild.pill(text: "💎  \(Costs.life) coin → +1 can", width: pw, height: 54 * k,
                                fill: canAfford ? UIColor(red: 0.44, green: 0.82, blue: 0.74, alpha: 0.95)
                                                : UIColor(white: 0.86, alpha: 0.8),
                                line: .white,
                                textColor: canAfford ? .white : UIColor(white: 0.55, alpha: 1),
                                fontSize: 18 * k, name: canAfford ? "lg_coins" : "lg_poor")
        coin.position = CGPoint(x: cx, y: cy - 12 * k)
        overlay.addChild(coin)

        let ad = UIBuild.pill(text: "▶  Reklam izle → +1 can", width: pw, height: 54 * k,
                              fill: UIColor(red: 0.78, green: 0.66, blue: 0.95, alpha: 0.95),
                              line: .white, textColor: .white, fontSize: 18 * k, name: "lg_ad")
        ad.position = CGPoint(x: cx, y: cy - 74 * k)
        overlay.addChild(ad)

        let close = UIBuild.pill(text: "Kapat", width: pw, height: 50 * k,
                                 fill: GamePalette.panel, line: GamePalette.tileLine, textColor: GamePalette.textPlum,
                                 fontSize: 17 * k, name: "lg_close")
        close.position = CGPoint(x: cx, y: cy - 134 * k)
        overlay.addChild(close)
    }
}

enum Layout {
    static func scale(_ size: CGSize) -> CGFloat {
        let w = min(size.width, size.height)
        guard w >= 600 else { return 1.0 }
        return min(w / 560, 1.5)
    }
}

extension Optional where Wrapped == String {
    var orEmpty: String { self ?? "" }
}

enum UIBuild {
    static func label(_ text: String, size: CGFloat, weight: String = Theme.medium,
                      color: UIColor = GamePalette.textPlum) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: weight)
        l.text = text
        l.fontSize = size
        l.fontColor = color
        l.horizontalAlignmentMode = .center
        l.verticalAlignmentMode = .center
        return l
    }

    static func heartsRow(lives: Int, size: CGFloat = 22, spacing: CGFloat = 26) -> SKNode {
        let row = SKNode()
        for i in 0..<Lives.maxLives {
            let h = heart(filled: i < lives, size: size)
            h.position = CGPoint(x: (CGFloat(i) - CGFloat(Lives.maxLives - 1) / 2) * spacing, y: 0)
            row.addChild(h)
        }
        return row
    }

    static func heart(filled: Bool, size s: CGFloat) -> SKNode {
        let node = SKNode()
        let shape = SKShapeNode(path: heartPath(s))
        shape.lineWidth = max(1, s * 0.05)
        if filled {
            shape.fillColor = UIColor(red: 1.0, green: 0.40, blue: 0.51, alpha: 1)
            shape.strokeColor = UIColor(red: 1.0, green: 0.66, blue: 0.73, alpha: 1)
            shape.glowWidth = s * 0.05
            node.addChild(shape)
            let shine = SKShapeNode(ellipseOf: CGSize(width: s * 0.20, height: s * 0.13))
            shine.fillColor = UIColor(white: 1, alpha: 0.65); shine.strokeColor = .clear
            shine.position = CGPoint(x: -s * 0.15, y: s * 0.20); shine.zRotation = -0.5
            node.addChild(shine)
        } else {
            shape.fillColor = UIColor(white: 0.84, alpha: 0.5)
            shape.strokeColor = UIColor(white: 0.66, alpha: 0.75)
            node.addChild(shape)
        }
        return node
    }

    private static func heartPath(_ s: CGFloat) -> CGPath {
        let w = s, h = s
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: -h * 0.40))
        p.addCurve(to: CGPoint(x: -w * 0.50, y: h * 0.15),
                   control1: CGPoint(x: -w * 0.25, y: -h * 0.15),
                   control2: CGPoint(x: -w * 0.50, y: -h * 0.05))
        p.addCurve(to: CGPoint(x: 0, y: h * 0.15),
                   control1: CGPoint(x: -w * 0.50, y: h * 0.40),
                   control2: CGPoint(x: -w * 0.10, y: h * 0.40))
        p.addCurve(to: CGPoint(x: w * 0.50, y: h * 0.15),
                   control1: CGPoint(x: w * 0.10, y: h * 0.40),
                   control2: CGPoint(x: w * 0.50, y: h * 0.40))
        p.addCurve(to: CGPoint(x: 0, y: -h * 0.40),
                   control1: CGPoint(x: w * 0.50, y: -h * 0.05),
                   control2: CGPoint(x: w * 0.25, y: -h * 0.15))
        p.closeSubpath()
        return p
    }

    static func pill(text: String, width: CGFloat, height: CGFloat,
                     fill: UIColor, line: UIColor, textColor: UIColor,
                     fontSize: CGFloat, weight: String = Theme.medium, name: String) -> SKNode {
        let node = SKNode()
        node.name = name
        node.isAccessibilityElement = true
        node.accessibilityLabel = text
        node.accessibilityTraits = .button
        let bg = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: height * 0.4)
        bg.fillColor = fill
        bg.strokeColor = line
        bg.lineWidth = 1.5
        bg.name = name
        bg.isAccessibilityElement = false
        node.addChild(bg)
        let l = label(text, size: fontSize, weight: weight, color: textColor)
        l.name = name
        l.isAccessibilityElement = false
        node.addChild(l)
        return node
    }
}
