import Foundation


var totalFails = 0
let trials = 80

print("band | fails | startsUnsolved | winnable | split fixed filter glass mix portal half (out of \(trials))")
for n in [1, 2, 3, 5, 7, 9, 11, 13, 15, 18, 24, 32] {
    var fails = 0
    var startsUnsolved = 0, winnable = 0
    var sp = 0, fx = 0, fl = 0, gl = 0, mx = 0, po = 0, hm = 0

    for _ in 0..<trials {
        let lvl = LevelGenerator.generate(level: n)

        if !lvl.isSolved { startsUnsolved += 1 } else { fails += 1 }

        if lvl.mirrorCoords.isEmpty && lvl.halfMirrorCoords.isEmpty { fails += 1 }

        let saved = lvl.pieces
        for (coord, o) in lvl.solved { lvl.set(coord, .mirror(o)) }
        for (coord, s) in lvl.solvedHalf { lvl.set(coord, .halfMirror(s)) }
        if lvl.isSolved { winnable += 1 } else { fails += 1 }
        lvl.pieces = saved

        var hSp = false, hFx = false, hFl = false, hGl = false, hMx = false, hPo = false, hHm = false
        for row in lvl.pieces { for p in row {
            switch p {
            case .splitter: hSp = true
            case .fixedMirror: hFx = true
            case .filter: hFl = true
            case .glass: hGl = true
            case .portal: hPo = true
            case .halfMirror: hHm = true
            case .target(let s): if s.count > 1 { hMx = true }
            default: break
            }
        } }
        if hSp { sp += 1 }; if hFx { fx += 1 }; if hFl { fl += 1 }; if hGl { gl += 1 }; if hMx { mx += 1 }; if hPo { po += 1 }; if hHm { hm += 1 }
    }

    totalFails += fails
    print(String(format: "L%-4d | %3d   | %3d            | %3d      | %3d  %3d  %3d   %3d  %3d  %3d  %3d",
                 n, fails, startsUnsolved, winnable, sp, fx, fl, gl, mx, po, hm))
}

print(totalFails == 0 ? "\nALL INVARIANTS HOLD ✅" : "\nTOTAL FAILS=\(totalFails) ❌")
