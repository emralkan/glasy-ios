import SpriteKit
import UIKit

// MARK: - Renk Paleti

enum GamePalette {
    static let textPlum  = UIColor(red: 0.41, green: 0.34, blue: 0.59, alpha: 1)
    static let tileFill  = UIColor(white: 1, alpha: 0.55)
    static let tileLine  = UIColor(red: 0.72, green: 0.66, blue: 0.88, alpha: 0.30)
    static let wallFill  = UIColor(red: 0.86, green: 0.83, blue: 0.93, alpha: 1)
    static let wallLine  = UIColor(red: 0.78, green: 0.73, blue: 0.90, alpha: 1)
    static let mirrorFill = UIColor(white: 1, alpha: 0.92)
    static let mirrorLine = UIColor(red: 0.79, green: 0.74, blue: 0.92, alpha: 1)
    static let mirrorBar  = UIColor(red: 0.60, green: 0.65, blue: 0.85, alpha: 1)
    static let panel      = UIColor(white: 1, alpha: 0.82)
    static let amber      = UIColor(red: 0.95, green: 0.78, blue: 0.47, alpha: 1)
    static let amberText  = UIColor(red: 0.79, green: 0.54, blue: 0.18, alpha: 1)

    static func core(_ c: LightColor) -> UIColor {
        switch c {
        case .red:    return UIColor(red: 1.00, green: 0.56, blue: 0.64, alpha: 1)
        case .blue:   return UIColor(red: 0.56, green: 0.79, blue: 0.96, alpha: 1)
        case .yellow: return UIColor(red: 0.96, green: 0.81, blue: 0.40, alpha: 1)
        }
    }
    static func mixColor(_ set: Set<LightColor>) -> UIColor {
        switch Set(set) {
        case [.red]:            return core(.red)
        case [.blue]:           return core(.blue)
        case [.yellow]:         return core(.yellow)
        case [.red, .blue]:     return UIColor(red: 0.77, green: 0.63, blue: 0.93, alpha: 1)
        case [.blue, .yellow]:  return UIColor(red: 0.56, green: 0.85, blue: 0.66, alpha: 1)
        case [.red, .yellow]:   return UIColor(red: 0.98, green: 0.70, blue: 0.42, alpha: 1)
        default:                return UIColor(red: 0.93, green: 0.90, blue: 0.97, alpha: 1)
        }
    }
}

final class GameScene: SKScene {

    private var cell: CGFloat = 44
    private var uiScale: CGFloat = 1
    private var gridLeft: CGFloat = 0
    private var gridBottom: CGFloat = 0
    private var gridPixH: CGFloat = 0

    var startLevel: Int = 0
    var dailyMode = false
    private var level: Level!
    private var busy = false

    private let boardNode = SKNode()
    private let beamNode = SKNode()
    private var mirrorBars: [GridCoordinate: SKShapeNode] = [:]
    private var halfMirrorBars: [GridCoordinate: SKShapeNode] = [:]
    private var halfMirrorSheens: [GridCoordinate: SKShapeNode] = [:]
    private var targetCores: [GridCoordinate: SKNode] = [:]
    private var targetHalos: [GridCoordinate: SKShapeNode] = [:]
    private var targetAims: [GridCoordinate: SKShapeNode] = [:]

    private var levelLabel = SKLabelNode()
    private var coinLabel = SKLabelNode()
    private var movesLabel = SKLabelNode()
    private var perfectLabel = SKLabelNode()
    private var targetCountLabel = SKLabelNode()
    private let heartsBox = SKNode()
    private let overlay = SKNode()
    private let tutorialLayer = SKNode()
    private var introActive = false
    private var cardActive = false
    private var welcomeActive = false
    private var chooserCost = 0
    private var chooserReason = ""
    private var chooserGranted: (() -> Void)?
    private var movesLeft = 0
    private var shownLevel = 1
    private var hintsUsed = 0
    private var topY: CGFloat = 0
    private var movesMade = 0
    private var pendingMechanicKey: String?
    private var undoButton = SKNode()
    private struct MoveSnapshot {
        let full: [GridCoordinate: MirrorOrientation]
        let half: [GridCoordinate: MirrorState]
        let movesLeft: Int
    }
    private var moveHistory: [MoveSnapshot] = []



    override func didMove(to view: SKView) {
        SoundManager.shared.startMusic()
        uiScale = Layout.scale(size)
        buildBackground()
        buildChrome()
        if dailyMode {
            loadDaily()
        } else {
            let n = startLevel > 0 ? startLevel : Wallet.level
            Wallet.level = n
            loadLevel(n)
        }
    }

    private func loadDaily() {
        level = LevelGenerator.generate(level: Daily.levelNumber, seed: Daily.seed)
        levelLabel.text = "Günlük 🗓️"
        shownLevel = Daily.levelNumber; hintsUsed = 0; movesMade = 0; moveHistory.removeAll()
        movesLeft = level.moveLimit
        clearOverlay(); layoutGrid(); buildBoard(); recomputeBeams(); updateMoves(); updateHearts()
        updateUndoButton()
    }

    private func safeTop() -> CGFloat { view?.safeAreaInsets.top ?? 24 }
    private func safeBottom() -> CGFloat { view?.safeAreaInsets.bottom ?? 16 }

    private func buildBackground() {
        let tex = gradientTexture(size: size,
                                  top: UIColor(red: 0.95, green: 0.92, blue: 1.00, alpha: 1),
                                  mid: UIColor(red: 0.99, green: 0.94, blue: 0.97, alpha: 1),
                                  bottom: UIColor(red: 0.91, green: 0.95, blue: 1.00, alpha: 1))
        let bg = SKSpriteNode(texture: tex, size: size)
        bg.position = CGPoint(x: size.width / 2, y: size.height / 2)
        bg.zPosition = -100
        addChild(bg)

        for _ in 0..<7 {
            let r = CGFloat.random(in: 18...46)
            let b = SKShapeNode(circleOfRadius: r)
            let tint: [UIColor] = [UIColor(red: 1, green: 0.78, blue: 0.90, alpha: 0.18),
                                   UIColor(red: 0.75, green: 0.85, blue: 1, alpha: 0.18),
                                   UIColor(red: 0.85, green: 0.80, blue: 1, alpha: 0.18)]
            b.fillColor = tint.randomElement()!
            b.strokeColor = .clear
            b.position = CGPoint(x: CGFloat.random(in: 0...size.width),
                                 y: CGFloat.random(in: 0...size.height))
            b.zPosition = -90
            let dy = CGFloat.random(in: 20...50)
            let dur = Double.random(in: 6...11)
            b.run(.repeatForever(.sequence([.moveBy(x: 0, y: dy, duration: dur),
                                            .moveBy(x: 0, y: -dy, duration: dur)])))
            addChild(b)
        }

        addChild(beamNode); beamNode.zPosition = 5
        addChild(boardNode)
    }



    // MARK: - Oyun Arayüzü

    private func buildChrome() {
        topY = size.height - safeTop() - 30 * uiScale

        levelLabel = makeLabel("", size: 24 * uiScale, weight: Theme.heavy)
        levelLabel.fontColor = GamePalette.textPlum
        levelLabel.position = CGPoint(x: size.width / 2, y: topY)
        levelLabel.zPosition = 100
        addChild(levelLabel)

        movesLabel = makeLabel("", size: 17 * uiScale, weight: Theme.heavy)
        movesLabel.position = CGPoint(x: size.width / 2, y: topY - 34 * uiScale)
        movesLabel.zPosition = 100
        addChild(movesLabel)

        perfectLabel = makeLabel("", size: 12 * uiScale, weight: Theme.medium)
        perfectLabel.fontColor = GamePalette.textPlum.withAlphaComponent(0.72)
        perfectLabel.position = CGPoint(x: size.width / 2, y: topY - 55 * uiScale)
        perfectLabel.zPosition = 100
        addChild(perfectLabel)

        targetCountLabel = makeLabel("", size: 16 * uiScale, weight: Theme.heavy)
        targetCountLabel.position = CGPoint(x: size.width - 64 * uiScale, y: topY - 34 * uiScale)
        targetCountLabel.zPosition = 100
        targetCountLabel.isHidden = true
        addChild(targetCountLabel)

        heartsBox.position = CGPoint(x: 56 * uiScale, y: topY - 34 * uiScale)
        heartsBox.zPosition = 100
        addChild(heartsBox)

        overlay.zPosition = 300
        addChild(overlay)

        tutorialLayer.zPosition = 250
        addChild(tutorialLayer)

        let gem = makeLabel("💎", size: 15 * uiScale, weight: Theme.heavy)
        gem.position = CGPoint(x: size.width - 72 * uiScale, y: topY + 2 * uiScale)
        gem.zPosition = 100
        addChild(gem)
        coinLabel = makeLabel("\(Wallet.coins)", size: 18 * uiScale, weight: Theme.medium)
        coinLabel.fontColor = GamePalette.textPlum
        coinLabel.horizontalAlignmentMode = .left
        coinLabel.position = CGPoint(x: size.width - 58 * uiScale, y: topY)
        coinLabel.zPosition = 100
        addChild(coinLabel)

        let back = makePill(text: "‹ Menü", width: 92 * uiScale, height: 34 * uiScale,
                            fill: GamePalette.panel, line: GamePalette.tileLine, textColor: GamePalette.textPlum,
                            fontSize: 15 * uiScale, name: "menu")
        back.position = CGPoint(x: 70 * uiScale, y: topY + 4 * uiScale)
        back.zPosition = 100
        addChild(back)

        let by = safeBottom() + 46 * uiScale
        var names = [("↶ Geri", "undo", GamePalette.tileLine, GamePalette.textPlum.withAlphaComponent(0.45)),
                     ("İpucu", "hint", GamePalette.amber, GamePalette.amberText)]
        if !dailyMode { names.append(("Atla", "skip", GamePalette.tileLine, GamePalette.textPlum)) }
        let bw: CGFloat = (names.count == 3 ? 94 : 102) * uiScale, gap: CGFloat = 10 * uiScale
        let totalW = bw * CGFloat(names.count) + gap * CGFloat(names.count - 1)
        var x = (size.width - totalW) / 2 + bw / 2
        for (title, name, line, txt) in names {
            let pill = makePill(text: title, width: bw, height: 50 * uiScale,
                                fill: GamePalette.panel, line: line, textColor: txt,
                                fontSize: 18 * uiScale, name: name)
            pill.position = CGPoint(x: x, y: by)
            pill.zPosition = 100
            addChild(pill)
            if name == "undo" { undoButton = pill }
            x += bw + gap
        }
        updateUndoButton()
    }



    // MARK: - Bölüm Akışı

    private func loadLevel(_ n: Int) {
        level = LevelGenerator.generate(level: n, seed: LevelGenerator.normalSeed)
        levelLabel.text = "Bölüm \(n)"
        shownLevel = n; hintsUsed = 0; movesMade = 0; moveHistory.removeAll()
        movesLeft = level.moveLimit
        clearOverlay()
        layoutGrid()
        buildBoard()
        recomputeBeams()
        updateMoves()
        updateHearts()
        maybeShowTutorial(n)
        updateUndoButton()
    }

    private func updateMoves() {
        movesLabel.text = "\(movesLeft) hamle"
        perfectLabel.text = "Mükemmel hedef: \(level.minMoves)"
        movesLabel.fontColor = movesLeft <= 2 ? UIColor(red: 0.90, green: 0.35, blue: 0.42, alpha: 1) : GamePalette.textPlum
    }
    private func updateHearts() {
        heartsBox.removeAllChildren()
        heartsBox.addChild(UIBuild.heartsRow(lives: Wallet.lives, size: 12 * uiScale, spacing: 14 * uiScale))
    }

    private func currentSnapshot() -> MoveSnapshot {
        var full: [GridCoordinate: MirrorOrientation] = [:], half: [GridCoordinate: MirrorState] = [:]
        for coord in level.mirrorCoords { if case .mirror(let o) = level.piece(coord) { full[coord] = o } }
        for coord in level.halfMirrorCoords { if case .halfMirror(let s) = level.piece(coord) { half[coord] = s } }
        return MoveSnapshot(full: full, half: half, movesLeft: movesLeft)
    }

    private func pushMoveSnapshot() {
        moveHistory.append(currentSnapshot())
        if moveHistory.count > 20 { moveHistory.removeFirst() }
    }

    private func undoLastMove() {
        guard !busy, let snapshot = moveHistory.popLast() else { haptic(.light); return }
        for (coord, orient) in snapshot.full { level.set(coord, .mirror(orient)) }
        for (coord, state) in snapshot.half { level.set(coord, .halfMirror(state)) }
        movesLeft = snapshot.movesLeft
        movesMade = max(0, movesMade - 1)
        for (coord, bar) in mirrorBars {
            if case .mirror(let o) = level.piece(coord) {
                bar.run(.rotate(toAngle: o == .slash ? .pi / 4 : -.pi / 4, duration: 0.12, shortestUnitArc: true))
            }
        }
        for coord in halfMirrorBars.keys {
            if case .halfMirror(let s) = level.piece(coord) { applyHalfMirrorVisual(coord, state: s, animated: true) }
        }
        updateMoves(); updateUndoButton(); recomputeBeams(); haptic(.light)
    }

    private func updateUndoButton() {
        undoButton.alpha = moveHistory.isEmpty ? 0.45 : 1
        undoButton.accessibilityValue = moveHistory.isEmpty ? "Kullanılamıyor" : "Son hamleyi geri al"
    }
    private func flashLifeLost() {
        heartsBox.run(.sequence([.scale(to: 1.25, duration: 0.1), .scale(to: 1.0, duration: 0.12)]))
        let tag = makeLabel("−1 ♥", size: 16, weight: Theme.heavy)
        tag.fontColor = UIColor(red: 0.90, green: 0.35, blue: 0.42, alpha: 1)
        tag.position = CGPoint(x: heartsBox.position.x, y: heartsBox.position.y - 20)
        tag.zPosition = 200
        addChild(tag)
        tag.run(.sequence([.group([.moveBy(x: 0, y: 24, duration: 0.8), .fadeOut(withDuration: 0.8)]),
                           .removeFromParent()]))
    }
    private func clearOverlay() { overlay.removeAllChildren() }

    private func layoutGrid() {
        let margin: CGFloat = 18 * uiScale
        let topBar = safeTop() + 96 * uiScale
        let bottomBar = safeBottom() + 96 * uiScale
        let availW = size.width - margin * 2
        let availH = size.height - topBar - bottomBar
        cell = min(availW / CGFloat(level.cols), availH / CGFloat(level.rows))
        cell = min(cell, 72 * uiScale)
        gridPixH = cell * CGFloat(level.rows)
        let gridPixW = cell * CGFloat(level.cols)
        gridLeft = (size.width - gridPixW) / 2
        gridBottom = bottomBar + (availH - gridPixH) / 2
    }

    private func gridToPixel(_ g: CGPoint) -> CGPoint {
        CGPoint(x: gridLeft + (g.x + 0.5) * cell,
                y: gridBottom + gridPixH - (g.y + 0.5) * cell)
    }
    private func cellCenter(_ x: GridCoordinate) -> CGPoint { gridToPixel(CGPoint(x: CGFloat(x.c), y: CGFloat(x.r))) }

    private func buildBoard() {
        boardNode.removeAllChildren()
        mirrorBars.removeAll(); halfMirrorBars.removeAll(); halfMirrorSheens.removeAll()
        targetCores.removeAll(); targetHalos.removeAll(); targetAims.removeAll()

        let inset: CGFloat = cell * 0.07
        let tileSize = cell - inset * 2

        for r in 0..<level.rows { for c in 0..<level.cols {
            let coord = GridCoordinate(c: c, r: r)
            let center = cellCenter(coord)

            let tile = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize), cornerRadius: tileSize * 0.26)
            tile.fillColor = GamePalette.tileFill
            tile.strokeColor = GamePalette.tileLine
            tile.lineWidth = 1
            tile.position = center
            tile.zPosition = 0
            boardNode.addChild(tile)

            switch level.piece(coord) {
            case .empty: break
            case .wall: addWall(at: center, size: tileSize)
            case .source(let dir, let col): addSource(at: center, size: tileSize, dir: dir, color: col)
            case .mirror(let o): addMirror(at: center, size: tileSize, orient: o, coord: coord)
            case .fixedMirror(let o): addFixedMirror(at: center, size: tileSize, orient: o)
            case .splitter(let o): addSplitter(at: center, size: tileSize, orient: o)
            case .filter(let col): addFilter(at: center, size: tileSize, color: col)
            case .glass: addGlass(at: center, size: tileSize)
            case .portal(let id): addPortal(at: center, size: tileSize, id: id)
            case .halfMirror(let s): addHalfMirror(at: center, size: tileSize, state: s, coord: coord)
            case .target(let set): addTarget(at: center, size: tileSize, set: set, coord: coord)
            }
        } }
    }

    private func addWall(at p: CGPoint, size s: CGFloat) {
        let w = SKShapeNode(rectOf: CGSize(width: s, height: s), cornerRadius: s * 0.26)
        w.fillColor = GamePalette.wallFill
        w.strokeColor = GamePalette.wallLine
        w.lineWidth = 1
        w.position = p
        w.zPosition = 10
        boardNode.addChild(w)
        for d in [-1, 1] {
            let dot = SKShapeNode(circleOfRadius: s * 0.05)
            dot.fillColor = GamePalette.wallLine
            dot.strokeColor = .clear
            dot.position = CGPoint(x: p.x + CGFloat(d) * s * 0.18, y: p.y)
            dot.zPosition = 11
            boardNode.addChild(dot)
        }
    }

    private func addSource(at p: CGPoint, size s: CGFloat, dir: BeamDirection, color: LightColor) {
        let glow = SKShapeNode(circleOfRadius: s * 0.5)
        glow.fillColor = GamePalette.core(color).withAlphaComponent(0.28)
        glow.strokeColor = .clear
        glow.position = p; glow.zPosition = 9
        boardNode.addChild(glow)

        let crystal = SKShapeNode(rectOf: CGSize(width: s * 0.62, height: s * 0.62), cornerRadius: s * 0.2)
        crystal.fillColor = GamePalette.core(color)
        crystal.strokeColor = .white; crystal.lineWidth = 2
        crystal.position = p; crystal.zPosition = 10
        boardNode.addChild(crystal)

        let inner = SKShapeNode(rectOf: CGSize(width: s * 0.3, height: s * 0.3), cornerRadius: s * 0.1)
        inner.fillColor = UIColor(white: 1, alpha: 0.8)
        inner.strokeColor = .clear
        inner.position = p; inner.zPosition = 11
        boardNode.addChild(inner)

        let arrow = SKShapeNode()
        let path = CGMutablePath()
        let a = s * 0.16
        path.move(to: CGPoint(x: -a, y: -a)); path.addLine(to: CGPoint(x: a, y: 0)); path.addLine(to: CGPoint(x: -a, y: a))
        arrow.path = path
        arrow.fillColor = GamePalette.core(color)
        arrow.strokeColor = .clear
        let off = s * 0.42
        arrow.position = CGPoint(x: p.x + CGFloat(dir.delta.c) * off, y: p.y - CGFloat(dir.delta.r) * off)
        arrow.zPosition = 12
        switch dir {
        case .right: arrow.zRotation = 0
        case .up:    arrow.zRotation = .pi / 2
        case .left:  arrow.zRotation = .pi
        case .down:  arrow.zRotation = -.pi / 2
        }
        boardNode.addChild(arrow)
    }

    private func addInteractiveAura(at p: CGPoint, size s: CGFloat) {
        let aura = SKShapeNode(rectOf: CGSize(width: s + cell * 0.12, height: s + cell * 0.12), cornerRadius: s * 0.32)
        aura.fillColor = GamePalette.amber.withAlphaComponent(0.16)
        aura.strokeColor = GamePalette.amber.withAlphaComponent(0.72)
        aura.lineWidth = 2
        aura.position = p; aura.zPosition = 9.5
        aura.run(.repeatForever(.sequence([
            .group([.scale(to: 1.05, duration: 1.0), .fadeAlpha(to: 0.62, duration: 1.0)]),
            .group([.scale(to: 1.0, duration: 1.0), .fadeAlpha(to: 1.0, duration: 1.0)])])))
        boardNode.addChild(aura)
    }

    private func addMirror(at p: CGPoint, size s: CGFloat, orient: MirrorOrientation, coord: GridCoordinate) {
        addInteractiveAura(at: p, size: s)
        let tile = SKShapeNode(rectOf: CGSize(width: s, height: s), cornerRadius: s * 0.26)
        tile.fillColor = GamePalette.mirrorFill
        tile.strokeColor = GamePalette.mirrorLine
        tile.lineWidth = 1.5
        tile.position = p; tile.zPosition = 10
        boardNode.addChild(tile)

        let bar = SKShapeNode(rectOf: CGSize(width: s * 0.74, height: s * 0.14), cornerRadius: s * 0.07)
        bar.fillColor = GamePalette.mirrorBar
        bar.strokeColor = UIColor(white: 1, alpha: 0.7); bar.lineWidth = 1
        bar.position = p; bar.zPosition = 12
        bar.zRotation = orient == .slash ? .pi / 4 : -.pi / 4
        boardNode.addChild(bar)
        mirrorBars[coord] = bar
    }

    private func addHalfMirror(at p: CGPoint, size s: CGFloat, state: MirrorState, coord: GridCoordinate) {
        addInteractiveAura(at: p, size: s)
        let tile = SKShapeNode(rectOf: CGSize(width: s, height: s), cornerRadius: s * 0.26)
        tile.fillColor = GamePalette.mirrorFill
        tile.strokeColor = GamePalette.mirrorLine; tile.lineWidth = 1.5
        tile.position = p; tile.zPosition = 10
        boardNode.addChild(tile)

        let bar = SKShapeNode(rectOf: CGSize(width: s * 0.76, height: s * 0.16), cornerRadius: s * 0.08)
        bar.fillColor = UIColor(red: 0.74, green: 0.83, blue: 0.96, alpha: 0.40)
        bar.strokeColor = UIColor(white: 1, alpha: 0.65); bar.lineWidth = 1
        bar.position = p; bar.zPosition = 12
        boardNode.addChild(bar)
        halfMirrorBars[coord] = bar

        let sheen = SKShapeNode(rectOf: CGSize(width: s * 0.7, height: s * 0.07), cornerRadius: s * 0.035)
        sheen.fillColor = GamePalette.mirrorBar
        sheen.strokeColor = UIColor(white: 1, alpha: 0.85); sheen.lineWidth = 0.5
        sheen.position = p; sheen.zPosition = 13
        boardNode.addChild(sheen)
        halfMirrorSheens[coord] = sheen

        applyHalfMirrorVisual(coord, state: state, animated: false)
    }

    private func applyHalfMirrorVisual(_ coord: GridCoordinate, state s: MirrorState, animated: Bool) {
        guard let bar = halfMirrorBars[coord], let sheen = halfMirrorSheens[coord] else { return }
        let angle: CGFloat = s.orient == .slash ? .pi / 4 : -.pi / 4
        let perp = CGVector(dx: -sin(angle), dy: cos(angle))
        let faceA = (s == .slashA || s == .backA)
        let off = cell * 0.14 * (faceA ? -1 : 1)
        let base = cellCenter(coord)
        let sheenPos = CGPoint(x: base.x + perp.dx * off, y: base.y + perp.dy * off)
        if animated {
            bar.run(.rotate(toAngle: angle, duration: 0.14, shortestUnitArc: true))
            bar.run(.sequence([.scale(to: 1.15, duration: 0.07), .scale(to: 1.0, duration: 0.08)]))
            sheen.run(.group([.rotate(toAngle: angle, duration: 0.14, shortestUnitArc: true),
                              .move(to: sheenPos, duration: 0.14)]))
        } else {
            bar.zRotation = angle
            sheen.zRotation = angle
            sheen.position = sheenPos
        }
    }

    private func addFixedMirror(at p: CGPoint, size s: CGFloat, orient: MirrorOrientation) {
        let tile = SKShapeNode(rectOf: CGSize(width: s, height: s), cornerRadius: s * 0.26)
        tile.fillColor = UIColor(red: 0.90, green: 0.88, blue: 0.93, alpha: 0.95)
        tile.strokeColor = GamePalette.wallLine
        tile.lineWidth = 1.5
        tile.position = p; tile.zPosition = 10
        boardNode.addChild(tile)

        let bar = SKShapeNode(rectOf: CGSize(width: s * 0.74, height: s * 0.14), cornerRadius: s * 0.07)
        bar.fillColor = UIColor(red: 0.55, green: 0.56, blue: 0.62, alpha: 1)
        bar.strokeColor = UIColor(white: 1, alpha: 0.5); bar.lineWidth = 1
        bar.position = p; bar.zPosition = 12
        let a: CGFloat = orient == .slash ? .pi / 4 : -.pi / 4
        bar.zRotation = a
        boardNode.addChild(bar)

        for sgn in [-1.0, 1.0] {
            let dot = SKShapeNode(circleOfRadius: s * 0.05)
            dot.fillColor = UIColor(white: 0.45, alpha: 1); dot.strokeColor = .clear
            let off = CGFloat(sgn) * s * 0.3
            dot.position = CGPoint(x: p.x + cos(a) * off, y: p.y + sin(a) * off)
            dot.zPosition = 13
            boardNode.addChild(dot)
        }

        let lock = makeLabel("🔒", size: s * 0.26, weight: Theme.medium)
        lock.position = CGPoint(x: p.x + s * 0.28, y: p.y + s * 0.28)
        lock.zPosition = 14; lock.alpha = 0.75
        boardNode.addChild(lock)
    }

    private func addSplitter(at p: CGPoint, size s: CGFloat, orient: MirrorOrientation) {
        let tile = SKShapeNode(rectOf: CGSize(width: s, height: s), cornerRadius: s * 0.26)
        tile.fillColor = GamePalette.mirrorFill
        tile.strokeColor = GamePalette.mirrorLine; tile.lineWidth = 1.5
        tile.position = p; tile.zPosition = 10
        boardNode.addChild(tile)

        let glow = SKShapeNode(circleOfRadius: s * 0.42)
        glow.fillColor = UIColor(red: 0.55, green: 0.84, blue: 0.92, alpha: 0.30)
        glow.strokeColor = .clear
        glow.position = p; glow.zPosition = 10.5
        boardNode.addChild(glow)

        let diamond = SKShapeNode(rectOf: CGSize(width: s * 0.56, height: s * 0.56), cornerRadius: s * 0.12)
        diamond.fillColor = UIColor(red: 0.62, green: 0.88, blue: 0.95, alpha: 0.95)
        diamond.strokeColor = .white; diamond.lineWidth = 2
        diamond.position = p; diamond.zPosition = 11
        diamond.zRotation = .pi / 4
        boardNode.addChild(diamond)

        let split = SKShapeNode(rectOf: CGSize(width: s * 0.74, height: s * 0.1), cornerRadius: s * 0.05)
        split.fillColor = .white
        split.strokeColor = UIColor(red: 0.30, green: 0.66, blue: 0.80, alpha: 1); split.lineWidth = 0.75
        split.position = p; split.zPosition = 13
        split.zRotation = orient == .slash ? .pi / 4 : -.pi / 4
        boardNode.addChild(split)

        glow.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.9), .scale(to: 1.0, duration: 0.9)])))
    }

    private func addFilter(at p: CGPoint, size s: CGFloat, color: LightColor) {
        let sq = SKShapeNode(rectOf: CGSize(width: s * 0.72, height: s * 0.72), cornerRadius: s * 0.16)
        sq.fillColor = GamePalette.core(color).withAlphaComponent(0.42)
        sq.strokeColor = GamePalette.core(color); sq.lineWidth = 3
        sq.position = p; sq.zPosition = 11
        boardNode.addChild(sq)

        for sgn in [-1.0, 1.0] {
            let slit = SKShapeNode(rectOf: CGSize(width: s * 0.07, height: s * 0.42), cornerRadius: s * 0.035)
            slit.fillColor = UIColor(white: 1, alpha: 0.55); slit.strokeColor = .clear
            slit.position = CGPoint(x: p.x + CGFloat(sgn) * s * 0.17, y: p.y)
            slit.zPosition = 12
            boardNode.addChild(slit)
        }
    }

    static let portalColors: [UIColor] = [
        UIColor(red: 0.58, green: 0.46, blue: 0.90, alpha: 1),
        UIColor(red: 0.27, green: 0.72, blue: 0.78, alpha: 1),
    ]

    private func addPortal(at p: CGPoint, size s: CGFloat, id: Int) {
        let col = GameScene.portalColors[id % GameScene.portalColors.count]

        let glow = SKShapeNode(circleOfRadius: s * 0.44)
        glow.fillColor = col.withAlphaComponent(0.22); glow.strokeColor = .clear
        glow.position = p; glow.zPosition = 9
        glow.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.9), .scale(to: 1.0, duration: 0.9)])))
        boardNode.addChild(glow)

        for (i, radius) in [s * 0.36, s * 0.24].enumerated() {
            let arc = SKShapeNode()
            let path = CGMutablePath()
            path.addArc(center: .zero, radius: radius, startAngle: 0, endAngle: .pi * 1.5, clockwise: false)
            arc.path = path
            arc.fillColor = .clear
            arc.strokeColor = col.withAlphaComponent(i == 0 ? 1 : 0.7)
            arc.lineWidth = 3; arc.lineCap = .round
            arc.position = p; arc.zPosition = 10 + CGFloat(i)
            arc.run(.repeatForever(.rotate(byAngle: (i == 0 ? 1 : -1) * .pi * 2, duration: i == 0 ? 2.4 : 1.8)))
            boardNode.addChild(arc)
        }

        let core = SKShapeNode(circleOfRadius: s * 0.1)
        core.fillColor = .white; core.strokeColor = col; core.lineWidth = 1.5
        core.position = p; core.zPosition = 12
        boardNode.addChild(core)
    }

    private func addGlass(at p: CGPoint, size s: CGFloat) {
        let sq = SKShapeNode(rectOf: CGSize(width: s * 0.78, height: s * 0.78), cornerRadius: s * 0.2)
        sq.fillColor = UIColor(white: 1, alpha: 0.18)
        sq.strokeColor = UIColor(white: 1, alpha: 0.5); sq.lineWidth = 1.5
        sq.position = p; sq.zPosition = 2
        boardNode.addChild(sq)

        let sheen = SKShapeNode(rectOf: CGSize(width: s * 0.5, height: s * 0.06), cornerRadius: s * 0.03)
        sheen.fillColor = UIColor(white: 1, alpha: 0.4); sheen.strokeColor = .clear
        sheen.position = p; sheen.zRotation = .pi / 4; sheen.zPosition = 3
        boardNode.addChild(sheen)
    }

    private func addTarget(at p: CGPoint, size s: CGFloat, set: Set<LightColor>, coord: GridCoordinate) {
        let col = GamePalette.mixColor(set)
        let halo = SKShapeNode(circleOfRadius: s * 0.5)
        halo.fillColor = col.withAlphaComponent(0.30)
        halo.strokeColor = .clear
        halo.position = p; halo.zPosition = 9
        halo.alpha = 0
        boardNode.addChild(halo)
        targetHalos[coord] = halo

        let aim = SKShapeNode(path: dashedCirclePath(radius: s * 0.44))
        aim.fillColor = .clear
        aim.strokeColor = col.withAlphaComponent(0.95)
        aim.lineWidth = 2.5
        aim.position = p; aim.zPosition = 10
        aim.run(.repeatForever(.sequence([
            .group([.scale(to: 1.12, duration: 0.85), .fadeAlpha(to: 0.4, duration: 0.85)]),
            .group([.scale(to: 1.0, duration: 0.85), .fadeAlpha(to: 0.95, duration: 0.85)])])))
        boardNode.addChild(aim)
        targetAims[coord] = aim

        let ring = SKShapeNode(circleOfRadius: s * 0.32)
        ring.fillColor = .clear
        ring.strokeColor = col
        ring.lineWidth = 3
        ring.position = p; ring.zPosition = 11
        boardNode.addChild(ring)

        let core = targetCoreNode(set: set, radius: s * 0.22)
        core.position = p; core.zPosition = 12
        core.alpha = 0.35
        boardNode.addChild(core)
        targetCores[coord] = core
    }

    private func targetCoreNode(set: Set<LightColor>, radius r: CGFloat) -> SKNode {
        let colors = set.sorted { $0.rawValue < $1.rawValue }
        guard colors.count >= 2 else {
            let core = SKShapeNode(circleOfRadius: r)
            core.fillColor = GamePalette.core(colors.first ?? .red)
            core.strokeColor = .white; core.lineWidth = 2
            return core
        }
        let node = SKNode()
        let left = SKShapeNode(path: halfDiscPath(radius: r, leftSide: true))
        left.fillColor = GamePalette.core(colors[0]); left.strokeColor = .clear
        node.addChild(left)
        let right = SKShapeNode(path: halfDiscPath(radius: r, leftSide: false))
        right.fillColor = GamePalette.core(colors[1]); right.strokeColor = .clear
        node.addChild(right)
        let rim = SKShapeNode(circleOfRadius: r)
        rim.fillColor = .clear; rim.strokeColor = .white; rim.lineWidth = 2
        node.addChild(rim)
        return node
    }

    private func dashedCirclePath(radius r: CGFloat) -> CGPath {
        let base = CGPath(ellipseIn: CGRect(x: -r, y: -r, width: r * 2, height: r * 2), transform: nil)
        return base.copy(dashingWithPhase: 0, lengths: [r * 0.5, r * 0.36])
    }

    private func halfDiscPath(radius r: CGFloat, leftSide: Bool) -> CGPath {
        let path = CGMutablePath()
        let start: CGFloat = leftSide ? .pi / 2 : -.pi / 2
        let end: CGFloat = leftSide ? .pi * 1.5 : .pi / 2
        path.move(to: .zero)
        path.addArc(center: .zero, radius: r, startAngle: start, endAngle: end, clockwise: false)
        path.closeSubpath()
        return path
    }



    // MARK: - Işınların Gösterimi

    private func recomputeBeams() {
        beamNode.removeAllChildren()
        let (beams, incident) = level.computeBeams()

        for (idx, beam) in beams.enumerated() {
            guard beam.points.count >= 2 else { continue }
            let pix = beam.points.map { gridToPixel($0) }
            let path = CGMutablePath()
            path.move(to: pix[0])
            for p in pix.dropFirst() { path.addLine(to: p) }
            let core = GamePalette.core(beam.color)
            let outline = SKShapeNode(path: path)
            outline.strokeColor = GamePalette.textPlum.withAlphaComponent(beam.color == .yellow ? 0.38 : 0.20)
            outline.lineWidth = cell * 0.12
            outline.lineCap = .round; outline.lineJoin = .round; outline.fillColor = .clear; outline.zPosition = 4.9
            beamNode.addChild(outline)
            for (width, alpha) in [(cell * 0.34, 0.22), (cell * 0.18, 0.52), (cell * 0.065, 0.98)] {
                let s = SKShapeNode(path: path)
                s.strokeColor = (width > cell * 0.1 ? core : UIColor.white).withAlphaComponent(CGFloat(alpha))
                s.lineWidth = width
                s.lineCap = .round
                s.lineJoin = .round
                s.fillColor = .clear
                s.zPosition = 5
                beamNode.addChild(s)
            }

            var length: CGFloat = 0
            for i in 1..<pix.count { length += hypot(pix[i].x - pix[i - 1].x, pix[i].y - pix[i - 1].y) }
            if length > cell * 0.5 {
                let spark = SKShapeNode(circleOfRadius: cell * 0.11)
                spark.fillColor = .white
                spark.strokeColor = core
                spark.lineWidth = 1
                spark.glowWidth = cell * 0.09
                spark.zPosition = 6
                beamNode.addChild(spark)
                let dur = max(0.5, Double(length / (190 * uiScale)))
                let phase = Double(idx % 4) * 0.28
                spark.run(.sequence([.wait(forDuration: phase),
                                     .repeatForever(.follow(path, asOffset: false, orientToPath: false, duration: dur))]))
            }
        }

        var litCount = 0
        for (coord, set) in level.targetCoords {
            let lit = (incident[coord] ?? []) == set
            if lit { litCount += 1 }
            let core = targetCores[coord]
            let halo = targetHalos[coord]
            core?.removeAllActions(); halo?.removeAllActions()
            targetAims[coord]?.isHidden = lit
            if lit {
                core?.run(.fadeAlpha(to: 1, duration: 0.2))
                core?.run(.sequence([.scale(to: 1.25, duration: 0.12), .scale(to: 1.0, duration: 0.12)]))
                halo?.run(.fadeAlpha(to: 1, duration: 0.2))
                halo?.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.7), .scale(to: 1.0, duration: 0.7)])))
            } else {
                core?.run(.fadeAlpha(to: 0.35, duration: 0.2))
                halo?.run(.fadeAlpha(to: 0, duration: 0.2))
            }
        }

        let total = level.targetCoords.count
        targetCountLabel.isHidden = total <= 1
        if total > 1 {
            targetCountLabel.text = "🎯 \(litCount)/\(total)"
            targetCountLabel.fontColor = litCount == total
                ? UIColor(red: 0.30, green: 0.66, blue: 0.52, alpha: 1) : GamePalette.textPlum
        }
    }



    // MARK: - Kullanıcı Etkileşimi

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        let p = t.location(in: self)
        let hit = nodes(at: p).compactMap { $0.name }

        if !overlay.children.isEmpty {
            if hit.contains("win_continue") { return finishWinSummary() }
            if hit.contains("cc_coins")  { return chooserPayCoins() }
            if hit.contains("cc_ad")     { return chooserWatchAd() }
            if hit.contains("cc_cancel") { return closeChooser() }
            if hit.contains("om_coins")  { return continueWithCoinMoves() }
            if hit.contains("om_ad")     { return continueWithAdMoves() }
            if hit.contains("om_more")   { return buildMoveOptionsOverlay() }
            if hit.contains("om_back")   { return buildOutOfMovesOverlay() }
            if hit.contains("om_retry")  { return retryLevel() }
            if hit.contains("om_menu")   { return failToMenu() }
            return
        }
        if cardActive {
            if welcomeActive { dismissWelcomeCard() } else { dismissCard() }
            return
        }
        if busy { return }

        if hit.contains("hint") { return doHint() }
        if hit.contains("undo") { return undoLastMove() }
        if hit.contains("skip") { return doSkip() }
        if hit.contains("menu") { return goToMenu() }

        let col = Int((p.x - gridLeft) / cell)
        let row = level.rows - 1 - Int((p.y - gridBottom) / cell)
        let coord = GridCoordinate(c: col, r: row)
        guard level.inBounds(coord) else { return }
        if case .fixedMirror = level.piece(coord) { haptic(.light); return }

        switch level.piece(coord) {
        case .mirror:
            pushMoveSnapshot()
            level.toggleMirror(coord)
            if let bar = mirrorBars[coord], case .mirror(let o) = level.piece(coord) {
                bar.run(.rotate(toAngle: o == .slash ? .pi / 4 : -.pi / 4, duration: 0.14, shortestUnitArc: true))
                bar.run(.sequence([.scale(to: 1.18, duration: 0.07), .scale(to: 1.0, duration: 0.08)]))
            }
        case .halfMirror:
            pushMoveSnapshot()
            level.toggleHalfMirror(coord)
            if case .halfMirror(let s) = level.piece(coord) { applyHalfMirrorVisual(coord, state: s, animated: true) }
        default:
            return
        }
        haptic(.light)
        dismissIntro()
        SoundManager.shared.play("tap.wav", on: self)
        movesLeft -= 1
        movesMade += 1
        updateMoves()
        updateUndoButton()
        recomputeBeams()

        if level.isSolved { winLevel() }
        else if movesLeft <= 0 { outOfMoves() }
    }



    // MARK: - Oyun İçi Eğitim

    private func maybeShowTutorial(_ n: Int) {
        tutorialLayer.removeAllChildren()
        tutorialLayer.alpha = 1
        introActive = false; cardActive = false; welcomeActive = false

        if n == 1 && !Tutorial.seen("intro") {
            showWelcomeCard()
            return
        }
        let present = presentMechanics()
        for card in Tutorial.cards where present.contains(card.key) && !Tutorial.seen(card.key) {
            showMechanicCard(card)
            return
        }
    }

    private func presentMechanics() -> Set<String> {
        var s = Set<String>()
        for row in level.pieces { for p in row {
            switch p {
            case .fixedMirror:     s.insert("fixedMirror")
            case .splitter:        s.insert("splitter")
            case .filter:          s.insert("filter")
            case .glass:           s.insert("glass")
            case .portal:          s.insert("portal")
            case .halfMirror:      s.insert("halfMirror")
            case .target(let set): if set.count > 1 { s.insert("mixedTarget") }
            default: break
            }
        } }
        return s
    }


    private func showWelcomeCard() {
        cardActive = true; welcomeActive = true; busy = true
        let cx = size.width / 2, cy = size.height / 2
        addCardBackdrop(height: 380)

        let title = makeLabel("Işığı hedefe ulaştır", size: 24 * uiScale, weight: Theme.heavy)
        title.fontColor = GamePalette.textPlum
        title.position = CGPoint(x: cx, y: cy + 138 * uiScale); title.zPosition = 302
        tutorialLayer.addChild(title)

        let diagram = welcomeDiagram(width: min(size.width - 150, 300 * uiScale))
        diagram.position = CGPoint(x: cx, y: cy + 30 * uiScale); diagram.zPosition = 302
        tutorialLayer.addChild(diagram)

        addWrapped("Aynaya dokun ve döndür — ışığın yolunu büküp renkli hedefe getir.",
                   at: CGPoint(x: cx, y: cy - 92 * uiScale))

        addCardButton(title: "Başla", y: cy - 150 * uiScale)
    }

    private func welcomeDiagram(width w: CGFloat) -> SKNode {
        let node = SKNode()
        let s = w * 0.18
        let srcP = CGPoint(x: -w * 0.42, y: -s * 0.6)
        let mirP = CGPoint(x:  w * 0.06, y: -s * 0.6)
        let tgtP = CGPoint(x:  w * 0.06, y:  s * 1.5)

        let path = CGMutablePath()
        path.move(to: srcP); path.addLine(to: mirP); path.addLine(to: tgtP)
        let glow = SKShapeNode(path: path)
        glow.strokeColor = GamePalette.core(.red).withAlphaComponent(0.45); glow.lineWidth = 6
        glow.lineCap = .round; glow.lineJoin = .round; node.addChild(glow)
        let core = SKShapeNode(path: path)
        core.strokeColor = UIColor(white: 1, alpha: 0.9); core.lineWidth = 2
        core.lineCap = .round; core.lineJoin = .round; node.addChild(core)

        let src = SKShapeNode(rectOf: CGSize(width: s, height: s), cornerRadius: s * 0.22)
        src.fillColor = GamePalette.core(.red); src.strokeColor = .white; src.lineWidth = 2
        src.position = srcP; node.addChild(src)

        let aura = SKShapeNode(rectOf: CGSize(width: s + 8, height: s + 8), cornerRadius: s * 0.3)
        aura.fillColor = GamePalette.amber.withAlphaComponent(0.16); aura.strokeColor = GamePalette.amber.withAlphaComponent(0.5); aura.lineWidth = 1.5
        aura.position = mirP; node.addChild(aura)
        let tile = SKShapeNode(rectOf: CGSize(width: s, height: s), cornerRadius: s * 0.22)
        tile.fillColor = GamePalette.mirrorFill; tile.strokeColor = GamePalette.mirrorLine; tile.lineWidth = 1.5
        tile.position = mirP; node.addChild(tile)
        let bar = SKShapeNode(rectOf: CGSize(width: s * 0.74, height: s * 0.14), cornerRadius: s * 0.07)
        bar.fillColor = GamePalette.mirrorBar; bar.strokeColor = UIColor(white: 1, alpha: 0.7); bar.lineWidth = 1
        bar.position = mirP; bar.zRotation = .pi / 4; node.addChild(bar)

        let ring = SKShapeNode(circleOfRadius: s * 0.42)
        ring.fillColor = .clear; ring.strokeColor = GamePalette.core(.red); ring.lineWidth = 3
        ring.position = tgtP; node.addChild(ring)
        let tcore = SKShapeNode(circleOfRadius: s * 0.24)
        tcore.fillColor = GamePalette.core(.red); tcore.strokeColor = .white; tcore.lineWidth = 2
        tcore.position = tgtP; node.addChild(tcore)

        let l1 = makeLabel("💡 Işık", size: 12 * uiScale, weight: Theme.medium)
        l1.fontColor = GamePalette.textPlum.withAlphaComponent(0.8); l1.position = CGPoint(x: srcP.x, y: srcP.y - s * 0.85)
        node.addChild(l1)
        let l2 = makeLabel("🎯 Hedef", size: 12 * uiScale, weight: Theme.medium)
        l2.fontColor = GamePalette.textPlum.withAlphaComponent(0.8); l2.horizontalAlignmentMode = .left
        l2.position = CGPoint(x: tgtP.x + s * 0.7, y: tgtP.y); node.addChild(l2)

        let finger = makeLabel("👆", size: s * 0.85, weight: Theme.heavy)
        finger.position = CGPoint(x: mirP.x + s * 0.55, y: mirP.y - s * 0.55)
        finger.run(.repeatForever(.sequence([.moveBy(x: 0, y: 5, duration: 0.5), .moveBy(x: 0, y: -5, duration: 0.5)])))
        node.addChild(finger)

        let spark = SKShapeNode(circleOfRadius: s * 0.12)
        spark.fillColor = .white; spark.strokeColor = GamePalette.core(.red); spark.lineWidth = 1; spark.glowWidth = s * 0.1
        node.addChild(spark)
        spark.run(.repeatForever(.sequence([.follow(path, asOffset: false, orientToPath: false, duration: 1.3),
                                            .wait(forDuration: 0.3)])))
        return node
    }

    private func dismissWelcomeCard() {
        welcomeActive = false; cardActive = false; busy = false
        startIntroPointer()
    }


    private func startIntroPointer() {
        tutorialLayer.removeAllChildren()
        tutorialLayer.alpha = 1
        guard let mc = introMirrorCoord() else { introActive = false; return }
        introActive = true
        let c = cellCenter(mc)

        let ring = SKShapeNode(circleOfRadius: cell * 0.52)
        ring.strokeColor = GamePalette.amber; ring.lineWidth = 4; ring.fillColor = .clear
        ring.position = c
        ring.run(.repeatForever(.sequence([
            .group([.scale(to: 1.12, duration: 0.6), .fadeAlpha(to: 0.35, duration: 0.6)]),
            .group([.scale(to: 1.0, duration: 0.6), .fadeAlpha(to: 1.0, duration: 0.6)])])))
        tutorialLayer.addChild(ring)

        let finger = makeLabel("👆", size: cell * 0.66, weight: Theme.heavy)
        finger.position = CGPoint(x: c.x, y: c.y - cell * 0.68)
        finger.run(.repeatForever(.sequence([.moveBy(x: 0, y: 7, duration: 0.5),
                                             .moveBy(x: 0, y: -7, duration: 0.5)])))
        tutorialLayer.addChild(finger)

        let hint = makeLabel("Aynaya dokun, döndür", size: 16 * uiScale, weight: Theme.heavy)
        hint.fontColor = GamePalette.amberText
        hint.position = CGPoint(x: clampedLabelX(hint, desiredX: c.x), y: c.y - cell * 1.2)
        tutorialLayer.addChild(hint)

        for r in 0..<level.rows { for col in 0..<level.cols {
            guard case .source = level.piece(GridCoordinate(c: col, r: r)) else { continue }
            let p = cellCenter(GridCoordinate(c: col, r: r))
            let tag = makeLabel("💡 Işık", size: 12 * uiScale, weight: Theme.medium)
            tag.fontColor = GamePalette.textPlum
            tag.position = CGPoint(x: clampedLabelX(tag, desiredX: p.x), y: p.y + cell * 0.62)
            tutorialLayer.addChild(tag)
        } }

        for (coord, _) in level.targetCoords {
            let p = cellCenter(coord)
            let g = SKShapeNode(circleOfRadius: cell * 0.5)
            g.strokeColor = UIColor(white: 1, alpha: 0.9); g.lineWidth = 3; g.fillColor = .clear
            g.position = p
            g.run(.repeatForever(.sequence([
                .group([.scale(to: 1.3, duration: 1.0), .fadeAlpha(to: 0, duration: 1.0)]),
                .group([.scale(to: 1.0, duration: 0.01), .fadeAlpha(to: 0.9, duration: 0.01)]),
                .wait(forDuration: 0.4)])))
            tutorialLayer.addChild(g)
            let tag = makeLabel("🎯 Hedef", size: 12 * uiScale, weight: Theme.medium)
            tag.fontColor = GamePalette.textPlum
            tag.position = CGPoint(x: clampedLabelX(tag, desiredX: p.x), y: p.y + cell * 0.62)
            tutorialLayer.addChild(tag)
        }
    }

    private func clampedLabelX(_ label: SKLabelNode, desiredX: CGFloat) -> CGFloat {
        let margin = 14 * uiScale
        let halfWidth = min(label.frame.width / 2, (size.width - margin * 2) / 2)
        return min(max(desiredX, margin + halfWidth), size.width - margin - halfWidth)
    }

    private func dismissIntro() {
        guard introActive else { return }
        introActive = false
        Tutorial.markSeen("intro")
        tutorialLayer.run(.sequence([.fadeOut(withDuration: 0.3), .run { [weak self] in
            self?.tutorialLayer.removeAllChildren()
            self?.tutorialLayer.alpha = 1
        }]))
    }

    private func introMirrorCoord() -> GridCoordinate? {
        for (coord, want) in level.solved {
            if case .mirror(let cur) = level.piece(coord), cur != want { return coord }
        }
        return level.mirrorCoords.first
    }


    private func showMechanicCard(_ card: Tutorial.Card) {
        Tutorial.markSeen(card.key)
        cardActive = true; busy = true; pendingMechanicKey = card.key
        let cx = size.width / 2, cy = size.height / 2
        addCardBackdrop(height: 330)

        let badge = makeLabel("YENİ", size: 13 * uiScale, weight: Theme.heavy)
        badge.fontColor = GamePalette.amberText
        badge.position = CGPoint(x: cx, y: cy + 122 * uiScale); badge.zPosition = 302
        tutorialLayer.addChild(badge)

        let icon = mechanicIcon(for: card.key, size: 62 * uiScale)
        icon.position = CGPoint(x: cx, y: cy + 66 * uiScale); icon.zPosition = 302
        tutorialLayer.addChild(icon)

        let title = makeLabel(card.title, size: 24 * uiScale, weight: Theme.heavy)
        title.fontColor = GamePalette.textPlum
        title.position = CGPoint(x: cx, y: cy + 8 * uiScale); title.zPosition = 302
        tutorialLayer.addChild(title)

        addWrapped(card.body, at: CGPoint(x: cx, y: cy - 44 * uiScale))
        addCardButton(title: "Anladım", y: cy - 118 * uiScale)
    }

    private func dismissCard() {
        let key = pendingMechanicKey
        pendingMechanicKey = nil
        cardActive = false; busy = false
        tutorialLayer.removeAllChildren()
        tutorialLayer.alpha = 1
        if let key { highlightMechanic(key) }
    }

    private func highlightMechanic(_ key: String) {
        var coords: [GridCoordinate] = []
        for r in 0..<level.rows { for c in 0..<level.cols {
            let coord = GridCoordinate(c: c, r: r)
            let matches: Bool
            switch (key, level.piece(coord)) {
            case ("fixedMirror", .fixedMirror), ("splitter", .splitter), ("filter", .filter),
                 ("glass", .glass), ("portal", .portal), ("halfMirror", .halfMirror): matches = true
            case ("mixedTarget", .target(let colors)): matches = colors.count > 1
            default: matches = false
            }
            if matches { coords.append(coord) }
        } }
        for (i, coord) in coords.enumerated() {
            let ring = SKShapeNode(circleOfRadius: cell * 0.48)
            ring.strokeColor = GamePalette.amber; ring.lineWidth = 4; ring.fillColor = .clear
            ring.position = cellCenter(coord); ring.zPosition = 40; ring.setScale(0.65); ring.alpha = 0
            boardNode.addChild(ring)
            ring.run(.sequence([.wait(forDuration: Double(i) * 0.12),
                                .group([.fadeIn(withDuration: 0.15), .scale(to: 1.15, duration: 0.35)]),
                                .repeat(.sequence([.fadeAlpha(to: 0.25, duration: 0.25), .fadeAlpha(to: 1, duration: 0.25)]), count: 3),
                                .fadeOut(withDuration: 0.2), .removeFromParent()]))
        }
        if let first = coords.first {
            let tag = makeLabel("Yeni parça burada", size: 14 * uiScale, weight: Theme.heavy)
            tag.fontColor = .white
            let bubbleWidth = min(tag.frame.width + 24 * uiScale, size.width - 24 * uiScale)
            let halfWidth = bubbleWidth / 2
            let desiredX = cellCenter(first).x
            let safeX = min(max(desiredX, halfWidth + 12 * uiScale), size.width - halfWidth - 12 * uiScale)
            tag.position = CGPoint(x: safeX, y: cellCenter(first).y + cell * 0.72)
            tag.zPosition = 41
            let bg = SKShapeNode(rectOf: CGSize(width: bubbleWidth, height: 34 * uiScale), cornerRadius: 17 * uiScale)
            bg.fillColor = GamePalette.textPlum.withAlphaComponent(0.9); bg.strokeColor = .clear; bg.position = tag.position; bg.zPosition = 40.5
            boardNode.addChild(bg); boardNode.addChild(tag)
            let action = SKAction.sequence([.wait(forDuration: 2.0), .fadeOut(withDuration: 0.25), .removeFromParent()])
            bg.run(action); tag.run(action)
        }
    }


    private func addCardBackdrop(height: CGFloat) {
        let cx = size.width / 2, cy = size.height / 2
        let dim = SKSpriteNode(color: UIColor(white: 0.35, alpha: 0.4), size: size)
        dim.position = CGPoint(x: cx, y: cy); dim.zPosition = 300; dim.name = "tut_dismiss"
        tutorialLayer.addChild(dim)
        let panel = SKShapeNode(rectOf: CGSize(width: min(size.width - 70, 460 * uiScale), height: height * uiScale), cornerRadius: 28)
        panel.fillColor = UIColor(white: 1, alpha: 0.97); panel.strokeColor = GamePalette.tileLine; panel.lineWidth = 1
        panel.position = CGPoint(x: cx, y: cy); panel.zPosition = 301; panel.name = "tut_dismiss"
        tutorialLayer.addChild(panel)
    }

    private func addCardButton(title: String, y: CGFloat) {
        let btn = makePill(text: title, width: 180 * uiScale, height: 52 * uiScale,
                           fill: UIColor(red: 0.78, green: 0.66, blue: 0.95, alpha: 0.95),
                           line: .white, textColor: .white, fontSize: 20 * uiScale, name: "tut_dismiss")
        btn.position = CGPoint(x: size.width / 2, y: y); btn.zPosition = 302
        tutorialLayer.addChild(btn)
    }

    private func addWrapped(_ text: String, at p: CGPoint) {
        let l = makeLabel(text, size: 16 * uiScale, weight: Theme.medium)
        l.fontColor = GamePalette.textPlum.withAlphaComponent(0.85)
        l.numberOfLines = 0
        l.preferredMaxLayoutWidth = min(size.width - 130, 400 * uiScale)
        l.position = p; l.zPosition = 302
        tutorialLayer.addChild(l)
    }

    private func mechanicIcon(for key: String, size s: CGFloat) -> SKNode {
        let node = SKNode()
        switch key {
        case "splitter":
            let tile = SKShapeNode(rectOf: CGSize(width: s, height: s), cornerRadius: s * 0.26)
            tile.fillColor = GamePalette.mirrorFill; tile.strokeColor = GamePalette.mirrorLine; tile.lineWidth = 1.5
            node.addChild(tile)
            let diamond = SKShapeNode(rectOf: CGSize(width: s * 0.56, height: s * 0.56), cornerRadius: s * 0.12)
            diamond.fillColor = UIColor(red: 0.62, green: 0.88, blue: 0.95, alpha: 0.95)
            diamond.strokeColor = .white; diamond.lineWidth = 2; diamond.zRotation = .pi / 4
            node.addChild(diamond)
            let split = SKShapeNode(rectOf: CGSize(width: s * 0.74, height: s * 0.1), cornerRadius: s * 0.05)
            split.fillColor = .white; split.strokeColor = UIColor(red: 0.30, green: 0.66, blue: 0.80, alpha: 1)
            split.lineWidth = 0.75; split.zRotation = .pi / 4
            node.addChild(split)
        case "filter":
            let sq = SKShapeNode(rectOf: CGSize(width: s * 0.82, height: s * 0.82), cornerRadius: s * 0.16)
            sq.fillColor = GamePalette.core(.red).withAlphaComponent(0.42); sq.strokeColor = GamePalette.core(.red); sq.lineWidth = 3
            node.addChild(sq)
            for sgn in [-1.0, 1.0] {
                let slit = SKShapeNode(rectOf: CGSize(width: s * 0.08, height: s * 0.48), cornerRadius: s * 0.04)
                slit.fillColor = UIColor(white: 1, alpha: 0.55); slit.strokeColor = .clear
                slit.position = CGPoint(x: CGFloat(sgn) * s * 0.19, y: 0)
                node.addChild(slit)
            }
        case "glass":
            let sq = SKShapeNode(rectOf: CGSize(width: s * 0.86, height: s * 0.86), cornerRadius: s * 0.2)
            sq.fillColor = UIColor(white: 1, alpha: 0.18); sq.strokeColor = UIColor(white: 1, alpha: 0.6); sq.lineWidth = 1.5
            node.addChild(sq)
            let sheen = SKShapeNode(rectOf: CGSize(width: s * 0.5, height: s * 0.06), cornerRadius: s * 0.03)
            sheen.fillColor = UIColor(white: 1, alpha: 0.5); sheen.strokeColor = .clear; sheen.zRotation = .pi / 4
            node.addChild(sheen)
        case "fixedMirror":
            let tile = SKShapeNode(rectOf: CGSize(width: s, height: s), cornerRadius: s * 0.26)
            tile.fillColor = UIColor(red: 0.90, green: 0.88, blue: 0.93, alpha: 0.95)
            tile.strokeColor = GamePalette.wallLine; tile.lineWidth = 1.5
            node.addChild(tile)
            let a: CGFloat = .pi / 4
            let bar = SKShapeNode(rectOf: CGSize(width: s * 0.74, height: s * 0.14), cornerRadius: s * 0.07)
            bar.fillColor = UIColor(red: 0.55, green: 0.56, blue: 0.62, alpha: 1)
            bar.strokeColor = UIColor(white: 1, alpha: 0.5); bar.lineWidth = 1; bar.zRotation = a
            node.addChild(bar)
            for sgn in [-1.0, 1.0] {
                let dot = SKShapeNode(circleOfRadius: s * 0.05)
                dot.fillColor = UIColor(white: 0.45, alpha: 1); dot.strokeColor = .clear
                let off = CGFloat(sgn) * s * 0.3
                dot.position = CGPoint(x: cos(a) * off, y: sin(a) * off)
                node.addChild(dot)
            }
            let lock = makeLabel("🔒", size: s * 0.26, weight: Theme.medium)
            lock.position = CGPoint(x: s * 0.28, y: s * 0.28); lock.alpha = 0.8
            node.addChild(lock)
        case "mixedTarget":
            let col = GamePalette.mixColor([.red, .blue])
            let halo = SKShapeNode(circleOfRadius: s * 0.5)
            halo.fillColor = col.withAlphaComponent(0.30); halo.strokeColor = .clear
            node.addChild(halo)
            let ring = SKShapeNode(circleOfRadius: s * 0.34)
            ring.fillColor = .clear; ring.strokeColor = col; ring.lineWidth = 3
            node.addChild(ring)
            let core = targetCoreNode(set: [.red, .blue], radius: s * 0.22)
            node.addChild(core)
        case "portal":
            for (i, dx) in [-s * 0.28, s * 0.28].enumerated() {
                let col = GameScene.portalColors[0]
                let glow = SKShapeNode(circleOfRadius: s * 0.26)
                glow.fillColor = col.withAlphaComponent(0.22); glow.strokeColor = .clear
                glow.position = CGPoint(x: dx, y: 0); node.addChild(glow)
                let arc = SKShapeNode()
                let path = CGMutablePath()
                path.addArc(center: .zero, radius: s * 0.22, startAngle: 0, endAngle: .pi * 1.5, clockwise: false)
                arc.path = path; arc.fillColor = .clear; arc.strokeColor = col; arc.lineWidth = 3; arc.lineCap = .round
                arc.position = CGPoint(x: dx, y: 0)
                arc.run(.repeatForever(.rotate(byAngle: (i == 0 ? 1 : -1) * .pi * 2, duration: 2.2)))
                node.addChild(arc)
            }
        case "halfMirror":
            let tile = SKShapeNode(rectOf: CGSize(width: s, height: s), cornerRadius: s * 0.26)
            tile.fillColor = GamePalette.mirrorFill; tile.strokeColor = GamePalette.mirrorLine; tile.lineWidth = 1.5
            node.addChild(tile)
            let bar = SKShapeNode(rectOf: CGSize(width: s * 0.76, height: s * 0.16), cornerRadius: s * 0.08)
            bar.fillColor = UIColor(red: 0.74, green: 0.83, blue: 0.96, alpha: 0.40)
            bar.strokeColor = UIColor(white: 1, alpha: 0.65); bar.lineWidth = 1
            bar.zRotation = .pi / 4; node.addChild(bar)
            let sheen = SKShapeNode(rectOf: CGSize(width: s * 0.7, height: s * 0.07), cornerRadius: s * 0.035)
            sheen.fillColor = GamePalette.mirrorBar; sheen.strokeColor = UIColor(white: 1, alpha: 0.85); sheen.lineWidth = 0.5
            sheen.zRotation = .pi / 4
            let perp = CGVector(dx: -sin(CGFloat.pi / 4), dy: cos(CGFloat.pi / 4))
            sheen.position = CGPoint(x: -perp.dx * s * 0.16, y: -perp.dy * s * 0.16)
            node.addChild(sheen)
        default: break
        }
        return node
    }



    // MARK: - Yardımcı İşlemler

    private func doHint() {
        let wrongFull = level.solved.contains { coord, want in
            if case .mirror(let cur) = level.piece(coord) { return cur != want }
            return false
        }
        let wrongHalf = level.solvedHalf.contains { coord, want in
            if case .halfMirror(let cur) = level.piece(coord) { return cur != want }
            return false
        }
        guard wrongFull || wrongHalf else {
            haptic(.light); flashToast("Aynalar doğru — ışığın yolunu izle"); return
        }
        if hintsUsed == 0 && !dailyMode && shownLevel <= 5 {
            hintsUsed += 1
            revealHint()
            return
        }
        showCostChooser(title: "İpucu al", cost: Costs.hint, reason: "hint") { [weak self] in
            self?.hintsUsed += 1
            self?.revealHint()
        }
    }

    private func revealHint() {
        for (coord, want) in level.solved {
            if case .mirror(let cur) = level.piece(coord), cur != want { pulseHint(coord); return }
        }
        for (coord, want) in level.solvedHalf {
            if case .halfMirror(let cur) = level.piece(coord), cur != want { pulseHint(coord); return }
        }
    }

    private func pulseHint(_ coord: GridCoordinate) {
        guard let bar = mirrorBars[coord] ?? halfMirrorBars[coord] else { return }
        let ring = SKShapeNode(circleOfRadius: cell * 0.5)
        ring.strokeColor = GamePalette.amber
        ring.lineWidth = 4
        ring.fillColor = .clear
        ring.position = cellCenter(coord)
        ring.zPosition = 30
        boardNode.addChild(ring)
        ring.run(.sequence([
            .repeat(.sequence([.fadeAlpha(to: 0.2, duration: 0.3), .fadeAlpha(to: 1, duration: 0.3)]), count: 4),
            .removeFromParent()]))
        bar.run(.sequence([.scale(to: 1.25, duration: 0.15), .scale(to: 1.0, duration: 0.15)]))
        haptic(.medium)
        SoundManager.shared.play("hint.wav", on: self)
    }

    private func doSkip() {
        guard !dailyMode else { return }
        showCostChooser(title: "Bölümü atla", cost: Costs.skip, reason: "skip") { [weak self] in
            self?.advance()
        }
    }



    private func showCostChooser(title: String, cost: Int, reason: String, onGranted: @escaping () -> Void) {
        chooserCost = cost; chooserReason = reason; chooserGranted = onGranted
        busy = true
        clearOverlay()
        let cx = size.width / 2, cy = size.height / 2

        let dim = SKSpriteNode(color: UIColor(white: 0.35, alpha: 0.35), size: size)
        dim.position = CGPoint(x: cx, y: cy); dim.zPosition = 0; dim.name = "cc_cancel"
        overlay.addChild(dim)

        let panel = SKShapeNode(rectOf: CGSize(width: min(size.width - 70, 460 * uiScale), height: 300 * uiScale), cornerRadius: 28)
        panel.fillColor = UIColor(white: 1, alpha: 0.97); panel.strokeColor = GamePalette.tileLine; panel.lineWidth = 1
        panel.position = CGPoint(x: cx, y: cy); panel.zPosition = 1
        overlay.addChild(panel)

        let t = makeLabel(title, size: 26 * uiScale, weight: Theme.heavy)
        t.fontColor = GamePalette.textPlum
        t.position = CGPoint(x: cx, y: cy + 100 * uiScale); t.zPosition = 2
        overlay.addChild(t)

        let bal = makeLabel("Coin'in: \(Wallet.coins)", size: 14 * uiScale, weight: Theme.medium)
        bal.fontColor = GamePalette.textPlum.withAlphaComponent(0.7)
        bal.position = CGPoint(x: cx, y: cy + 70 * uiScale); bal.zPosition = 2
        overlay.addChild(bal)

        let canAfford = Wallet.coins >= cost
        addOverlayButton(name: canAfford ? "cc_coins" : "cc_poor",
                         title: "💎  \(cost) coin",
                         fill: canAfford ? UIColor(red: 0.44, green: 0.82, blue: 0.74, alpha: 0.95)
                                         : UIColor(white: 0.86, alpha: 0.8),
                         text: canAfford ? .white : UIColor(white: 0.55, alpha: 1), y: cy + 30 * uiScale)
        addOverlayButton(name: "cc_ad", title: "▶  Reklam izle",
                         fill: UIColor(red: 0.78, green: 0.66, blue: 0.95, alpha: 0.95), text: .white, y: cy - 34 * uiScale)
        addOverlayButton(name: "cc_cancel", title: "Vazgeç",
                         fill: GamePalette.panel, text: GamePalette.textPlum, y: cy - 98 * uiScale)
    }

    private func chooserPayCoins() {
        guard Wallet.coins >= chooserCost else { haptic(.heavy); return }
        Wallet.spend(chooserCost)
        coinLabel.text = "\(Wallet.coins)"
        let granted = chooserGranted
        closeChooser()
        haptic(.light)
        granted?()
    }

    private func chooserWatchAd() {
        guard AdManager.shared.isRewardedReady else {
            flashToast("Reklam şu an hazır değil, biraz sonra tekrar dene")
            return
        }
        let granted = chooserGranted
        let reason = chooserReason
        clearOverlay(); chooserGranted = nil
        busy = true
        AdManager.shared.showRewarded(reason: reason) { [weak self] ok in
            guard let self else { return }
            self.busy = false
            if ok { granted?() } else { self.flashToast("Reklam tamamlanmadı") }
        }
    }

    private func closeChooser() {
        clearOverlay()
        chooserGranted = nil
        busy = false
    }

    private func goToMenu() {
        let m = MenuScene(size: size)
        m.scaleMode = .resizeFill
        view?.presentScene(m, transition: .fade(withDuration: 0.4))
    }



    // MARK: - Bölüm Sonuçları

    private func outOfMoves() {
        busy = true
        haptic(.heavy)
        buildOutOfMovesOverlay()
    }

    private func buildOutOfMovesOverlay() {
        clearOverlay()
        let cx = size.width / 2, cy = size.height / 2

        let dim = SKSpriteNode(color: UIColor(white: 0.35, alpha: 0.35), size: size)
        dim.position = CGPoint(x: cx, y: cy); dim.zPosition = 0
        overlay.addChild(dim)

        let panel = SKShapeNode(rectOf: CGSize(width: min(size.width - 70, 460 * uiScale), height: 330 * uiScale), cornerRadius: 28)
        panel.fillColor = UIColor(white: 1, alpha: 0.97)
        panel.strokeColor = GamePalette.tileLine; panel.lineWidth = 1
        panel.position = CGPoint(x: cx, y: cy); panel.zPosition = 1
        overlay.addChild(panel)

        let title = makeLabel("Az kaldı! 💪", size: 30 * uiScale, weight: Theme.heavy)
        title.fontColor = GamePalette.textPlum
        title.position = CGPoint(x: cx, y: cy + 116 * uiScale); title.zPosition = 2
        overlay.addChild(title)

        let sub = makeLabel("Tekrar dene, ya da hamle ekle", size: 14 * uiScale, weight: Theme.medium)
        sub.fontColor = GamePalette.textPlum.withAlphaComponent(0.7)
        sub.position = CGPoint(x: cx, y: cy + 84 * uiScale); sub.zPosition = 2
        overlay.addChild(sub)

        let canRetry = Wallet.lives > 0
        addOverlayButton(name: "om_retry",
                         title: canRetry ? "↻  Yeniden dene  (−1 ♥)" : "↻  Yeniden (can yok)",
                         fill: canRetry ? UIColor(red: 0.78, green: 0.66, blue: 0.95, alpha: 0.95)
                                        : UIColor(white: 0.9, alpha: 0.7),
                         text: canRetry ? .white : GamePalette.textPlum, y: cy + 32 * uiScale)
        addOverlayButton(name: "om_more", title: "+5 hamle al",
                         fill: GamePalette.panel, text: UIColor(red: 0.55, green: 0.45, blue: 0.85, alpha: 1), y: cy - 32 * uiScale)
        addOverlayButton(name: "om_menu", title: "‹  Menü", fill: GamePalette.panel, text: GamePalette.textPlum, y: cy - 96 * uiScale)
    }

    private func buildMoveOptionsOverlay() {
        clearOverlay()
        let cx = size.width / 2, cy = size.height / 2
        let dim = SKSpriteNode(color: UIColor(white: 0.35, alpha: 0.35), size: size)
        dim.position = CGPoint(x: cx, y: cy); overlay.addChild(dim)
        let panel = SKShapeNode(rectOf: CGSize(width: min(size.width - 70, 460 * uiScale), height: 300 * uiScale), cornerRadius: 28)
        panel.fillColor = UIColor(white: 1, alpha: 0.97); panel.strokeColor = GamePalette.tileLine; panel.lineWidth = 1
        panel.position = CGPoint(x: cx, y: cy); panel.zPosition = 1; overlay.addChild(panel)
        let title = makeLabel("+5 hamle", size: 28 * uiScale, weight: Theme.heavy)
        title.fontColor = GamePalette.textPlum; title.position = CGPoint(x: cx, y: cy + 102 * uiScale); title.zPosition = 2; overlay.addChild(title)
        let canAfford = Wallet.coins >= Costs.moves
        addOverlayButton(name: canAfford ? "om_coins" : "om_poor", title: "💎  \(Costs.moves) coin kullan",
                         fill: canAfford ? UIColor(red: 0.44, green: 0.82, blue: 0.74, alpha: 0.95) : UIColor(white: 0.88, alpha: 0.8),
                         text: canAfford ? .white : UIColor(white: 0.58, alpha: 1), y: cy + 36 * uiScale)
        addOverlayButton(name: "om_ad", title: "▶  Reklam izle",
                         fill: UIColor(red: 0.78, green: 0.66, blue: 0.95, alpha: 0.95), text: .white, y: cy - 28 * uiScale)
        addOverlayButton(name: "om_back", title: "‹  Geri", fill: GamePalette.panel, text: GamePalette.textPlum, y: cy - 92 * uiScale)
    }

    private func addOverlayButton(name: String, title: String, fill: UIColor, text: UIColor, y: CGFloat) {
        let bg = SKShapeNode(rectOf: CGSize(width: min(size.width - 120, 400 * uiScale), height: 52 * uiScale), cornerRadius: 16)
        bg.fillColor = fill; bg.strokeColor = GamePalette.tileLine; bg.lineWidth = 1
        bg.position = CGPoint(x: size.width / 2, y: y); bg.zPosition = 2; bg.name = name
        overlay.addChild(bg)
        let l = makeLabel(title, size: 18 * uiScale, weight: Theme.medium)
        l.fontColor = text; l.position = bg.position; l.zPosition = 3; l.name = name
        overlay.addChild(l)
    }

    private func continueWithAdMoves() {
        guard AdManager.shared.isRewardedReady else {
            flashToast("Reklam şu an hazır değil, biraz sonra tekrar dene")
            return
        }
        clearOverlay(); busy = true
        AdManager.shared.showRewarded(reason: "moves") { [weak self] ok in
            guard let self else { return }
            self.busy = false
            if ok {
                self.movesLeft += 5; self.moveHistory.removeAll(); self.updateUndoButton(); self.updateMoves()
            }
            else { self.buildOutOfMovesOverlay(); self.busy = true }
        }
    }

    private func continueWithCoinMoves() {
        guard Wallet.spend(Costs.moves) else { haptic(.heavy); return }
        coinLabel.text = "\(Wallet.coins)"
        clearOverlay()
        movesLeft += 5
        moveHistory.removeAll(); updateUndoButton()
        updateMoves()
        busy = false
        haptic(.light)
    }

    private func retryLevel() {
        guard Wallet.lives > 0 else { haptic(.heavy); return }
        Wallet.loseLife()
        updateHearts()
        flashLifeLost()
        level.resetToInitial()
        for (coord, bar) in mirrorBars {
            if case .mirror(let o) = level.piece(coord) {
                bar.run(.rotate(toAngle: o == .slash ? .pi / 4 : -.pi / 4, duration: 0.14, shortestUnitArc: true))
            }
        }
        for coord in halfMirrorBars.keys {
            if case .halfMirror(let s) = level.piece(coord) { applyHalfMirrorVisual(coord, state: s, animated: true) }
        }
        movesLeft = level.moveLimit
        movesMade = 0; moveHistory.removeAll(); updateUndoButton()
        updateMoves(); recomputeBeams(); clearOverlay()
        busy = false; haptic(.light)
    }

    private func failToMenu() {
        Wallet.loseLife()
        goToMenu()
    }



    private func winLevel() {
        busy = true
        let before = Wallet.coins
        if dailyMode {
            if !Daily.isDoneToday {
                Wallet.coins += Daily.reward
                Daily.recordCompletion()
            }
        } else {
            Wallet.coins += 10
        }
        let gained = Wallet.coins - before
        coinLabel.text = "\(before)"

        haptic(.heavy)
        SoundManager.shared.play("win.wav", on: self)
        celebrateTargets()
        winBurst()
        confetti()
        if gained > 0 { flyCoins(count: gained, startValue: before) }

        let banner = makeLabel(dailyMode ? "Günlük tamam!  🔥\(Wallet.dailyStreak)" : "Harika!",
                               size: (dailyMode ? 30 : 40) * uiScale, weight: Theme.heavy)
        banner.fontColor = GamePalette.textPlum
        banner.position = CGPoint(x: size.width / 2, y: size.height / 2 + 64 * uiScale)
        banner.zPosition = 210
        banner.setScale(0.2); banner.alpha = 0
        addChild(banner)
        banner.run(.sequence([
            .group([.sequence([.scale(to: 1.18, duration: 0.26), .scale(to: 1.0, duration: 0.14)]),
                    .fadeIn(withDuration: 0.18)]),
            .wait(forDuration: 1.1),
            .group([.fadeOut(withDuration: 0.3), .scale(to: 0.6, duration: 0.3)]),
            .removeFromParent()]))

        if !dailyMode { Wallet.maxLevel = max(Wallet.maxLevel, Wallet.level + 1) }
        let newAchievements = Achievements.evaluate()
        for (i, a) in newAchievements.enumerated() {
            showAchievementPopup(a, delay: 0.7 + Double(i) * 2.0)
        }
        let advanceWait = newAchievements.isEmpty ? 1.95 : 0.7 + Double(newAchievements.count) * 2.0 + 0.6

        run(.sequence([.wait(forDuration: advanceWait), .run { [weak self] in
            guard let self else { return }
            self.showWinSummary(gained: gained)
        }]))
    }

    private func showWinSummary(gained: Int) {
        clearOverlay()
        let cx = size.width / 2, cy = size.height / 2
        let dim = SKSpriteNode(color: UIColor(white: 0.35, alpha: 0.30), size: size)
        dim.position = CGPoint(x: cx, y: cy); overlay.addChild(dim)
        let panel = SKShapeNode(rectOf: CGSize(width: min(size.width - 70, 440 * uiScale), height: 330 * uiScale), cornerRadius: 28)
        panel.fillColor = UIColor(white: 1, alpha: 0.98); panel.strokeColor = GamePalette.tileLine; panel.lineWidth = 1.5
        panel.position = CGPoint(x: cx, y: cy); panel.zPosition = 1; overlay.addChild(panel)
        let perfect = movesMade <= level.minMoves
        let title = makeLabel(perfect ? "Mükemmel! ✨" : "Bölüm tamamlandı!", size: 29 * uiScale, weight: Theme.heavy)
        title.fontColor = GamePalette.textPlum; title.position = CGPoint(x: cx, y: cy + 112 * uiScale); title.zPosition = 2; overlay.addChild(title)
        let result = makeLabel("\(movesMade) hamlede çözdün", size: 20 * uiScale, weight: Theme.heavy)
        result.fontColor = perfect ? UIColor(red: 0.30, green: 0.66, blue: 0.52, alpha: 1) : GamePalette.textPlum
        result.position = CGPoint(x: cx, y: cy + 60 * uiScale); result.zPosition = 2; overlay.addChild(result)
        let par = makeLabel("Mükemmel çözüm: \(level.minMoves) hamle", size: 15 * uiScale, weight: Theme.medium)
        par.fontColor = GamePalette.textPlum.withAlphaComponent(0.66); par.position = CGPoint(x: cx, y: cy + 28 * uiScale); par.zPosition = 2; overlay.addChild(par)
        if gained > 0 {
            let reward = makeLabel("+\(gained) 💎", size: 23 * uiScale, weight: Theme.heavy)
            reward.fontColor = UIColor(red: 0.30, green: 0.66, blue: 0.52, alpha: 1)
            reward.position = CGPoint(x: cx, y: cy - 18 * uiScale); reward.zPosition = 2; overlay.addChild(reward)
        }
        addOverlayButton(name: "win_continue", title: dailyMode ? "Menüye Dön" : "Devam",
                         fill: UIColor(red: 0.78, green: 0.66, blue: 0.95, alpha: 0.95), text: .white, y: cy - 92 * uiScale)
    }

    private func finishWinSummary() {
        clearOverlay()
        dailyMode ? goToMenu() : advance()
    }

    private func showAchievementPopup(_ a: Achievement, delay: TimeInterval) {
        let w = min(size.width - 60, 360 * uiScale)
        let pill = SKNode()
        let bg = SKShapeNode(rectOf: CGSize(width: w, height: 62 * uiScale), cornerRadius: 20 * uiScale)
        bg.fillColor = UIColor(red: 0.42, green: 0.36, blue: 0.60, alpha: 0.97)
        bg.strokeColor = UIColor(white: 1, alpha: 0.3); bg.lineWidth = 1
        pill.addChild(bg)
        let icon = makeLabel(a.icon, size: 26 * uiScale, weight: Theme.heavy)
        icon.position = CGPoint(x: -w / 2 + 32 * uiScale, y: 0); pill.addChild(icon)
        let head = makeLabel("🏆 Başarım açıldı!", size: 12 * uiScale, weight: Theme.medium)
        head.fontColor = UIColor(white: 1, alpha: 0.8); head.horizontalAlignmentMode = .left
        head.position = CGPoint(x: -w / 2 + 58 * uiScale, y: 11 * uiScale); pill.addChild(head)
        let title = makeLabel(a.title, size: 17 * uiScale, weight: Theme.heavy)
        title.fontColor = .white; title.horizontalAlignmentMode = .left
        title.position = CGPoint(x: -w / 2 + 58 * uiScale, y: -10 * uiScale); pill.addChild(title)

        let topY = size.height - safeTop() - 70 * uiScale
        pill.position = CGPoint(x: size.width / 2, y: topY + 44 * uiScale); pill.alpha = 0; pill.zPosition = 320
        addChild(pill)
        pill.run(.sequence([
            .wait(forDuration: delay),
            .run { [weak self] in self?.haptic(.medium) },
            .group([.fadeIn(withDuration: 0.25), .moveTo(y: topY, duration: 0.3)]),
            .wait(forDuration: 1.6),
            .group([.fadeOut(withDuration: 0.3), .moveTo(y: topY + 44 * uiScale, duration: 0.3)]),
            .removeFromParent()]))
    }

    private func winBurst() {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let glow = SKShapeNode(circleOfRadius: 70 * uiScale)
        glow.fillColor = UIColor(red: 1, green: 0.96, blue: 0.78, alpha: 1); glow.strokeColor = .clear
        glow.position = c; glow.zPosition = 206; glow.alpha = 0
        addChild(glow)
        glow.run(.sequence([.fadeAlpha(to: 0.55, duration: 0.12), .fadeAlpha(to: 0, duration: 0.55), .removeFromParent()]))
        for (i, col) in [GamePalette.amber, GamePalette.core(.blue)].enumerated() {
            let ring = SKShapeNode(circleOfRadius: 40 * uiScale)
            ring.strokeColor = col.withAlphaComponent(0.85); ring.lineWidth = 4 * uiScale; ring.fillColor = .clear
            ring.position = c; ring.zPosition = 206; ring.setScale(0.3)
            addChild(ring)
            ring.run(.sequence([.wait(forDuration: Double(i) * 0.12),
                                .group([.scale(to: 3.4, duration: 0.6), .fadeOut(withDuration: 0.6)]),
                                .removeFromParent()]))
        }
    }

    private func celebrateTargets() {
        for (coord, set) in level.targetCoords {
            let ring = SKShapeNode(circleOfRadius: cell * 0.34)
            ring.strokeColor = GamePalette.mixColor(set); ring.lineWidth = 3; ring.fillColor = .clear
            ring.position = cellCenter(coord); ring.zPosition = 20
            addChild(ring)
            ring.run(.sequence([.group([.scale(to: 2.0, duration: 0.5), .fadeOut(withDuration: 0.5)]),
                                .removeFromParent()]))
        }
    }

    private func flyCoins(count: Int, startValue: Int) {
        let origin = CGPoint(x: size.width / 2, y: size.height / 2 - 44 * uiScale)
        let dest = CGPoint(x: size.width - 70 * uiScale, y: topY + 8 * uiScale)
        let tokens = min(count, 12)
        guard tokens > 0 else { return }
        let per = max(1, count / tokens)
        var landed = 0
        for i in 0..<tokens {
            let coin = SKShapeNode(circleOfRadius: 9 * uiScale)
            coin.fillColor = UIColor(red: 0.44, green: 0.82, blue: 0.74, alpha: 1)
            coin.strokeColor = .white; coin.lineWidth = 1.5
            coin.position = origin; coin.zPosition = 215; coin.setScale(0.1)
            addChild(coin)
            let spread = CGPoint(x: origin.x + CGFloat.random(in: -45...45) * uiScale,
                                 y: origin.y + CGFloat.random(in: 28...72) * uiScale)
            coin.run(.sequence([
                .group([.scale(to: 1.0, duration: 0.16), .move(to: spread, duration: 0.22)]),
                .wait(forDuration: 0.2 + Double(i) * 0.05),
                .group([.move(to: dest, duration: 0.42), .scale(to: 0.4, duration: 0.42)]),
                .run { [weak self] in
                    guard let self else { return }
                    landed += per
                    self.coinLabel.text = "\(min(startValue + landed, Wallet.coins))"
                    self.coinLabel.run(.sequence([.scale(to: 1.3, duration: 0.07), .scale(to: 1.0, duration: 0.08)]))
                    self.haptic(.light)
                },
                .removeFromParent()]))
        }
        run(.sequence([.wait(forDuration: 1.5), .run { [weak self] in self?.coinLabel.text = "\(Wallet.coins)" }]))
    }

    private func advance() {
        busy = false
        Wallet.level += 1
        Wallet.maxLevel = max(Wallet.maxLevel, Wallet.level)
        loadLevel(Wallet.level)
    }

    private func confetti() {
        let colors: [UIColor] = [GamePalette.core(.red), GamePalette.core(.blue), GamePalette.core(.yellow),
                                 GamePalette.mixColor([.red, .blue]), GamePalette.mixColor([.blue, .yellow])]
        for i in 0..<5 {
            let e = SKEmitterNode()
            e.particleTexture = circleTexture(radius: 6, color: .white)
            e.particleColor = colors[i]
            e.particleColorBlendFactor = 1
            e.position = CGPoint(x: CGFloat.random(in: size.width * 0.2...size.width * 0.8), y: size.height + 20)
            e.particleBirthRate = 120
            e.numParticlesToEmit = 30
            e.particleLifetime = 2.2
            e.particlePositionRange = CGVector(dx: size.width * 0.5, dy: 0)
            e.yAcceleration = -260
            e.particleSpeed = 60
            e.particleSpeedRange = 40
            e.emissionAngle = -.pi / 2
            e.emissionAngleRange = 0.5
            e.particleScale = 0.5
            e.particleScaleRange = 0.3
            e.particleAlpha = 0.95
            e.particleAlphaSpeed = -0.4
            e.particleRotationSpeed = 3
            e.zPosition = 205
            addChild(e)
            e.run(.sequence([.wait(forDuration: 2.8), .removeFromParent()]))
        }
    }



    // MARK: - Ortak Arayüz Bileşenleri

    private func makeLabel(_ text: String, size: CGFloat, weight: String) -> SKLabelNode {
        let l = SKLabelNode(fontNamed: weight)
        l.text = text
        l.fontSize = size
        l.fontColor = GamePalette.textPlum
        l.horizontalAlignmentMode = .center
        l.verticalAlignmentMode = .center
        return l
    }

    private func makePill(text: String, width: CGFloat, height: CGFloat,
                          fill: UIColor, line: UIColor, textColor: UIColor,
                          fontSize: CGFloat, name: String) -> SKNode {
        let node = SKNode()
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
        let l = makeLabel(text, size: fontSize, weight: Theme.medium)
        l.fontColor = textColor
        l.name = name
        l.isAccessibilityElement = false
        node.addChild(l)
        node.name = name
        return node
    }

    private func gradientTexture(size: CGSize, top: UIColor, mid: UIColor, bottom: UIColor) -> SKTexture {
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let cg = ctx.cgContext
            let colors = [top.cgColor, mid.cgColor, bottom.cgColor] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.5, 1])!
            cg.drawLinearGradient(grad, start: CGPoint(x: 0, y: 0),
                                  end: CGPoint(x: size.width * 0.3, y: size.height),
                                  options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        }
        return SKTexture(image: img)
    }

    private func circleTexture(radius: CGFloat, color: UIColor) -> SKTexture {
        let s = CGSize(width: radius * 2, height: radius * 2)
        let img = UIGraphicsImageRenderer(size: s).image { ctx in
            color.setFill()
            ctx.cgContext.fillEllipse(in: CGRect(origin: .zero, size: s))
        }
        return SKTexture(image: img)
    }

    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard Wallet.hapticsOn else { return }
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    private func flashToast(_ text: String) {
        let l = makeLabel(text, size: 15 * uiScale, weight: Theme.medium)
        l.fontColor = .white
        let pad: CGFloat = 18 * uiScale
        let bg = SKShapeNode(rectOf: CGSize(width: l.frame.width + pad * 2, height: 42 * uiScale), cornerRadius: 21 * uiScale)
        bg.fillColor = UIColor(red: 0.42, green: 0.36, blue: 0.60, alpha: 0.95); bg.strokeColor = .clear
        bg.position = CGPoint(x: size.width / 2, y: safeBottom() + 112 * uiScale); bg.zPosition = 220
        l.position = bg.position; l.zPosition = 221
        addChild(bg); addChild(l)
        let fade = SKAction.sequence([.wait(forDuration: 1.3), .fadeOut(withDuration: 0.4), .removeFromParent()])
        bg.run(fade); l.run(fade)
    }
}

enum Theme {
    static let heavy = "AvenirNext-Heavy"
    static let medium = "AvenirNext-DemiBold"
}
