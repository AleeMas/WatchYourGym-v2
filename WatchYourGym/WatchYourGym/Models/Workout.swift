//
//  Workout.swift
//  WatchYourGym
//

import Foundation

/// The two kinds of workout supported by the app.
///
/// They differ in how the session is executed:
/// - `.tab`     : exercise by exercise. Every exercise repeats its own sets
///                before moving to the next one.
/// - `.circuit` : round by round. Every round runs through *all* the exercises
///                once, then rests, then the next round starts.
enum WorkoutType: String, Codable, CaseIterable, Identifiable {
    case tab = "Workout Plan"
    case circuit = "Circuit"

    var id: String { rawValue }

    var label: String { rawValue }
}

/// A full workout: a named list of exercises plus workout-level settings.
struct Workout: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String = ""
    var type: WorkoutType = .tab

    /// `.tab`     : rest between one exercise and the next.
    /// `.circuit` : rest between one round and the next.
    var restBetweenExercises: Int = 0

    /// Number of rounds of the whole circuit. Ignored by `.tab` workouts,
    /// where the number of sets belongs to each single exercise.
    var rounds: Int = 1

    var exercises: [Exercise] = []

    init(type: WorkoutType = .tab) {
        self.type = type
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !exercises.isEmpty
    }

    /// "Circuit · 3 rounds · 5 exercises" / "Tab · 5 exercises"
    var summary: String {
        switch type {
        case .circuit:
            return "Circuit · \(rounds) rounds · \(exercises.count) exercises"
        case .tab:
            return "Tab · \(exercises.count) exercises"
        }
    }

    // MARK: - Codable

    enum CodingKeys: String, CodingKey {
        case id, name, type, restBetweenExercises, rounds, exercises
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        type = try container.decodeIfPresent(WorkoutType.self, forKey: .type) ?? .tab
        restBetweenExercises = try container.decodeIfPresent(Int.self, forKey: .restBetweenExercises) ?? 0
        exercises = try container.decodeIfPresent([Exercise].self, forKey: .exercises) ?? []
        // Files written before `rounds` existed stored the round count
        // duplicated on every exercise of the circuit.
        rounds = try container.decodeIfPresent(Int.self, forKey: .rounds)
            ?? max(exercises.first?.sets ?? 1, 1)
    }
}
