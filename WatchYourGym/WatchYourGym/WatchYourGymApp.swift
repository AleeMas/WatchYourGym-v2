//
//  WatchYourGymApp.swift
//  WatchYourGym
//

import SwiftUI

@main
struct WatchYourGymApp: App {

    @StateObject private var workoutStore = WorkoutStore()
    @StateObject private var userStore = UserStore()
    @StateObject private var historyStore = HistoryStore()
    @StateObject private var weightStore = WeightStore()
    // Shared instances: non-view types (the session controller, the sound
    // player) read them directly, and the views observe the same objects.
    @StateObject private var settingsStore = SettingsStore.shared
    @StateObject private var activeSessionStore = ActiveSessionStore.shared

    init() {
        NotificationManager.shared.configure()
        SoundPlayer.shared.preload()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(workoutStore)
                .environmentObject(userStore)
                .environmentObject(historyStore)
                .environmentObject(weightStore)
                .environmentObject(settingsStore)
                .environmentObject(activeSessionStore)
                .onAppear {
                    // A Live Activity from a previous run would otherwise
                    // linger on the Lock Screen with stale data.
                    if ActiveSessionStore.shared.session == nil {
                        LiveActivityManager.shared.endOrphanedActivities()
                    }
                }
        }
    }
}
