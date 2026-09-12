import Foundation

struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64
    private let seeded: Bool
    private var sys = SystemRandomNumberGenerator()

    init(seed: UInt64?) {
        if let seed { state = (seed == 0 ? 0x9E3779B9 : seed) &* 0x9E3779B97F4A7C15; seeded = true }
        else { state = 0; seeded = false }
    }
    mutating func next() -> UInt64 {
        guard seeded else { return sys.next() }
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum LevelGenerator {

    static var rng = SeededRandomNumberGenerator(seed: nil)

    static let normalSeed: UInt64 = 0xA17E_C0DE

    struct Config {
        var rows: Int
        var cols: Int
        var specs: [Set<LightColor>]
        var segMin: Int
        var segMax: Int
        var maxRun: Int
        var decoys: Int
        var walls: Int
        var fixedMirrors: Int
        var splitters: Int
        var filters: Int
        var glass: Int
        var portals: Int
        var halfMirrors: Int
    }

    static func config(level n: Int) -> Config {
        func clamp(_ v: Int, _ lo: Int, _ hi: Int) -> Int { min(max(v, lo), hi) }
        let cols = clamp(5 + n / 3, 5, 8)
        let rows = clamp(4 + n / 3, 4, 8)

        let splittersN = n < 10 ? 0 : 1
        let portalsN   = n < 16 ? 0 : 1

        var specs: [Set<LightColor>]
        switch n {
        case 1: specs = [[.red]]
        case 2: specs = [[.red], [.blue]]
        case 3: specs = [[.red], [.blue], [.yellow]]
        default:
            let budget = clamp(3 + (n - 4) / 6, 3, 5)
            let count  = max(1, budget - 2 * splittersN - portalsN)
            let mixes: [Set<LightColor>] = [[.red, .blue], [.blue, .yellow], [.red, .yellow]]
            specs = [mixes.randomElement(using: &rng)!]
            let primaries: [Set<LightColor>] = [[.red], [.blue], [.yellow]]
            while specs.count < count { specs.append(primaries.randomElement(using: &rng)!) }
        }

        let minSeg = n <= 1 ? 2 : (n <= 3 ? 3 : 2)

        return Config(rows: rows, cols: cols, specs: specs,
                      segMin: minSeg,
                      segMax: max(minSeg, clamp(2 + n / 4, 2, 5)),
                      maxRun: 3,
                      decoys: n < 4 ? 0 : clamp((n - 3) / 3, 0, 3),
                      walls: n < 3 ? 0 : clamp((n - 2) / 3, 0, 3),
                      fixedMirrors: n < 7  ? 0 : clamp(n - 6, 1, 2),
                      splitters:    splittersN,
                      filters:      n < 14 ? 0 : 1,
                      glass:        n < 4  ? 0 : 1,
                      portals:      portalsN,
                      halfMirrors:  n < 12 ? 0 : 1)
    }

    /// Aynı bölüm ve tohum için aynı, çözülebilir bulmacayı üretir.
    static func generate(level n: Int, seed: UInt64? = nil) -> Level {
        let saved = rng
        if let seed { rng = SeededRandomNumberGenerator(seed: seed &+ UInt64(n)) }
        defer { rng = saved }
        let cfg = config(level: n)
        for _ in 0..<300 {
            guard let lvl = attempt(cfg, n) else { continue }
            guard lvl.isSolved, hasLoadBearingRotatableMirror(lvl) else { continue }
            guard scrambleToStart(lvl, floor: minMovesFloor(n)) else { continue }
            lvl.captureInitial()
            return lvl
        }
        return fallback(n)
    }



    // MARK: - Bölüm Üretimi

    private static func attempt(_ cfg: Config, _ n: Int) -> Level? {
        let lvl = Level(rows: cfg.rows, cols: cfg.cols, number: n)
        var used = Set<GridCoordinate>()

        func free(_ x: GridCoordinate) -> Bool {
            guard lvl.inBounds(x), !used.contains(x) else { return false }
            if case .empty = lvl.piece(x) { return true }
            return false
        }
        func reserve(_ x: GridCoordinate) { used.insert(x) }

        for _ in 0..<cfg.splitters {
            _ = carveSharedSource(lvl: lvl, color: LightColor.allCases.randomElement(using: &rng)!,
                                  free: free, reserve: reserve)
        }
        for i in 0..<cfg.portals {
            _ = carvePortalPair(lvl: lvl, color: LightColor.allCases.randomElement(using: &rng)!,
                                id: i, free: free, reserve: reserve)
        }

        var targets: [(GridCoordinate, Set<LightColor>)] = []
        for spec in cfg.specs {
            var placed = false
            for _ in 0..<40 {
                let c = Int.random(in: 0..<cfg.cols, using: &rng)
                let r = Int.random(in: 0..<cfg.rows, using: &rng)
                let coord = GridCoordinate(c: c, r: r)
                guard free(coord) else { continue }
                let freeSides = BeamDirection.allCases.filter { free(coord + $0) }.count
                guard freeSides >= spec.count else { continue }
                lvl.set(coord, .target(spec))
                reserve(coord)
                targets.append((coord, spec))
                placed = true
                break
            }
            if !placed { return nil }
        }

        var fixedBudget = cfg.fixedMirrors
        var filterBudget = cfg.filters
        var halfBudget = cfg.halfMirrors
        for (coord, spec) in targets {
            let candidateArrs = BeamDirection.allCases.shuffled(using: &rng).filter { free(coord - $0) }
            guard candidateArrs.count >= spec.count else { return nil }
            let colors = spec.sorted { $0.rawValue < $1.rawValue }.shuffled(using: &rng)
            for i in 0..<colors.count {
                let arr = candidateArrs[i]
                if !carveBeam(lvl: lvl, target: coord, arr: arr, color: colors[i],
                              cfg: cfg, free: free, reserve: reserve,
                              fixedBudget: &fixedBudget, filterBudget: &filterBudget,
                              halfBudget: &halfBudget) {
                    return nil
                }
            }
        }

        for _ in 0..<cfg.fixedMirrors {
            if let x = randomFree(lvl, used) { lvl.set(x, .fixedMirror(Bool.random(using: &rng) ? .slash : .backslash)); used.insert(x) }
        }
        for _ in 0..<cfg.filters {
            if let x = randomFree(lvl, used) { lvl.set(x, .filter(LightColor.allCases.randomElement(using: &rng)!)); used.insert(x) }
        }
        for _ in 0..<cfg.glass {
            if let x = randomFree(lvl, used) { lvl.set(x, .glass); used.insert(x) }
        }
        for _ in 0..<cfg.decoys {
            if let x = randomFree(lvl, used) { lvl.set(x, .mirror(Bool.random(using: &rng) ? .slash : .backslash)); used.insert(x) }
        }
        for _ in 0..<cfg.walls {
            if let x = randomFree(lvl, used) { lvl.set(x, .wall); used.insert(x) }
        }
        return lvl
    }

    private static func carveBeam(lvl: Level, target: GridCoordinate, arr: BeamDirection, color: LightColor,
                                  cfg: Config,
                                  free: (GridCoordinate) -> Bool, reserve: (GridCoordinate) -> Void,
                                  fixedBudget: inout Int, filterBudget: inout Int,
                                  halfBudget: inout Int) -> Bool {
        var cell = target - arr
        guard free(cell) else { return false }
        reserve(cell)
        var fdir = arr
        let segments = Int.random(in: cfg.segMin...cfg.segMax, using: &rng)

        for seg in 0..<segments {
            let runLen = Int.random(in: 1...cfg.maxRun, using: &rng)
            var extended = 0
            while extended < runLen {
                let nxt = cell - fdir
                guard free(nxt) else { break }
                reserve(nxt); cell = nxt; extended += 1
                if filterBudget > 0, extended == 1, runLen >= 2, Bool.random(using: &rng) {
                    lvl.set(cell, .filter(color)); filterBudget -= 1
                }
            }

            if seg == segments - 1 {
                lvl.set(cell, .source(fdir, color))
                return true
            }
            var turned = false
            for inDir in fdir.perpendiculars.shuffled(using: &rng) {
                let prev = cell - inDir
                if free(prev) {
                    let o = mirrorMapping(inDir, fdir)
                    if fixedBudget > 0, Bool.random(using: &rng) {
                        lvl.set(cell, .fixedMirror(o))
                        fixedBudget -= 1
                    } else if halfBudget > 0, Bool.random(using: &rng) {
                        let s = mirrorStateMapping(inDir, fdir)!
                        lvl.set(cell, .halfMirror(s))
                        lvl.solvedHalf[cell] = s
                        halfBudget -= 1
                    } else {
                        lvl.set(cell, .mirror(o))
                        lvl.solved[cell] = o
                    }
                    reserve(prev); cell = prev; fdir = inDir
                    turned = true
                    break
                }
            }
            if !turned {
                lvl.set(cell, .source(fdir, color))
                return true
            }
        }
        return true
    }

    private static func carveSharedSource(lvl: Level, color: LightColor,
                                          free: (GridCoordinate) -> Bool, reserve: (GridCoordinate) -> Void) -> Bool {
        for _ in 0..<30 {
            guard lvl.cols > 2, lvl.rows > 2 else { return false }
            let s = GridCoordinate(c: Int.random(in: 1..<lvl.cols - 1, using: &rng), r: Int.random(in: 1..<lvl.rows - 1, using: &rng))
            let dStraight = BeamDirection.allCases.randomElement(using: &rng)!
            let o: MirrorOrientation = Bool.random(using: &rng) ? .slash : .backslash
            let dBent = reflect(dStraight, o)

            var claimed = Set<GridCoordinate>()
            var plan: [(GridCoordinate, Piece)] = []
            var mirrorAt: (GridCoordinate, MirrorOrientation)? = nil
            func claim(_ x: GridCoordinate) -> Bool {
                if claimed.contains(x) { return false }
                guard free(x) else { return false }
                claimed.insert(x); return true
            }

            guard claim(s) else { continue }
            plan.append((s, .splitter(o)))

            var ok = true
            var cell = s
            for _ in 0..<Int.random(in: 1...2, using: &rng) { cell = cell + dStraight; if !claim(cell) { ok = false; break } }
            guard ok else { continue }
            plan.append((cell, .target([color])))

            ok = true; cell = s
            for _ in 0..<Int.random(in: 1...2, using: &rng) { cell = cell + dBent; if !claim(cell) { ok = false; break } }
            guard ok else { continue }
            plan.append((cell, .target([color])))

            ok = true; cell = s
            for _ in 0..<Int.random(in: 0...2, using: &rng) { cell = cell - dStraight; if !claim(cell) { ok = false; break } }
            guard ok else { continue }
            let m = cell - dStraight
            guard claim(m) else { continue }
            var sourced = false
            for inDir in dStraight.perpendiculars.shuffled(using: &rng) {
                let src = m - inDir
                if claim(src) {
                    mirrorAt = (m, mirrorMapping(inDir, dStraight))
                    plan.append((m, .mirror(mirrorMapping(inDir, dStraight))))
                    plan.append((src, .source(inDir, color)))
                    sourced = true
                    break
                }
            }
            guard sourced else { continue }

            for x in claimed { reserve(x) }
            for (x, p) in plan { lvl.set(x, p) }
            if let (mc, mo) = mirrorAt { lvl.solved[mc] = mo }
            return true
        }
        return false
    }

    private static func carvePortalPair(lvl: Level, color: LightColor, id: Int,
                                        free: (GridCoordinate) -> Bool, reserve: (GridCoordinate) -> Void) -> Bool {
        for _ in 0..<30 {
            guard lvl.cols > 3, lvl.rows > 3 else { return false }
            let d = BeamDirection.allCases.randomElement(using: &rng)!

            var claimed = Set<GridCoordinate>()
            var plan: [(GridCoordinate, Piece)] = []
            var mirrorAt: (GridCoordinate, MirrorOrientation)? = nil
            func claim(_ x: GridCoordinate) -> Bool {
                if claimed.contains(x) { return false }
                guard free(x) else { return false }
                claimed.insert(x); return true
            }

            let pa = GridCoordinate(c: Int.random(in: 0..<lvl.cols, using: &rng),
                           r: Int.random(in: 0..<lvl.rows, using: &rng))
            guard claim(pa) else { continue }
            var cell = pa, ok = true
            for _ in 0..<Int.random(in: 1...2, using: &rng) { cell = cell + d; if !claim(cell) { ok = false; break } }
            guard ok else { continue }
            plan.append((pa, .portal(id)))
            plan.append((cell, .target([color])))

            var pb: GridCoordinate? = nil
            for _ in 0..<20 {
                let cand = GridCoordinate(c: Int.random(in: 0..<lvl.cols, using: &rng),
                                 r: Int.random(in: 0..<lvl.rows, using: &rng))
                if !claimed.contains(cand), free(cand) { pb = cand; break }
            }
            guard let pbc = pb, claim(pbc) else { continue }
            plan.append((pbc, .portal(id)))

            cell = pbc; ok = true
            for _ in 0..<Int.random(in: 0...2, using: &rng) { cell = cell - d; if !claim(cell) { ok = false; break } }
            guard ok else { continue }
            let m = cell - d
            guard claim(m) else { continue }
            var sourced = false
            for inDir in d.perpendiculars.shuffled(using: &rng) {
                let src = m - inDir
                if claim(src) {
                    mirrorAt = (m, mirrorMapping(inDir, d))
                    plan.append((m, .mirror(mirrorMapping(inDir, d))))
                    plan.append((src, .source(inDir, color)))
                    sourced = true
                    break
                }
            }
            guard sourced else { continue }

            for x in claimed { reserve(x) }
            for (x, p) in plan { lvl.set(x, p) }
            if let (mc, mo) = mirrorAt { lvl.solved[mc] = mo }
            return true
        }
        return false
    }

    private static func hasLoadBearingRotatableMirror(_ lvl: Level) -> Bool {
        guard !lvl.mirrorCoords.isEmpty || !lvl.halfMirrorCoords.isEmpty else { return false }
        for x in lvl.mirrorCoords {
            lvl.toggleMirror(x)
            let broke = !lvl.isSolved
            lvl.toggleMirror(x)
            if broke { return true }
        }
        for x in lvl.halfMirrorCoords {
            lvl.toggleHalfMirror(x)
            let broke = !lvl.isSolved
            lvl.toggleHalfMirror(x); lvl.toggleHalfMirror(x); lvl.toggleHalfMirror(x)
            if broke { return true }
        }
        return false
    }

    private static func randomFree(_ lvl: Level, _ used: Set<GridCoordinate>) -> GridCoordinate? {
        var pool: [GridCoordinate] = []
        for r in 0..<lvl.rows { for c in 0..<lvl.cols {
            let x = GridCoordinate(c: c, r: r)
            if !used.contains(x), case .empty = lvl.piece(x) { pool.append(x) }
        } }
        return pool.randomElement(using: &rng)
    }

    static func minMovesFloor(_ n: Int) -> Int {
        switch n {
        case ...1:   return 1
        case 2...3:  return 2
        case 4...7:  return 3
        case 8...12: return 4
        default:     return 5
        }
    }

    @discardableResult
    private static func scrambleToStart(_ lvl: Level, floor: Int) -> Bool {
        let pathFulls  = Set(lvl.solved.keys)
        let pathHalves = Set(lvl.solvedHalf.keys)

        for c in lvl.mirrorCoords where !pathFulls.contains(c) {
            lvl.set(c, .mirror(Bool.random(using: &rng) ? .slash : .backslash))
        }
        for c in lvl.halfMirrorCoords where !pathHalves.contains(c) {
            lvl.set(c, .halfMirror(MirrorState.allCases.randomElement(using: &rng)!))
        }
        for (c, o) in lvl.solved { lvl.set(c, .mirror(o)) }
        for (c, s) in lvl.solvedHalf { lvl.set(c, .halfMirror(s)) }

        let fulls  = lvl.solved.keys.sorted     { ($0.r, $0.c) < ($1.r, $1.c) }
        let halves = lvl.solvedHalf.keys.sorted { ($0.r, $0.c) < ($1.r, $1.c) }
        func isLit(_ t: GridCoordinate, _ req: Set<LightColor>) -> Bool {
            let (_, inc) = lvl.computeBeams(); return (inc[t] ?? []) == req
        }
        func anyLit() -> Bool { lvl.targetCoords.contains { isLit($0.0, $0.1) } }
        func wrongMoves() -> Int {
            var m = 0
            for (c, want) in lvl.solved { if case .mirror(let o) = lvl.piece(c), o != want { m += 1 } }
            for (c, want) in lvl.solvedHalf { if case .halfMirror(let s) = lvl.piece(c) { m += s.steps(to: want) } }
            return m
        }

        for c in fulls {
            if wrongMoves() >= floor { break }
            if case .mirror(let o) = lvl.piece(c), o == lvl.solved[c]! { lvl.set(c, .mirror(o.toggled)) }
        }
        for c in halves {
            while wrongMoves() < floor {
                guard case .halfMirror(let s) = lvl.piece(c), s.steps(to: lvl.solvedHalf[c]!) < 3 else { break }
                lvl.set(c, .halfMirror(s.cycled))
            }
            if wrongMoves() >= floor { break }
        }

        for (t, req) in lvl.targetCoords {
            if !isLit(t, req) { continue }
            var darkened = false
            for c in fulls {
                guard case .mirror(let o) = lvl.piece(c), o == lvl.solved[c]! else { continue }
                lvl.set(c, .mirror(o.toggled))
                if !isLit(t, req) { darkened = true; break }
                lvl.set(c, .mirror(o))
            }
            if darkened { continue }
            for c in halves {
                guard case .halfMirror(let s) = lvl.piece(c), s == lvl.solvedHalf[c]! else { continue }
                lvl.set(c, .halfMirror(s.cycled))
                if !isLit(t, req) { darkened = true; break }
                lvl.set(c, .halfMirror(s))
            }
        }

        for c in fulls {
            if !anyLit() { break }
            if case .mirror(let o) = lvl.piece(c), o == lvl.solved[c]! { lvl.set(c, .mirror(o.toggled)) }
        }
        for c in halves {
            while anyLit(), case .halfMirror(let s) = lvl.piece(c), s.steps(to: lvl.solvedHalf[c]!) < 3 {
                lvl.set(c, .halfMirror(s.cycled))
            }
        }
        return !anyLit()
    }



    private static func fallback(_ n: Int) -> Level {
        let lvl = Level(rows: 5, cols: 5, number: n)
        lvl.set(GridCoordinate(c: 0, r: 2), .source(.right, .red))
        let m = GridCoordinate(c: 2, r: 2)
        lvl.set(m, .mirror(.backslash))
        lvl.solved[m] = .slash
        lvl.set(GridCoordinate(c: 2, r: 0), .target([.red]))
        lvl.captureInitial()
        return lvl
    }
}
