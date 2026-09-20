//
//  ActiveSessionStore.swift
//  WatchYourGym
//
//  Keeps the in-progress workout on disk so it survives the app being closed.
//
//  Shared instance: the session controller writes to it on every change, and
//  the workout list reads it at launch to reopen the session automatically.
//

import Foundation

final class ActiveSessionStore: ObservableObject {

    static let shared = ActiveSessionStore()

    @Published private(set) var session: ActiveSession?

    private let persistence: PersistenceManager

    init(persistence: PersistenceManager = .shared) {
        self.persistence = persistence

        let stored = persistence.load(ActiveSession.self, from: persistence.activeSessionURL)
        if let stored, stored.isStale {
            // Too old to be meaningful: forget it.
            persistence.removeFile(at: persistence.activeSessionURL)
            session = nil
        } else {
            session = stored
        }
    }

    /// The snapshot for a given workout, if the saved session belongs to it.
    func session(matching workoutID: Workout.ID) -> ActiveSession? {
        guard let session, session.workout.id == workoutID else { return nil }
        return session
    }

    func save(_ session: ActiveSession) {
        var snapshot = session
        snapshot.savedAt = Date()
        self.session = snapshot
        persistence.save(snapshot, to: persistence.activeSessionURL)
    }

    /// The workout ended, was abandoned, or was restored and consumed.
    func clear() {
        session = nil
        persistence.removeFile(at: persistence.activeSessionURL)
    }
}
