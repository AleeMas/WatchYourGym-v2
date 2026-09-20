//
//  RestOverlayView.swift
//  WatchYourGym
//
//  Full-screen overlay shown while the rest timer runs.
//

import SwiftUI

struct RestOverlayView: View {

    let remainingSeconds: Int
    /// Name of the exercise coming up after this rest, if any.
    let nextUp: String?
    let onSkip: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("Rest")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))

                Text(formattedDuration(remainingSeconds))
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.default, value: remainingSeconds)

                if let nextUp, !nextUp.isEmpty {
                    Text("Next: \(nextUp)")
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.8))
                }

                Button("Skip rest") {
                    onSkip()
                }
                .buttonStyle(PrimaryButtonStyle(color: .red))
                .padding(.top, 8)
            }
        }
        .transition(.opacity)
    }
}

#Preview {
    RestOverlayView(remainingSeconds: 92, nextUp: "Push up") {}
}
