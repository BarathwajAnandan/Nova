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
    @State private var startCollapsed: Bool = true
    @State private var hideIconWhenExpanded: Bool = false

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
            Section(header: Text("Nova UI")) {
                Toggle("Start collapsed", isOn: $startCollapsed)
                Toggle("Hide icon while window is open", isOn: $hideIconWhenExpanded)
                HStack {
                    Button("Apply Now") { applyUiSettings() }
                    Spacer()
                }
            }
            Section(footer: Text("Your key is stored securely using Apple Keychain and is only used for requests to Google Gemini.").font(.footnote)) { EmptyView() }
        }
        .padding(16)
        .onAppear { load(); loadUiSettings() }
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

    private func loadUiSettings() {
        let defaults = UserDefaults.standard
        startCollapsed = (defaults.object(forKey: "StartCollapsed") as? Bool) ?? true
        hideIconWhenExpanded = defaults.bool(forKey: "HideIconWhenExpanded")
    }

    private func applyUiSettings() {
        let defaults = UserDefaults.standard
        defaults.set(startCollapsed, forKey: "StartCollapsed")
        defaults.set(hideIconWhenExpanded, forKey: "HideIconWhenExpanded")
        if startCollapsed {
            AppVisibilityController.shared.collapse()
        } else {
            AppVisibilityController.shared.expand()
        }
    }
}

#Preview { SettingsView() }


