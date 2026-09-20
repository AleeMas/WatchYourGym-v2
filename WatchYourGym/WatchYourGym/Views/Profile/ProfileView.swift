//
//  ProfileView.swift
//  WatchYourGym
//
//  Uses PhotosPicker (no UIKit wrapper, no photo-library permission needed)
//  and binds the fields directly to the store.
//

import SwiftUI
import PhotosUI

struct ProfileView: View {

    @EnvironmentObject private var userStore: UserStore

    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            VStack(spacing: 8) {
                                profileImage
                                Text("Change photo")
                                    .font(.footnote)
                            }
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

                Section("Personal info") {
                    TextField("First name", text: $userStore.profile.firstName)
                        .textContentType(.givenName)

                    TextField("Last name", text: $userStore.profile.lastName)
                        .textContentType(.familyName)

                    TextField("Email", text: $userStore.profile.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)

                    TextField("Age", text: $userStore.profile.age)
                        .keyboardType(.numberPad)
                }

                Section("Activity") {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Label("History", systemImage: "clock.arrow.circlepath")
                    }

                    NavigationLink {
                        CalendarView()
                    } label: {
                        Label("Calendar & weight", systemImage: "calendar")
                    }
                }

                Section {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("Profile")
            .onChange(of: selectedPhoto) { _, newItem in
                loadPhoto(from: newItem)
            }
        }
    }

    @ViewBuilder
    private var profileImage: some View {
        Group {
            if let image = userStore.profileImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 150, height: 150)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 3))
        .shadow(radius: 8)
    }

    private func loadPhoto(from item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { return }
            await MainActor.run {
                userStore.updateProfileImage(image)
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(UserStore())
        .environmentObject(HistoryStore())
        .environmentObject(WeightStore())
        .environmentObject(SettingsStore.shared)
}
