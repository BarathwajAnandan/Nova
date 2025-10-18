//
//  SettingsView.swift
//  nova
//
//  Manage Gemini API key stored in Keychain.
//

import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = ""
    @State private var status: String = ""

    var body: some View {
        Form {
            Section(header: Text("Google Gemini")) {
                SecureField("API Key", text: $apiKey)
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("Save") { save() }
                        .keyboardShortcut(.defaultAction)
                    Button("Delete", role: .destructive) { deleteKey() }
                    Spacer()
                    Text(status).foregroundStyle(.secondary)
                }
            }
            Section(footer: Text("Your key is stored securely using Apple Keychain and is only used for requests to Google Gemini.").font(.footnote)) { EmptyView() }
        }
        .padding(16)
        .onAppear { load() }
        .frame(width: 520)
    }

    private func load() {
        apiKey = (try? KeychainService.shared.readApiKey()) ?? ""
        status = apiKey.isEmpty ? "No key saved" : "Key present"
    }

    private func save() {
        do {
            try KeychainService.shared.saveApiKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
            status = "Saved"
        } catch {
            status = "Error: \(error.localizedDescription)"
        }
    }

    private func deleteKey() {
        do {
            try KeychainService.shared.deleteApiKey()
            apiKey = ""
            status = "Deleted"
        } catch {
            status = "Error: \(error.localizedDescription)"
        }
    }
}

#Preview { SettingsView() }


