import AppKit

enum SoundEffect: String {
    case doorCreak = "door-creak"
    case catChirp = "cat-chirp"
    case sparkle = "sparkle"
}

@MainActor
protocol SoundPlaying {
    func play(_ sound: SoundEffect)
    var isEnabled: Bool { get set }
}

@MainActor
final class SoundPlayer: NSObject, NSSoundDelegate, SoundPlaying {
    var isEnabled = true
    private var activeSounds: [NSSound] = []

    func play(_ sound: SoundEffect) {
        guard isEnabled,
              let url = ResourceBundle.current.url(forResource: sound.rawValue, withExtension: "aiff", subdirectory: "Sounds"),
              let player = NSSound(contentsOf: url, byReference: false)
        else {
            return
        }

        player.volume = 0.5
        player.delegate = self
        activeSounds.append(player)
        player.play()
    }

    func sound(_ sound: NSSound, didFinishPlaying aBool: Bool) {
        activeSounds.removeAll { $0 === sound }
    }
}
