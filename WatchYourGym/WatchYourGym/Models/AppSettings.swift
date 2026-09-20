//
//  AppSettings.swift
//  WatchYourGym
//
//  User preferences shown in Profile › Settings.
//

import Foundation

struct AppSettings: Codable, Equatable {

    /// Master switch for the rest-timer sounds.
    var soundEnabled: Bool = true

    /// Playback volume of the timer sounds, 0...1.
    /// Applies while the app is in the foreground; when the app is in the
    /// background the alert is a local notification, which uses the system
    /// notification volume instead.
    var soundVolume: Double = 0.8

    /// Extra alert when 30 seconds of rest are left.
    var warnAt30Seconds: Bool = true

    /// Local notification when a rest ends while the app is in the background.
    var backgroundNotifications: Bool = true

    /// Live Activity on the Lock Screen and Dynamic Island.
    var liveActivityEnabled: Bool = true

    // Decoded leniently so that settings files written by older versions
    // (missing keys) still load with sensible defaults.
    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        soundEnabled = try container.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? true
        soundVolume = try container.decodeIfPresent(Double.self, forKey: .soundVolume) ?? 0.8
        warnAt30Seconds = try container.decodeIfPresent(Bool.self, forKey: .warnAt30Seconds) ?? true
        backgroundNotifications = try container.decodeIfPresent(Bool.self, forKey: .backgroundNotifications) ?? true
        liveActivityEnabled = try container.decodeIfPresent(Bool.self, forKey: .liveActivityEnabled) ?? true
    }
}
