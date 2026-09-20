//
//  UserProfile.swift
//  WatchYourGym
//

import Foundation

/// The data shown in the Profile tab.
struct UserProfile: Codable, Equatable {
    var firstName: String = ""
    var lastName: String = ""
    var email: String = ""
    var age: String = ""

    var fullName: String {
        [firstName, lastName]
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
