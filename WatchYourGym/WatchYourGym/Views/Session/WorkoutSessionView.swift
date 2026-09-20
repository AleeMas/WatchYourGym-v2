//
//  WorkoutSessionView.swift
//  WatchYourGym
//
//  The live workout screen. Replaces VisuWOView + VisuEX.
//
//  Lifecycle:
//    open  -> browse the exercises, stopwatch at 00:00
//    Start -> stopwatch runs, "Set done" / "Exercise done" drive the session
//    Stop  -> confirmation, nothing is saved
//    last step done -> completion screen, a WorkoutRecord goes to the history
//

import SwiftUI

struct WorkoutSessionView: View {

    @StateObject private var controller: WorkoutSessionController
    @EnvironmentObject private var historyStore: HistoryStore
    @Environment(\.dismiss) private var dismiss

    @State private var isConfirmingStop = false
    @State private var isConfirmingEarlyFinish = false

    init(workout: Workout) {
        // If the app was closed mid-workout, pick the session up where it was.
        let snapshot = ActiveSessionStore.shared.session(matching: workout.id)
        _controller = StateObject(
            wrappedValue: WorkoutSessionController(workout: workout, restoring: snapshot)
        )
    }

    var body: some View {
        Group {
            if controller.isFinished {
                completionView
            } else {
                sessionView
            }
        }
        .navigationTitle(controller.workout.name)
        .navigationBarTitleDisplayMode(.inline)
        // While a workout is running the system back button is replaced by
        // an explicit Stop (discard) on the left and Finish (save) on the right.
        .navigationBarBackButtonHidden(controller.isInProgress)
        .toolbar {
            if controller.isInProgress {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Stop", role: .destructive) {
                        isConfirmingStop = true
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Finish") {
                        if controller.isEverythingDone {
                            controller.finishEarly()
                        } else {
                            isConfirmingEarlyFinish = true
                        }
                    }
                    .bold()
                }
            }
        }
        .alert("Stop workout?", isPresented: $isConfirmingStop) {
            Button("Stop", role: .destructive) {
                controller.abandon()
                dismiss()
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("This workout will not be saved to your history.")
        }
        .alert("Finish workout?", isPresented: $isConfirmingEarlyFinish) {
            Button("Finish and save") {
                controller.finishEarly()
            }
            Button("Keep going", role: .cancel) {}
        } message: {
            Text("Your workout isn't finished yet. Do you want to complete it and save it anyway?")
        }
        .onChange(of: controller.isFinished) { _, finished in
            if finished, let record = controller.makeRecord() {
                historyStore.add(record)
            }
        }
        .onAppear {
            // Keep the screen on during a workout.
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Session

    private var sessionView: some View {
        VStack(spacing: 0) {
            stopwatchHeader

            TabView(selection: $controller.currentExerciseIndex) {
                ForEach(Array(controller.workout.exercises.enumerated()), id: \.element.id) { index, exercise in
                    ExercisePageView(
                        exercise: exercise,
                        exerciseNumber: index + 1,
                        exerciseCount: controller.exerciseCount,
                        isCircuit: controller.isCircuit,
                        completedSets: controller.completedSets(at: index),
                        targetSets: controller.targetSets(at: index),
                        currentRound: controller.currentRound,
                        roundCount: controller.roundCount,
                        isResting: controller.isResting,
                        buttonTitle: controller.hasStarted ? controller.advanceButtonTitle : "Start workout",
                        onAdvance: {
                            if controller.hasStarted {
                                controller.completeCurrentStep()
                            } else {
                                controller.start()
                            }
                        }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(.easeInOut, value: controller.currentExerciseIndex)
            .onChange(of: controller.currentExerciseIndex) { _, _ in
                // Remember the page the user is on, so a restored session
                // reopens on the exercise they were actually doing.
                controller.persist()
            }
            .overlay {
                if controller.isResting {
                    RestOverlayView(
                        remainingSeconds: controller.remainingRestSeconds,
                        nextUp: controller.nextExerciseName,
                        onSkip: { controller.skipRest() }
                    )
                }
            }
        }
    }

    /// Whole-workout stopwatch, always visible above the exercise pages.
    private var stopwatchHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "stopwatch")
                .font(.title3)
                .foregroundStyle(controller.hasStarted ? Color.accentColor : Color.secondary)

            Text(formattedElapsed(controller.elapsedSeconds))
                .font(.system(.title2, design: .rounded).weight(.bold))
                .monospacedDigit()
                .foregroundStyle(controller.hasStarted ? Color.primary : Color.secondary)

            Spacer()

            if !controller.hasStarted {
                Text("Not started")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Completion

    private var completionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Workout complete!")
                .font(.largeTitle.bold())

            VStack(spacing: 4) {
                Text("Total time")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(formattedElapsed(controller.elapsedSeconds))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }

            Button("Done") {
                dismiss()
            }
            .buttonStyle(PrimaryButtonStyle(color: .green))
        }
        .padding()
    }
}

#Preview("Circuit") {
    NavigationStack {
        WorkoutSessionView(workout: {
            var workout = Workout(type: .circuit)
            workout.name = "Full body circuit"
            workout.rounds = 3
            workout.restBetweenExercises = 90

            var squat = Exercise()
            squat.name = "Squat"
            squat.muscle = "Legs"
            squat.reps = 15
            squat.restSeconds = 20

            var pushUp = Exercise()
            pushUp.name = "Push up"
            pushUp.muscle = "Chest"
            pushUp.reps = 12
            pushUp.restSeconds = 20

            workout.exercises = [squat, pushUp]
            return workout
        }())
    }
    .environmentObject(HistoryStore())
}
