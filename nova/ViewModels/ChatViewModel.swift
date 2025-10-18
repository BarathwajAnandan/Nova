//
//  ChatViewModel.swift
//  nova
//
//  Orchestrates chat state and streaming.
//

import Foundation
import AppKit

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var input: String = ""
    @Published var isStreaming: Bool = false
    @Published var errorMessage: String?
    @Published var autoCaptureEnabled: Bool = false
    @Published var recognizedApp: RecognizedApp?
    @Published var pendingContext: String?
    @Published var screenshot: NSImage?

    private let client = GeminiClient()
    private let capturer = AccessibilityCaptureService()

    init() {
        // Optional: seed a greeting
        messages = []

        capturer.onCapture = { [weak self] text in
            guard let self else { return }
            print("Captured context (\(text.count) chars)\n\(text)\n---")
            // Replace any existing context with the most recent capture
            self.pendingContext = String(text.prefix(10000))
        }

        capturer.onRecognizedAppChange = { [weak self] app in
            guard let self else { return }
            self.recognizedApp = app
        }

        capturer.onScreenshot = { [weak self] image in
            self?.screenshot = image
        }
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
            let hidden = pendingContext
            pendingContext = nil
            let stream = try await client.streamResponse(history: messages, hiddenContext: hidden)
            for await delta in stream {
                messages[assistantIndex].text += delta
            }
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
        isStreaming = false
    }

    func setAutoCapture(_ enabled: Bool) {
        autoCaptureEnabled = enabled
        if enabled {
            let started = capturer.start()
            if started == false {
                errorMessage = "Accessibility permission required. Enable Nova in System Settings → Privacy & Security → Accessibility."
            }
        } else {
            capturer.stop()
        }
    }

    func captureSelection() {
        // Try last non-self app first (so switching back to Nova doesn't clear context)
        if let text = capturer.captureSelectedTextFromLastAppOnce(), text.isEmpty == false {
            pendingContext = text
            print("Selected context (\(text.count) chars)\n\(text)\n---")
        } else if let text = capturer.captureSelectedTextOnce(), text.isEmpty == false {
            pendingContext = text
            print("Selected context (\(text.count) chars)\n\(text)\n---")
        } else {
            errorMessage = "No selected text found in the frontmost app."
        }
    }

    func clearPendingContext() {
        pendingContext = nil
    }
}


