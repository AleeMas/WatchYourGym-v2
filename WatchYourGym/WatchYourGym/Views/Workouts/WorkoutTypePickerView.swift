//
//  WorkoutTypePickerView.swift
//  WatchYourGym
//
//  Shown after tapping "+": lets the user create a classic workout (Tab),
//  a Circuit, or import a plan from a JSON file.
//

import SwiftUI

struct WorkoutTypePickerView: View {

    let onSelect: (WorkoutType) -> Void
    let onImport: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("New workout")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Close")
            }

            actionButton(
                title: "Classic Workout",
                subtitle: "Classic workout, exercise by exercise",
                systemImage: "list.bullet",
                color: .green,
                action: { onSelect(.tab) }
            )

            actionButton(
                title: "Circuit",
                subtitle: "Rounds of exercises in sequence",
                systemImage: "arrow.triangle.2.circlepath",
                color: .orange,
                action: { onSelect(.circuit) }
            )

            actionButton(
                title: "Import plan",
                subtitle: "Load a workout from a file",
                systemImage: "square.and.arrow.down",
                color: .blue,
                action: onImport
            )

            Spacer(minLength: 0)
        }
        .padding()
    }

    private func actionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.subheadline)
                        .opacity(0.85)
                        .multilineTextAlignment(.leading)
                }

                Spacer()
                Image(systemName: "chevron.right")
            }
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(color, in: RoundedRectangle(cornerRadius: 12))
        }
    }
}

#Preview {
    WorkoutTypePickerView(onSelect: { _ in }, onImport: {})
}
