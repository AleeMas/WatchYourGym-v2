//
//  WorkoutSessionController.swift
//  WatchYourGym
//
//  Drives a live workout session. The two workout types have genuinely
//  different execution loops:
//
//  TAB — the outer loop is the exercise, the inner loop is the set:
//      Exercise 1, set 1 -> rest(exercise) -> set 2 -> ... -> rest(workout)
//      Exercise 2, set 1 -> ...
//
//  CIRCUIT — the outer loop is the round, the inner loop is the exercise:
//      Round 1: Exercise 1 -> rest(exercise) -> Exercise 2 -> rest(exercise)
//               -> Exercise 3 -> rest(workout, between rounds)
//      Round 2: Exercise 1 -> ...
//
//  Every timer is date-based (it counts towards an end date), so values stay
//  correct after a delayed tick or a spell in the background. The whole state
//  is mirrored to disk on each change, so closing the app does not lose the
//  session: see ActiveSession / ActiveSessionStore.
//

import Foundation
import UIKit

final class WorkoutSessionController: ObservableObject {

    let workout: Workout

    @Published var currentExerciseIndex = 0
    /// Sets completed so far, one entry per exercise. Only meaningful for `.tab`.
    /// Survives swiping between pages, so going back to an exercise shows its
    /// real progress; extra sets beyond the target are counted too (e.g. 6/5).
    @Published private(set) var completedSets: [Int]
    /// Current round of the circuit. Only meaningful for `.circuit`.
    @Published private(set) var currentRound = 0
    @Published private(set) var isResting = false
    @Published private(set) var remainingRestSeconds = 0
    @Published private(set) var isFinished = false

    /// Whole-workout stopwatch. Starts on `start()`, stops on finish.
    @Published private(set) var hasStarted = false
    @Published private(set) var elapsedSeconds = 0

    private var startDate: Date?
    private var finishDate: Date?
    private var elapsedTimer: Timer?

    private var restEndDate: Date?
    private var restCompletion: RestCompletion = .stayHere
    private var timer: Timer?
    private var lastBeepedSecond: Int?
    private var didWarnAt30 = false

    private let settings: SettingsStore
    private let sessionStore: ActiveSessionStore
    private let sound: SoundPlayer
    private let notifications: NotificationManager
    private let liveActivity: LiveActivityManager

    init(
        workout: Workout,
        restoring snapshot: ActiveSession? = nil,
        settings: SettingsStore = .shared,
        sessionStore: ActiveSessionStore = .shared,
        sound: SoundPlayer = .shared,
        notifications: NotificationManager = .shared,
        liveActivity: LiveActivityManager = .shared
    ) {
        self.workout = snapshot?.workout ?? workout
        self.settings = settings
        self.sessionStore = sessionStore
        self.sound = sound
        self.notifications = notifications
        self.liveActivity = liveActivity
        self.completedSets = Array(repeating: 0, count: (snapshot?.workout ?? workout).exercises.count)

        if let snapshot {
            restore(from: snapshot)
        }
    }

    deinit {
        timer?.invalidate()
        elapsedTimer?.invalidate()
    }

    // MARK: - Whole-workout stopwatch

    var isInProgress: Bool { hasStarted && !isFinished }

    /// Starts the session and the stopwatch. Called by the "Start workout" button.
    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        startDate = Date()
        elapsedSeconds = 0

        startStopwatch()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Ask for notification permission here, where the reason is obvious,
        // rather than at launch. Without it the rest alert is never delivered.
        if settings.settings.backgroundNotifications {
            Task { await notifications.ensureAuthorization() }
        }

        liveActivity.start(
            workoutName: workout.name,
            workoutType: workout.type.label,
            state: makeActivityState()
        )
        persist()
    }

    /// The user left before finishing: stop every timer, record nothing.
    func abandon() {
        stopTimer()
        stopStopwatch()
        notifications.cancelRestFinished()
        liveActivity.end()
        sessionStore.clear()
    }

    /// Snapshot for the history. Available only once the workout is finished.
    func makeRecord() -> WorkoutRecord? {
        guard let startDate, let finishDate else { return nil }
        return WorkoutRecord(
            workoutName: workout.name,
            type: workout.type,
            startedAt: startDate,
            durationSeconds: max(0, Int(finishDate.timeIntervalSince(startDate)))
        )
    }

    private func startStopwatch() {
        stopStopwatch()
        let stopwatch = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateElapsed()
        }
        RunLoop.main.add(stopwatch, forMode: .common)
        elapsedTimer = stopwatch
        updateElapsed()
    }

    private func stopStopwatch() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
    }

    /// Date-based, so the value is right even after the app was in background.
    private func updateElapsed() {
        guard let startDate else { return }
        let reference = finishDate ?? Date()
        elapsedSeconds = max(0, Int(reference.timeIntervalSince(startDate)))
    }

    // MARK: - Restore

    private func restore(from snapshot: ActiveSession) {
        hasStarted = true
        startDate = snapshot.startedAt
        currentExerciseIndex = min(snapshot.currentExerciseIndex, max(workout.exercises.count - 1, 0))
        currentRound = snapshot.currentRound
        restCompletion = snapshot.restCompletion

        // Defensive: the snapshot could come from a plan with a different
        // number of exercises if the file was hand-edited.
        var sets = Array(repeating: 0, count: workout.exercises.count)
        for index in sets.indices where snapshot.completedSets.indices.contains(index) {
            sets[index] = snapshot.completedSets[index]
        }
        completedSets = sets

        startStopwatch()

        // A rest that was still running when the app closed resumes with the
        // time actually left; if it expired meanwhile, apply its outcome now.
        if let restEnd = snapshot.restEndDate {
            if restEnd > Date() {
                restEndDate = restEnd
                remainingRestSeconds = max(0, Int(restEnd.timeIntervalSinceNow.rounded(.up)))
                isResting = true
                didWarnAt30 = remainingRestSeconds <= 30
                lastBeepedSecond = nil
                startRestTicker()
            } else {
                restEndDate = nil
                isResting = false
                applyRestCompletion()
            }
        }

        liveActivity.start(
            workoutName: workout.name,
            workoutType: workout.type.label,
            state: makeActivityState()
        )
    }

    // MARK: - Derived state

    var isCircuit: Bool { workout.type == .circuit }

    var currentExercise: Exercise? {
        guard workout.exercises.indices.contains(currentExerciseIndex) else { return nil }
        return workout.exercises[currentExerciseIndex]
    }

    var exerciseCount: Int { workout.exercises.count }

    var roundCount: Int { max(workout.rounds, 1) }

    // MARK: Tab progress

    /// Sets to do for an exercise. An exercise saved with 0 sets counts as 1,
    /// otherwise it could never be completed.
    func targetSets(at index: Int) -> Int {
        guard workout.exercises.indices.contains(index) else { return 1 }
        return max(workout.exercises[index].sets, 1)
    }

    func completedSets(at index: Int) -> Int {
        completedSets.indices.contains(index) ? completedSets[index] : 0
    }

    func isExerciseComplete(at index: Int) -> Bool {
        completedSets(at: index) >= targetSets(at: index)
    }

    /// Tab only: every exercise has reached its sets. Circuits never report
    /// "everything done" here — their natural end is handled by the round flow.
    var isEverythingDone: Bool {
        guard !isCircuit, exerciseCount > 0 else { return false }
        return workout.exercises.indices.allSatisfy { isExerciseComplete(at: $0) }
    }

    /// The exercise the user will face once the current rest is over.
    var nextExerciseName: String? {
        switch restCompletion {
        case .stayHere:
            return currentExercise?.displayName
        case .nextExercise:
            let index = currentExerciseIndex + 1
            return workout.exercises.indices.contains(index) ? workout.exercises[index].displayName : nil
        case .nextRound:
            return workout.exercises.first?.displayName
        }
    }

    /// Label for the button that advances the session.
    var advanceButtonTitle: String {
        isCircuit ? "Exercise done" : "Set done"
    }

    // MARK: - Session flow

    /// Called when the user completes the current step:
    /// one set (Tab) or one exercise of the round (Circuit).
    func completeCurrentStep() {
        guard hasStarted, !isFinished, let exercise = currentExercise else { return }

        if isCircuit {
            advanceCircuit(after: exercise)
        } else {
            advanceTab(after: exercise)
        }
        persist()
    }

    /// TAB: count one more set for the current exercise and decide what's next.
    private func advanceTab(after exercise: Exercise) {
        let index = currentExerciseIndex
        guard completedSets.indices.contains(index) else { return }

        completedSets[index] += 1
        let done = completedSets[index]
        let target = targetSets(at: index)
        let isLastExercise = index == exerciseCount - 1

        if done < target {
            // More sets to go: rest between sets.
            startRest(seconds: exercise.restSeconds, then: .stayHere)
        } else if done == target {
            // Target just reached.
            if isLastExercise, isEverythingDone {
                // Last set of the last exercise, nothing left anywhere: done.
                finish()
            } else if isLastExercise {
                // Last exercise done but others are still open: rest and stay,
                // the user goes back to them (or taps Finish).
                startRest(seconds: workout.restBetweenExercises, then: .stayHere)
            } else {
                // Exercise done: rest between exercises, then move on.
                startRest(seconds: workout.restBetweenExercises, then: .nextExercise)
            }
        } else {
            // Extra set on an exercise that was already complete (e.g. 6/5):
            // rest as between sets and stay on this page.
            startRest(seconds: exercise.restSeconds, then: .stayHere)
        }
    }

    /// CIRCUIT: run through every exercise once, then start the next round.
    private func advanceCircuit(after exercise: Exercise) {
        if currentExerciseIndex + 1 < exerciseCount {
            // Still inside the round: rest after this exercise, if configured.
            startRest(seconds: exercise.restSeconds, then: .nextExercise)
        } else if currentRound + 1 < roundCount {
            // Round complete: rest between rounds, then start over.
            startRest(seconds: workout.restBetweenExercises, then: .nextRound)
        } else {
            finish()
        }
    }

    /// The "Finish" button: end the workout now, whatever the progress.
    func finishEarly() {
        guard isInProgress else { return }
        // Cancel a running rest so the completion screen appears cleanly.
        stopTimer()
        restEndDate = nil
        isResting = false
        notifications.cancelRestFinished()
        finish()
    }

    func skipRest() {
        restEndDate = Date()
        tick()
    }

    private func finish() {
        stopTimer()
        finishDate = Date()
        stopStopwatch()
        updateElapsed()
        isFinished = true
        notifications.cancelRestFinished()
        liveActivity.end()
        sessionStore.clear()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    // MARK: - Rest timer

    private func startRest(seconds: Int, then completion: RestCompletion) {
        restCompletion = completion

        // A rest of 0 means "no rest": jump straight to the next step.
        guard seconds > 0 else {
            applyRestCompletion()
            updateActivity()
            return
        }

        restEndDate = Date().addingTimeInterval(TimeInterval(seconds))
        remainingRestSeconds = seconds
        lastBeepedSecond = nil
        // Only warn at 30s when the rest is actually longer than that,
        // otherwise the warning would fire the instant the rest starts.
        didWarnAt30 = seconds <= 30
        isResting = true

        startRestTicker()
        scheduleRestNotification(in: TimeInterval(seconds))
        updateActivity()
    }

    private func startRestTicker() {
        stopTimer()
        let ticker = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(ticker, forMode: .common)
        timer = ticker
    }

    private func tick() {
        guard let endDate = restEndDate else { return }
        let remaining = max(0, Int(endDate.timeIntervalSinceNow.rounded(.up)))

        if remaining != remainingRestSeconds {
            remainingRestSeconds = remaining
        }

        // Halfway warning: 30 seconds left.
        if !didWarnAt30, remaining <= 30, remaining > 0 {
            didWarnAt30 = true
            if settings.settings.warnAt30Seconds {
                sound.play(.warning)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }

        // Countdown feedback for the last 3 seconds.
        if remaining > 0, remaining <= 3, lastBeepedSecond != remaining {
            lastBeepedSecond = remaining
            sound.play(.tick)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        if remaining == 0 {
            endRest()
        }
    }

    private func endRest() {
        stopTimer()
        restEndDate = nil
        isResting = false
        sound.play(.end)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        notifications.cancelRestFinished()
        applyRestCompletion()
        updateActivity()
        persist()
    }

    private func applyRestCompletion() {
        switch restCompletion {
        case .stayHere:
            break
        case .nextExercise:
            advanceExercise()
        case .nextRound:
            advanceRound()
        }
        restCompletion = .stayHere
    }

    private func advanceExercise() {
        guard currentExerciseIndex + 1 < exerciseCount else {
            finish()
            return
        }
        currentExerciseIndex += 1
    }

    private func advanceRound() {
        guard currentRound + 1 < roundCount else {
            finish()
            return
        }
        currentRound += 1
        currentExerciseIndex = 0
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func scheduleRestNotification(in seconds: TimeInterval) {
        guard settings.settings.backgroundNotifications else { return }
        notifications.scheduleRestFinished(in: seconds, exerciseName: nextExerciseName)
    }

    // MARK: - Persistence & Live Activity

    /// Mirrors the current state to disk. Called after every change that the
    /// user would be annoyed to lose.
    func persist() {
        guard isInProgress, let startDate else { return }
        sessionStore.save(
            ActiveSession(
                workout: workout,
                startedAt: startDate,
                completedSets: completedSets,
                currentExerciseIndex: currentExerciseIndex,
                currentRound: currentRound,
                restEndDate: restEndDate,
                restCompletion: restCompletion,
                savedAt: Date()
            )
        )
        updateActivity()
    }

    private func makeActivityState() -> WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            startedAt: startDate ?? Date(),
            exerciseName: currentExercise?.displayName ?? workout.name,
            progress: activityProgressText,
            isResting: isResting,
            restEndsAt: restEndDate
        )
    }

    private var activityProgressText: String {
        if isCircuit {
            return "Round \(currentRound + 1)/\(roundCount)"
        }
        let index = currentExerciseIndex
        return "Set \(completedSets(at: index))/\(targetSets(at: index))"
    }

    private func updateActivity() {
        guard isInProgress else { return }
        liveActivity.update(makeActivityState())
    }
}
