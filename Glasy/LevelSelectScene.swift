import SpriteKit

final class LevelSelectScene: SKScene {

    private let content = SKNode()
    private let crop = SKCropNode()
    private var gridTop: CGFloat = 0
    private var scrollOffset: CGFloat = 0
    private var maxScroll: CGFloat = 0

    private var startTouchY: CGFloat = 0
    private var startOffset: CGFloat = 0
    private var lastY: CGFloat = 0
    private var moved = false

    private var cols = 5
    private var uiScale: CGFloat = 1
    private let gate = SKNode()
    private var busy = false
    private var lastTick: TimeInterval = 0

    override func didMove(to view: SKView) {
        SoundManager.shared.startMusic()
        uiScale = Layout.scale(size)
        cols = size.width >= 600 ? 6 : 5
        SceneFX.addBackground(to: self)
        buildChrome()
        buildGrid()
        gate.zPosition = 300
        addChild(gate)
    }

    override func update(_ currentTime: TimeInterval) {
        if currentTime - lastTick >= 1 {
            lastTick = currentTime
            if let c = gate.childNode(withName: "lg_count") as? SKLabelNode { c.text = LivesGate.countdownText() }
        }
    }

    private func watchAdForLife() {
        guard !busy else { return }
        guard AdManager.shared.isRewardedReady else { toast("Reklam şu an hazır değil, biraz sonra tekrar dene"); return }
        busy = true
        AdManager.shared.showRewarded(reason: "life") { [weak self] ok in
            guard let self else { return }
            self.busy = false
            if ok { Wallet.addLife(); self.gate.removeAllChildren() }
            else { self.toast("Reklam tamamlanmadı") }
        }
    }

    private func toast(_ text: String) {
        let t = UIBuild.label(text, size: 15 * uiScale, weight: Theme.heavy, color: .white)
        let pad: CGFloat = 18 * uiScale
        let bg = SKShapeNode(rectOf: CGSize(width: t.frame.width + pad * 2, height: 44 * uiScale), cornerRadius: 22 * uiScale)
        bg.fillColor = UIColor(red: 0.42, green: 0.36, blue: 0.60, alpha: 0.96); bg.strokeColor = .clear
        bg.position = CGPoint(x: size.width / 2, y: safeBottom() + 80 * uiScale); bg.zPosition = 500
        t.position = bg.position; t.zPosition = 501
        addChild(bg); addChild(t)
        let fade = SKAction.sequence([.wait(forDuration: 1.6), .fadeOut(withDuration: 0.4), .removeFromParent()])
        bg.run(fade); t.run(fade)
    }

    private func buyLifeWithCoins() {
        guard Wallet.spend(Costs.life) else { return }
        Wallet.addLife()
        gate.removeAllChildren()
    }

    private func safeTop() -> CGFloat { view?.safeAreaInsets.top ?? 24 }
    private func safeBottom() -> CGFloat { view?.safeAreaInsets.bottom ?? 16 }

    private func buildChrome() {
        let title = UIBuild.label("Bölümler", size: 28 * uiScale, weight: Theme.heavy, color: GamePalette.textPlum)
        title.position = CGPoint(x: size.width / 2, y: size.height - safeTop() - 30 * uiScale)
        title.zPosition = 50
        addChild(title)

        let back = UIBuild.pill(text: "‹ Menü", width: 92 * uiScale, height: 40 * uiScale,
                                fill: GamePalette.panel, line: GamePalette.tileLine, textColor: GamePalette.textPlum,
                                fontSize: 16 * uiScale, name: "back")
        back.position = CGPoint(x: 64 * uiScale, y: size.height - safeTop() - 28 * uiScale)
        back.zPosition = 50
        addChild(back)
    }

    private func buildGrid() {
        let side: CGFloat = 24
        let cellW = (size.width - side * 2) / CGFloat(cols)
        let rowH = cellW
        gridTop = size.height - safeTop() - 80
        let gridBottom = safeBottom() + 20
        let visibleH = gridTop - gridBottom

        let playable = Wallet.maxLevel
        let total = playable + 3

        for i in 0..<total {
            let n = i + 1
            let col = i % cols
            let row = i / cols
            let x = side + cellW * (CGFloat(col) + 0.5)
            let y = -rowH * (CGFloat(row) + 0.5)
            content.addChild(levelButton(n: n, unlocked: n <= playable, current: n == Wallet.level,
                                          done: n < Wallet.level, at: CGPoint(x: x, y: y), radius: cellW * 0.32))
        }

        let rows = (total + cols - 1) / cols
        let contentH = CGFloat(rows) * rowH
        maxScroll = max(0, contentH - visibleH)

        let mask = SKSpriteNode(color: .white, size: CGSize(width: size.width, height: visibleH))
        mask.position = CGPoint(x: size.width / 2, y: gridBottom + visibleH / 2)
        crop.maskNode = mask
        content.position = CGPoint(x: 0, y: gridTop)
        crop.addChild(content)
        crop.zPosition = 10
        addChild(crop)
    }

    private func levelButton(n: Int, unlocked: Bool, current: Bool, done: Bool,
                             at p: CGPoint, radius: CGFloat) -> SKNode {
        let node = SKNode()
        node.position = p
        node.name = unlocked ? "lvl-\(n)" : "locked"
        node.isAccessibilityElement = true
        node.accessibilityLabel = unlocked ? "Bölüm \(n)" : "Kilitli bölüm \(n)"
        node.accessibilityValue = current ? "Şu anki bölüm" : (done ? "Tamamlandı" : nil)
        node.accessibilityTraits = unlocked ? .button : .notEnabled

        let circle = SKShapeNode(circleOfRadius: radius)
        circle.lineWidth = 2.5
        if !unlocked {
            circle.fillColor = UIColor(white: 0.86, alpha: 0.7)
            circle.strokeColor = UIColor(white: 0.75, alpha: 0.8)
        } else if current {
            circle.fillColor = UIColor(red: 0.78, green: 0.66, blue: 0.95, alpha: 0.95)
            circle.strokeColor = .white
            circle.run(.repeatForever(.sequence([.scale(to: 1.08, duration: 0.8), .scale(to: 1.0, duration: 0.8)])))
        } else if done {
            circle.fillColor = UIColor(red: 0.62, green: 0.86, blue: 0.70, alpha: 0.95)
            circle.strokeColor = .white
        } else {
            circle.fillColor = GamePalette.panel
            circle.strokeColor = GamePalette.tileLine
        }
        circle.name = node.name
        node.addChild(circle)

        if unlocked {
            let label = UIBuild.label("\(n)", size: radius * 0.9, weight: Theme.heavy,
                                      color: (current || done) ? .white : GamePalette.textPlum)
            label.name = node.name
            node.addChild(label)
        } else {
            let body = SKShapeNode(rectOf: CGSize(width: radius * 0.6, height: radius * 0.5), cornerRadius: radius * 0.12)
            body.fillColor = UIColor(white: 0.55, alpha: 1); body.strokeColor = .clear
            body.position = CGPoint(x: 0, y: -radius * 0.1)
            node.addChild(body)
            let shackle = SKShapeNode(circleOfRadius: radius * 0.2)
            shackle.fillColor = .clear; shackle.strokeColor = UIColor(white: 0.55, alpha: 1); shackle.lineWidth = radius * 0.1
            shackle.position = CGPoint(x: 0, y: radius * 0.18)
            node.addChild(shackle)
        }
        return node
    }



    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        let names = nodes(at: p).compactMap { $0.name }
        if !gate.children.isEmpty {
            if names.contains("lg_coins") { buyLifeWithCoins() }
            else if names.contains("lg_ad") { watchAdForLife() }
            else if names.contains("lg_close") { gate.removeAllChildren() }
            return
        }
        if names.contains("back") { goBack(); return }
        startTouchY = p.y; lastY = p.y; startOffset = scrollOffset; moved = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gate.children.isEmpty, let t = touches.first, maxScroll > 0 else { return }
        let y = t.location(in: self).y
        if abs(y - startTouchY) > 8 { moved = true }
        scrollOffset = min(maxScroll, max(0, startOffset + (y - startTouchY)))
        content.position.y = gridTop + scrollOffset
        lastY = y
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard gate.children.isEmpty, let t = touches.first, !moved else { return }
        let names = nodes(at: t.location(in: self)).compactMap { $0.name }
        for name in names where name.hasPrefix("lvl-") {
            if let n = Int(name.dropFirst(4)) { play(level: n); return }
        }
    }

    private func play(level: Int) {
        if Wallet.lives <= 0 { LivesGate.build(into: gate, size: size); return }
        Wallet.level = level
        let g = GameScene(size: size)
        g.scaleMode = .resizeFill
        g.startLevel = level
        view?.presentScene(g, transition: .fade(withDuration: 0.4))
    }

    private func goBack() {
        let m = MenuScene(size: size)
        m.scaleMode = .resizeFill
        view?.presentScene(m, transition: .push(with: .right, duration: 0.35))
    }
}
