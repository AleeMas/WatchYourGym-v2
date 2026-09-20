//
//  PersistenceManager.swift
//  WatchYourGym
//
//  Centralizes every file-system path and the generic JSON load/save logic.
//  Replaces the old SysManager and its custom "XYX"-delimited text format.
//

import Foundation
import UIKit

final class PersistenceManager {

    static let shared = PersistenceManager()

    private let fileManager = FileManager.default

    /// Documents/WatchYourGym
    let directoryURL: URL

    // New JSON files
    let workoutsURL: URL
    let profileURL: URL
    let profileImageURL: URL
    let historyURL: URL
    let settingsURL: URL
    let weightsURL: URL
    let activeSessionURL: URL

    // Old text files (kept only to migrate existing data once)
    let legacyWorkoutsURL: URL
    let legacyProfileURL: URL

    private init() {
        let documents = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directoryURL = documents.appendingPathComponent("WatchYourGym", isDirectory: true)

        workoutsURL = directoryURL.appendingPathComponent("workouts.json")
        profileURL = directoryURL.appendingPathComponent("profile.json")
        profileImageURL = directoryURL.appendingPathComponent("profileImage.jpg")
        historyURL = directoryURL.appendingPathComponent("history.json")
        settingsURL = directoryURL.appendingPathComponent("settings.json")
        weightsURL = directoryURL.appendingPathComponent("weights.json")
        activeSessionURL = directoryURL.appendingPathComponent("activeSession.json")

        legacyWorkoutsURL = directoryURL.appendingPathComponent("gymTabDataURL.txt")
        legacyProfileURL = directoryURL.appendingPathComponent("userData.txt")

        ensureDirectoryExists()
    }

    private func ensureDirectoryExists() {
        guard !fileManager.fileExists(atPath: directoryURL.path) else { return }
        do {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        } catch {
            assertionFailure("Could not create app directory: \(error)")
        }
    }

    // MARK: - Generic JSON

    func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            // A corrupted file must never crash the app: we log and start fresh.
            print("PersistenceManager: failed to load \(url.lastPathComponent): \(error)")
            return nil
        }
    }

    func save<T: Encodable>(_ value: T, to url: URL) {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(value)
            try data.write(to: url, options: .atomic)
        } catch {
            print("PersistenceManager: failed to save \(url.lastPathComponent): \(error)")
        }
    }

    func removeFile(at url: URL) {
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Profile image

    func loadProfileImage() -> UIImage? {
        guard fileManager.fileExists(atPath: profileImageURL.path),
              let data = try? Data(contentsOf: profileImageURL) else { return nil }
        return UIImage(data: data)
    }

    func saveProfileImage(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return }
        do {
            try data.write(to: profileImageURL, options: .atomic)
        } catch {
            print("PersistenceManager: failed to save profile image: \(error)")
        }
    }

    // MARK: - Legacy helpers

    func legacyFileExists(at url: URL) -> Bool {
        fileManager.fileExists(atPath: url.path)
    }

    /// After a successful migration the old file is renamed to .bak
    /// so the migration never runs twice but no data is thrown away.
    func archiveLegacyFile(at url: URL) {
        let backupURL = url.appendingPathExtension("bak")
        try? fileManager.removeItem(at: backupURL)
        try? fileManager.moveItem(at: url, to: backupURL)
    }
}
