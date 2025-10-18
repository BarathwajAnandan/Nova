//
//  GeminiClient.swift
//  nova
//
//  Streaming client for Google's Gemini API using SSE.
//

import Foundation

struct GeminiChunk: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable { let text: String? }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]

    var text: String { candidates.first?.content.parts.first?.text ?? "" }
}

final class GeminiClient {
    private let model = "gemini-2.5-flash"
    private let base = URL(string: "https://generativelanguage.googleapis.com/v1beta/")!

    func streamResponse(history: [Message]) async throws -> AsyncStream<String> {
        guard let apiKey = try KeychainService.shared.readApiKey(), apiKey.isEmpty == false else {
            throw NSError(domain: "GeminiClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key not set. Open Settings to add your key."])
        }

        var url = base.appendingPathComponent("models/\(model):streamGenerateContent")
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "alt", value: "sse")]
        url = components.url!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60

        let body = try makeBody(history: history)
        request.httpBody = body

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "GeminiClient", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Server error"])
        }

        return AsyncStream { continuation in
            Task {
                do {
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = line.dropFirst(6)
                        if payload == "[DONE]" { break }
                        if let data = payload.data(using: .utf8) {
                            if let chunk = try? JSONDecoder().decode(GeminiChunk.self, from: data) {
                                let text = chunk.text
                                if text.isEmpty == false {
                                    continuation.yield(text)
                                }
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish()
                }
            }
        }
    }

    private func makeBody(history: [Message]) throws -> Data {
        struct Part: Encodable { let text: String }
        struct Content: Encodable { let role: String; let parts: [Part] }
        struct Payload: Encodable { let contents: [Content] }

        let contents: [Content] = history.map { msg in
            Content(role: msg.role == .user ? "user" : "model", parts: [Part(text: msg.text)])
        }
        let payload = Payload(contents: contents)
        return try JSONEncoder().encode(payload)
    }
}


