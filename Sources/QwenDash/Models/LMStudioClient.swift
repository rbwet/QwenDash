import Foundation

/// Minimal streaming client for LM Studio's OpenAI-compatible endpoint.
/// LM Studio serves at http://localhost:1234/v1 by default when the local server is enabled.
actor LMStudioClient {
    struct Config {
        var baseURL: URL = URL(string: "http://localhost:1234/v1")!
        var model: String = "local-model"          // overridden by /v1/models if available
        var temperature: Double = 0.7
        var maxTokens: Int = 2048
    }

    enum ClientError: LocalizedError {
        case badResponse(Int, String)
        case notConnected
        case decoding(String)

        var errorDescription: String? {
            switch self {
            case .badResponse(let code, let body):
                return "LM Studio returned HTTP \(code): \(body.prefix(200))"
            case .notConnected:
                return "Can't reach LM Studio at localhost:1234. Is the local server running?"
            case .decoding(let msg):
                return "Stream decode error: \(msg)"
            }
        }
    }

    var config: Config

    init(config: Config = .init()) {
        self.config = config
    }

    func updateConfig(_ update: (inout Config) -> Void) {
        update(&config)
    }

    // MARK: - Models discovery

    /// Returns the id of the first currently-loaded model, or nil if the server
    /// isn't reachable.
    func fetchFirstModelId() async -> String? {
        let url = config.baseURL.appendingPathComponent("models")
        var req = URLRequest(url: url)
        req.timeoutInterval = 3
        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let arr = json["data"] as? [[String: Any]],
                  let first = arr.first,
                  let id = first["id"] as? String
            else { return nil }
            return id
        } catch {
            return nil
        }
    }

    // MARK: - Streaming chat

    /// Streams assistant content tokens for the given message history.
    /// Yields one string per SSE `delta.content` event.
    func streamChat(messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        let cfg = self.config
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = cfg.baseURL.appendingPathComponent("chat/completions")
                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    let body: [String: Any] = [
                        "model": cfg.model,
                        "stream": true,
                        "temperature": cfg.temperature,
                        "max_tokens": cfg.maxTokens,
                        "messages": messages.map {
                            ["role": $0.role.rawValue, "content": $0.content]
                        }
                    ]
                    req.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, resp) = try await URLSession.shared.bytes(for: req)

                    guard let http = resp as? HTTPURLResponse else {
                        throw ClientError.badResponse(-1, "no http response")
                    }
                    if http.statusCode != 200 {
                        var collected = Data()
                        for try await byte in bytes { collected.append(byte) }
                        let body = String(data: collected, encoding: .utf8) ?? ""
                        throw ClientError.badResponse(http.statusCode, body)
                    }

                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        guard line.hasPrefix("data:") else { continue }
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload.isEmpty { continue }
                        if payload == "[DONE]" { break }

                        guard let data = payload.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let choices = obj["choices"] as? [[String: Any]],
                              let first = choices.first
                        else { continue }

                        // OpenAI streams chunks in either "delta":{"content":...}
                        // or a final message — both are handled.
                        if let delta = first["delta"] as? [String: Any],
                           let content = delta["content"] as? String,
                           !content.isEmpty {
                            continuation.yield(content)
                        } else if let message = first["message"] as? [String: Any],
                                  let content = message["content"] as? String,
                                  !content.isEmpty {
                            continuation.yield(content)
                        }
                    }
                    continuation.finish()
                } catch let urlErr as URLError where urlErr.code == .cannotConnectToHost
                                                    || urlErr.code == .cannotFindHost
                                                    || urlErr.code == .networkConnectionLost {
                    continuation.finish(throwing: ClientError.notConnected)
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
