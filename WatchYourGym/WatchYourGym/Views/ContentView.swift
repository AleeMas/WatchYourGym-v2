//
//  ContentView.swift
//  WatchYourGym
//

import SwiftUI

struct ContentView: View {

    var body: some View {
        TabView {
            WorkoutListView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.run.square.stack")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.circle")
                }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WorkoutStore())
        .environmentObject(UserStore())
        .environmentObject(HistoryStore())
        .environmentObject(WeightStore())
        .environmentObject(SettingsStore.shared)
        .environmentObject(ActiveSessionStore.shared)
}
