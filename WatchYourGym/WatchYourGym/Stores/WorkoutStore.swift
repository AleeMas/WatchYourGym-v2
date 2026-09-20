//
//  WorkoutStore.swift
//  WatchYourGym
//
//  Single source of truth for the workouts. Replaces GymTabController,
//  Tabs, DataChanging and the text-file parsing in generateTabs().
//

import Foundation

final class WorkoutStore: ObservableObject {

    @Published private(set) var workouts: [Workout] = []

    private let persistence: PersistenceManager

    init(persistence: PersistenceManager = .shared) {
        self.persistence = persistence
        load()
    }

    // MARK: - CRUD

    /// Adds the workout if it is new, updates it if it already exists.
    func upsert(_ workout: Workout) {
        if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
            workouts[index] = workout
        } else {
            workouts.append(workout)
        }
        save()
    }

    func delete(_ workout: Workout) {
        workouts.removeAll { $0.id == workout.id }
        save()
    }

    func workout(with id: Workout.ID) -> Workout? {
        workouts.first { $0.id == id }
    }

    // MARK: - Persistence

    private func load() {
        if let saved = persistence.load([Workout].self, from: persistence.workoutsURL) {
            workouts = saved
        } else if persistence.legacyFileExists(at: persistence.legacyWorkoutsURL) {
            migrateLegacyFile()
        }
    }

    private func save() {
        persistence.save(workouts, to: persistence.workoutsURL)
    }

    // MARK: - Legacy migration (old "XYX" text format)

    /// Old format, one workout per "----" section:
    ///   NUOVOESXYX<name>XYX<type>XYX<rest>
    ///   NUOVOESXYX<exName>XYX<muscle>XYX<kg>XYX<rest>XYX<reps>XYX<sets>XYX<note>XYX<repsType>
    /// Parsing is fully defensive: a malformed line is skipped, never a crash.
    private func migrateLegacyFile() {
        guard let content = try? String(contentsOf: persistence.legacyWorkoutsURL, encoding: .utf8) else { return }

        var migrated: [Workout] = []

        for section in content.components(separatedBy: "----") {
            let lines = section
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasPrefix("NUOVOES") }

            guard let headerLine = lines.first else { continue }
            let header = headerLine.components(separatedBy: "XYX")
            guard header.count >= 4 else { continue }

            var workout = Workout(type: header[2] == "Circuit" ? .circuit : .tab)
            workout.name = header[1]
            workout.restBetweenExercises = Int(header[3]) ?? 0

            for line in lines.dropFirst() {
                let fields = line.components(separatedBy: "XYX")
                guard fields.count >= 9 else { continue }

                var exercise = Exercise()
                exercise.name = fields[1]
                exercise.muscle = fields[2]
                exercise.weightKg = Int(fields[3]) ?? 0
                exercise.restSeconds = Int(fields[4]) ?? 0
                exercise.reps = Int(fields[5]) ?? 0
                exercise.sets = Int(fields[6]) ?? 0
                exercise.notes = fields[7] == "vuotoZ" ? "" : fields[7]
                exercise.repsType = RepsType(rawValue: Int(fields[8]) ?? 0) ?? .reps
                workout.exercises.append(exercise)
            }

            // In the old format a circuit stored its round count duplicated
            // on every exercise; it now belongs to the workout.
            if workout.type == .circuit {
                workout.rounds = max(workout.exercises.first?.sets ?? 1, 1)
                for index in workout.exercises.indices {
                    workout.exercises[index].sets = 1
                }
            }

            if !workout.exercises.isEmpty || !workout.name.isEmpty {
                migrated.append(workout)
            }
        }

        workouts = migrated
        save()
        persistence.archiveLegacyFile(at: persistence.legacyWorkoutsURL)
    }
}
