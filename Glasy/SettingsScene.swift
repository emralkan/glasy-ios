import SpriteKit
import UIKit
import StoreKit

final class SettingsScene: SKScene {

    private let content = SKNode()
    private let crop = SKCropNode()
    private var contentTopY: CGFloat = 0
    private var visibleH: CGFloat = 0
    private var scrollOffset: CGFloat = 0
    private var maxScroll: CGFloat = 0

    private var startTouchY: CGFloat = 0
    private var startOffset: CGFloat = 0
    private var moved = false
    private var busy = false
    private var uiScale: CGFloat = 1

    private struct Row {
        let title: String; let name: String; let value: () -> (String, UIColor)
        var isOn: (() -> Bool)? = nil
    }

    override func didMove(to view: SKView) {
        uiScale = Layout.scale(size)
        SoundManager.shared.startMusic()
        SceneFX.addBackground(to: self)
        buildChrome()
        buildList()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard view != nil, !children.isEmpty, oldSize != .zero else { return }
        uiScale = Layout.scale(size)
        removeAllChildren()
        SceneFX.addBackground(to: self)
        buildChrome()
        buildList()
    }

    private func safeTop() -> CGFloat { view?.safeAreaInsets.top ?? 24 }
    private func safeBottom() -> CGFloat { view?.safeAreaInsets.bottom ?? 16 }



    private func buildChrome() {
        let title = UIBuild.label("Ayarlar", size: 28 * uiScale, weight: Theme.heavy, color: GamePalette.textPlum)
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

    private func onOff(_ on: Bool) -> (String, UIColor) {
        on ? ("Açık", UIColor(red: 0.30, green: 0.66, blue: 0.52, alpha: 1))
           : ("Kapalı", UIColor(white: 0.6, alpha: 1))
    }

    private func sections() -> [(String, [Row])] {
        var purchase: [Row] = []
        if !Wallet.adsRemoved {
            purchase.append(Row(title: "Banner Reklamlarını Kaldır", name: "remove_ads", value: { ("Satın al ›", GamePalette.amberText) }))
        }
        purchase.append(Row(title: "Satın Alımları Geri Yükle", name: "restore", value: { ("›", GamePalette.textPlum.withAlphaComponent(0.5)) }))

        var legal = [
            Row(title: "Gizlilik Politikası", name: "privacy", value: { ("›", GamePalette.textPlum.withAlphaComponent(0.5)) }),
            Row(title: "Kullanım Koşulları", name: "terms", value: { ("›", GamePalette.textPlum.withAlphaComponent(0.5)) }),
        ]
        if AdManager.shared.privacyOptionsRequired {
            legal.insert(Row(title: "Reklam Gizlilik Tercihleri", name: "privacy_options",
                             value: { ("›", GamePalette.textPlum.withAlphaComponent(0.5)) }), at: 0)
        }

        return [
            ("SES & TİTREŞİM", [
                Row(title: "Müzik", name: "set_music", value: { [self] in onOff(Wallet.musicOn) }, isOn: { Wallet.musicOn }),
                Row(title: "Ses Efektleri", name: "set_sfx", value: { [self] in onOff(Wallet.sfxOn) }, isOn: { Wallet.sfxOn }),
                Row(title: "Titreşim", name: "set_haptics", value: { [self] in onOff(Wallet.hapticsOn) }, isOn: { Wallet.hapticsOn }),
            ]),
            ("OYUN", [
                Row(title: "🏆 Başarımlar", name: "achievements",
                    value: { ("\(Achievements.unlockedCount)/\(Achievements.all.count)  ›", GamePalette.textPlum.withAlphaComponent(0.6)) }),
                Row(title: "Eğitimi Tekrar Göster", name: "replay_tutorial", value: { ("›", GamePalette.textPlum.withAlphaComponent(0.5)) }),
            ]),
            ("SATIN ALMA", purchase),
            ("DESTEK", [
                Row(title: "Yardım & Destek", name: "help", value: { ("✉︎", GamePalette.textPlum.withAlphaComponent(0.6)) }),
                Row(title: "Uygulamayı Değerlendir", name: "rate", value: { ("★", GamePalette.amber) }),
            ]),
            ("YASAL", legal),
        ]
    }

    private func buildList() {
        crop.removeFromParent()
        content.removeAllChildren()

        contentTopY = size.height - safeTop() - 78 * uiScale
        let bottomY = safeBottom() + 24 * uiScale
        visibleH = contentTopY - bottomY
        let side = 24 * uiScale
        let width = size.width - side * 2
        let cx = size.width / 2
        let rowH = 56 * uiScale, gap = 10 * uiScale

        var y: CGFloat = -gap
        for (header, rows) in sections() where !rows.isEmpty {
            let h = UIBuild.label(header, size: 12 * uiScale, weight: Theme.heavy,
                                  color: GamePalette.textPlum.withAlphaComponent(0.6))
            h.horizontalAlignmentMode = .left
            h.position = CGPoint(x: cx - width / 2 + 8 * uiScale, y: y - 14 * uiScale)
            content.addChild(h)
            y -= 34 * uiScale
            for row in rows {
                content.addChild(rowNode(row, at: CGPoint(x: cx, y: y - rowH / 2), width: width, height: rowH))
                y -= rowH + gap
            }
            y -= 8 * uiScale
        }

        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        let footer = UIBuild.label("Glasy  v\(v) (\(b))   ·   © 2026 Emre Alkan", size: 12 * uiScale,
                                   weight: Theme.medium, color: GamePalette.textPlum.withAlphaComponent(0.4))
        footer.position = CGPoint(x: cx, y: y - 16 * uiScale)
        content.addChild(footer)
        y -= 40 * uiScale

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

    private func rowNode(_ row: Row, at p: CGPoint, width: CGFloat, height: CGFloat) -> SKNode {
        let node = SKNode(); node.position = p; node.name = row.name
        node.isAccessibilityElement = true
        node.accessibilityLabel = row.title
        node.accessibilityValue = row.isOn?() == true ? "Açık" : (row.isOn == nil ? nil : "Kapalı")
        node.accessibilityTraits = row.isOn?() == true ? [.button, .selected] : .button
        let bg = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 16 * uiScale)
        bg.fillColor = GamePalette.panel; bg.strokeColor = GamePalette.tileLine; bg.lineWidth = 1; bg.name = row.name
        node.addChild(bg)
        let label = UIBuild.label(row.title, size: 17 * uiScale, weight: Theme.medium, color: GamePalette.textPlum)
        label.horizontalAlignmentMode = .left
        label.position = CGPoint(x: -width / 2 + 20 * uiScale, y: 0); label.name = row.name
        node.addChild(label)

        if let on = row.isOn?() {
            let sw = toggleSwitch(on: on)
            sw.position = CGPoint(x: width / 2 - 44 * uiScale, y: 0); sw.name = row.name
            sw.children.forEach { $0.name = row.name }
            node.addChild(sw)
        } else {
            let (text, color) = row.value()
            let value = UIBuild.label(text, size: 16 * uiScale, weight: Theme.heavy, color: color)
            value.horizontalAlignmentMode = .right
            value.position = CGPoint(x: width / 2 - 20 * uiScale, y: 0); value.name = row.name
            node.addChild(value)
        }
        return node
    }

    private func toggleSwitch(on: Bool) -> SKNode {
        let n = SKNode()
        let tw = 50 * uiScale, th = 30 * uiScale
        let track = SKShapeNode(rectOf: CGSize(width: tw, height: th), cornerRadius: th / 2)
        track.fillColor = on ? UIColor(red: 0.40, green: 0.78, blue: 0.55, alpha: 1) : UIColor(white: 0.80, alpha: 1)
        track.strokeColor = .clear
        n.addChild(track)
        let knob = SKShapeNode(circleOfRadius: th / 2 - 3 * uiScale)
        knob.fillColor = .white; knob.strokeColor = UIColor(white: 0, alpha: 0.08); knob.lineWidth = 1
        knob.position = CGPoint(x: on ? (tw / 2 - th / 2) : -(tw / 2 - th / 2), y: 0)
        n.addChild(knob)
        return n
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

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, !moved, !busy else { return }
        let names = nodes(at: t.location(in: self)).compactMap { $0.name }
        guard let name = names.first(where: { $0 != "back" }) else { return }
        dispatch(name)
    }

    private func dispatch(_ name: String) {
        switch name {
        case "set_music":   SoundManager.shared.setMusic(on: !Wallet.musicOn); rebuild()
        case "set_sfx":     SoundManager.shared.setSFX(on: !Wallet.sfxOn); rebuild()
        case "set_haptics":
            Wallet.hapticsOn.toggle()
            if Wallet.hapticsOn { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            rebuild()
        case "achievements":
            let s = AchievementsScene(size: size); s.scaleMode = .resizeFill
            view?.presentScene(s, transition: .push(with: .left, duration: 0.35))
        case "replay_tutorial":
            Tutorial.resetAll(); toast("Eğitim bir sonraki bölümde gösterilecek")
        case "remove_ads":
            busy = true
            StoreManager.shared.purchaseRemoveAds { [weak self] ok in
                self?.busy = false
                if ok { self?.toast("Reklamlar kaldırıldı"); self?.rebuild() }
            }
        case "restore":
            busy = true
            StoreManager.shared.restorePurchases { [weak self] ok in
                self?.busy = false
                self?.toast(ok ? "Satın alımlar geri yüklendi" : "Geri yüklenecek bir şey yok")
                self?.rebuild()
            }
        case "help":    openURL("mailto:\(Support.email)?subject=Glasy%20Destek")
        case "rate":    requestRate()
        case "privacy": openURL(Support.privacyURL)
        case "terms":   openURL(Support.termsURL)
        case "privacy_options":
            busy = true
            AdManager.shared.presentPrivacyOptions { [weak self] ok in
                self?.busy = false
                self?.toast(ok ? "Gizlilik tercihlerin güncellendi" : "Gizlilik formu şu an açılamadı")
                self?.rebuild()
            }
        default: break
        }
    }

    private func rebuild() { buildList() }

    private func openURL(_ s: String) {
        guard let url = URL(string: s) else { return }
        UIApplication.shared.open(url)
    }

    private func requestRate() {
        if let scene = view?.window?.windowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }

    private func toast(_ text: String) {
        let t = UIBuild.label(text, size: 16 * uiScale, weight: Theme.heavy, color: .white)
        let pad: CGFloat = 18 * uiScale
        let bg = SKShapeNode(rectOf: CGSize(width: t.frame.width + pad * 2, height: 44 * uiScale), cornerRadius: 22 * uiScale)
        bg.fillColor = UIColor(red: 0.42, green: 0.36, blue: 0.60, alpha: 0.96); bg.strokeColor = .clear
        bg.position = CGPoint(x: size.width / 2, y: safeBottom() + 90 * uiScale); bg.zPosition = 400
        t.position = bg.position; t.zPosition = 401
        addChild(bg); addChild(t)
        let fade = SKAction.sequence([.wait(forDuration: 1.4), .fadeOut(withDuration: 0.4), .removeFromParent()])
        bg.run(fade); t.run(fade)
    }

    private func goBack() {
        let m = MenuScene(size: size)
        m.scaleMode = .resizeFill
        view?.presentScene(m, transition: .push(with: .right, duration: 0.35))
    }
}
