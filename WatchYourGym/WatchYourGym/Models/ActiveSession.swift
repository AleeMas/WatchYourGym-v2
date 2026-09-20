//
//  ActiveSession.swift
//  WatchYourGym
//
//  Snapshot of a workout in progress, so that quitting the app (or being
//  killed by the system) does not lose the session.
//
//  It stores its own copy of the Workout: if the plan is edited or deleted
//  while a session is running, the session stays coherent with what the user
//  actually started.
//

import Foundation

/// What has to happen once the running rest is over.
/// String-backed so it can be written to disk.
enum RestCompletion: String, Codable {
    case stayHere       // next set of the same exercise (Tab)
    case nextExercise   // move to the following exercise
    case nextRound      // back to the first exercise, one round further (Circuit)
}

struct ActiveSession: Codable {

    var workout: Workout
    var startedAt: Date
    /// Sets completed per exercise (Tab).
    var completedSets: [Int]
    var currentExerciseIndex: Int
    var currentRound: Int
    /// When the running rest ends. Nil when not resting.
    var restEndDate: Date?
    var restCompletion: RestCompletion
    var savedAt: Date

    /// Sessions older than this are dropped instead of being restored:
    /// reopening the app a week later should not resume last Tuesday's workout.
    static let maximumAge: TimeInterval = 12 * 60 * 60

    var isStale: Bool {
        Date().timeIntervalSince(startedAt) > Self.maximumAge
    }

    /// Elapsed time counts real time, including while the app was closed.
    var elapsedSeconds: Int {
        max(0, Int(Date().timeIntervalSince(startedAt)))
    }
}
