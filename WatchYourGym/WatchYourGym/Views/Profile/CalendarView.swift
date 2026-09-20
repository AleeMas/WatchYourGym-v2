//
//  CalendarView.swift
//  WatchYourGym
//
//  Profile › Calendar: month grid with the workouts done and the body-weight
//  log, the detail of the selected day, and the weight trend chart.
//

import SwiftUI

struct CalendarView: View {

    @EnvironmentObject private var historyStore: HistoryStore
    @EnvironmentObject private var weightStore: WeightStore

    @State private var visibleMonth = Date()
    @State private var selectedDate = Date()
    @State private var isEditingWeight = false

    private let calendar = Calendar.current

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                monthCard
                legend
                dayDetail
                WeightChartView()
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Today") {
                    withAnimation {
                        visibleMonth = Date()
                        selectedDate = Date()
                    }
                }
            }
        }
        .sheet(isPresented: $isEditingWeight) {
            WeightEntrySheet(date: selectedDate)
        }
    }

    // MARK: - Month

    private var monthCard: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel("Previous month")

                Spacer()

                Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)

                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .accessibilityLabel("Next month")
            }

            CalendarMonthView(
                month: visibleMonth,
                selectedDate: selectedDate,
                marks: marks(for:),
                onSelect: { day in
                    withAnimation(.easeInOut(duration: 0.15)) { selectedDate = day }
                }
            )
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var legend: some View {
        HStack(spacing: 16) {
            legendItem(color: .green, shape: .dot, text: "Tab")
            legendItem(color: .orange, shape: .dot, text: "Circuit")
            legendItem(color: .cyan, shape: .bar, text: "Weight")
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private enum LegendShape { case dot, bar }

    private func legendItem(color: Color, shape: LegendShape, text: String) -> some View {
        HStack(spacing: 5) {
            Group {
                switch shape {
                case .dot:
                    Circle().fill(color).frame(width: 6, height: 6)
                case .bar:
                    RoundedRectangle(cornerRadius: 1.5).fill(color).frame(width: 8, height: 3)
                }
            }
            Text(text)
        }
    }

    // MARK: - Selected day

    private var dayDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(selectedDate.formatted(date: .complete, time: .omitted))
                .font(.headline)

            // Weight
            HStack {
                Label {
                    if let entry = weightStore.entry(on: selectedDate) {
                        Text(entry.formatted)
                            .font(.title3.bold())
                    } else {
                        Text("No weight logged")
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "scalemass")
                        .foregroundStyle(.cyan)
                }

                Spacer()

                Button(weightStore.hasEntry(on: selectedDate) ? "Edit" : "Add") {
                    isEditingWeight = true
                }
                .buttonStyle(.bordered)
                .disabled(selectedDate > Date())
            }

            Divider()

            // Workouts
            let records = workouts(on: selectedDate)
            if records.isEmpty {
                Label("No workouts", systemImage: "figure.strengthtraining.traditional")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(records) { record in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(record.type == .circuit ? Color.orange : Color.green)
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(record.workoutName)
                                .font(.subheadline.weight(.medium))
                            Text(record.startedAt.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(formattedElapsed(record.durationSeconds))
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Data

    private func marks(for day: Date) -> DayMarks {
        // One dot per distinct type, so a day with two Tabs still shows one dot.
        var types: [WorkoutType] = []
        for record in workouts(on: day) where !types.contains(record.type) {
            types.append(record.type)
        }
        return DayMarks(workoutTypes: types, hasWeight: weightStore.hasEntry(on: day))
    }

    private func workouts(on day: Date) -> [WorkoutRecord] {
        historyStore.records
            .filter { calendar.isDate($0.startedAt, inSameDayAs: day) }
            .sorted { $0.startedAt < $1.startedAt }
    }

    private func changeMonth(by value: Int) {
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: visibleMonth) else { return }
        withAnimation(.easeInOut(duration: 0.2)) { visibleMonth = newMonth }
    }
}

#Preview {
    NavigationStack {
        CalendarView()
    }
    .environmentObject(HistoryStore())
    .environmentObject(WeightStore())
}
