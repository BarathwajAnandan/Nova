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

    func streamResponse(history: [Message], hiddenContext: String?) async throws -> AsyncStream<String> {
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

        let body = try makeBody(history: history, hiddenContext: hiddenContext)
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

    // MARK: - Single response with inline image (non-stream)
    private struct GenerateResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable { let text: String? }
                let parts: [Part]
            }
            let content: Content
        }
        let candidates: [Candidate]

        var text: String {
            guard let first = candidates.first else { return "" }
            return first.content.parts.compactMap { $0.text }.joined()
        }
    }

    func generateOnce(history: [Message], hiddenContext: String?, imageData: Data, mimeType: String) async throws -> String {
        struct InlineData: Encodable {
            let mimeType: String
            let data: String
            enum CodingKeys: String, CodingKey { case mimeType = "mime_type", data }
        }
        struct Part: Encodable {
            var text: String?
            var inlineData: InlineData?
            enum CodingKeys: String, CodingKey { case text; case inlineData = "inline_data" }
        }
        struct Content: Encodable { let role: String; let parts: [Part] }
        struct Payload: Encodable { let contents: [Content] }

        guard let apiKey = try KeychainService.shared.readApiKey(), apiKey.isEmpty == false else {
            throw NSError(domain: "GeminiClient", code: 401, userInfo: [NSLocalizedDescriptionKey: "API key not set. Open Settings to add your key."])
        }

        // Identify the last user message to attach the image to
        let lastUserIndex: Int? = {
            for (idx, msg) in history.enumerated().reversed() {
                if msg.role == .user { return idx }
            }
            return nil
        }()

        var contents: [Content] = []
        for (idx, msg) in history.enumerated() {
            var parts: [Part] = []
            if idx == lastUserIndex {
                // 1) inline image
                let b64 = imageData.base64EncodedString()
                parts.append(Part(text: nil, inlineData: InlineData(mimeType: mimeType, data: b64)))
                // 2) optional hidden context
                if let ctx = hiddenContext, ctx.isEmpty == false {
                    parts.append(Part(text: "Selection context:\n" + ctx, inlineData: nil))
                }
                // 3) user's text
                parts.append(Part(text: msg.text, inlineData: nil))
            } else {
                parts.append(Part(text: msg.text, inlineData: nil))
            }
            contents.append(Content(role: msg.role == .user ? "user" : "model", parts: parts))
        }

        var url = base.appendingPathComponent("models/\(model):generateContent")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 60

        let body = try JSONEncoder().encode(Payload(contents: contents))
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "GeminiClient", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Server error"])
        }
        let decoded = try JSONDecoder().decode(GenerateResponse.self, from: data)
        return decoded.text
    }

    private func makeBody(history: [Message], hiddenContext: String?) throws -> Data {
        struct Part: Encodable { let text: String }
        struct Content: Encodable { let role: String; let parts: [Part] }
        struct Payload: Encodable { let contents: [Content] }

        var contents: [Content] = history.map { msg in
            Content(role: msg.role == .user ? "user" : "model", parts: [Part(text: msg.text)])
        }
        if let ctx = hiddenContext, ctx.isEmpty == false {
            // Insert context just before the last message if it is user, otherwise append.
            let contextContent = Content(role: "user", parts: [Part(text: "Selection context:\n" + ctx)])
            if let lastIndex = contents.indices.last, contents[lastIndex].role == "user" {
                contents.insert(contextContent, at: lastIndex)
            } else {
                contents.append(contextContent)
            }
        }
        let payload = Payload(contents: contents)
        return try JSONEncoder().encode(payload)
    }
}


