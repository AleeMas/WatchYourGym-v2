//
//  SoundPlayer.swift
//  WatchYourGym
//
//  Plays the rest-timer sounds at the volume chosen in Settings.
//
//  AVAudioPlayer is used instead of AudioServicesPlaySystemSound because
//  system sounds ignore any app-level volume: their loudness is fixed.
//
//  The session category is `.playback` with `.mixWithOthers`, so the beeps
//  are audible even with the ring switch on silent (common at the gym) while
//  the user's music keeps playing underneath.
//

import AVFoundation

final class SoundPlayer {

    static let shared = SoundPlayer()

    enum Cue: String {
        case tick = "beep_tick"       // 3 - 2 - 1 countdown
        case warning = "beep_warning" // 30 seconds left
        case end = "beep_end"         // rest is over
    }

    private var players: [Cue: AVAudioPlayer] = [:]
    private var isSessionConfigured = false
    private let settings: SettingsStore

    init(settings: SettingsStore = .shared) {
        self.settings = settings
    }

    /// Loads the audio files once, so the first beep is not delayed.
    /// The audio session is *not* touched here: configuring it at launch
    /// would duck whatever the user is listening to for no reason.
    func preload() {
        for cue in [Cue.tick, .warning, .end] {
            _ = player(for: cue)
        }
    }

    /// Plays a cue, unless sounds are switched off in Settings.
    /// `force` ignores that switch: used by the "Test sound" button.
    func play(_ cue: Cue, force: Bool = false) {
        guard force || settings.settings.soundEnabled else { return }
        configureSessionIfNeeded()

        guard let player = player(for: cue) else { return }
        player.volume = Float(min(max(settings.settings.soundVolume, 0), 1))
        player.currentTime = 0
        player.play()
    }

    // MARK: - Private

    private func player(for cue: Cue) -> AVAudioPlayer? {
        if let existing = players[cue] { return existing }

        guard let url = Bundle.main.url(forResource: cue.rawValue, withExtension: "wav") else {
            print("SoundPlayer: missing sound file \(cue.rawValue).wav")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            players[cue] = player
            return player
        } catch {
            print("SoundPlayer: could not load \(cue.rawValue).wav: \(error)")
            return nil
        }
    }

    private func configureSessionIfNeeded() {
        guard !isSessionConfigured else { return }
        isSessionConfigured = true
        do {
            try AVAudioSession.sharedInstance().setCategory(
                .playback,
                mode: .default,
                options: [.mixWithOthers, .duckOthers]
            )
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("SoundPlayer: could not configure the audio session: \(error)")
        }
    }
}
