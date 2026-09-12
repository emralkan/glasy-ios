import Foundation

enum Tutorial {
    private static let d = UserDefaults.standard
    private static func storageKey(_ key: String) -> String { "tut_\(key)" }

    static func seen(_ key: String) -> Bool { d.bool(forKey: storageKey(key)) }
    static func markSeen(_ key: String) { d.set(true, forKey: storageKey(key)) }

    static func resetAll() { allKeys.forEach { d.removeObject(forKey: storageKey($0)) } }

    static let allKeys = ["intro", "mixedTarget", "fixedMirror", "splitter", "filter", "glass", "portal", "halfMirror"]

    struct Card { let key: String; let title: String; let body: String }
    static let cards: [Card] = [
        Card(key: "mixedTarget", title: "Karışık Hedef",
             body: "Bu hedef iki renk ister — iki yarısı hangi renkleri istediğini gösterir. Her iki ışını da buraya ulaştır."),
        Card(key: "fixedMirror", title: "Sabit Ayna",
             body: "Kilitli (🔒) gümüş aynalar dönmez — dokunsan da sabit kalır. Yalnızca sıcak parıltılı aynalar döner."),
        Card(key: "splitter", title: "Prizma",
             body: "Işığı ikiye böler: biri düz devam eder, diğeri 90° saparak yeni bir yol açar."),
        Card(key: "filter", title: "Renk Kapısı",
             body: "Yalnızca kendi rengindeki ışığı geçirir, diğer renkleri yutar."),
        Card(key: "glass", title: "Cam",
             body: "Saydamdır. Işık camın içinden sapmadan, hiç etkilenmeden geçer."),
        Card(key: "portal", title: "Portal",
             body: "Aynı renkteki iki portal bağlıdır. Bir portala giren ışık, diğerinden aynı yönde çıkar."),
        Card(key: "halfMirror", title: "Yarı Ayna",
             body: "Tek yüzü aynalı. Yalnızca parlak yüze çarpan ışını yansıtır; öbür yönden gelen ışık camdan düz geçer. Dokundukça 4 duruma döner."),
    ]
}
