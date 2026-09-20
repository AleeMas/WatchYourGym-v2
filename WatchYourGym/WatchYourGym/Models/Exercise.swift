//
//  Exercise.swift
//  WatchYourGym
//

import Foundation

/// How the effort of an exercise is measured.
enum RepsType: Int, Codable, CaseIterable, Identifiable {
    case reps = 0
    case seconds = 1

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .reps: return "Reps"
        case .seconds: return "Seconds"
        }
    }
}

/// The second exercise of a superset (Tab workouts only).
///
/// It is performed right after its parent exercise with no rest in between,
/// and one set of the superset means doing both. That is why it has no
/// `sets` and no `restSeconds` of its own: those belong to the parent.
struct SupersetExercise: Codable, Hashable {
    var name: String = ""
    var muscle: String = ""
    var weightKg: Int = 0
    var reps: Int = 0
    var repsType: RepsType = .reps
    var notes: String = ""

    /// "12 reps" or "30s"
    var effortSummary: String {
        repsType == .seconds ? "\(reps)s" : "\(reps) reps"
    }
}

/// A single exercise inside a workout.
struct Exercise: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var muscle: String = ""
    var name: String = ""
    var weightKg: Int = 0
    var sets: Int = 0
    var reps: Int = 0
    var repsType: RepsType = .reps
    var restSeconds: Int = 0
    var notes: String = ""

    /// When set, this exercise is a superset: `superset` is done immediately
    /// after it, sharing `sets` and `restSeconds`. Optional, so files saved
    /// before this field existed still decode.
    var superset: SupersetExercise? = nil

    var isSuperset: Bool { superset != nil }

    /// "Bench press" or "Bench press + Push up" for a superset.
    var displayName: String {
        if let superset, !superset.name.isEmpty {
            return "\(name) + \(superset.name)"
        }
        return name
    }

    /// "3 x 12" or "3 x 30s" — used by Tab workouts, where sets belong to the exercise.
    var setsSummary: String {
        let unit = repsType == .seconds ? "s" : ""
        return "\(sets) x \(reps)\(unit)"
    }

    /// "12 reps" or "30s" — used by circuits, where the round count belongs to the workout.
    var effortSummary: String {
        repsType == .seconds ? "\(reps)s" : "\(reps) reps"
    }
}
