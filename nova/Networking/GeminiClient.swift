//
//  BackendClient.swift
//  nova
//
//  Non-streaming client for the custom Nova backend.
//

import Foundation

/// Simple DTO for backend responses.
private struct BackendResponse: Decodable {
    struct Content: Decodable {
        struct Part: Decodable { let text: String? }
        let role: String
        let parts: [Part]
    }
    let content: Content

    var text: String { content.parts.compactMap { $0.text }.joined() }
}

final class BackendClient {
    private static let baseURL = URL(string: "http://10.0.0.138:8000")!
    private static let appName = "multi_tool_agent"
    private static let userId = "u"
    private static let sessionId: String = UUID().uuidString
    private let sessionCreationTask: Task<Void, Error>
    private let decoder = JSONDecoder()

    init() {
        sessionCreationTask = Task {
            try await BackendClient.createSessionIfNeeded(
                baseURL: BackendClient.baseURL,
                appName: BackendClient.appName,
                userId: BackendClient.userId,
                sessionId: BackendClient.sessionId
            )
        }
    }

    private static func createSessionIfNeeded(baseURL: URL, appName: String, userId: String, sessionId: String) async throws {
        struct SessionPayload: Encodable {
            struct State: Encodable {
                let key1: String
                let key2: Int
            }
            let state: State
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("apps/\(appName)/users/\(userId)/sessions/\(sessionId)"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload = SessionPayload(state: .init(key1: "value1", key2: 42))
        request.httpBody = try JSONEncoder().encode(payload)
        request.timeoutInterval = 60

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return }
        switch http.statusCode {
        case 200..<300, 409:
            return
        default:
            throw NSError(domain: "BackendClient", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "Failed to create session (status: \(http.statusCode))"])
        }
    }

    func sendMessage(text: String, inlineImageData: Data?, mimeType: String?, hiddenContext: String?) async throws -> String {
        _ = try await sessionCreationTask.value

        struct InlineData: Encodable {
            let mimeType: String
            let data: String
        }
        struct Part: Encodable {
            var text: String?
            var inlineData: InlineData?
        }
        struct NewMessage: Encodable {
            let role: String
            let parts: [Part]
        }
        struct Payload: Encodable {
            let appName: String
            let userId: String
            let sessionId: String
            let newMessage: NewMessage
            let streaming: Bool
        }

        var parts: [Part] = []
        parts.append(Part(text: text, inlineData: nil))
        if let ctx = hiddenContext, ctx.isEmpty == false {
            parts.append(Part(text: "Selection context:\n" + ctx, inlineData: nil))
        }
        if let data = inlineImageData, let type = mimeType {
            parts.append(Part(text: nil, inlineData: InlineData(mimeType: type, data: data.base64EncodedString())))
        }

        let payload = Payload(
            appName: BackendClient.appName,
            userId: BackendClient.userId,
            sessionId: BackendClient.sessionId,
            newMessage: NewMessage(role: "user", parts: parts),
            streaming: false
        )

        var request = URLRequest(url: BackendClient.baseURL.appendingPathComponent("run_sse"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 60
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NSError(domain: "BackendClient", code: (response as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: "Server error"])
        }

        let raw = String(data: data, encoding: .utf8) ?? ""
        let trimmed = raw.hasPrefix("data: ") ? String(raw.dropFirst(6)) : raw
        guard let jsonData = trimmed.data(using: .utf8) else {
            throw NSError(domain: "BackendClient", code: -2, userInfo: [NSLocalizedDescriptionKey: "Invalid response encoding"])
        }

        let decoded = try decoder.decode(BackendResponse.self, from: jsonData)
        return decoded.text
    }
}


