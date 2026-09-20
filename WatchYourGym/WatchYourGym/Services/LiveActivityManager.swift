//
//  LiveActivityManager.swift
//  WatchYourGym
//
//  Starts, updates and ends the workout Live Activity.
//
//  The app compiles and runs fine without the widget extension: in that case
//  starting an activity simply fails and is ignored. Add the extension to
//  actually see it on the Lock Screen and in the Dynamic Island (WIDGET_SETUP.md).
//

import Foundation
import ActivityKit

final class LiveActivityManager {

    static let shared = LiveActivityManager()

    private var activity: Activity<WorkoutActivityAttributes>?
    private let settings: SettingsStore

    init(settings: SettingsStore = .shared) {
        self.settings = settings
    }

    private var isEnabled: Bool {
        settings.settings.liveActivityEnabled && ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(workoutName: String, workoutType: String, state: WorkoutActivityAttributes.ContentState) {
        guard isEnabled else { return }

        // An activity started before the app was relaunched is still alive on
        // the Lock Screen, but `activity` is nil again because memory was
        // wiped. Without this, restoring a session would add a second,
        // identical banner next to the first one.
        adoptRunningActivity()

        if activity != nil {
            update(state)
            return
        }

        let attributes = WorkoutActivityAttributes(workoutName: workoutName, workoutType: workoutType)
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            // No widget extension installed, or the user disabled Live Activities.
            print("LiveActivityManager: could not start the activity: \(error)")
        }
    }

    /// Keeps at most one activity alive: adopts the first one still running
    /// and ends any extra.
    private func adoptRunningActivity() {
        let running = Activity<WorkoutActivityAttributes>.activities
        guard !running.isEmpty else { return }

        let kept = activity ?? running[0]
        activity = kept

        for other in running where other.id != kept.id {
            Task { await other.end(nil, dismissalPolicy: .immediate) }
        }
    }

    func update(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity else { return }
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    /// Ends every running activity, not just the one we hold a reference to,
    /// so the Lock Screen is always left clean.
    func end() {
        let running = Activity<WorkoutActivityAttributes>.activities
        activity = nil
        guard !running.isEmpty else { return }
        Task {
            for activity in running {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    /// Clears activities left behind by a previous run of the app.
    func endOrphanedActivities() {
        Task {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
