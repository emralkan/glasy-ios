import SwiftUI
import SpriteKit
import GoogleMobileAds

@main
struct GlasyApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}

struct GameView: View {
    @State private var scene: SKScene? = nil
    @State private var adsRemoved = Wallet.adsRemoved
    @State private var adsCanLoad = AdManager.shared.canRequestAds

    var body: some View {
        ZStack {
            Color(red: 0.91, green: 0.95, blue: 1.0).ignoresSafeArea()
            VStack(spacing: 0) {
                GeometryReader { geo in
                    ZStack {
                        Color(red: 0.97, green: 0.94, blue: 1.0)
                        if let scene {
                            SpriteView(scene: scene, preferredFramesPerSecond: 60)
                        }
                    }
                    .onAppear {
                        if scene == nil {
                            let s = MenuScene(size: geo.size)
                            s.scaleMode = .resizeFill
                            scene = s
                            StoreManager.shared.configure()
                            AdManager.shared.startConsentFlow()
                        }
                    }
                }
                if !adsRemoved {
                    ZStack {
                        Color(red: 0.91, green: 0.95, blue: 1.0)
                        if adsCanLoad {
                            BannerAdView()
                                .frame(width: 320, height: 50)
                                .clipped()
                        }
                    }
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .clipped()
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .onReceive(NotificationCenter.default.publisher(for: .glasyAdsEntitlementChanged)) { note in
            guard let active = note.object as? Bool else { return }
            withAnimation(.easeInOut(duration: 0.35)) { adsRemoved = active }
        }
        .onReceive(NotificationCenter.default.publisher(for: .glasyAdConsentChanged)) { note in
            adsCanLoad = (note.object as? Bool) ?? AdManager.shared.canRequestAds
        }
    }
}

struct BannerAdView: UIViewRepresentable {
    func makeUIView(context: Context) -> GADBannerView {
        let banner = GADBannerView(adSize: GADAdSizeBanner)
        banner.adUnitID = AdManager.bannerUnit
        banner.rootViewController = Self.rootVC()
        banner.load(GADRequest())
        return banner
    }
    func updateUIView(_ banner: GADBannerView, context: Context) {
        if banner.rootViewController == nil { banner.rootViewController = Self.rootVC() }
    }
    private static func rootVC() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let active = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        return active?.keyWindow?.rootViewController
    }
}
