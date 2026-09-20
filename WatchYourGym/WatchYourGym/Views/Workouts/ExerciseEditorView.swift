//
//  ExerciseEditorView.swift
//  WatchYourGym
//
//  The form fields for a single exercise, used by WorkoutEditorView.
//  A Binding<Exercise> replaces all the old index-based getters/setters.
//

import SwiftUI

struct ExerciseEditorView: View {

    @Binding var exercise: Exercise
    let isCircuit: Bool

    /// Bridges the optional `superset` to the toggle: on creates an empty
    /// second exercise, off removes it (together with what was typed in it).
    private var isSuperset: Binding<Bool> {
        Binding(
            get: { exercise.superset != nil },
            set: { enabled in
                if enabled {
                    if exercise.superset == nil { exercise.superset = SupersetExercise() }
                } else {
                    exercise.superset = nil
                }
            }
        )
    }

    var body: some View {
        TextField("Exercise name", text: $exercise.name)

        TextField("Muscle", text: $exercise.muscle)

        numberRow("Weight (kg)", value: $exercise.weightKg)

        // In a circuit every exercise runs once per round,
        // so the round count belongs to the workout instead.
        if !isCircuit {
            numberRow("Sets", value: $exercise.sets)
        }

        effortRow(reps: $exercise.reps, repsType: $exercise.repsType)

        DurationRow(
            label: isCircuit ? "Rest after this exercise" : "Rest between sets",
            seconds: $exercise.restSeconds
        )

        notesField($exercise.notes)

        // Supersets exist only in Tab workouts: a circuit is already a sequence.
        if !isCircuit {
            Toggle("Superset", isOn: isSuperset.animation())

            if let supersetBinding = Binding($exercise.superset) {
                supersetFields(supersetBinding)
            }
        }
    }

    // MARK: - Superset

    @ViewBuilder
    private func supersetFields(_ superset: Binding<SupersetExercise>) -> some View {
        Group {
            HStack(spacing: 6) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(.purple)
                Text("Second exercise · same sets and rest, no rest in between")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            TextField("Second exercise name", text: superset.name)

            TextField("Muscle", text: superset.muscle)

            numberRow("Weight (kg)", value: superset.weightKg)

            effortRow(reps: superset.reps, repsType: superset.repsType)

            notesField(superset.notes)
        }
        .listRowBackground(Color.purple.opacity(0.08))
    }

    // MARK: - Reusable rows

    private func numberRow(_ label: String, value: Binding<Int>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: value.asText)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 80)
        }
    }

    private func effortRow(reps: Binding<Int>, repsType: Binding<RepsType>) -> some View {
        HStack {
            TextField(repsType.wrappedValue.label, text: reps.asText)
                .keyboardType(.numberPad)

            Picker("Effort type", selection: repsType) {
                ForEach(RepsType.allCases) { type in
                    Text(type.label).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private func notesField(_ notes: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Notes")
                .font(.footnote)
                .foregroundStyle(.secondary)
            TextEditor(text: notes)
                .frame(minHeight: 60)
        }
    }
}
