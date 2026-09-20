//
//  SettingsStore.swift
//  WatchYourGym
//
//  Holds the user preferences and writes them to settings.json.
//
//  It is a shared instance because non-view types (the session controller,
//  the sound player) need to read the settings without going through the
//  SwiftUI environment.
//

import Foundation

final class SettingsStore: ObservableObject {

    static let shared = SettingsStore()

    @Published var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            persistence.save(settings, to: persistence.settingsURL)
        }
    }

    private let persistence: PersistenceManager

    init(persistence: PersistenceManager = .shared) {
        self.persistence = persistence
        self.settings = persistence.load(AppSettings.self, from: persistence.settingsURL) ?? AppSettings()
    }
}
