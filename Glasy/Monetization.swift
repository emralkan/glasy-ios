import UIKit
import GoogleMobileAds
import AppTrackingTransparency
import RevenueCat
import Network
import UserMessagingPlatform
import OSLog

enum Wallet {
    private static let d = UserDefaults.standard
    static var level: Int {
        get { max(1, d.integer(forKey: "lp_level")) }
        set { d.set(newValue, forKey: "lp_level") }
    }
    static var maxLevel: Int {
        get { max(level, d.integer(forKey: "lp_maxlevel")) }
        set { d.set(newValue, forKey: "lp_maxlevel") }
    }
    static var coins: Int {
        get { d.integer(forKey: "lp_coins") }
        set { d.set(newValue, forKey: "lp_coins") }
    }
    @discardableResult
    static func spend(_ amount: Int) -> Bool {
        guard coins >= amount else { return false }
        coins -= amount
        return true
    }
    static var soundOn: Bool {
        get { d.object(forKey: "lp_sound") == nil ? true : d.bool(forKey: "lp_sound") }
        set { d.set(newValue, forKey: "lp_sound") }
    }
    static var musicOn: Bool {
        get { d.object(forKey: "lp_music") == nil ? soundOn : d.bool(forKey: "lp_music") }
        set { d.set(newValue, forKey: "lp_music") }
    }
    static var sfxOn: Bool {
        get { d.object(forKey: "lp_sfx") == nil ? soundOn : d.bool(forKey: "lp_sfx") }
        set { d.set(newValue, forKey: "lp_sfx") }
    }
    static var hapticsOn: Bool {
        get { d.object(forKey: "lp_haptics") == nil ? true : d.bool(forKey: "lp_haptics") }
        set { d.set(newValue, forKey: "lp_haptics") }
    }
    static var adsRemoved: Bool {
        get { d.bool(forKey: "lp_remove_ads") }
        set { d.set(newValue, forKey: "lp_remove_ads") }
    }



    static var lastDailyIndex: Int {
        get { d.object(forKey: "lp_daily_idx") == nil ? -1 : d.integer(forKey: "lp_daily_idx") }
        set { d.set(newValue, forKey: "lp_daily_idx") }
    }
    static var dailyStreak: Int {
        get { d.integer(forKey: "lp_daily_streak") }
        set { d.set(newValue, forKey: "lp_daily_streak") }
    }
    static var dailyBest: Int {
        get { d.integer(forKey: "lp_daily_best") }
        set { d.set(newValue, forKey: "lp_daily_best") }
    }



    static var lastLoginIndex: Int {
        get { d.object(forKey: "lp_login_idx") == nil ? -1 : d.integer(forKey: "lp_login_idx") }
        set { d.set(newValue, forKey: "lp_login_idx") }
    }
    static var loginCycleDay: Int {
        get { d.integer(forKey: "lp_login_day") }
        set { d.set(newValue, forKey: "lp_login_day") }
    }



    private static var livesStored: Int {
        get { d.object(forKey: "lp_lives") == nil ? Lives.maxLives : d.integer(forKey: "lp_lives") }
        set { d.set(newValue, forKey: "lp_lives") }
    }
    private static var livesAnchor: Double {
        get { d.double(forKey: "lp_anchor") }
        set { d.set(newValue, forKey: "lp_anchor") }
    }

    static var lives: Int {
        let now = Date().timeIntervalSince1970
        let (l, a) = Lives.resolve(lives: livesStored, anchor: livesAnchor, now: now)
        livesStored = l; livesAnchor = a
        return l
    }
    static func loseLife() {
        let now = Date().timeIntervalSince1970
        var (l, a) = Lives.resolve(lives: livesStored, anchor: livesAnchor, now: now)
        if l >= Lives.maxLives { a = now }
        l = max(0, l - 1)
        livesStored = l; livesAnchor = a
    }
    static func addLife() {
        let now = Date().timeIntervalSince1970
        var (l, a) = Lives.resolve(lives: livesStored, anchor: livesAnchor, now: now)
        l = min(Lives.maxLives, l + 1)
        if l >= Lives.maxLives { a = now }
        livesStored = l; livesAnchor = a
    }
    static var secondsToNextLife: Int {
        let now = Date().timeIntervalSince1970
        let (l, a) = Lives.resolve(lives: livesStored, anchor: livesAnchor, now: now)
        guard l < Lives.maxLives else { return 0 }
        return max(0, Int(Lives.regen - (now - a)))
    }
}

enum Daily {
    static let reward = 50

    static func dayIndex(_ date: Date = Date()) -> Int {
        Int(Calendar.current.startOfDay(for: date).timeIntervalSince1970 / 86_400)
    }
    static var todayIndex: Int { dayIndex() }
    static var seed: UInt64 { UInt64(bitPattern: Int64(todayIndex &* 2_654_435_761)) }
    static var levelNumber: Int { 7 + (todayIndex % 12 + 12) % 12 }
    static var isDoneToday: Bool { Wallet.lastDailyIndex == todayIndex }
    static var streak: Int { Wallet.dailyStreak }

    static func recordCompletion() {
        let today = todayIndex
        guard Wallet.lastDailyIndex != today else { return }
        Wallet.dailyStreak = (Wallet.lastDailyIndex == today - 1) ? Wallet.dailyStreak + 1 : 1
        Wallet.lastDailyIndex = today
        Wallet.dailyBest = max(Wallet.dailyBest, Wallet.dailyStreak)
    }
}

enum LoginReward {
    static let cycle: [(coins: Int, lives: Int)] = [
        (25, 0), (40, 0), (0, 1), (60, 0), (90, 0), (0, 1), (150, 0)
    ]
    static var isClaimableToday: Bool { Wallet.lastLoginIndex != Daily.todayIndex }
    static var pendingDay: Int {
        if Wallet.lastLoginIndex == Daily.todayIndex - 1 { return Wallet.loginCycleDay % 7 + 1 }
        return 1
    }
    @discardableResult
    static func claim() -> (coins: Int, lives: Int) {
        let day = pendingDay
        let r = cycle[day - 1]
        Wallet.coins += r.coins
        for _ in 0..<r.lives { Wallet.addLife() }
        Wallet.loginCycleDay = day
        Wallet.lastLoginIndex = Daily.todayIndex
        return r
    }
}

enum Costs {
    static let hint  = 50
    static let skip  = 100
    static let moves = 75
    static let life  = 80
}

// MARK: - Destek Bağlantıları

enum Support {
    static let email      = "emralkaan7@gmail.com"
    static let privacyURL = "https://emrealkan.com.tr/glasy"
    static let termsURL   = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"
}

enum Lives {
    static let maxLives = 5
    static let regen: TimeInterval = 3600

    static func resolve(lives: Int, anchor: Double, now: Double) -> (lives: Int, anchor: Double) {
        if lives >= maxLives { return (maxLives, now) }
        guard anchor > 0 else { return (lives, now) }
        let elapsed = now - anchor
        guard elapsed > 0 else { return (lives, now) }
        let gained = Int(elapsed / regen)
        guard gained > 0 else { return (lives, anchor) }
        let nl = min(maxLives, lives + gained)
        return nl >= maxLives ? (maxLives, now) : (nl, anchor + Double(gained) * regen)
    }
}

// MARK: - Reklamlar

final class AdManager: NSObject, GADFullScreenContentDelegate {
    static let shared = AdManager()

    #if DEBUG
    private let rewardedUnit = "ca-app-pub-3940256099942544/1712485313"
    static let bannerUnit    = "ca-app-pub-3940256099942544/2934735716"
    #else
    private let rewardedUnit = "ca-app-pub-7795937092215431/7115232943"
    static let bannerUnit    = "ca-app-pub-7795937092215431/1040779186"
    #endif

    private var rewarded: GADRewardedAd?
    private var rewardEarned = false
    private var onRewardClosed: ((Bool) -> Void)?
    private let netMonitor = NWPathMonitor()
    private var online = true
    private var sdkStarted = false

    private override init() { super.init() }

    func startConsentFlow() {
        netMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async { self?.online = (path.status == .satisfied) }
        }
        netMonitor.start(queue: DispatchQueue(label: "glasy.net.monitor"))
        let parameters = UMPRequestParameters()
        UMPConsentInformation.sharedInstance.requestConsentInfoUpdate(with: parameters) { [weak self] _ in
            guard let self else { return }
            UMPConsentForm.loadAndPresentIfRequired(from: self.rootVC) { [weak self] _ in
                self?.startAdsIfAllowed()
            }
            self.startAdsIfAllowed()
        }
    }

    var canRequestAds: Bool { UMPConsentInformation.sharedInstance.canRequestAds }
    var privacyOptionsRequired: Bool {
        UMPConsentInformation.sharedInstance.privacyOptionsRequirementStatus == .required
    }

    private func startAdsIfAllowed() {
        if canRequestAds && !sdkStarted {
            sdkStarted = true
            GADMobileAds.sharedInstance().start(completionHandler: nil)
            loadRewarded()
        }
        NotificationCenter.default.post(name: .glasyAdConsentChanged, object: canRequestAds)
    }

    func presentPrivacyOptions(completion: @escaping (Bool) -> Void) {
        guard privacyOptionsRequired else { completion(false); return }
        UMPConsentForm.presentPrivacyOptionsForm(from: rootVC) { [weak self] error in
            self?.startAdsIfAllowed()
            completion(error == nil)
        }
    }

    private func requestTrackingIfNeeded(completion: @escaping () -> Void) {
        guard #available(iOS 14, *),
              ATTrackingManager.trackingAuthorizationStatus == .notDetermined else {
            completion(); return
        }
        ATTrackingManager.requestTrackingAuthorization { _ in
            DispatchQueue.main.async(execute: completion)
        }
    }

    private var rootVC: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let active = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        return active?.keyWindow?.rootViewController
    }

    private func loadRewarded() {
        GADRewardedAd.load(withAdUnitID: rewardedUnit, request: GADRequest()) { [weak self] ad, _ in
            ad?.fullScreenContentDelegate = self
            self?.rewarded = ad
        }
    }

    var isRewardedReady: Bool { canRequestAds && online && rewarded != nil }

    func showRewarded(reason: String, completion: @escaping (Bool) -> Void) {
        guard canRequestAds, online else { startAdsIfAllowed(); completion(false); return }
        requestTrackingIfNeeded { [weak self] in
            guard let self, let ad = self.rewarded, let vc = self.rootVC else {
                self?.loadRewarded(); completion(false); return
            }
            self.rewardEarned = false
            self.onRewardClosed = completion
            ad.present(fromRootViewController: vc) { [weak self] in self?.rewardEarned = true }
        }
    }



    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        let done = onRewardClosed; onRewardClosed = nil
        rewarded = nil; loadRewarded()
        done?(rewardEarned)
    }
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        let done = onRewardClosed; onRewardClosed = nil
        rewarded = nil; loadRewarded()
        done?(false)
    }
}

enum StoreProductCatalog {
    static let removeAds = "com.emrealkan.glasy.removeads"
    static let adReward  = 50
    static let coins: [(id: String, coins: Int, fallback: String, tag: String?)] = [
        (id: "com.emrealkan.glasy.coins.500",  coins: 500,  fallback: "₺19,99", tag: nil),
        (id: "com.emrealkan.glasy.coins.1500", coins: 1500, fallback: "₺49,99", tag: "POPÜLER"),
        (id: "com.emrealkan.glasy.coins.4000", coins: 4000, fallback: "₺99,99", tag: "EN İYİ"),
    ]
    static let coinAmount: [String: Int] = Dictionary(uniqueKeysWithValues: coins.map { ($0.id, $0.coins) })
    static var allIDs: [String] { [removeAds] + coins.map { $0.id } }
}

enum RevenueCatConfiguration {
    static let apiKey = "appl_zxqveGkWsgWtBbuvZiadLnDRVNq"
    static let entitlement = "premium"
}

extension Notification.Name {
    static let glasyAdsEntitlementChanged = Notification.Name("glasyAdsEntitlementChanged")
    static let glasyAdConsentChanged = Notification.Name("glasyAdConsentChanged")
}

// MARK: - Satın Almalar

final class StoreManager {
    static let shared = StoreManager()
    private static let logger = Logger(subsystem: "com.emrealkan.glasy", category: "Purchases")
    private(set) var products: [String: StoreProduct] = [:]
    private init() {}

    func configure() {
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .error
        #endif
        Purchases.configure(withAPIKey: RevenueCatConfiguration.apiKey)
        Task { await loadProducts(); await refreshEntitlements() }
    }

    func loadProducts() async {
        let loaded = await Purchases.shared.products(StoreProductCatalog.allIDs)
        await MainActor.run { for p in loaded { self.products[p.productIdentifier] = p } }
    }

    func price(_ id: String) -> String? { products[id]?.localizedPriceString }

    private func apply(_ info: CustomerInfo) async {
        let active = info.entitlements[RevenueCatConfiguration.entitlement]?.isActive == true
        await MainActor.run {
            Wallet.adsRemoved = active
            NotificationCenter.default.post(name: .glasyAdsEntitlementChanged, object: active)
        }
    }

    private func buy(_ id: String) async -> Bool {
        if products[id] == nil { await loadProducts() }
        guard let product = products[id] else { return false }
        do {
            let result = try await Purchases.shared.purchase(product: product)
            if result.userCancelled { return false }
            await apply(result.customerInfo)
            if let amount = StoreProductCatalog.coinAmount[id] { await MainActor.run { Wallet.coins += amount } }
            return true
        } catch {
            Self.logger.error("Purchase failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    func refreshEntitlements() async {
        if let info = try? await Purchases.shared.customerInfo() { await apply(info) }
    }



    func purchaseRemoveAds(completion: @escaping (Bool) -> Void) {
        Task { let ok = await buy(StoreProductCatalog.removeAds); await MainActor.run { completion(ok) } }
    }
    func purchaseCoins(productID: String, completion: @escaping (Bool) -> Void) {
        Task { let ok = await buy(productID); await MainActor.run { completion(ok) } }
    }
    func restorePurchases(completion: @escaping (Bool) -> Void) {
        Task {
            if let info = try? await Purchases.shared.restorePurchases() { await apply(info) }
            await MainActor.run { completion(Wallet.adsRemoved) }
        }
    }
}
