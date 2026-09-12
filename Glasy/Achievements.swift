import SpriteKit

struct Achievement {
    let id: String
    let icon: String
    let title: String
    let detail: String
    let test: () -> Bool
}

enum Achievements {
    static let all: [Achievement] = [
        Achievement(id: "first",   icon: "💡", title: "İlk Işık",           detail: "İlk bölümü tamamla",      test: { Wallet.maxLevel >= 2 }),
        Achievement(id: "lvl10",   icon: "🔥", title: "Isınıyor",           detail: "10. bölüme ulaş",         test: { Wallet.maxLevel >= 10 }),
        Achievement(id: "lvl25",   icon: "🏆", title: "Usta",               detail: "25. bölüme ulaş",         test: { Wallet.maxLevel >= 25 }),
        Achievement(id: "lvl50",   icon: "👑", title: "Işık Ustası",        detail: "50. bölüme ulaş",         test: { Wallet.maxLevel >= 50 }),
        Achievement(id: "lvl100",  icon: "🌟", title: "Efsane",             detail: "100. bölüme ulaş",        test: { Wallet.maxLevel >= 100 }),
        Achievement(id: "daily3",  icon: "📅", title: "Günlük Sadık",       detail: "3 günlük seri yakala",    test: { Wallet.dailyBest >= 3 }),
        Achievement(id: "daily7",  icon: "⭐", title: "Haftalık Kahraman",  detail: "7 günlük seri yakala",    test: { Wallet.dailyBest >= 7 }),
        Achievement(id: "daily30", icon: "💎", title: "Ayın Yıldızı",       detail: "30 günlük seri yakala",   test: { Wallet.dailyBest >= 30 }),
    ]

    private static let d = UserDefaults.standard
    private static let key = "ach_unlocked"

    static var unlocked: Set<String> {
        get { Set(d.stringArray(forKey: key) ?? []) }
        set { d.set(Array(newValue), forKey: key) }
    }
    static func isUnlocked(_ id: String) -> Bool { unlocked.contains(id) }
    static var unlockedCount: Int { all.filter { unlocked.contains($0.id) }.count }

    @discardableResult
    static func evaluate() -> [Achievement] {
        var u = unlocked, newly: [Achievement] = []
        for a in all where !u.contains(a.id) && a.test() { u.insert(a.id); newly.append(a) }
        if !newly.isEmpty { unlocked = u }
        return newly
    }
}

final class AchievementsScene: SKScene {
    private let content = SKNode()
    private let crop = SKCropNode()
    private var contentTopY: CGFloat = 0
    private var visibleH: CGFloat = 0
    private var scrollOffset: CGFloat = 0
    private var maxScroll: CGFloat = 0
    private var startTouchY: CGFloat = 0
    private var startOffset: CGFloat = 0
    private var moved = false
    private var uiScale: CGFloat = 1

    override func didMove(to view: SKView) {
        uiScale = Layout.scale(size)
        SoundManager.shared.startMusic()
        SceneFX.addBackground(to: self)
        buildChrome()
        buildList()
    }

    private func safeTop() -> CGFloat { view?.safeAreaInsets.top ?? 24 }
    private func safeBottom() -> CGFloat { view?.safeAreaInsets.bottom ?? 16 }

    private func buildChrome() {
        let title = UIBuild.label("Başarımlar  \(Achievements.unlockedCount)/\(Achievements.all.count)",
                                  size: 26 * uiScale, weight: Theme.heavy, color: GamePalette.textPlum)
        title.position = CGPoint(x: size.width / 2, y: size.height - safeTop() - 30 * uiScale)
        title.zPosition = 50
        addChild(title)

        let back = UIBuild.pill(text: "‹ Geri", width: 92 * uiScale, height: 40 * uiScale,
                                fill: GamePalette.panel, line: GamePalette.tileLine, textColor: GamePalette.textPlum,
                                fontSize: 16 * uiScale, name: "back")
        back.position = CGPoint(x: 64 * uiScale, y: size.height - safeTop() - 28 * uiScale)
        back.zPosition = 50
        addChild(back)
    }

    private func buildList() {
        crop.removeFromParent(); content.removeAllChildren()
        contentTopY = size.height - safeTop() - 78 * uiScale
        let bottomY = safeBottom() + 24 * uiScale
        visibleH = contentTopY - bottomY
        let side = 24 * uiScale
        let width = size.width - side * 2
        let cx = size.width / 2
        let rowH = 74 * uiScale, gap = 12 * uiScale

        var y: CGFloat = -gap
        for a in Achievements.all {
            content.addChild(rowNode(a, at: CGPoint(x: cx, y: y - rowH / 2), width: width, height: rowH))
            y -= rowH + gap
        }
        let contentH = -y
        maxScroll = max(0, contentH - visibleH)
        scrollOffset = min(scrollOffset, maxScroll)

        let mask = SKSpriteNode(color: .white, size: CGSize(width: size.width, height: visibleH))
        mask.position = CGPoint(x: cx, y: bottomY + visibleH / 2)
        crop.maskNode = mask
        content.position = CGPoint(x: 0, y: contentTopY + scrollOffset)
        if content.parent == nil { crop.addChild(content) }
        crop.zPosition = 10
        addChild(crop)
    }

    private func rowNode(_ a: Achievement, at p: CGPoint, width: CGFloat, height: CGFloat) -> SKNode {
        let on = Achievements.isUnlocked(a.id)
        let node = SKNode(); node.position = p
        let bg = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 18 * uiScale)
        bg.fillColor = on ? UIColor(red: 0.96, green: 0.93, blue: 1.0, alpha: 1) : GamePalette.panel
        bg.strokeColor = on ? UIColor(red: 0.78, green: 0.66, blue: 0.95, alpha: 0.6) : GamePalette.tileLine
        bg.lineWidth = on ? 1.5 : 1
        node.addChild(bg)

        let badge = SKShapeNode(circleOfRadius: height * 0.3)
        badge.fillColor = on ? UIColor(red: 0.78, green: 0.66, blue: 0.95, alpha: 0.25) : UIColor(white: 0.85, alpha: 0.4)
        badge.strokeColor = .clear
        badge.position = CGPoint(x: -width / 2 + height * 0.52, y: 0)
        node.addChild(badge)
        let icon = UIBuild.label(on ? a.icon : "🔒", size: height * 0.34, weight: Theme.heavy, color: GamePalette.textPlum)
        icon.position = badge.position; icon.alpha = on ? 1 : 0.6
        node.addChild(icon)

        let tx = -width / 2 + height * 1.0
        let title = UIBuild.label(a.title, size: 18 * uiScale, weight: Theme.heavy,
                                  color: on ? GamePalette.textPlum : GamePalette.textPlum.withAlphaComponent(0.55))
        title.horizontalAlignmentMode = .left; title.position = CGPoint(x: tx, y: 11 * uiScale)
        node.addChild(title)
        let detail = UIBuild.label(a.detail, size: 14 * uiScale, weight: Theme.medium,
                                   color: GamePalette.textPlum.withAlphaComponent(on ? 0.7 : 0.45))
        detail.horizontalAlignmentMode = .left; detail.position = CGPoint(x: tx, y: -11 * uiScale)
        node.addChild(detail)

        if on {
            let chk = UIBuild.label("✓", size: 22 * uiScale, weight: Theme.heavy,
                                    color: UIColor(red: 0.30, green: 0.66, blue: 0.52, alpha: 1))
            chk.position = CGPoint(x: width / 2 - 24 * uiScale, y: 0)
            node.addChild(chk)
        }
        return node
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        if nodes(at: p).contains(where: { $0.name == "back" }) { goBack(); return }
        startTouchY = p.y; startOffset = scrollOffset; moved = false
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, maxScroll > 0 else { return }
        let y = t.location(in: self).y
        if abs(y - startTouchY) > 8 { moved = true }
        scrollOffset = min(maxScroll, max(0, startOffset + (y - startTouchY)))
        content.position.y = contentTopY + scrollOffset
    }

    private func goBack() {
        let s = SettingsScene(size: size); s.scaleMode = .resizeFill
        view?.presentScene(s, transition: .push(with: .right, duration: 0.35))
    }
}
