//
//  WorkoutLiveActivity.swift
//  WatchYourGymWidgetExtension
//
//  Lock Screen banner and Dynamic Island presentation of a running workout.
//
//  This file belongs to the WIDGET EXTENSION target only.
//  See WIDGET_SETUP.md for how to create that target and add this file to it.
//

import SwiftUI
import WidgetKit
import ActivityKit

struct WorkoutLiveActivity: Widget {

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            lockScreenView(context)
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded: shown on long press / when there is room.
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(context.attributes.workoutName)
                            .font(.caption)
                            .lineLimit(1)
                    } icon: {
                        Image(systemName: "figure.strengthtraining.traditional")
                    }
                    .foregroundStyle(.green)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startedAt...Date.distantFuture,
                         countsDown: false)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .frame(maxWidth: 70)
                        .foregroundStyle(.white)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.exerciseName)
                        .font(.headline)
                        .lineLimit(1)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.isResting, let restEndsAt = context.state.restEndsAt {
                        HStack {
                            Label("Rest", systemImage: "pause.circle.fill")
                                .font(.subheadline)
                                .foregroundStyle(.orange)
                            Spacer()
                            Text(timerInterval: Date()...restEndsAt, countsDown: true)
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .monospacedDigit()
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 70)
                                .foregroundStyle(.orange)
                        }
                    } else {
                        Text(context.state.progress)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

            } compactLeading: {
                Image(systemName: context.state.isResting
                      ? "pause.circle.fill"
                      : "figure.strengthtraining.traditional")
                    .foregroundStyle(context.state.isResting ? .orange : .green)

            } compactTrailing: {
                if context.state.isResting, let restEndsAt = context.state.restEndsAt {
                    Text(timerInterval: Date()...restEndsAt, countsDown: true)
                        .monospacedDigit()
                        .frame(maxWidth: 44)
                        .foregroundStyle(.orange)
                } else {
                    Text(timerInterval: context.state.startedAt...Date.distantFuture,
                         countsDown: false)
                        .monospacedDigit()
                        .frame(maxWidth: 44)
                        .foregroundStyle(.green)
                }

            } minimal: {
                Image(systemName: context.state.isResting
                      ? "pause.circle.fill"
                      : "figure.strengthtraining.traditional")
                    .foregroundStyle(context.state.isResting ? .orange : .green)
            }
            .keylineTint(context.state.isResting ? .orange : .green)
        }
    }

    // MARK: - Lock Screen

    @ViewBuilder
    private func lockScreenView(
        _ context: ActivityViewContext<WorkoutActivityAttributes>
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(context.attributes.workoutName, systemImage: "figure.strengthtraining.traditional")
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text(timerInterval: context.state.startedAt...Date.distantFuture,
                     countsDown: false)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .monospacedDigit()
                    .frame(maxWidth: 80, alignment: .trailing)
            }

            HStack {
                Text(context.state.exerciseName)
                    .font(.subheadline)
                    .lineLimit(1)

                Spacer()

                if context.state.isResting, let restEndsAt = context.state.restEndsAt {
                    HStack(spacing: 4) {
                        Image(systemName: "pause.circle.fill")
                        Text(timerInterval: Date()...restEndsAt, countsDown: true)
                            .monospacedDigit()
                            .frame(maxWidth: 60, alignment: .trailing)
                    }
                    .font(.subheadline.bold())
                    .foregroundStyle(.orange)
                } else {
                    Text(context.state.progress)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}
