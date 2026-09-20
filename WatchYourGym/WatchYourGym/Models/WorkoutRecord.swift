//
//  WorkoutRecord.swift
//  WatchYourGym
//
//  One completed workout, as shown in the History screen.
//  It stores a snapshot of the name and type: renaming or deleting the
//  original workout later must not change what is already in the history.
//

import Foundation

struct WorkoutRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var workoutName: String
    var type: WorkoutType
    var startedAt: Date
    var durationSeconds: Int

    var finishedAt: Date {
        startedAt.addingTimeInterval(TimeInterval(durationSeconds))
    }
}
