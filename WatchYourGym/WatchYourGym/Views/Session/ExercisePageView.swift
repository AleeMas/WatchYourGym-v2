//
//  ExercisePageView.swift
//  WatchYourGym
//
//  One page of the workout session: a single exercise.
//  What is shown depends on the workout type:
//  - Tab     : "3 x 12" and this exercise's own set counter, which survives
//              swiping between pages and can exceed the target (6/5).
//              A superset shows both exercises side by side; one "Set done" covers both.
//  - Circuit : "12 reps" and the current round of the whole circuit.
//

import SwiftUI

struct ExercisePageView: View {

    let exercise: Exercise
    let exerciseNumber: Int
    let exerciseCount: Int
    let isCircuit: Bool
    /// Tab only: sets done so far for this exercise and how many are planned.
    let completedSets: Int
    let targetSets: Int
    /// Circuit only: current round index (0-based) and total rounds.
    let currentRound: Int
    let roundCount: Int
    let isResting: Bool
    let buttonTitle: String
    let onAdvance: () -> Void

    private var superset: SupersetExercise? {
        isCircuit ? nil : exercise.superset
    }

    private var isComplete: Bool {
        !isCircuit && completedSets >= targetSets
    }

    var body: some View {
        VStack(spacing: 12) {
            header

            if let superset {
                supersetBody(superset)
            } else {
                singleBody
            }

            Spacer()

            progressView

            if !isResting {
                Button(buttonTitle) {
                    onAdvance()
                }
                .buttonStyle(PrimaryButtonStyle(color: .green))
            }
        }
        .padding()
        .padding(.bottom, 24)
    }

    // MARK: - Header

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 8) {
            if isCircuit {
                // In a circuit the round is the primary progress indicator.
                badge("Round \(currentRound + 1)/\(roundCount)", color: .orange)
            } else if superset != nil {
                badge("Superset", color: .purple)
            }

            if isComplete {
                badge("Completed", systemImage: "checkmark", color: .green)
            }
        }

        Text("Exercise \(exerciseNumber)/\(exerciseCount)")
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    private func badge(_ text: String, systemImage: String? = nil, color: Color) -> some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
        }
        .font(.headline)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(color.opacity(0.2), in: Capsule())
        .foregroundStyle(color)
    }

    // MARK: - Progress

    @ViewBuilder
    private var progressView: some View {
        if isCircuit {
            Text("Round \(currentRound + 1) of \(roundCount)")
                .font(.headline)
                .foregroundStyle(.secondary)
        } else {
            // Always "next set to do / planned sets", so an extra set reads 6/5.
            Text("Current set: \(completedSets)/\(exercise.sets)")
                .font(.headline)
                .foregroundStyle(isComplete ? Color.green : Color.secondary)
        }
    }

    // MARK: - Single exercise

    @ViewBuilder
    private var singleBody: some View {
        Text(exercise.name)
            .font(.largeTitle.bold())
            .multilineTextAlignment(.center)

        if !exercise.muscle.isEmpty {
            Text(exercise.muscle)
                .font(.title3)
                .foregroundStyle(.secondary)
        }

        Spacer()

        VStack(spacing: 8) {
            Text(isCircuit ? exercise.effortSummary : exercise.setsSummary)
                .font(.system(size: 44, weight: .bold, design: .rounded))

            if exercise.weightKg > 0 {
                Text("\(exercise.weightKg) kg")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }

        Spacer()

        notesBox(exercise.notes)
    }

    // MARK: - Superset (two exercises side by side, one set)

    @ViewBuilder
    private func supersetBody(_ superset: SupersetExercise) -> some View {
        Text("\(exercise.sets) sets")
            .font(.title3.bold())
            .foregroundStyle(.secondary)

        Spacer(minLength: 4)

        HStack(alignment: .top, spacing: 6) {
            supersetColumn(
                name: exercise.name,
                muscle: exercise.muscle,
                effort: exercise.effortSummary,
                weightKg: exercise.weightKg
            )

            Image(systemName: "plus")
                .font(.title2.bold())
                .foregroundStyle(.purple)
                .padding(.top, 28)

            supersetColumn(
                name: superset.name,
                muscle: superset.muscle,
                effort: superset.effortSummary,
                weightKg: superset.weightKg
            )
        }

        // Notes are the part that used to eat the screen: keep them short.
        VStack(alignment: .leading, spacing: 4) {
            supersetNote(label: exercise.name, notes: exercise.notes)
            supersetNote(label: superset.name, notes: superset.notes)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func supersetColumn(name: String, muscle: String, effort: String, weightKg: Int) -> some View {
        VStack(spacing: 4) {
            Text(name)
                .font(.title3.bold())
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(height: 50, alignment: .bottom)

            Text(muscle.isEmpty ? " " : muscle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Text(effort)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(weightKg > 0 ? "\(weightKg) kg" : " ")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
        .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func supersetNote(label: String, notes: String) -> some View {
        if !notes.isEmpty {
            (Text("\(label): ").bold() + Text(notes))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }

    // MARK: - Shared

    @ViewBuilder
    private func notesBox(_ notes: String) -> some View {
        if !notes.isEmpty {
            Text(notes)
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
    }
}
