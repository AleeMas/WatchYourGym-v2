//
//  SettingsView.swift
//  WatchYourGym
//
//  Profile › Settings: rest-timer sounds, alerts and Live Activity.
//

import SwiftUI

struct SettingsView: View {

    @EnvironmentObject private var settingsStore: SettingsStore
    @StateObject private var notifications = NotificationManager.shared

    @State private var didSendTest = false

    private var settings: Binding<AppSettings> { $settingsStore.settings }

    var body: some View {
        Form {
            soundSection
            alertsSection
            liveActivitySection
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            notifications.refreshAuthorizationStatus()
        }
    }

    // MARK: - Sound

    private var soundSection: some View {
        Section {
            Toggle("Timer sound", isOn: settings.soundEnabled)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Volume")
                    Spacer()
                    Text("\(Int(settingsStore.settings.soundVolume * 100))%")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }

                HStack(spacing: 10) {
                    Image(systemName: "speaker.fill")
                        .foregroundStyle(.secondary)
                    Slider(value: settings.soundVolume, in: 0...1, step: 0.05)
                        .onChange(of: settingsStore.settings.soundVolume) { _, _ in
                            // Play while dragging so the level can be judged.
                            SoundPlayer.shared.play(.tick, force: true)
                        }
                    Image(systemName: "speaker.wave.3.fill")
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(!settingsStore.settings.soundEnabled)

            Button {
                SoundPlayer.shared.play(.end, force: true)
            } label: {
                Label("Test sound", systemImage: "play.circle")
            }
            .disabled(!settingsStore.settings.soundEnabled)
        } header: {
            Text("Sound")
        } footer: {
            Text("The beeps play even with the ring switch on silent, mixed with your music. The volume applies while the app is open.")
        }
    }

    // MARK: - Alerts

    private var alertsSection: some View {
        Section {
            Toggle("Alert at 30 seconds left", isOn: settings.warnAt30Seconds)

            Toggle("Notify when the app is in background", isOn: settings.backgroundNotifications)
                .onChange(of: settingsStore.settings.backgroundNotifications) { _, enabled in
                    guard enabled else { return }
                    Task { await notifications.ensureAuthorization() }
                }

            if settingsStore.settings.backgroundNotifications {
                permissionRow
                testNotificationRow
            }
        } header: {
            Text("Rest alerts")
        } footer: {
            Text("Besides the 3-2-1 countdown, an alert can warn you 30 seconds before the rest ends. With the app in the background the alert is a notification: it uses the system notification volume and stays silent if the ring switch is on silent or a Focus is on.")
        }
    }

    /// Makes the permission state visible: a notification that is never
    /// delivered because permission was never granted is otherwise invisible.
    @ViewBuilder
    private var permissionRow: some View {
        switch notifications.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            Label("Notifications allowed", systemImage: "checkmark.circle.fill")
                .font(.footnote)
                .foregroundStyle(.green)

        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Label("Notifications are turned off for WatchYourGym", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                Button("Open iOS Settings") {
                    notifications.openSystemSettings()
                }
                .font(.footnote)
            }

        case .notDetermined:
            Button {
                Task { await notifications.ensureAuthorization() }
            } label: {
                Label("Allow notifications", systemImage: "bell.badge")
            }

        @unknown default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var testNotificationRow: some View {
        Button {
            Task { await notifications.sendTestNotification() }
            didSendTest = true
        } label: {
            Label("Send a test notification", systemImage: "bell.and.waves.left.and.right")
        }

        if didSendTest {
            Text("Lock the phone now: it arrives in about 5 seconds.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        if let error = notifications.lastError {
            Text(error)
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    // MARK: - Live Activity

    private var liveActivitySection: some View {
        Section {
            Toggle("Lock Screen & Dynamic Island", isOn: settings.liveActivityEnabled)
        } header: {
            Text("During the workout")
        } footer: {
            Text("Shows the running timer outside the app. The Dynamic Island needs an iPhone 14 Pro or later; on other models the timer appears on the Lock Screen.")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .environmentObject(SettingsStore.shared)
}
