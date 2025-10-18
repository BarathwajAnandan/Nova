//
//  ChatViewModel.swift
//  nova
//
//  Orchestrates chat state and streaming.
//

import Foundation

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var input: String = ""
    @Published var isStreaming: Bool = false
    @Published var errorMessage: String?

    private let client = GeminiClient()

    init() {
        // Optional: seed a greeting
        messages = []
    }

    func loadApiKeyExists() -> Bool {
        (try? KeychainService.shared.readApiKey())?.isEmpty == false
    }

    func clearChat() {
        messages.removeAll()
        errorMessage = nil
    }

    func send() async {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, isStreaming == false else { return }
        errorMessage = nil

        let userMessage = Message(role: .user, text: trimmed)
        messages.append(userMessage)
        input = ""

        let assistant = Message(role: .model, text: "")
        messages.append(assistant)
        let assistantIndex = messages.count - 1

        isStreaming = true
        do {
            let stream = try await client.streamResponse(history: messages)
            for await delta in stream {
                messages[assistantIndex].text += delta
            }
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
        isStreaming = false
    }
}


