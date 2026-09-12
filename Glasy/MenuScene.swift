import SpriteKit

final class MenuScene: SKScene {

    private var settingsBtn = SKNode()
    private var removeAdsBtn = SKNode()
    private var busy = false

    private let heartsBox = SKNode()
    private var livesInfo = SKLabelNode()
    private var coinLabel = SKLabelNode()
    private let gate = SKNode()
    private let reward = SKNode()
    private let shop = SKNode()
    private var lastTick: TimeInterval = 0
    private var uiScale: CGFloat = 1

    override func didMove(to view: SKView) {
        SoundManager.shared.configureSession()
        SoundManager.shared.startMusic()
        uiScale = Layout.scale(size)
        SceneFX.addBackground(to: self)
        build()
        if LoginReward.isClaimableToday && Wallet.maxLevel > 1 { showLoginReward() }
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard view != nil, !children.isEmpty, oldSize != .zero else { return }
        uiScale = Layout.scale(size)
        heartsBox.removeAllChildren(); gate.removeAllChildren(); reward.removeAllChildren(); shop.removeAllChildren()
        removeAllChildren()
        SceneFX.addBackground(to: self)
        build()
    }

    private func build() {
        let cx = size.width / 2
        let topSafe = view?.safeAreaInsets.top ?? 24

        let gem = UIBuild.label("💎", size: 16 * uiScale, weight: Theme.heavy)
        gem.position = CGPoint(x: size.width - 80 * uiScale, y: size.height - topSafe - 30 * uiScale)
        gem.name = "coinshop"
        addChild(gem)
        coinLabel = UIBuild.label("\(Wallet.coins)", size: 18 * uiScale, color: GamePalette.textPlum)
        coinLabel.horizontalAlignmentMode = .left
        coinLabel.position = CGPoint(x: size.width - 64 * uiScale, y: size.height - topSafe - 32 * uiScale)
        addChild(coinLabel)
        let plus = UIBuild.label("+", size: 20 * uiScale, weight: Theme.heavy, color: UIColor(red: 0.44, green: 0.82, blue: 0.74, alpha: 1))
        plus.position = CGPoint(x: size.width - 24 * uiScale, y: size.height - topSafe - 30 * uiScale)
        plus.name = "coinshop"; addChild(plus)
        let coinHit = SKShapeNode(rectOf: CGSize(width: 130 * uiScale, height: 56 * uiScale))
        coinHit.fillColor = .clear; coinHit.strokeColor = .clear; coinHit.name = "coinshop"
        coinHit.position = CGPoint(x: size.width - 60 * uiScale, y: size.height - topSafe - 26 * uiScale)
        addChild(coinHit)

        let glow = SKShapeNode(circleOfRadius: 70 * uiScale)
        glow.fillColor = UIColor(red: 1, green: 0.82, blue: 0.92, alpha: 0.30)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: cx, y: size.height * 0.74)
        glow.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 1.6), .scale(to: 1.0, duration: 1.6)])))
        addChild(glow)

        let title = UIBuild.label("Glasy", size: 52 * uiScale, weight: Theme.heavy, color: GamePalette.textPlum)
        title.position = CGPoint(x: cx, y: size.height * 0.74)
        addChild(title)

        let sub = UIBuild.label("aynaları döndür, ışığı yönlendir", size: 17 * uiScale,
                                color: GamePalette.textPlum.withAlphaComponent(0.78))
        sub.position = CGPoint(x: cx, y: size.height * 0.74 - 48 * uiScale)
        addChild(sub)

        heartsBox.position = CGPoint(x: cx, y: size.height * 0.62)
        addChild(heartsBox)
        livesInfo = UIBuild.label("", size: 15 * uiScale, weight: Theme.medium,
                                  color: GamePalette.textPlum.withAlphaComponent(0.7))
        livesInfo.position = CGPoint(x: cx, y: size.height * 0.62 - 28 * uiScale)
        addChild(livesInfo)

        gate.zPosition = 300
        addChild(gate)
        reward.zPosition = 350
        addChild(reward)
        shop.zPosition = 360
        addChild(shop)
        refreshLives()

        let cont = UIBuild.pill(text: "Oyna  ·  Bölüm \(Wallet.level)", width: 280 * uiScale, height: 64 * uiScale,
                                fill: UIColor(red: 0.78, green: 0.66, blue: 0.95, alpha: 0.95),
                                line: .white, textColor: .white, fontSize: 22 * uiScale,
                                weight: Theme.heavy, name: "continue")
        cont.position = CGPoint(x: cx, y: size.height * 0.46)
        addChild(cont)

        let levels = UIBuild.pill(text: "Bölümler", width: 220 * uiScale, height: 50 * uiScale,
                                  fill: GamePalette.panel, line: GamePalette.tileLine, textColor: GamePalette.textPlum,
                                  fontSize: 18 * uiScale, name: "levels")
        levels.position = CGPoint(x: cx, y: size.height * 0.46 - 70 * uiScale)
        addChild(levels)

        let done = Daily.isDoneToday
        let daily = UIBuild.pill(text: done ? "🗓️ Günlük ✓   🔥 \(Daily.streak)" : "🗓️ Günlük Bulmaca  ·  +\(Daily.reward) 💎",
                                 width: 280 * uiScale, height: 56 * uiScale,
                                 fill: done ? GamePalette.panel : GamePalette.amber,
                                 line: done ? GamePalette.tileLine : .white,
                                 textColor: done ? GamePalette.textPlum : GamePalette.amberText,
                                 fontSize: 18 * uiScale, name: "daily")
        daily.position = CGPoint(x: cx, y: size.height * 0.46 - 144 * uiScale)
        addChild(daily)

        settingsBtn = UIBuild.pill(text: "⚙  Ayarlar", width: 134 * uiScale, height: 48 * uiScale,
                                   fill: GamePalette.panel, line: GamePalette.tileLine, textColor: GamePalette.textPlum,
                                   fontSize: 16 * uiScale, name: "settings")
        settingsBtn.position = CGPoint(x: cx - 72 * uiScale, y: size.height * 0.46 - 216 * uiScale)
        addChild(settingsBtn)

        removeAdsBtn = UIBuild.pill(text: "Reklamsız", width: 134 * uiScale, height: 48 * uiScale,
                                    fill: GamePalette.panel, line: GamePalette.tileLine, textColor: GamePalette.textPlum,
                                    fontSize: 16 * uiScale, name: "removeads")
        removeAdsBtn.position = CGPoint(x: cx + 72 * uiScale, y: size.height * 0.46 - 216 * uiScale)
        removeAdsBtn.isHidden = Wallet.adsRemoved
        addChild(removeAdsBtn)
    }

    private func refreshLives() {
        heartsBox.removeAllChildren()
        heartsBox.addChild(UIBuild.heartsRow(lives: Wallet.lives, size: 24 * uiScale, spacing: 30 * uiScale))
        if Wallet.lives >= Lives.maxLives {
            livesInfo.text = "Canların dolu  ·  kaybedince azalır"
        } else {
            let s = Wallet.secondsToNextLife
            livesInfo.text = String(format: "Kaybedince −1 ♥  ·  +1 can: %02d:%02d", s / 60, s % 60)
        }
    }

    override func update(_ currentTime: TimeInterval) {
        if currentTime - lastTick >= 1 {
            lastTick = currentTime
            refreshLives()
            if let c = gate.childNode(withName: "lg_count") as? SKLabelNode { c.text = LivesGate.countdownText() }
        }
    }

    private func watchAdForLife() {
        guard AdManager.shared.isRewardedReady else { toast("Reklam şu an hazır değil, biraz sonra tekrar dene"); return }
        busy = true
        AdManager.shared.showRewarded(reason: "life") { [weak self] ok in
            guard let self else { return }
            self.busy = false
            if ok { Wallet.addLife(); self.refreshLives(); self.gate.removeAllChildren() }
            else { self.toast("Reklam tamamlanmadı") }
        }
    }

    private func toast(_ text: String) {
        let t = UIBuild.label(text, size: 15 * uiScale, weight: Theme.heavy, color: .white)
        let pad: CGFloat = 18 * uiScale
        let bg = SKShapeNode(rectOf: CGSize(width: t.frame.width + pad * 2, height: 44 * uiScale), cornerRadius: 22 * uiScale)
        bg.fillColor = UIColor(red: 0.42, green: 0.36, blue: 0.60, alpha: 0.96); bg.strokeColor = .clear
        bg.position = CGPoint(x: size.width / 2, y: (view?.safeAreaInsets.bottom ?? 16) + 80 * uiScale); bg.zPosition = 500
        t.position = bg.position; t.zPosition = 501
        addChild(bg); addChild(t)
        let fade = SKAction.sequence([.wait(forDuration: 1.6), .fadeOut(withDuration: 0.4), .removeFromParent()])
        bg.run(fade); t.run(fade)
    }

    private func buyLifeWithCoins() {
        guard Wallet.spend(Costs.life) else { return }
        Wallet.addLife()
        refreshLives()
        gate.removeAllChildren()
        coinLabel.text = "\(Wallet.coins)"
    }



    private func showLoginReward() {
        reward.removeAllChildren()
        let cx = size.width / 2, cy = size.height / 2
        let panelH: CGFloat = 300 * uiScale
        let panelW = min(size.width - 32 * uiScale, 460 * uiScale)

        let dim = SKSpriteNode(color: UIColor(white: 0.35, alpha: 0.45), size: size)
        dim.position = CGPoint(x: cx, y: cy)
        reward.addChild(dim)

        let panel = SKShapeNode(rectOf: CGSize(width: panelW, height: panelH), cornerRadius: 28)
        panel.fillColor = UIColor(white: 1, alpha: 0.98); panel.strokeColor = GamePalette.tileLine; panel.lineWidth = 1
        panel.position = CGPoint(x: cx, y: cy)
        reward.addChild(panel)

        let title = UIBuild.label("Günlük Giriş Ödülü 🎁", size: 21 * uiScale, weight: Theme.heavy, color: GamePalette.textPlum)
        title.position = CGPoint(x: cx, y: cy + panelH / 2 - 38 * uiScale)
        reward.addChild(title)

        let pending = LoginReward.pendingDay
        let stripW = panelW - 24 * uiScale
        let cellW = stripW / 7
        let startX = cx - stripW / 2 + cellW / 2
        for i in 0..<7 {
            let day = i + 1, isToday = day == pending, claimed = day < pending
            let x = startX + CGFloat(i) * cellW
            let box = SKShapeNode(rectOf: CGSize(width: cellW - 4 * uiScale, height: 72 * uiScale), cornerRadius: 10 * uiScale)
            box.fillColor = isToday ? GamePalette.amber
                          : (claimed ? UIColor(red: 0.62, green: 0.86, blue: 0.70, alpha: 0.55) : GamePalette.panel)
            box.strokeColor = isToday ? .white : GamePalette.tileLine
            box.lineWidth = isToday ? 2.5 : 1
            box.position = CGPoint(x: x, y: cy + 12 * uiScale)
            reward.addChild(box)

            let dayL = UIBuild.label("\(day)", size: 11 * uiScale, weight: Theme.medium,
                                     color: isToday ? .white : GamePalette.textPlum.withAlphaComponent(0.7))
            dayL.position = CGPoint(x: x, y: cy + 36 * uiScale)
            reward.addChild(dayL)

            let r = LoginReward.cycle[i]
            let rewardColor: UIColor = isToday ? .white : GamePalette.textPlum
            let icon = UIBuild.label(r.lives > 0 ? "♥" : "💎", size: 12 * uiScale,
                                     weight: Theme.heavy, color: rewardColor)
            icon.position = CGPoint(x: x, y: cy + 10 * uiScale)
            reward.addChild(icon)
            let amount = UIBuild.label("\(r.lives > 0 ? r.lives : r.coins)", size: 11 * uiScale,
                                       weight: Theme.heavy, color: rewardColor)
            amount.position = CGPoint(x: x, y: cy - 8 * uiScale)
            reward.addChild(amount)

            if claimed {
                let chk = UIBuild.label("✓", size: 14 * uiScale, weight: Theme.heavy,
                                        color: UIColor(red: 0.27, green: 0.58, blue: 0.40, alpha: 1))
                chk.position = CGPoint(x: x, y: cy - 22 * uiScale)
                reward.addChild(chk)
            }
        }

        let r = LoginReward.cycle[pending - 1]
        let claimText = r.lives > 0 ? "Al   →   ♥ \(r.lives) can" : "Al   →   💎 \(r.coins) coin"
        let btn = UIBuild.pill(text: claimText, width: panelW - 40 * uiScale, height: 54 * uiScale,
                               fill: UIColor(red: 0.78, green: 0.66, blue: 0.95, alpha: 0.95),
                               line: .white, textColor: .white, fontSize: 19 * uiScale, name: "lr_claim")
        btn.position = CGPoint(x: cx, y: cy - panelH / 2 + 44 * uiScale)
        reward.addChild(btn)
    }

    private func claimLoginReward() {
        let r = LoginReward.claim()
        coinLabel.text = "\(Wallet.coins)"
        refreshLives()
        reward.removeAllChildren()
        let txt = r.lives > 0 ? "+\(r.lives) ♥" : "+\(r.coins) 💎"
        let tag = UIBuild.label(txt, size: 20, weight: Theme.heavy,
                                color: UIColor(red: 0.36, green: 0.55, blue: 0.50, alpha: 1))
        tag.position = CGPoint(x: size.width / 2, y: size.height / 2)
        tag.zPosition = 360
        addChild(tag)
        tag.run(.sequence([.group([.moveBy(x: 0, y: 40, duration: 0.9), .fadeOut(withDuration: 0.9)]),
                           .removeFromParent()]))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let names = nodes(at: t.location(in: self)).compactMap { $0.name }

        if !reward.children.isEmpty {
            if names.contains("lr_claim") { claimLoginReward() }
            return
        }
        if !gate.children.isEmpty {
            if names.contains("lg_coins") { buyLifeWithCoins() }
            else if names.contains("lg_ad") { watchAdForLife() }
            else if names.contains("lg_close") { gate.removeAllChildren() }
            return
        }
        if !shop.children.isEmpty {
            if names.contains("cs_ad") { shopWatchAd() }
            else if let p = names.first(where: { $0.hasPrefix("cs_pack_") }), let i = Int(p.dropFirst(8)) { shopBuy(i) }
            else if names.contains("cs_close") { shop.removeAllChildren() }
            return
        }
        if busy { return }

        if names.contains("coinshop") { showCoinShop() }
        else if names.contains("continue") { play(level: Wallet.level) }
        else if names.contains("daily") { playDaily() }
        else if names.contains("levels") { presentLevelSelect() }
        else if names.contains("settings") { presentSettings() }
        else if names.contains("removeads") { buyRemoveAds() }
    }

    private func presentSettings() {
        let s = SettingsScene(size: size)
        s.scaleMode = .resizeFill
        view?.presentScene(s, transition: .push(with: .left, duration: 0.35))
    }

    private func buyRemoveAds() {
        busy = true
        StoreManager.shared.purchaseRemoveAds { [weak self] ok in
            guard let self else { return }
            self.busy = false
            if ok { self.removeAdsBtn.isHidden = true; self.toast("✓ Reklamlar kaldırıldı") }
        }
    }



    private func showCoinShop() {
        shop.removeAllChildren()
        let cx = size.width / 2, cy = size.height / 2
        let panelW = min(size.width - 50, 470 * uiScale)
        let panelH: CGFloat = 470 * uiScale

        let dim = SKSpriteNode(color: UIColor(white: 0.35, alpha: 0.45), size: size)
        dim.position = CGPoint(x: cx, y: cy); dim.name = "cs_close"; shop.addChild(dim)
        let panel = SKShapeNode(rectOf: CGSize(width: panelW, height: panelH), cornerRadius: 28)
        panel.fillColor = UIColor(white: 1, alpha: 0.98); panel.strokeColor = GamePalette.tileLine; panel.lineWidth = 1
        panel.position = CGPoint(x: cx, y: cy); shop.addChild(panel)

        let title = UIBuild.label("Coin Mağazası 💎", size: 22 * uiScale, weight: Theme.heavy, color: GamePalette.textPlum)
        title.position = CGPoint(x: cx, y: cy + panelH / 2 - 42 * uiScale); shop.addChild(title)
        let bal = UIBuild.label("Coin'in: \(Wallet.coins)", size: 14 * uiScale, weight: Theme.medium,
                                color: GamePalette.textPlum.withAlphaComponent(0.7))
        bal.position = CGPoint(x: cx, y: cy + panelH / 2 - 72 * uiScale); shop.addChild(bal)

        let rowW = panelW - 56 * uiScale
        var y = cy + panelH / 2 - 128 * uiScale
        shop.addChild(shopRow(title: "▶  Reklam izle (ücretsiz)", value: "+\(StoreProductCatalog.adReward) 💎", name: "cs_ad",
                              accent: UIColor(red: 0.55, green: 0.45, blue: 0.85, alpha: 1),
                              at: CGPoint(x: cx, y: y), w: rowW,
                              fill: UIColor(red: 0.95, green: 0.93, blue: 1.0, alpha: 1),
                              border: UIColor(red: 0.70, green: 0.62, blue: 0.92, alpha: 0.6), borderW: 1.5))
        y -= 78 * uiScale
        for (i, pack) in StoreProductCatalog.coins.enumerated() {
            let best = pack.tag == "EN İYİ"
            let label = "💎  \(pack.coins)" + pack.tag.map { "   ·  \($0)" }.orEmpty
            let price = StoreManager.shared.price(pack.id) ?? pack.fallback
            shop.addChild(shopRow(title: label, value: price, name: "cs_pack_\(i)",
                                  accent: UIColor(red: 0.30, green: 0.66, blue: 0.52, alpha: 1),
                                  at: CGPoint(x: cx, y: y), w: rowW,
                                  fill: best ? UIColor(red: 0.93, green: 0.98, blue: 0.94, alpha: 1) : GamePalette.panel,
                                  border: best ? UIColor(red: 0.30, green: 0.66, blue: 0.52, alpha: 1) : GamePalette.tileLine,
                                  borderW: best ? 2 : 1))
            y -= 70 * uiScale
        }
        let close = UIBuild.pill(text: "Kapat", width: rowW, height: 50 * uiScale,
                                 fill: GamePalette.panel, line: GamePalette.tileLine, textColor: GamePalette.textPlum,
                                 fontSize: 17 * uiScale, name: "cs_close")
        close.position = CGPoint(x: cx, y: cy - panelH / 2 + 44 * uiScale); shop.addChild(close)
    }

    private func shopRow(title: String, value: String, name: String, accent: UIColor, at p: CGPoint, w: CGFloat,
                         fill: UIColor = GamePalette.panel, border: UIColor = GamePalette.tileLine, borderW: CGFloat = 1) -> SKNode {
        let node = SKNode(); node.position = p; node.name = name
        let bg = SKShapeNode(rectOf: CGSize(width: w, height: 56 * uiScale), cornerRadius: 16 * uiScale)
        bg.fillColor = fill; bg.strokeColor = border; bg.lineWidth = borderW; bg.name = name
        node.addChild(bg)
        let l = UIBuild.label(title, size: 16 * uiScale, weight: Theme.medium, color: GamePalette.textPlum)
        l.horizontalAlignmentMode = .left; l.position = CGPoint(x: -w / 2 + 20 * uiScale, y: 0); l.name = name
        node.addChild(l)
        let v = UIBuild.label(value, size: 16 * uiScale, weight: Theme.heavy, color: accent)
        v.horizontalAlignmentMode = .right; v.position = CGPoint(x: w / 2 - 20 * uiScale, y: 0); v.name = name
        node.addChild(v)
        return node
    }

    private func shopWatchAd() {
        guard !busy else { return }
        guard AdManager.shared.isRewardedReady else { toast("Reklam şu an hazır değil, biraz sonra tekrar dene"); return }
        busy = true
        AdManager.shared.showRewarded(reason: "coins") { [weak self] ok in
            guard let self else { return }
            self.busy = false
            if ok { Wallet.coins += StoreProductCatalog.adReward; self.coinLabel.text = "\(Wallet.coins)"; self.showCoinShop() }
            else { self.toast("Reklam tamamlanmadı") }
        }
    }

    private func shopBuy(_ i: Int) {
        guard i < StoreProductCatalog.coins.count, !busy else { return }
        busy = true
        StoreManager.shared.purchaseCoins(productID: StoreProductCatalog.coins[i].id) { [weak self] ok in
            guard let self else { return }
            self.busy = false
            if ok { self.coinLabel.text = "\(Wallet.coins)"; self.showCoinShop() }
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

    private func playDaily() {
        let g = GameScene(size: size)
        g.scaleMode = .resizeFill
        g.dailyMode = true
        view?.presentScene(g, transition: .fade(withDuration: 0.4))
    }

    private func presentLevelSelect() {
        let s = LevelSelectScene(size: size)
        s.scaleMode = .resizeFill
        view?.presentScene(s, transition: .push(with: .left, duration: 0.35))
    }
}
