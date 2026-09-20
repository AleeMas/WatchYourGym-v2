//
//  WorkoutImport.swift
//  WatchYourGym
//
//  Imports a workout from an external JSON file, typically produced by an AI
//  from a photo of a paper training plan.
//
//  The parsing is deliberately forgiving: an AI rarely returns exactly the
//  schema it was given. Missing fields fall back to defaults, key names are
//  matched case-insensitively with common aliases, and numbers are accepted
//  as numbers or as strings ("60", "60 kg", "8-12", "1:30").
//
//  Identifiers are NOT read from the file: the app always generates fresh
//  UUIDs, so importing the same file twice creates two distinct workouts and
//  never overwrites an existing one.
//

import Foundation

// MARK: - Errors

enum WorkoutImportError: LocalizedError {
    case unreadableFile
    case invalidJSON
    case multipleWorkouts(Int)
    case noExercises

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "The file could not be opened."
        case .invalidJSON:
            return "This file is not valid JSON. Make sure you saved only the JSON text, without any extra characters."
        case .multipleWorkouts(let count):
            return "This file contains \(count) workouts. Import one workout per file."
        case .noExercises:
            return "No exercises found in this file. Check that the \"exercises\" list is not empty."
        }
    }
}

// MARK: - Importer

enum WorkoutImporter {

    /// Reads a JSON file and converts it into a Workout with freshly generated IDs.
    static func importWorkout(from url: URL) throws -> Workout {
        // Files picked through the Files app live outside the sandbox.
        let needsScopedAccess = url.startAccessingSecurityScopedResource()
        defer {
            if needsScopedAccess { url.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? Data(contentsOf: url) else {
            throw WorkoutImportError.unreadableFile
        }

        return try importWorkout(from: data)
    }

    /// Split out from the URL version so it can be unit-tested and previewed.
    static func importWorkout(from data: Data) throws -> Workout {
        let cleaned = stripMarkdownFences(from: data)
        let decoder = JSONDecoder()

        let imported: ImportedWorkout

        if let single = try? decoder.decode(ImportedWorkout.self, from: cleaned) {
            imported = single
        } else if let list = try? decoder.decode([ImportedWorkout].self, from: cleaned) {
            if list.isEmpty {
                throw WorkoutImportError.noExercises
            }
            guard list.count == 1 else {
                throw WorkoutImportError.multipleWorkouts(list.count)
            }
            imported = list[0]
        } else {
            throw WorkoutImportError.invalidJSON
        }

        let workout = imported.toWorkout()

        guard !workout.exercises.isEmpty else {
            throw WorkoutImportError.noExercises
        }

        return workout
    }

    /// AI assistants often wrap their answer in ```json fences. Drop them
    /// instead of failing, so a copy-pasted answer still imports.
    private static func stripMarkdownFences(from data: Data) -> Data {
        guard let text = String(data: data, encoding: .utf8),
              text.contains("```") else {
            return data
        }
        let withoutFences = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```JSON", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return withoutFences.data(using: .utf8) ?? data
    }
}

// MARK: - Intermediate representation

/// What we accept from the file. Kept separate from `Workout` so that the
/// stored model stays strict while the imported one stays forgiving.
struct ImportedWorkout: Decodable {

    var name: String
    var type: WorkoutType
    var rounds: Int
    var restBetweenExercises: Int
    var exercises: [ImportedExercise]

    init(from decoder: Decoder) throws {
        let container = try LooseContainer(decoder: decoder)

        name = container.string("name", "title", "workoutName", "planName") ?? ""
        type = Self.parseType(container.string("type", "kind", "workoutType", "mode"))
        restBetweenExercises = container.int(
            "restBetweenExercises", "restBetweenRounds", "restBetweenSets",
            "restBetweenCircuits", "rest", "restSeconds"
        ) ?? 0
        rounds = container.int("rounds", "circuitRounds", "sets", "circuitSets", "laps") ?? 1
        exercises = container.decode([ImportedExercise].self, "exercises", "exerciseList", "items", "movements") ?? []

        // Some assistants wrap the answer, e.g. {"workout": { ... }}.
        // Unwrap it instead of failing.
        if exercises.isEmpty,
           let nested = container.decode(ImportedWorkout.self, "workout", "plan", "trainingPlan", "data"),
           !nested.exercises.isEmpty {
            name = name.isEmpty ? nested.name : name
            type = nested.type
            rounds = nested.rounds
            restBetweenExercises = nested.restBetweenExercises
            exercises = nested.exercises
        }
    }

    private static func parseType(_ raw: String?) -> WorkoutType {
        guard let raw = raw?.lowercased() else { return .tab }
        return raw.contains("circ") ? .circuit : .tab
    }

    /// Converts to the app model, generating all identifiers locally.
    func toWorkout() -> Workout {
        var workout = Workout(type: type)
        workout.id = UUID()
        workout.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        workout.restBetweenExercises = max(0, restBetweenExercises)

        let isCircuit = type == .circuit
        var converted: [Exercise] = []
        var previousWantsPartner = false

        for imported in exercises {
            // Flat superset forms: fold this exercise into the previous one
            // (Tab only, and only if the previous one has no partner yet).
            let foldIntoPrevious = !isCircuit
                && (imported.isSupersetWithPrevious || previousWantsPartner)
                && converted.last?.superset == nil
                && !converted.isEmpty

            if foldIntoPrevious {
                converted[converted.count - 1].superset = imported.toSupersetExercise()
                previousWantsPartner = false
            } else {
                converted.append(imported.toExercise(isCircuit: isCircuit))
                previousWantsPartner = imported.isSupersetWithNext
            }
        }
        workout.exercises = converted

        if type == .circuit {
            // A circuit repeats the whole sequence: the round count belongs to
            // the workout. If the file only put it on the exercises, recover it.
            let fromExercises = exercises.compactMap { $0.sets }.first ?? 1
            workout.rounds = max(rounds > 1 ? rounds : fromExercises, 1)
        } else {
            workout.rounds = 1
        }

        return workout
    }
}

struct ImportedExercise: Decodable {

    var name: String
    var muscle: String
    var weightKg: Int
    var sets: Int?
    var reps: Int
    var repsType: RepsType
    var restSeconds: Int
    var notes: String
    /// Nested second exercise, e.g. "superset": { "name": "Push up", "reps": 15 }
    var superset: ImportedSupersetExercise?
    /// Flat alternatives some assistants produce: "supersetWithPrevious": true
    /// on the exercise that follows, or "superset": true on the one that leads.
    /// Both are folded into a nested superset in toWorkout().
    var isSupersetWithPrevious: Bool
    var isSupersetWithNext: Bool

    init(from decoder: Decoder) throws {
        let container = try LooseContainer(decoder: decoder)

        name = container.string("name", "exercise", "exerciseName", "title", "movement") ?? ""
        muscle = container.string("muscle", "muscleGroup", "muscles", "group", "bodyPart") ?? ""
        weightKg = container.int("weightKg", "weight", "kg", "load") ?? 0
        sets = container.int("sets", "series", "numberOfSets")
        reps = container.int("reps", "repetitions", "rep", "count", "seconds", "duration", "time") ?? 0
        restSeconds = container.int("restSeconds", "rest", "restBetweenSets", "recovery", "pause") ?? 0
        notes = container.string("notes", "note", "comment", "description") ?? ""
        repsType = Self.parseRepsType(
            container.string("repsType", "type", "unit", "measure"),
            hasSecondsKey: container.hasKey("seconds", "duration")
        )
        let supersetKeys = ["superset", "supersetWith", "pairedWith", "secondExercise", "then"]
        superset = container.decode(ImportedSupersetExercise.self, supersetKeys)
        if superset == nil, let partnerName = container.string(supersetKeys), !partnerName.isEmpty {
            // "superset": "Push up" — just a name, fill in the rest with defaults.
            superset = ImportedSupersetExercise(name: partnerName)
        }
        isSupersetWithPrevious = container.bool(["supersetWithPrevious", "supersetPrevious", "pairedWithPrevious"]) ?? false
        // "superset": true on the first exercise means "the next one is my partner".
        isSupersetWithNext = superset == nil && (container.bool(["superset", "isSuperset"]) ?? false)
    }

    fileprivate static func parseRepsType(_ raw: String?, hasSecondsKey: Bool) -> RepsType {
        if let raw = raw?.lowercased() {
            if raw.hasPrefix("sec") || raw.hasPrefix("s") || raw.contains("time") || raw.contains("durat") {
                return .seconds
            }
            if raw.hasPrefix("rep") {
                return .reps
            }
        }
        // The value came from a "seconds"/"duration" key: it is a timed exercise.
        return hasSecondsKey ? .seconds : .reps
    }

    func toExercise(isCircuit: Bool) -> Exercise {
        var exercise = Exercise()
        exercise.id = UUID()
        exercise.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        exercise.muscle = muscle.trimmingCharacters(in: .whitespacesAndNewlines)
        exercise.weightKg = max(0, weightKg)
        exercise.reps = max(0, reps)
        exercise.repsType = repsType
        exercise.restSeconds = max(0, restSeconds)
        exercise.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        // In a circuit every exercise runs once per round.
        exercise.sets = isCircuit ? 1 : max(0, sets ?? 0)
        // Supersets are a Tab-only concept.
        if !isCircuit, let superset, !superset.name.isEmpty {
            exercise.superset = superset.toSupersetExercise()
        }
        return exercise
    }

    /// The flat form: this exercise becomes the second half of the previous one.
    func toSupersetExercise() -> SupersetExercise {
        var superset = SupersetExercise()
        superset.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        superset.muscle = muscle.trimmingCharacters(in: .whitespacesAndNewlines)
        superset.weightKg = max(0, weightKg)
        superset.reps = max(0, reps)
        superset.repsType = repsType
        superset.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return superset
    }
}

/// The second exercise of a superset as found in the file.
/// No sets and no rest: they belong to the first exercise.
struct ImportedSupersetExercise: Decodable {

    var name: String
    var muscle: String = ""
    var weightKg: Int = 0
    var reps: Int = 0
    var repsType: RepsType = .reps
    var notes: String = ""

    /// Used when the file gives only the partner's name: "superset": "Push up"
    init(name: String) {
        self.name = name
    }

    init(from decoder: Decoder) throws {
        let container = try LooseContainer(decoder: decoder)

        name = container.string("name", "exercise", "exerciseName", "title", "movement") ?? ""
        muscle = container.string("muscle", "muscleGroup", "muscles", "group", "bodyPart") ?? ""
        weightKg = container.int("weightKg", "weight", "kg", "load") ?? 0
        reps = container.int("reps", "repetitions", "rep", "count", "seconds", "duration", "time") ?? 0
        notes = container.string("notes", "note", "comment", "description") ?? ""
        repsType = ImportedExercise.parseRepsType(
            container.string("repsType", "type", "unit", "measure"),
            hasSecondsKey: container.hasKey("seconds", "duration")
        )
    }

    func toSupersetExercise() -> SupersetExercise {
        var superset = SupersetExercise()
        superset.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        superset.muscle = muscle.trimmingCharacters(in: .whitespacesAndNewlines)
        superset.weightKg = max(0, weightKg)
        superset.reps = max(0, reps)
        superset.repsType = repsType
        superset.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        return superset
    }
}

// MARK: - Loose decoding helpers

/// A keyed container that matches key names ignoring case, spaces,
/// underscores and dashes, and that accepts numbers written as strings.
private struct LooseContainer {

    private struct AnyKey: CodingKey {
        var stringValue: String
        var intValue: Int? { nil }
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    private let container: KeyedDecodingContainer<AnyKey>
    /// normalized key name -> real key in the file
    private let keyMap: [String: AnyKey]

    init(decoder: Decoder) throws {
        container = try decoder.container(keyedBy: AnyKey.self)
        var map: [String: AnyKey] = [:]
        for key in container.allKeys {
            map[Self.normalize(key.stringValue)] = key
        }
        keyMap = map
    }

    private static func normalize(_ value: String) -> String {
        value.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private func key(for names: [String]) -> AnyKey? {
        for name in names {
            if let key = keyMap[Self.normalize(name)] { return key }
        }
        return nil
    }

    // Every accessor exists in two flavours: variadic for readability at the
    // call site, array-based when the same alias list is reused.

    func hasKey(_ names: String...) -> Bool { hasKey(names) }
    func hasKey(_ names: [String]) -> Bool {
        key(for: names) != nil
    }

    func string(_ names: String...) -> String? { string(names) }
    func string(_ names: [String]) -> String? {
        guard let key = key(for: names) else { return nil }
        if let value = try? container.decode(String.self, forKey: key) { return value }
        if let value = try? container.decode(Int.self, forKey: key) { return String(value) }
        return nil
    }

    func int(_ names: String...) -> Int? { int(names) }
    func int(_ names: [String]) -> Int? {
        guard let key = key(for: names) else { return nil }
        if let value = try? container.decode(Int.self, forKey: key) { return value }
        if let value = try? container.decode(Double.self, forKey: key) { return Int(value.rounded()) }
        if let text = try? container.decode(String.self, forKey: key) { return Self.parseNumber(text) }
        return nil
    }

    func decode<T: Decodable>(_ type: T.Type, _ names: String...) -> T? { decode(type, names) }
    func decode<T: Decodable>(_ type: T.Type, _ names: [String]) -> T? {
        guard let key = key(for: names) else { return nil }
        return try? container.decode(type, forKey: key)
    }

    /// true / "true" / "yes" / 1
    func bool(_ names: String...) -> Bool? { bool(names) }
    func bool(_ names: [String]) -> Bool? {
        guard let key = key(for: names) else { return nil }
        if let value = try? container.decode(Bool.self, forKey: key) { return value }
        if let value = try? container.decode(Int.self, forKey: key) { return value != 0 }
        if let text = try? container.decode(String.self, forKey: key) {
            return ["true", "yes", "y", "1"].contains(text.lowercased())
        }
        return nil
    }

    /// "60" -> 60, "60 kg" -> 60, "8-12" -> 8, "1:30" -> 90
    private static func parseNumber(_ text: String) -> Int? {
        let parts = text.split(whereSeparator: { !$0.isNumber }).compactMap { Int($0) }
        guard let first = parts.first else { return nil }

        // mm:ss written as a duration
        if text.contains(":"), parts.count >= 2 {
            return first * 60 + parts[1]
        }
        return first
    }
}
