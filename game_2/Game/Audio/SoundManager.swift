import AVFoundation
import SpriteKit

final class SoundManager {
    static let shared = SoundManager()
    static let soundEnabledKey = "soundEnabled"
    private let defaults: UserDefaults
    private var players: [String: AVAudioPlayer] = [:]

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func configure(hostNode: SKNode) {
        preloadSounds()
    }

    func playHitSound() {
        playSoundFileNamed("hit.wav")
    }

    func playScoreSound() {
        playSoundFileNamed("score.wav")
    }

    func preloadSounds() {
        ["hit.wav", "score.wav"].forEach { fileName in
            guard players[fileName] == nil else { return }
            guard let url = Bundle.main.url(forResource: fileName, withExtension: nil) else { return }
            do {
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                players[fileName] = player
            } catch {
                players[fileName] = nil
            }
        }
    }

    private var isSoundEnabled: Bool {
        defaults.object(forKey: Self.soundEnabledKey) as? Bool ?? true
    }

    private func playSoundFileNamed(_ fileName: String) {
        guard isSoundEnabled else { return }
        if players[fileName] == nil {
            preloadSounds()
        }
        guard let player = players[fileName] else { return }
        player.currentTime = 0
        player.play()
    }
}
