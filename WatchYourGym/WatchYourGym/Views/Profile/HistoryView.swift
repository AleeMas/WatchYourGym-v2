//
//  HistoryView.swift
//  WatchYourGym
//
//  List of completed workouts, most recent first. Reached from the Profile.
//

import SwiftUI

struct HistoryView: View {

    @EnvironmentObject private var historyStore: HistoryStore

    var body: some View {
        Group {
            if historyStore.records.isEmpty {
                ContentUnavailableView(
                    "No workouts yet",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Completed workouts will appear here.")
                )
            } else {
                List {
                    ForEach(historyStore.records) { record in
                        HistoryRowView(record: record)
                    }
                    .onDelete { offsets in
                        historyStore.delete(at: offsets)
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A single completed workout.
struct HistoryRowView: View {
    let record: WorkoutRecord

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(record.type == .circuit ? Color.orange : Color.green)
                .frame(width: 5, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(record.workoutName)
                    .font(.headline)
                Text(record.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(formattedElapsed(record.durationSeconds))
                    .font(.headline)
                    .monospacedDigit()
                Text(record.type.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .environmentObject(HistoryStore())
}
