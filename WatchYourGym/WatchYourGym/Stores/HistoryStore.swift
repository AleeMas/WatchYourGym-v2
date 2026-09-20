//
//  HistoryStore.swift
//  WatchYourGym
//
//  Single source of truth for the completed workouts history.
//

import Foundation

final class HistoryStore: ObservableObject {

    /// Most recent first.
    @Published private(set) var records: [WorkoutRecord] = []

    private let persistence: PersistenceManager

    init(persistence: PersistenceManager = .shared) {
        self.persistence = persistence
        records = (persistence.load([WorkoutRecord].self, from: persistence.historyURL) ?? [])
            .sorted { $0.startedAt > $1.startedAt }
    }

    func add(_ record: WorkoutRecord) {
        records.insert(record, at: 0)
        save()
    }

    func delete(_ record: WorkoutRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    func delete(at offsets: IndexSet) {
        records.remove(atOffsets: offsets)
        save()
    }

    private func save() {
        persistence.save(records, to: persistence.historyURL)
    }
}
