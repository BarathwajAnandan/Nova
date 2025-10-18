//
//  ChatViewModel.swift
//  nova
//
//  Orchestrates chat state and streaming.
//

import Foundation
import AppKit
import Speech
import AVFoundation

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
    @Published var isListening: Bool = false
    @Published var partialTranscript: String?

    private let client = GeminiClient()
    private let capturer = AccessibilityCaptureService()
    private let speech = SpeechRecognitionService()

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
            guard let self else { return }
            self.screenshot = image
            DispatchQueue.global(qos: .utility).async {
                if let url = self.saveScreenshotToDisk(image: image) {
                    print("Screenshot saved at: \(url.path)")
                } else {
                    print("Failed to save screenshot to disk")
                }
            }
        }
        speech.delegate = self
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
            if let image = screenshot, let jpeg = toJPEGData(image) {
                // Clear screenshot so it isn't reused unintentionally
                screenshot = nil
                let reply = try await client.generateOnce(history: messages, hiddenContext: hidden, imageData: jpeg, mimeType: "image/jpeg")
                messages[assistantIndex].text = reply
            } else {
                let stream = try await client.streamResponse(history: messages, hiddenContext: hidden)
                for await delta in stream {
                    messages[assistantIndex].text += delta
                }
            }
        } catch {
            errorMessage = (error as NSError).localizedDescription
        }
        isStreaming = false
    }

    func sendTranscribedText(_ text: String) async {
        guard text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false, isStreaming == false else { return }
        input = text
        await send()
    }

    func toggleMic() {
        if isListening { stopListening(commitPartial: true, send: false) } else { startListening() }
    }

    private func startListening() {
        speech.requestAuthorization { [weak self] granted in
            guard let self else { return }
            if granted == false {
                self.errorMessage = "Microphone/Speech permission required in System Settings."
                return
            }
            do {
                try self.speech.start()
                self.isListening = true
            } catch {
                self.errorMessage = (error as NSError).localizedDescription
            }
        }
    }

    private func stopListening(commitPartial: Bool = false, send: Bool = false) {
        speech.stop()
        if commitPartial {
            let text = partialTranscript?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if text.isEmpty == false {
                if send {
                    Task { await sendTranscribedText(text) }
                } else {
                    input = text
                }
            }
        }
        isListening = false
        partialTranscript = nil
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

    // MARK: - Screenshot saving
    private func saveScreenshotToDisk(image: NSImage) -> URL? {
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        guard let png = bitmap.representation(using: .png, properties: [:]) else { return nil }

        let fm = FileManager.default
        let picturesDir = (fm.urls(for: .picturesDirectory, in: .userDomainMask).first ?? fm.temporaryDirectory)
        let targetDir = picturesDir.appendingPathComponent("Nova", isDirectory: true)
        do {
            try fm.createDirectory(at: targetDir, withIntermediateDirectories: true)
        } catch {
            // Fallback to temporary directory if we cannot create Pictures/Nova
            let tempURL = fm.temporaryDirectory.appendingPathComponent("nova_screenshot_\(Int(Date().timeIntervalSince1970)).png")
            do { try png.write(to: tempURL) } catch { return nil }
            return tempURL
        }

        let filename = "screenshot_\(Int(Date().timeIntervalSince1970)).png"
        let fileURL = targetDir.appendingPathComponent(filename)
        do {
            try png.write(to: fileURL)
            return fileURL
        } catch {
            return nil
        }
    }

    // MARK: - Image encoding
    private func toJPEGData(_ image: NSImage, quality: Double = 0.9) -> Data? {
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: quality])
    }
}

// MARK: - SpeechRecognitionServiceDelegate
extension ChatViewModel: SpeechRecognitionServiceDelegate {
    func speechService(_ svc: SpeechRecognitionService, didUpdatePartial text: String) {
        partialTranscript = text
    }

    func speechService(_ svc: SpeechRecognitionService, didFinishWith text: String) {
        isListening = false
        partialTranscript = nil
        Task { await sendTranscribedText(text) }
    }

    func speechService(_ svc: SpeechRecognitionService, didFail error: Error) {
        isListening = false
        partialTranscript = nil
        errorMessage = (error as NSError).localizedDescription
    }

    func speechServiceDidChangeState(_ svc: SpeechRecognitionService, isRunning: Bool) {
        isListening = isRunning
    }
}


