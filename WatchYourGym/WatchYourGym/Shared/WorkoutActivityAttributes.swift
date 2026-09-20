//
//  WorkoutActivityAttributes.swift
//  WatchYourGym
//
//  Shape of the Live Activity shown on the Lock Screen and in the
//  Dynamic Island.
//
//  IMPORTANT: this file must belong to BOTH targets — the app and the widget
//  extension. After creating the widget target in Xcode, select this file and
//  tick "WatchYourGymWidgetExtension" in the File Inspector › Target Membership.
//  See WIDGET_SETUP.md.
//

import Foundation
import ActivityKit

struct WorkoutActivityAttributes: ActivityAttributes {

    /// Fixed for the whole activity.
    var workoutName: String
    /// "Tab" or "Circuit" — a String so the widget target does not need the app models.
    var workoutType: String

    /// Everything that changes while the workout runs.
    struct ContentState: Codable, Hashable {
        /// When the workout started: the widget renders the running stopwatch
        /// from this date, so it keeps ticking without any update from the app.
        var startedAt: Date
        var exerciseName: String
        /// "Set 2/4", "Round 1/3", ...
        var progress: String
        var isResting: Bool
        /// When the current rest ends; nil when not resting.
        var restEndsAt: Date?
    }
}
