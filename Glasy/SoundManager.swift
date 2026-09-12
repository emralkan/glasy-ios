import SpriteKit
import AVFoundation

final class SoundManager {
    static let shared = SoundManager()
    private init() {}

    private var music: AVAudioPlayer?
    private var sfxCache: [String: SKAction] = [:]

    func configureSession() {
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }



    func startMusic() {
        guard Wallet.musicOn else { return }
        if music == nil {
            guard let url = Bundle.main.url(forResource: "music", withExtension: "wav") else { return }
            music = try? AVAudioPlayer(contentsOf: url)
            music?.numberOfLoops = -1
            music?.volume = 0.35
            music?.prepareToPlay()
        }
        if music?.isPlaying == false { music?.play() }
    }

    func stopMusic() { music?.pause() }

    func setMusic(on: Bool) {
        Wallet.musicOn = on
        if on { startMusic() } else { stopMusic() }
    }
    func setSFX(on: Bool) { Wallet.sfxOn = on }



    func play(_ name: String, on node: SKNode) {
        guard Wallet.sfxOn else { return }
        let action = sfxCache[name] ?? SKAction.playSoundFileNamed(name, waitForCompletion: false)
        sfxCache[name] = action
        node.run(action)
    }
}
