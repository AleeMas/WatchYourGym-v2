//
//  UserStore.swift
//  WatchYourGym
//
//  Single source of truth for the user profile and picture.
//  Replaces the old User class (which mixed model, view state and file I/O).
//

import Foundation
import UIKit

final class UserStore: ObservableObject {

    @Published var profile: UserProfile {
        didSet {
            guard profile != oldValue else { return }
            persistence.save(profile, to: persistence.profileURL)
        }
    }

    @Published private(set) var profileImage: UIImage?

    private let persistence: PersistenceManager

    init(persistence: PersistenceManager = .shared) {
        self.persistence = persistence

        if let saved = persistence.load(UserProfile.self, from: persistence.profileURL) {
            profile = saved
        } else if let migrated = Self.migrateLegacyProfile(persistence: persistence) {
            profile = migrated
            persistence.save(migrated, to: persistence.profileURL)
            persistence.archiveLegacyFile(at: persistence.legacyProfileURL)
        } else {
            profile = UserProfile()
        }

        profileImage = persistence.loadProfileImage()
    }

    func updateProfileImage(_ image: UIImage) {
        profileImage = image
        persistence.saveProfileImage(image)
    }

    // MARK: - Legacy migration (old userData.txt: 4 plain lines)

    private static func migrateLegacyProfile(persistence: PersistenceManager) -> UserProfile? {
        guard persistence.legacyFileExists(at: persistence.legacyProfileURL),
              let content = try? String(contentsOf: persistence.legacyProfileURL, encoding: .utf8) else {
            return nil
        }
        let lines = content.components(separatedBy: .newlines)
        var profile = UserProfile()
        if lines.indices.contains(0) { profile.firstName = lines[0] }
        if lines.indices.contains(1) { profile.lastName = lines[1] }
        if lines.indices.contains(2) { profile.email = lines[2] }
        if lines.indices.contains(3) { profile.age = lines[3] }
        return profile
    }
}
