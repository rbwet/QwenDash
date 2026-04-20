import Foundation

/// One streaming delta from the server: a chunk of text plus (optionally) the
/// per-token confidence data OpenAI-compatible endpoints emit when `logprobs`
/// is requested. `confidence` is already converted from a natural log-prob
/// into a 0...1 probability for the chosen token.
struct TokenDelta {
    let content: String
    let confidence: Double?
    let alternatives: [(token: String, probability: Double)]
}

/// Minimal streaming client for LM Studio's OpenAI-compatible endpoint.
/// LM Studio serves at http://localhost:1234/v1 by default when the local server is enabled.
actor LMStudioClient {
    struct Config {
        var baseURL: URL = URL(string: "http://localhost:1234/v1")!
        var model: String = "local-model"          // overridden by /v1/models if available
        var temperature: Double = 0.7
        var maxTokens: Int = 2048
        /// Ask the server for per-token log-probabilities so we can drive the
        /// synapse map with the model's own confidence signal.
        var requestLogprobs: Bool = true
        var topLogprobs: Int = 5
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

    /// Streams assistant deltas for the given message history. Each yielded
    /// value bundles the text chunk with the model's own confidence data
    /// (when the backend supports `logprobs`).
    func streamChat(messages: [ChatMessage]) -> AsyncThrowingStream<TokenDelta, Error> {
        let cfg = self.config
        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let url = cfg.baseURL.appendingPathComponent("chat/completions")
                    var req = URLRequest(url: url)
                    req.httpMethod = "POST"
                    req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    req.setValue("text/event-stream", forHTTPHeaderField: "Accept")

                    var body: [String: Any] = [
                        "model": cfg.model,
                        "stream": true,
                        "temperature": cfg.temperature,
                        "max_tokens": cfg.maxTokens,
                        "messages": messages.map {
                            ["role": $0.role.rawValue, "content": $0.content]
                        }
                    ]
                    if cfg.requestLogprobs {
                        body["logprobs"] = true
                        body["top_logprobs"] = cfg.topLogprobs
                    }
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

                        // Pull text out of either the streaming `delta` or the
                        // terminal `message` shape — both are valid OpenAI forms.
                        let content: String
                        if let delta = first["delta"] as? [String: Any],
                           let c = delta["content"] as? String, !c.isEmpty {
                            content = c
                        } else if let message = first["message"] as? [String: Any],
                                  let c = message["content"] as? String, !c.isEmpty {
                            content = c
                        } else {
                            continue
                        }

                        let (confidence, alts) = Self.parseLogprobs(first)
                        continuation.yield(TokenDelta(
                            content: content,
                            confidence: confidence,
                            alternatives: alts
                        ))
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

    // MARK: - Logprob parsing

    /// A delta may contain 0, 1, or many tokens' worth of logprob data. We
    /// average their probabilities into a single confidence number (weighting
    /// each token equally) and surface the alternatives for the LAST token —
    /// the one most relevant to the most-recent node we're about to draw.
    private static func parseLogprobs(
        _ choice: [String: Any]
    ) -> (Double?, [(String, Double)]) {
        guard let lp = choice["logprobs"] as? [String: Any],
              let content = lp["content"] as? [[String: Any]],
              !content.isEmpty
        else { return (nil, []) }

        var probs: [Double] = []
        for entry in content {
            if let v = entry["logprob"] as? Double {
                probs.append(exp(v))
            }
        }
        let avg: Double? = probs.isEmpty
            ? nil
            : probs.reduce(0, +) / Double(probs.count)

        var alts: [(String, Double)] = []
        if let last = content.last,
           let top = last["top_logprobs"] as? [[String: Any]] {
            for t in top {
                if let tok = t["token"] as? String,
                   let v = t["logprob"] as? Double {
                    alts.append((tok, exp(v)))
                }
            }
        }
        return (avg, alts)
    }
}
