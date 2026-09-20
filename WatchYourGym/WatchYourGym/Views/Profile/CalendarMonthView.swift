//
//  CalendarMonthView.swift
//  WatchYourGym
//
//  Month grid used by CalendarView.
//
//  Each day can show:
//  - one dot per workout type done that day (green = Tab, orange = Circuit)
//  - a small light-blue mark in the bottom-left corner when a weight was logged
//

import SwiftUI

/// What to draw on a single day.
struct DayMarks {
    var workoutTypes: [WorkoutType] = []
    var hasWeight: Bool = false
}

struct CalendarMonthView: View {

    /// Any date inside the month to display.
    let month: Date
    let selectedDate: Date
    let marks: (Date) -> DayMarks
    let onSelect: (Date) -> Void

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    var body: some View {
        VStack(spacing: 6) {
            weekdayHeader

            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
    }

    // MARK: - Header

    private var weekdayHeader: some View {
        HStack(spacing: 2) {
            ForEach(orderedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    /// Weekday initials rotated to match the user's first day of the week.
    private var orderedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let shift = calendar.firstWeekday - 1
        return Array(symbols[shift...] + symbols[..<shift])
    }

    // MARK: - Days

    /// The days of the month, padded at the front so the first one falls
    /// under the right weekday.
    private var days: [Date?] {
        guard
            let interval = calendar.dateInterval(of: .month, for: month),
            let dayCount = calendar.range(of: .day, in: .month, for: month)?.count
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7

        let dates = (0..<dayCount).compactMap {
            calendar.date(byAdding: .day, value: $0, to: interval.start)
        }
        return Array(repeating: nil, count: leadingBlanks) + dates.map { Optional($0) }
    }

    private func dayCell(_ day: Date) -> some View {
        let dayMarks = marks(day)
        let isSelected = calendar.isDate(day, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(day)
        let isFuture = day > Date()

        return VStack(spacing: 3) {
            Text("\(calendar.component(.day, from: day))")
                .font(.system(.callout, design: .rounded))
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(dayNumberColor(isSelected: isSelected, isToday: isToday, isFuture: isFuture))

            HStack(spacing: 3) {
                ForEach(Array(dayMarks.workoutTypes.enumerated()), id: \.offset) { _, type in
                    Circle()
                        .fill(type == .circuit ? Color.orange : Color.green)
                        .frame(width: 6, height: 6)
                }
            }
            .frame(height: 6)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor)
            } else if isToday {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.accentColor, lineWidth: 1)
            }
        }
        // The weight mark: small, bottom-left, light blue.
        .overlay(alignment: .bottomLeading) {
            if dayMarks.hasWeight {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(isSelected ? Color.white : Color.cyan)
                    .frame(width: 8, height: 3)
                    .padding(.leading, 5)
                    .padding(.bottom, 4)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect(day) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel(for: day, marks: dayMarks))
    }

    private func dayNumberColor(isSelected: Bool, isToday: Bool, isFuture: Bool) -> Color {
        if isSelected { return .white }
        if isFuture { return .secondary }
        if isToday { return .accentColor }
        return .primary
    }

    private func accessibilityLabel(for day: Date, marks: DayMarks) -> String {
        var parts = [day.formatted(date: .long, time: .omitted)]
        if !marks.workoutTypes.isEmpty {
            parts.append("\(marks.workoutTypes.count) workouts")
        }
        if marks.hasWeight {
            parts.append("weight logged")
        }
        return parts.joined(separator: ", ")
    }
}
