import Foundation

enum AIError: LocalizedError {
    case missingKey(AIProvider)
    case badResponse
    case http(Int, String)
    case empty

    var errorDescription: String? {
        switch self {
        case .missingKey(let p):
            return "\(p.displayName) API 키가 설정되지 않았습니다. 설정에서 입력하세요."
        case .badResponse:
            return "서버 응답을 해석할 수 없습니다."
        case .http(let code, let body):
            return "요청 실패 (HTTP \(code))\n\(body)"
        case .empty:
            return "응답이 비어 있습니다."
        }
    }
}

/// Anthropic / OpenAI 비전 + 멀티턴 대화 API 호출.
struct AIClient {

    /// 대화 메시지 전체를 보내고 마지막 응답 텍스트를 받습니다(후속 질문 지원).
    static func complete(model: AIModel, apiKey: String, messages: [ChatMessage]) async throws -> String {
        guard !apiKey.isEmpty else { throw AIError.missingKey(model.provider) }
        switch model.provider {
        case .anthropic:
            return try await callAnthropic(modelID: model.id, apiKey: apiKey, messages: messages)
        case .openai:
            return try await callOpenAI(modelID: model.id, apiKey: apiKey, messages: messages)
        }
    }

    // MARK: - Anthropic

    private static func callAnthropic(modelID: String, apiKey: String, messages: [ChatMessage]) async throws -> String {
        var apiMessages: [[String: Any]] = []
        for m in messages {
            var content: [[String: Any]] = []
            if let b64 = m.imageBase64 {
                content.append(["type": "image",
                                "source": ["type": "base64", "media_type": "image/png", "data": b64]])
            }
            if !m.text.isEmpty {
                content.append(["type": "text", "text": m.text])
            }
            apiMessages.append(["role": m.role.rawValue, "content": content])
        }

        let body: [String: Any] = [
            "model": modelID,
            "max_tokens": 4096,
            "messages": apiMessages
        ]

        var req = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        req.httpMethod = "POST"
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "content-type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: req)
        try checkStatus(response, data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw AIError.badResponse
        }
        let text = content.compactMap { block -> String? in
            (block["type"] as? String) == "text" ? block["text"] as? String : nil
        }.joined(separator: "\n")

        guard !text.isEmpty else { throw AIError.empty }
        return text
    }

    // MARK: - OpenAI

    private static func callOpenAI(modelID: String, apiKey: String, messages: [ChatMessage]) async throws -> String {
        var apiMessages: [[String: Any]] = []
        for m in messages {
            if let b64 = m.imageBase64 {
                var content: [[String: Any]] = []
                if !m.text.isEmpty { content.append(["type": "text", "text": m.text]) }
                content.append(["type": "image_url",
                                "image_url": ["url": "data:image/png;base64,\(b64)"]])
                apiMessages.append(["role": m.role.rawValue, "content": content])
            } else {
                apiMessages.append(["role": m.role.rawValue, "content": m.text])
            }
        }

        let body: [String: Any] = [
            "model": modelID,
            "messages": apiMessages
        ]

        var req = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 120

        let (data, response) = try await URLSession.shared.data(for: req)
        try checkStatus(response, data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let first = choices.first,
              let message = first["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIError.badResponse
        }
        guard !content.isEmpty else { throw AIError.empty }
        return content
    }

    // MARK: - Helpers

    private static func checkStatus(_ response: URLResponse, _ data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AIError.http(http.statusCode, body)
        }
    }
}
