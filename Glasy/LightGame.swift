import CoreGraphics

// MARK: - Temel Modeller

enum BeamDirection: CaseIterable {
    case up, down, left, right

    var delta: (c: Int, r: Int) {
        switch self {
        case .up:    return (0, -1)
        case .down:  return (0,  1)
        case .left:  return (-1, 0)
        case .right: return (1,  0)
        }
    }
    var opposite: BeamDirection {
        switch self {
        case .up: return .down; case .down: return .up
        case .left: return .right; case .right: return .left
        }
    }
    var isHorizontal: Bool { self == .left || self == .right }
    var perpendiculars: [BeamDirection] { isHorizontal ? [.up, .down] : [.left, .right] }
}

enum MirrorOrientation {
    case slash
    case backslash
    var toggled: MirrorOrientation { self == .slash ? .backslash : .slash }
}

enum MirrorState: Int, CaseIterable {
    case slashA, slashB, backA, backB
    var orient: MirrorOrientation { (self == .slashA || self == .slashB) ? .slash : .backslash }
    var cycled: MirrorState { MirrorState(rawValue: (rawValue + 1) % 4)! }
    func steps(to other: MirrorState) -> Int { ((other.rawValue - rawValue) % 4 + 4) % 4 }
}

enum LightColor: Int, CaseIterable {
    case red, blue, yellow
}

struct GridCoordinate: Hashable {
    var c: Int
    var r: Int
    static func + (a: GridCoordinate, d: BeamDirection) -> GridCoordinate { GridCoordinate(c: a.c + d.delta.c, r: a.r + d.delta.r) }
    static func - (a: GridCoordinate, d: BeamDirection) -> GridCoordinate { GridCoordinate(c: a.c - d.delta.c, r: a.r - d.delta.r) }
}

enum Piece {
    case empty
    case wall
    case source(BeamDirection, LightColor)
    case mirror(MirrorOrientation)
    case fixedMirror(MirrorOrientation)
    case splitter(MirrorOrientation)
    case filter(LightColor)
    case glass
    case portal(Int)
    case halfMirror(MirrorState)
    case target(Set<LightColor>)
}

struct Beam {
    let color: LightColor
    let points: [CGPoint]
}

struct BeamVisitKey: Hashable { let c: Int; let r: Int; let d: BeamDirection }

// MARK: - Yansıma

func reflect(_ dir: BeamDirection, _ orient: MirrorOrientation) -> BeamDirection {
    switch (orient, dir) {
    case (.slash, .right): return .up
    case (.slash, .up):    return .right
    case (.slash, .left):  return .down
    case (.slash, .down):  return .left
    case (.backslash, .right): return .down
    case (.backslash, .down):  return .right
    case (.backslash, .left):  return .up
    case (.backslash, .up):    return .left
    }
}

func mirrorMapping(_ inDir: BeamDirection, _ outDir: BeamDirection) -> MirrorOrientation {
    reflect(inDir, .slash) == outDir ? .slash : .backslash
}

func reflectHalf(_ dir: BeamDirection, _ s: MirrorState) -> BeamDirection? {
    switch (s, dir) {
    case (.slashA, .up):    return .right
    case (.slashA, .left):  return .down
    case (.slashB, .down):  return .left
    case (.slashB, .right): return .up
    case (.backA, .up):     return .left
    case (.backA, .right):  return .down
    case (.backB, .down):   return .right
    case (.backB, .left):   return .up
    default:                return nil
    }
}

func mirrorStateMapping(_ inDir: BeamDirection, _ outDir: BeamDirection) -> MirrorState? {
    MirrorState.allCases.first { reflectHalf(inDir, $0) == outDir }
}

// MARK: - Bölüm

final class Level {
    let rows: Int
    let cols: Int
    var pieces: [[Piece]]
    var solved: [GridCoordinate: MirrorOrientation] = [:]
    var initial: [GridCoordinate: MirrorOrientation] = [:]
    var solvedHalf: [GridCoordinate: MirrorState] = [:]
    var initialHalf: [GridCoordinate: MirrorState] = [:]
    let number: Int

    init(rows: Int, cols: Int, number: Int) {
        self.rows = rows
        self.cols = cols
        self.number = number
        self.pieces = Array(repeating: Array(repeating: .empty, count: cols), count: rows)
    }

    func inBounds(_ x: GridCoordinate) -> Bool { x.c >= 0 && x.c < cols && x.r >= 0 && x.r < rows }
    func piece(_ x: GridCoordinate) -> Piece { inBounds(x) ? pieces[x.r][x.c] : .wall }
    func set(_ x: GridCoordinate, _ p: Piece) { if inBounds(x) { pieces[x.r][x.c] = p } }

    var mirrorCoords: [GridCoordinate] {
        var out: [GridCoordinate] = []
        for r in 0..<rows { for c in 0..<cols {
            if case .mirror = pieces[r][c] { out.append(GridCoordinate(c: c, r: r)) }
        } }
        return out
    }
    var halfMirrorCoords: [GridCoordinate] {
        var out: [GridCoordinate] = []
        for r in 0..<rows { for c in 0..<cols {
            if case .halfMirror = pieces[r][c] { out.append(GridCoordinate(c: c, r: r)) }
        } }
        return out
    }
    var targetCoords: [(GridCoordinate, Set<LightColor>)] {
        var out: [(GridCoordinate, Set<LightColor>)] = []
        for r in 0..<rows { for c in 0..<cols {
            if case .target(let set) = pieces[r][c] { out.append((GridCoordinate(c: c, r: r), set)) }
        } }
        return out
    }

    func toggleMirror(_ x: GridCoordinate) {
        if case .mirror(let o) = piece(x) { set(x, .mirror(o.toggled)) }
    }
    func toggleHalfMirror(_ x: GridCoordinate) {
        if case .halfMirror(let s) = piece(x) { set(x, .halfMirror(s.cycled)) }
    }

    func partnerPortal(of x: GridCoordinate, id: Int) -> GridCoordinate? {
        for r in 0..<rows { for c in 0..<cols {
            if case .portal(let pid) = pieces[r][c], pid == id, !(c == x.c && r == x.r) {
                return GridCoordinate(c: c, r: r)
            }
        } }
        return nil
    }

    func captureInitial() {
        initial.removeAll(); initialHalf.removeAll()
        for x in mirrorCoords { if case .mirror(let o) = piece(x) { initial[x] = o } }
        for x in halfMirrorCoords { if case .halfMirror(let s) = piece(x) { initialHalf[x] = s } }
    }
    func resetToInitial() {
        for (x, o) in initial { set(x, .mirror(o)) }
        for (x, s) in initialHalf { set(x, .halfMirror(s)) }
    }

    var minMoves: Int {
        var n = 0
        for (coord, want) in solved where (initial[coord] ?? want) != want { n += 1 }
        for (coord, want) in solvedHalf { n += (initialHalf[coord] ?? want).steps(to: want) }
        return max(1, n)
    }
    var moveLimit: Int { minMoves * 2 + 7 }



    /// Tüm kaynaklardan çıkan ışınları hesaplar ve hedeflere ulaşan renkleri döndürür.
    func computeBeams() -> (beams: [Beam], incident: [GridCoordinate: Set<LightColor>]) {
        var beams: [Beam] = []
        var incident: [GridCoordinate: Set<LightColor>] = [:]
        for r in 0..<rows { for c in 0..<cols {
            guard case .source(let dir, let color) = pieces[r][c] else { continue }
            traceColor(from: GridCoordinate(c: c, r: r), dir: dir, color: color, beams: &beams, incident: &incident)
        } }
        return (beams, incident)
    }

    /// Döngüleri ziyaret anahtarıyla keserek tek bir rengin bütün dallarını izler.
    private func traceColor(from start: GridCoordinate, dir dir0: BeamDirection, color: LightColor,
                            beams: inout [Beam], incident: inout [GridCoordinate: Set<LightColor>]) {
        var visited = Set<BeamVisitKey>()
        var work: [(origin: GridCoordinate, dir: BeamDirection)] = [(start, dir0)]

        while let head = work.popLast() {
            var pos = head.origin
            var d = head.dir
            var pts: [CGPoint] = [pt(pos)]
            rayLoop: while true {
                let k = BeamVisitKey(c: pos.c, r: pos.r, d: d)
                if visited.contains(k) { break rayLoop }
                visited.insert(k)

                let next = pos + d
                if !inBounds(next) { pts.append(edgePoint(from: pos, dir: d)); break rayLoop }

                switch piece(next) {
                case .empty, .glass:
                    pos = next; pts.append(pt(pos))
                case .mirror(let o), .fixedMirror(let o):
                    pos = next; pts.append(pt(pos)); d = reflect(d, o)
                case .filter(let fc):
                    if fc == color { pos = next; pts.append(pt(pos)) }
                    else { pts.append(facePoint(of: next, from: pos)); break rayLoop }
                case .splitter(let o):
                    pos = next; pts.append(pt(pos))
                    work.append((origin: pos, dir: reflect(d, o)))
                case .portal(let id):
                    pos = next; pts.append(pt(pos))
                    if pts.count >= 2 { beams.append(Beam(color: color, points: pts)) }
                    guard let exit = partnerPortal(of: pos, id: id) else { pts = []; break rayLoop }
                    pos = exit; pts = [pt(pos)]
                case .halfMirror(let s):
                    pos = next; pts.append(pt(pos))
                    if let nd = reflectHalf(d, s) { d = nd }
                case .wall, .source:
                    pts.append(facePoint(of: next, from: pos)); break rayLoop
                case .target:
                    pts.append(pt(next))
                    incident[next, default: []].insert(color)
                    break rayLoop
                }
            }
            if pts.count >= 2 { beams.append(Beam(color: color, points: pts)) }
        }
    }

    var isSolved: Bool {
        guard !targetCoords.isEmpty else { return false }
        let (_, incident) = computeBeams()
        for (coord, req) in targetCoords {
            if (incident[coord] ?? []) != req { return false }
        }
        return true
    }



    private func pt(_ x: GridCoordinate) -> CGPoint { CGPoint(x: CGFloat(x.c), y: CGFloat(x.r)) }
    private func edgePoint(from pos: GridCoordinate, dir: BeamDirection) -> CGPoint {
        CGPoint(x: CGFloat(pos.c) + CGFloat(dir.delta.c) * 0.5,
                y: CGFloat(pos.r) + CGFloat(dir.delta.r) * 0.5)
    }
    private func facePoint(of blocker: GridCoordinate, from pos: GridCoordinate) -> CGPoint {
        CGPoint(x: CGFloat(pos.c) + CGFloat(blocker.c - pos.c) * 0.5,
                y: CGFloat(pos.r) + CGFloat(blocker.r - pos.r) * 0.5)
    }
}

// MARK: - Renk Yardımcıları

extension Set where Element == LightColor {
    var mixKey: String { self.map { String($0.rawValue) }.sorted().joined() }
}
