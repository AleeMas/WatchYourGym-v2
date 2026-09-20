//
//  WatchYourGymWidgetBundle.swift
//  WatchYourGymWidget
//
//  Entry point of the widget extension.
//  The only thing this extension provides is the workout Live Activity.
//

import WidgetKit
import SwiftUI

@main
struct WatchYourGymWidgetBundle: WidgetBundle {
    var body: some Widget {
        WorkoutLiveActivity()
    }
}
