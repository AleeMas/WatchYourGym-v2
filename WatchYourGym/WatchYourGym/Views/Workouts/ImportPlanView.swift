//
//  ImportPlanView.swift
//  WatchYourGym
//
//  Lets the user import a workout from a JSON file produced by an AI
//  starting from a photo of a paper plan.
//

import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ImportPlanView: View {

    /// Called with the parsed workout. The caller opens the editor for review.
    let onImported: (Workout) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var isPickingFile = false
    @State private var errorMessage: String?
    @State private var didCopyPrompt = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    filePicker
                    promptCard
                }
                .padding()
            }
            .navigationTitle("Import plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .fileImporter(
                isPresented: $isPickingFile,
                allowedContentTypes: [.json, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .alert(
                "Import failed",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - File picker

    private var filePicker: some View {
        VStack(spacing: 12) {
            Button {
                isPickingFile = true
            } label: {
                VStack(spacing: 10) {
                    Image(systemName: "plus")
                        .font(.system(size: 44, weight: .semibold))
                    Text("Choose a JSON file")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            Color.accentColor,
                            style: StrokeStyle(lineWidth: 2, dash: [7])
                        )
                )
            }
            .accessibilityLabel("Import a JSON file")

            Text("The file must contain one workout.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - AI prompt

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Don't have a JSON yet?", systemImage: "sparkles")
                .font(.headline)

            Text("Take a photo of your training plan, send it to an AI assistant together with this prompt, then save its answer as a .json file.")
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            Text(WorkoutImportPrompt.text)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Color(.systemBackground).opacity(0.6), in: RoundedRectangle(cornerRadius: 10))

            Button {
                copyPrompt()
            } label: {
                Label(
                    didCopyPrompt ? "Copied!" : "Copy prompt",
                    systemImage: didCopyPrompt ? "checkmark" : "doc.on.doc"
                )
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 10))
                .foregroundStyle(.white)
            }
        }
        .padding(16)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func copyPrompt() {
        UIPasteboard.general.string = WorkoutImportPrompt.text
        withAnimation { didCopyPrompt = true }
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { didCopyPrompt = false }
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            errorMessage = error.localizedDescription

        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                let workout = try WorkoutImporter.importWorkout(from: url)
                onImported(workout)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ImportPlanView { _ in }
}
