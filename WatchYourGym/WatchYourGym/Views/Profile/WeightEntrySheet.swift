//
//  WeightEntrySheet.swift
//  WatchYourGym
//
//  Add or edit the body weight of a single day.
//

import SwiftUI

struct WeightEntrySheet: View {

    let date: Date

    @EnvironmentObject private var weightStore: WeightStore
    @Environment(\.dismiss) private var dismiss

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    private var parsedWeight: Double? {
        // Accept both "72.4" and "72,4".
        let normalised = text.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalised), value > 0, value < 500 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("0.0", text: $text)
                            .keyboardType(.decimalPad)
                            .font(.system(.largeTitle, design: .rounded).weight(.bold))
                            .focused($isFocused)
                        Text("kg")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text(date.formatted(date: .complete, time: .omitted))
                } footer: {
                    if !text.isEmpty && parsedWeight == nil {
                        Text("Enter a weight between 0 and 500 kg.")
                            .foregroundStyle(.red)
                    }
                }

                if weightStore.hasEntry(on: date) {
                    Section {
                        Button("Delete measurement", role: .destructive) {
                            weightStore.removeEntry(on: date)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let weight = parsedWeight {
                            weightStore.set(weight, on: date)
                        }
                        dismiss()
                    }
                    .bold()
                    .disabled(parsedWeight == nil)
                }
            }
            .onAppear {
                if let entry = weightStore.entry(on: date) {
                    text = String(format: "%.1f", entry.weightKg)
                }
                isFocused = true
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    WeightEntrySheet(date: Date())
        .environmentObject(WeightStore())
}
