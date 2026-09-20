//
//  Style.swift
//  WatchYourGym
//
//  Shared formatting helpers and styles. Only semantic colors are used,
//  so the whole app supports light and dark mode automatically.
//

import SwiftUI

// MARK: - Formatting

/// 95 -> "01:35" (rest timers, always under an hour)
func formattedDuration(_ seconds: Int) -> String {
    String(format: "%02d:%02d", seconds / 60, seconds % 60)
}

/// 95 -> "01:35", 3725 -> "1:02:05" (whole-workout durations)
func formattedElapsed(_ seconds: Int) -> String {
    let hours = seconds / 3600
    let minutes = (seconds % 3600) / 60
    let secs = seconds % 60
    if hours > 0 {
        return String(format: "%d:%02d:%02d", hours, minutes, secs)
    }
    return String(format: "%02d:%02d", minutes, secs)
}

// MARK: - Bindings

extension Binding where Value == Int {
    /// Bridges an Int model value to a numeric TextField.
    /// 0 is shown as an empty field; invalid input leaves the value unchanged.
    var asText: Binding<String> {
        Binding<String>(
            get: { self.wrappedValue == 0 ? "" : String(self.wrappedValue) },
            set: { newValue in
                if newValue.isEmpty {
                    self.wrappedValue = 0
                } else if let intValue = Int(newValue), intValue >= 0 {
                    self.wrappedValue = intValue
                }
            }
        )
    }
}

// MARK: - Styles

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title2.bold())
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .padding(.horizontal, 28)
            .background(color, in: RoundedRectangle(cornerRadius: 12))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
