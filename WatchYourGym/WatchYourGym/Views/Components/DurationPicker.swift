//
//  DurationPicker.swift
//  WatchYourGym
//
//  A reusable mm:ss wheel picker (0:00 to 5:00, 5-second steps).
//  Replaces the picker code that was duplicated in six different views.
//

import SwiftUI

struct DurationPicker: View {
    let title: String
    @Binding var seconds: Int

    private let values = Array(stride(from: 0, through: 300, by: 5))

    var body: some View {
        Picker(title, selection: $seconds) {
            ForEach(values, id: \.self) { value in
                Text(formattedDuration(value)).tag(value)
            }
        }
        .pickerStyle(.wheel)
        .frame(width: 90, height: 90)
    }
}

/// A labeled row hosting a DurationPicker, for use inside a Form.
struct DurationRow: View {
    let label: String
    @Binding var seconds: Int

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            DurationPicker(title: label, seconds: $seconds)
        }
    }
}
