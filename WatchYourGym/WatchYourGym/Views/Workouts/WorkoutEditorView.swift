//
//  WorkoutEditorView.swift
//  WatchYourGym
//
//  One editor for every case: create or edit, Tab or Circuit.
//  Replaces GymTabInsertingView, ExerciseFormView, ExerciseCircuitFormView,
//  ExerciseFormsCircuitRestAndRepsView and the four Modify* views.
//
//  It works on a local draft copy: nothing touches the store (or the disk)
//  until the user taps Save.
//

import SwiftUI

struct WorkoutEditorView: View {

    @State private var draft: Workout
    private let onSave: (Workout) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showValidationAlert = false

    init(workout: Workout, onSave: @escaping (Workout) -> Void) {
        var initial = workout
        if initial.exercises.isEmpty {
            initial.exercises.append(Exercise())
        }
        _draft = State(initialValue: initial)
        self.onSave = onSave
    }

    private var isCircuit: Bool { draft.type == .circuit }

    var body: some View {
        NavigationStack {
            Form {
                workoutSection

                ForEach($draft.exercises) { $exercise in
                    Section {
                        ExerciseEditorView(exercise: $exercise, isCircuit: isCircuit)
                    } header: {
                        exerciseHeader(for: exercise)
                    }
                }

                Section {
                    Button {
                        addExercise()
                    } label: {
                        Label("Add exercise", systemImage: "plus.circle.fill")
                    }
                }
            }
            .navigationTitle(draft.name.isEmpty ? "New \(draft.type.label)" : draft.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .bold()
                }
            }
            .alert("Missing information", isPresented: $showValidationAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Give the workout a name and add at least one exercise.")
            }
        }
    }

    // MARK: - Sections

    private var workoutSection: some View {
        Section("Workout") {
            TextField("Name*", text: $draft.name)

            Picker("Type", selection: $draft.type) {
                ForEach(WorkoutType.allCases) { type in
                    Text(type.label).tag(type)
                }
            }
            .pickerStyle(.segmented)

            if isCircuit {
                // In a circuit the whole sequence is repeated N times,
                // so the round count belongs to the workout, not to each exercise.
                HStack {
                    Text("Rounds")
                    Spacer()
                    TextField("0", text: $draft.rounds.asText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }
                DurationRow(label: "Rest between rounds", seconds: $draft.restBetweenExercises)
            } else {
                DurationRow(label: "Rest between exercises", seconds: $draft.restBetweenExercises)
            }
        }
    }

    private func exerciseHeader(for exercise: Exercise) -> some View {
        HStack {
            let index = draft.exercises.firstIndex(where: { $0.id == exercise.id }) ?? 0
            Text(exercise.isSuperset && !isCircuit ? "Exercise \(index + 1) · Superset" : "Exercise \(index + 1)")
            Spacer()
            if draft.exercises.count > 1 || !exerciseIsEmpty(exercise) {
                Button(role: .destructive) {
                    draft.exercises.removeAll { $0.id == exercise.id }
                } label: {
                    Image(systemName: "trash")
                }
                .font(.footnote)
            }
        }
    }

    // MARK: - Actions

    private func addExercise() {
        draft.exercises.append(Exercise())
    }

    private func exerciseIsEmpty(_ exercise: Exercise) -> Bool {
        exercise.name.isEmpty
            && exercise.muscle.isEmpty
            && exercise.reps == 0
            && (exercise.superset?.name.isEmpty ?? true)
    }

    private func save() {
        // Drop trailing exercises the user added but never filled in.
        draft.exercises.removeAll { exerciseIsEmpty($0) }

        if isCircuit {
            draft.rounds = max(draft.rounds, 1)
            for index in draft.exercises.indices {
                // A circuit runs every exercise once per round: the per-exercise
                // set count is not used, keep it consistent instead of stale.
                draft.exercises[index].sets = 1
                // Supersets are a Tab-only concept.
                draft.exercises[index].superset = nil
            }
        } else {
            // A superset left with an empty second exercise is just a plain exercise.
            for index in draft.exercises.indices {
                if let superset = draft.exercises[index].superset, superset.name.isEmpty {
                    draft.exercises[index].superset = nil
                }
            }
        }

        guard draft.isValid else {
            showValidationAlert = true
            return
        }
        onSave(draft)
        dismiss()
    }
}

#Preview {
    WorkoutEditorView(workout: Workout(type: .tab)) { _ in }
}
