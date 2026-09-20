//
//  WeightEntry.swift
//  WatchYourGym
//
//  One body-weight measurement, at most one per day.
//

import Foundation

struct WeightEntry: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    /// Normalised to the start of the day, so a day has a single entry.
    var date: Date
    var weightKg: Double

    /// "72.4 kg"
    var formatted: String {
        String(format: "%.1f kg", weightKg)
    }
}
