//
//  WorkoutListView.swift
//  WatchYourGym
//
//  Replaces GymTabView + GymTabShowerView. The list is driven directly
//  by the store, so it refreshes automatically after every change.
//

import SwiftUI

struct WorkoutListView: View {

    @EnvironmentObject private var workoutStore: WorkoutStore
    @EnvironmentObject private var userStore: UserStore
    @EnvironmentObject private var activeSessionStore: ActiveSessionStore

    /// What the user picked in the "+" sheet, applied once that sheet closes.
    private enum PendingAction {
        case create(WorkoutType)
        case importPlan
    }

    /// Navigation stack contents. Pre-filled at launch when a workout was
    /// left in progress, so the app reopens straight into it.
    @State private var path: [Workout] = []
    @State private var didRestoreSession = false

    @State private var isChoosingType = false
    @State private var isImporting = false
    @State private var pendingAction: PendingAction?
    @State private var importedWorkout: Workout?
    @State private var editingWorkout: Workout?
    @State private var workoutToDelete: Workout?

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if workoutStore.workouts.isEmpty {
                    emptyState
                } else {
                    workoutList
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        isChoosingType = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add workout")
                }
            }
            .navigationDestination(for: Workout.self) { workout in
                WorkoutSessionView(workout: workout)
            }
        }
        .onAppear(perform: restoreSessionIfNeeded)
        .sheet(isPresented: $isChoosingType, onDismiss: {
            // Act only after the type sheet is fully dismissed, otherwise the
            // presentation that follows can be dropped by SwiftUI.
            switch pendingAction {
            case .create(let type):
                editingWorkout = Workout(type: type)
            case .importPlan:
                isImporting = true
            case nil:
                break
            }
            pendingAction = nil
        }) {
            WorkoutTypePickerView(
                onSelect: { type in
                    pendingAction = .create(type)
                    isChoosingType = false
                },
                onImport: {
                    pendingAction = .importPlan
                    isChoosingType = false
                }
            )
            .presentationDetents([.fraction(0.45)])
        }
        .sheet(isPresented: $isImporting, onDismiss: {
            // An imported plan opens in the editor for review before saving.
            if let workout = importedWorkout {
                importedWorkout = nil
                editingWorkout = workout
            }
        }) {
            ImportPlanView { workout in
                importedWorkout = workout
                isImporting = false
            }
        }
        .fullScreenCover(item: $editingWorkout) { workout in
            WorkoutEditorView(workout: workout) { edited in
                workoutStore.upsert(edited)
            }
        }
        .alert(
            "Delete workout?",
            isPresented: Binding(
                get: { workoutToDelete != nil },
                set: { if !$0 { workoutToDelete = nil } }
            ),
            presenting: workoutToDelete
        ) { workout in
            Button("Delete", role: .destructive) {
                workoutStore.delete(workout)
                workoutToDelete = nil
            }
            Button("Cancel", role: .cancel) {
                workoutToDelete = nil
            }
        } message: { workout in
            Text("\"\(workout.name)\" will be deleted permanently.")
        }
    }

    // MARK: - Session restore

    /// Reopens a workout that was still running when the app was closed,
    /// landing on the exercise the user had left off.
    private func restoreSessionIfNeeded() {
        guard !didRestoreSession else { return }
        didRestoreSession = true

        guard let session = activeSessionStore.session, path.isEmpty else { return }
        path = [session.workout]
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell")
                .font(.system(size: 56))
                .foregroundStyle(.secondary)

            Text(welcomeMessage)
                .font(.title2)
                .multilineTextAlignment(.center)

            Button {
                isChoosingType = true
            } label: {
                Label("Create your first workout", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    private var welcomeMessage: String {
        let name = userStore.profile.fullName
        return name.isEmpty
            ? "Welcome!\nStart your workout"
            : "Welcome, \(name)!\nStart your workout"
    }

    // MARK: - List

    private var workoutList: some View {
        List {
            ForEach(workoutStore.workouts) { workout in
                NavigationLink(value: workout) {
                    WorkoutRowView(workout: workout)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        workoutToDelete = workout
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }

                    Button {
                        editingWorkout = workout
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(.plain)
    }
}

/// A single row of the workout list.
struct WorkoutRowView: View {
    let workout: Workout

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(workout.type == .circuit ? Color.orange : Color.green)
                .frame(width: 5, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(workout.name)
                    .font(.headline)

                Text(workout.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    WorkoutListView()
        .environmentObject(WorkoutStore())
        .environmentObject(UserStore())
}
