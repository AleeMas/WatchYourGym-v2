//
//  WeightStore.swift
//  WatchYourGym
//
//  Body-weight log, one entry per day.
//

import Foundation

final class WeightStore: ObservableObject {

    /// Oldest first, so charts can plot it directly.
    @Published private(set) var entries: [WeightEntry] = []

    private let persistence: PersistenceManager
    private let calendar = Calendar.current

    init(persistence: PersistenceManager = .shared) {
        self.persistence = persistence
        entries = (persistence.load([WeightEntry].self, from: persistence.weightsURL) ?? [])
            .sorted { $0.date < $1.date }
    }

    func entry(on date: Date) -> WeightEntry? {
        let day = calendar.startOfDay(for: date)
        return entries.first { calendar.isDate($0.date, inSameDayAs: day) }
    }

    func hasEntry(on date: Date) -> Bool {
        entry(on: date) != nil
    }

    /// Adds or replaces the measurement of that day.
    func set(_ weightKg: Double, on date: Date) {
        let day = calendar.startOfDay(for: date)
        guard weightKg > 0 else { return }

        if let index = entries.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: day) }) {
            entries[index].weightKg = weightKg
        } else {
            entries.append(WeightEntry(date: day, weightKg: weightKg))
            entries.sort { $0.date < $1.date }
        }
        save()
    }

    func removeEntry(on date: Date) {
        let day = calendar.startOfDay(for: date)
        entries.removeAll { calendar.isDate($0.date, inSameDayAs: day) }
        save()
    }

    /// Entries from `months` ago until today, for the chart.
    func entries(lastMonths months: Int) -> [WeightEntry] {
        guard let from = calendar.date(byAdding: .month, value: -months, to: Date()) else {
            return entries
        }
        return entries.filter { $0.date >= from }
    }

    private func save() {
        persistence.save(entries, to: persistence.weightsURL)
    }
}
