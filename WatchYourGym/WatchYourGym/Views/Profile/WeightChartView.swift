//
//  WeightChartView.swift
//  WatchYourGym
//
//  Body-weight trend under the calendar.
//

import SwiftUI
import Charts

struct WeightChartView: View {

    @EnvironmentObject private var weightStore: WeightStore

    private enum Range: Int, CaseIterable, Identifiable {
        case threeMonths = 3
        case sixMonths = 6
        case year = 12

        var id: Int { rawValue }

        var label: String {
            switch self {
            case .threeMonths: return "3M"
            case .sixMonths: return "6M"
            case .year: return "1Y"
            }
        }
    }

    @State private var range: Range = .threeMonths

    private var entries: [WeightEntry] {
        weightStore.entries(lastMonths: range.rawValue)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Weight")
                    .font(.headline)
                Spacer()
                Picker("Range", selection: $range) {
                    ForEach(Range.allCases) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 160)
            }

            if entries.count < 2 {
                Text(weightStore.entries.isEmpty
                     ? "Log your weight on a few days to see the trend here."
                     : "At least two measurements are needed to draw the trend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 24)
            } else {
                chart
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
    }

    private var chart: some View {
        Chart(entries) { entry in
            LineMark(
                x: .value("Date", entry.date),
                y: .value("Weight", entry.weightKg)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(Color.cyan)

            PointMark(
                x: .value("Date", entry.date),
                y: .value("Weight", entry.weightKg)
            )
            .foregroundStyle(Color.cyan)
            .symbolSize(28)

            AreaMark(
                x: .value("Date", entry.date),
                y: .value("Weight", entry.weightKg)
            )
            .interpolationMethod(.monotone)
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.cyan.opacity(0.28), Color.cyan.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .chartYScale(domain: yDomain)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .frame(height: 200)
    }

    /// A little padding around the data, so the line is never glued to the edges.
    private var yDomain: ClosedRange<Double> {
        let values = entries.map(\.weightKg)
        guard let min = values.min(), let max = values.max() else { return 0...100 }
        let padding = Swift.max((max - min) * 0.2, 1)
        return (min - padding)...(max + padding)
    }
}

#Preview {
    WeightChartView()
        .environmentObject(WeightStore())
        .padding()
}
