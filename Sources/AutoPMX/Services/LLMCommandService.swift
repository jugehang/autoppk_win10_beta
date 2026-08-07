import Foundation

struct DatasetProfile {
    let route: String
    let hasIVBolus: Bool
    let hasIVInfusion: Bool
    let hasOral: Bool
    let doseLevels: [Double]
    let subjectCount: Int
    let observationCount: Int
    let timeRangeDays: (Double, Double)
    let hasWT: Bool
    let hasAGE: Bool
    let hasSEX: Bool
    let hasSTUDY: Bool
    let hasBQL: Bool
    // Data-driven initial value guidance
    let typicalDV: Double?
    let dvRange: (Double, Double)?
    // Detailed covariate statistics
    let wtRange: (Double, Double)?     // (min, max) of WT
    let wtMedian: Double?
    let wtMean: Double?
    let ageRange: (Double, Double)?    // (min, max) of AGE
    let ageMedian: Double?
    let ageMean: Double?
    let sexLevels: [Int]               // unique SEX values found
    let studyLevels: [Int]             // unique STUDY values found
    let additionalCovariates: [String] // other covariate columns present (DOSE, ROUTE, ADA, ...)

    var summary: String {
        var lines = ["Dataset Profile:"]
        lines.append("  Administration route: \(route)")
        if !doseLevels.isEmpty { lines.append("  Dose groups: \(doseLevels.map { String($0) }.joined(separator: ", ")) (\(doseLevels.count) levels)") }
        lines.append("  Subjects: \(subjectCount), Observations: \(observationCount)")
        // TIME unit: PK datasets use hours as standard. Display raw TIME values as hours.
        lines.append("  Time span: \(String(format: "%.1f", timeRangeDays.0))–\(String(format: "%.1f", timeRangeDays.1)) h")
        lines.append("  DV range: \(dvRange.map { "\(String(format: "%.1f", $0.0))–\(String(format: "%.1f", $0.1))" } ?? "N/A") (concentration range)")
        lines.append("")

        lines.append("  ━━━ Available CoVariates ━━━")

        // WT (continuous)
        if hasWT {
            lines.append("  WT: \(wtRange.map { "\(String(format: "%.0f", $0.0))–\(String(format: "%.0f", $0.1)) kg" } ?? "N/A"), mean = \(wtMean.map { String(format: "%.4f", $0) } ?? "N/A"), median = \(wtMedian.map { "\(String(format: "%.0f", $0)) kg" } ?? "N/A")")
        }

        // AGE (continuous)
        if hasAGE {
            lines.append("  AGE: \(ageRange.map { "\(String(format: "%.0f", $0.0))–\(String(format: "%.0f", $0.1)) yr" } ?? "N/A"), mean = \(ageMean.map { String(format: "%.4f", $0) } ?? "N/A"), median = \(ageMedian.map { "\(String(format: "%.0f", $0)) yr" } ?? "N/A")")
        }

        // SEX (categorical)
        if hasSEX {
            let counts = sexLevels.sorted().map { "\($0)" }.joined(separator: ", ")
            lines.append("  SEX: \(sexLevels.count) levels (\(counts))")
        }

        // STUDY (categorical)
        if hasSTUDY {
            let counts = studyLevels.sorted().map { "study \($0)" }.joined(separator: ", ")
            lines.append("  STUDY: \(studyLevels.count) levels (\(counts))")
        }
        if !additionalCovariates.isEmpty {
            lines.append("  Additional covariates: \(additionalCovariates.joined(separator: ", "))")
        }

        if hasBQL { lines.append("  BQL: flag present in dataset") }
        return lines.joined(separator: "\n")
    }
}

struct NCAInitialEstimates {
    let clearanceLPerHour: Double?
    let volumeLiters: Double?
    let terminalHalfLifeHours: Double?
    let aucInfMedian: Double?
    let subjectCount: Int

    var summary: String {
        if subjectCount == 0 {
            return "NCA-based initial estimates: unavailable (check dataset columns)"
        }
        var lines = ["NCA-based initial estimates (median):"]
        if let auc = aucInfMedian {
            lines.append("  AUCinf = \(String(format: "%.3f", auc))")
        }
        if let cl = clearanceLPerHour {
            lines.append("  CL = \(String(format: "%.4g", cl)) L/h")
        }
        if let v = volumeLiters {
            lines.append("  Vz = \(String(format: "%.4g", v)) L")
        }
        if let hl = terminalHalfLifeHours {
            lines.append("  t1/2 = \(String(format: "%.1f", hl)) h")
        }
        if subjectCount > 0 {
            lines.append("  subjects with valid NCA = \(subjectCount)")
        }
        return lines.joined(separator: "\n")
    }
}

struct LLMCommandService {
    // MARK: - Token usage tracking
    struct TokenUsage {
        let input: Int
        let output: Int
        let cacheRead: Int
        let cacheWrite: Int

        init(input: Int, output: Int, cacheRead: Int = 0, cacheWrite: Int = 0) {
            self.input = input
            self.output = output
            self.cacheRead = cacheRead
            self.cacheWrite = cacheWrite
        }

        var total: Int { input + output }

        static let zero = TokenUsage(input: 0, output: 0)

        var description: String {
            if cacheRead > 0 || cacheWrite > 0 {
                return "in \(input) · out \(output) · cache r/w \(cacheRead)/\(cacheWrite)"
            }
            return "in \(input) · out \(output)"
        }
    }

    struct EndpointProbe {
        let baseURL: String
        let models: [String]
    }

    struct ModelsResponse: Decodable {
        struct Model: Decodable {
            let id: String
        }

        let data: [Model]
    }

    struct ChatRequest: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
        let temperature: Double
        // DeepSeek prefix-caching controls. Optional so non-DeepSeek OpenAI-compatible
        // endpoints simply ignore them (unknown fields).
        var prompt_cache: Bool? = nil
        var session_id: String? = nil
        var stream: Bool? = nil

        enum CodingKeys: String, CodingKey {
            case model, messages, temperature, prompt_cache, session_id, stream
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(model, forKey: .model)
            try c.encode(messages, forKey: .messages)
            try c.encode(temperature, forKey: .temperature)
            try c.encodeIfPresent(prompt_cache, forKey: .prompt_cache)
            try c.encodeIfPresent(session_id, forKey: .session_id)
            try c.encodeIfPresent(stream, forKey: .stream)
        }
    }

    struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String
            }

            let message: Message
        }

        struct Usage: Decodable {
            let prompt_tokens: Int
            let completion_tokens: Int
            let total_tokens: Int?
            // DeepSeek prefix-cache accounting (absent on other providers)
            let prompt_cache_hit_tokens: Int?
            let prompt_cache_creation_tokens: Int?

            enum CodingKeys: String, CodingKey {
                case prompt_tokens
                case completion_tokens
                case total_tokens
                case prompt_cache_hit_tokens
                case prompt_cache_creation_tokens
            }
        }

        let choices: [Choice]
        let usage: Usage?
    }

    struct ChatStreamChunk: Decodable {
        struct Delta: Decodable {
            let content: String?
            let reasoning_content: String?
        }

        struct Choice: Decodable {
            let delta: Delta
            let finish_reason: String?
        }

        struct Usage: Decodable {
            let prompt_tokens: Int?
            let completion_tokens: Int?
            let prompt_cache_hit_tokens: Int?
            let prompt_cache_creation_tokens: Int?

            enum CodingKeys: String, CodingKey {
                case prompt_tokens
                case completion_tokens
                case prompt_cache_hit_tokens
                case prompt_cache_creation_tokens
            }
        }

        let choices: [Choice]?
        let usage: Usage?
    }

    // MARK: - Anthropic API types

    struct AnthropicMessageRequest: Encodable {
        struct ContentBlock: Encodable {
            let type: String
            let text: String
        }

        let model: String
        let messages: [ContentBlock]
        let system: String?
        let max_tokens: Int
        let temperature: Double?
    }

    struct AnthropicMessageResponse: Decodable {
        struct ContentBlock: Decodable {
            let type: String
            let text: String
        }

        struct Usage: Decodable {
            let input_tokens: Int
            let output_tokens: Int
            let cache_read_input_tokens: Int?
            let cache_creation_input_tokens: Int?

            enum CodingKeys: String, CodingKey {
                case input_tokens
                case output_tokens
                case cache_read_input_tokens
                case cache_creation_input_tokens
            }
        }

        let content: [ContentBlock]
        let usage: Usage?
    }

    // MARK: - Gemini API types

    struct GeminiGenerateRequest: Encodable {
        struct Content: Encodable {
            struct Part: Encodable {
                let text: String
            }

            let role: String
            let parts: [Part]
        }

        struct SystemInstruction: Encodable {
            struct Part: Encodable {
                let text: String
            }

            let parts: [Part]
        }

        let contents: [Content]
        let systemInstruction: SystemInstruction?
        let generationConfig: GenerationConfig
    }

    struct GeminiGenerateResponse: Decodable {
        struct Candidate: Decodable {
            struct Content: Decodable {
                struct Part: Decodable {
                    let text: String
                }

                let parts: [Part]
            }

            let content: Content
        }

        struct UsageMetadata: Decodable {
            let promptTokenCount: Int?
            let candidatesTokenCount: Int?
            let totalTokenCount: Int?

            enum CodingKeys: String, CodingKey {
                case promptTokenCount
                case candidatesTokenCount
                case totalTokenCount
            }
        }

        let candidates: [Candidate]
        let usageMetadata: UsageMetadata?
    }

    struct GenerationConfig: Encodable {
        let temperature: Double?
        let maxOutputTokens: Int?

        enum CodingKeys: String, CodingKey {
            case temperature
            case maxOutputTokens = "maxOutputTokens"
        }
    }

    struct GeminiModelsResponse: Decodable {
        struct Model: Decodable {
            let name: String
            let displayName: String?
        }

        let models: [Model]
    }

    // MARK: - API Format dispatchers

    static func availableModels(baseURL: String, apiKey: String = "", apiFormat: APIFormat = .openAICompatible) async throws -> [String] {
        switch apiFormat {
        case .openAICompatible:
            return try await fetchOpenAIModels(baseURL: baseURL, apiKey: apiKey)
        case .anthropic:
            return AnthropicModels.list
        case .gemini:
            return try await fetchGeminiModels(baseURL: baseURL, apiKey: apiKey)
        case .codeBuddy:
            return LLMProviderProfile.codeBuddyModels
        }
    }

    static func detectEndpoint(preferredBaseURL: String, apiKey: String = "", apiFormat: APIFormat = .openAICompatible) async throws -> EndpointProbe {
        switch apiFormat {
        case .openAICompatible:
            return try await detectOpenAIEndpoint(preferredBaseURL: preferredBaseURL, apiKey: apiKey)
        case .anthropic:
            let trimmed = preferredBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            _ = try await sendAnthropicTestMessage(baseURL: trimmed, apiKey: apiKey)
            return EndpointProbe(baseURL: trimmed, models: AnthropicModels.list)
        case .gemini:
            let trimmed = preferredBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let models = try await fetchGeminiModels(baseURL: trimmed, apiKey: apiKey)
            return EndpointProbe(baseURL: trimmed, models: models)
        case .codeBuddy:
            let trimmed = preferredBaseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            _ = try await sendChat(
                baseURL: trimmed,
                model: "auto",
                messages: [.init(role: "user", content: "Hi")],
                temperature: 0,
                timeout: 20,
                apiKey: apiKey,
                apiFormat: .codeBuddy
            )
            return EndpointProbe(baseURL: trimmed, models: LLMProviderProfile.codeBuddyModels)
        }
    }

    static func testConnection(baseURL: String, apiKey: String, apiFormat: APIFormat) async throws -> EndpointProbe {
        try await detectEndpoint(preferredBaseURL: baseURL, apiKey: apiKey, apiFormat: apiFormat)
    }

    // MARK: - OpenAI-compatible methods

    static func fetchOpenAIModels(baseURL: String, apiKey: String = "") async throws -> [String] {
        let url = try endpointURL(baseURL: baseURL, path: "models")
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        applyAuthorization(apiKey, to: &request)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NSError(domain: "LLMCommandService", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "LLM models request failed with HTTP \(http.statusCode)"
            ])
        }

        // Try standard OpenAI format first: {"data": [{"id": "model-name"}, ...]}
        if let decoded = try? JSONDecoder().decode(ModelsResponse.self, from: data) {
            return decoded.data.map(\.id).sorted()
        }
        // Try cc-switch / custom format: {"models": [{"display_name": "...", "slug": "..."}, ...]}
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let models = json["models"] as? [[String: Any]] {
            return models.compactMap { ($0["display_name"] as? String) ?? ($0["slug"] as? String) ?? ($0["id"] as? String) }.sorted()
        }
        return []
    }

    static func detectOpenAIEndpoint(preferredBaseURL: String, apiKey: String = "") async throws -> EndpointProbe {
        var candidates = [
            preferredBaseURL,
            "http://127.0.0.1:11434/v1",  // Ollama (check first — hosts MLX models)
            "http://localhost:11434/v1",
            "http://127.0.0.1:1234/v1",   // LM Studio
            "http://localhost:1234/v1",
            "http://127.0.0.1:8080/v1",   // MLX standalone
            "http://localhost:8080/v1",
            "http://127.0.0.1:8000/v1",   // vLLM / custom
            "http://localhost:8000/v1"
        ]
        var seen = Set<String>()
        candidates = candidates.filter { seen.insert($0).inserted }

        var lastError: Error?
        for candidate in candidates {
            do {
                let models = try await fetchOpenAIModels(baseURL: candidate, apiKey: apiKey)
                return EndpointProbe(baseURL: normalizedBaseURL(candidate), models: models)
            } catch {
                // IMPORTANT: propagate cancellation immediately instead of swallowing it
                // and continuing through every candidate — otherwise STOP can never abort
                // this loop while the LLM service is down.
                if error is CancellationError || Task.isCancelled {
                    throw CancellationError()
                }
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    throw CancellationError()
                }
                lastError = error
            }
        }
        throw lastError ?? URLError(.cannotConnectToHost)
    }

    // MARK: - Anthropic API methods

    private enum AnthropicModels {
        static let list = [
            "claude-sonnet-5-20251001",
            "claude-opus-4-8-20250514",
            "claude-opus-4-7-20250619",
            "claude-haiku-4-5-20251001",
            "claude-fable-5"
        ]
    }

    static func sendAnthropicTestMessage(baseURL: String, apiKey: String) async throws {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)/v1/messages") else {
            throw URLError(.badURL)
        }

        let body = AnthropicMessageRequest(
            model: "claude-sonnet-5-20251001",
            messages: [.init(type: "text", text: "Hi")],
            system: nil,
            max_tokens: 10,
            temperature: 0.0
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let bodyPreview = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "LLMCommandService", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Anthropic API error \(http.statusCode): \(bodyPreview.prefix(200))"
            ])
        }
    }

    static func sendAnthropicChat(
        baseURL: String,
        model: String,
        messages: [LLMCommandService.ChatRequest.Message],
        systemPrompt: String?,
        temperature: Double,
        timeout: TimeInterval,
        apiKey: String
    ) async throws -> (text: String, usage: TokenUsage?) {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)/v1/messages") else {
            throw URLError(.badURL)
        }

        var anthropicMessages: [AnthropicMessageRequest.ContentBlock] = []
        // Merge consecutive same-role messages for Anthropic's stricter format
        var role: String = "user"
        var textBuffer = ""
        for msg in messages {
            let msgRole = msg.role == "user" || msg.role == "system" ? "user" : "assistant"
            if msgRole != role && !textBuffer.isEmpty {
                anthropicMessages.append(.init(type: "text", text: textBuffer))
                textBuffer = ""
            }
            role = msgRole
            textBuffer += (textBuffer.isEmpty ? "" : "\n") + msg.content
        }
        if !textBuffer.isEmpty {
            anthropicMessages.append(.init(type: "text", text: textBuffer))
        }

        // Guard: Anthropic requires alternating user/assistant, starting with user
        if anthropicMessages.isEmpty || anthropicMessages.first?.type == "assistant" {
            anthropicMessages.insert(.init(type: "text", text: "Start."), at: 0)
        }
        // Ensure last message is user (will be converted to assistant in response)
        // Actually Anthropic accepts trailing user with no assistant response

        let body = AnthropicMessageRequest(
            model: model,
            messages: anthropicMessages,
            system: systemPrompt,
            max_tokens: 4096,
            temperature: temperature
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let bodyPreview = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "LLMCommandService", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Anthropic API error \(http.statusCode): \(bodyPreview.prefix(300))"
            ])
        }

        let decoded = try JSONDecoder().decode(AnthropicMessageResponse.self, from: data)
        let text = decoded.content.first(where: { $0.type == "text" })?.text ?? ""
        let usage = decoded.usage.map {
            TokenUsage(
                input: $0.input_tokens,
                output: $0.output_tokens,
                cacheRead: $0.cache_read_input_tokens ?? 0,
                cacheWrite: $0.cache_creation_input_tokens ?? 0
            )
        }
        return (text, usage)
    }

    // MARK: - Gemini API methods

    static func fetchGeminiModels(baseURL: String, apiKey: String) async throws -> [String] {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)/models?key=\(apiKey)") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NSError(domain: "LLMCommandService", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Gemini API error \(http.statusCode)"
            ])
        }
        let decoded = try JSONDecoder().decode(GeminiModelsResponse.self, from: data)
        return decoded.models
            .filter { $0.name.hasPrefix("models/gemini") }
            .map { $0.name.replacingOccurrences(of: "models/", with: "") }
            .sorted()
    }

    static func sendGeminiChat(
        baseURL: String,
        model: String,
        messages: [LLMCommandService.ChatRequest.Message],
        systemPrompt: String?,
        temperature: Double,
        timeout: TimeInterval,
        apiKey: String
    ) async throws -> (text: String, usage: TokenUsage?) {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)/models/\(model):generateContent?key=\(apiKey)") else {
            throw URLError(.badURL)
        }

        var contents: [GeminiGenerateRequest.Content] = []
        for msg in messages {
            let role = msg.role == "assistant" ? "model" : "user"
            contents.append(.init(role: role, parts: [.init(text: msg.content)]))
        }

        let systemInst: GeminiGenerateRequest.SystemInstruction?
        if let sp = systemPrompt {
            systemInst = .init(parts: [.init(text: sp)])
        } else {
            systemInst = nil
        }

        let body = GeminiGenerateRequest(
            contents: contents,
            systemInstruction: systemInst,
            generationConfig: GenerationConfig(temperature: temperature, maxOutputTokens: 4096)
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let bodyPreview = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "LLMCommandService", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "Gemini API error \(http.statusCode): \(bodyPreview.prefix(300))"
            ])
        }
        let decoded = try JSONDecoder().decode(GeminiGenerateResponse.self, from: data)
        let text = decoded.candidates.first?.content.parts.map(\.text).joined(separator: "\n") ?? "No response."
        let usage = decoded.usageMetadata.flatMap { meta -> TokenUsage? in
            guard let inT = meta.promptTokenCount, let outT = meta.candidatesTokenCount else { return nil }
            return TokenUsage(input: inT, output: outT)
        }
        return (text, usage)
    }

    // MARK: - Unified chat dispatcher

    static func sendChat(
        baseURL: String,
        model: String,
        messages: [LLMCommandService.ChatRequest.Message],
        systemPrompt: String? = nil,
        temperature: Double,
        timeout: TimeInterval,
        apiKey: String,
        apiFormat: APIFormat
    ) async throws -> (text: String, usage: TokenUsage?) {
        switch apiFormat {
        case .openAICompatible, .codeBuddy:
            let url = try endpointURL(baseURL: baseURL, path: "chat/completions")
            return try await sendOpenAICompatibleChat(
                url: url,
                model: model,
                messages: messages,
                systemPrompt: systemPrompt,
                temperature: temperature,
                timeout: timeout,
                apiKey: apiKey,
                stream: apiFormat == .codeBuddy,
                promptCache: false,
                sessionId: nil
            )

        case .anthropic:
            return try await sendAnthropicChat(
                baseURL: baseURL, model: model, messages: messages,
                systemPrompt: systemPrompt, temperature: temperature,
                timeout: timeout, apiKey: apiKey
            )

        case .gemini:
            return try await sendGeminiChat(
                baseURL: baseURL, model: model, messages: messages,
                systemPrompt: systemPrompt, temperature: temperature,
                timeout: timeout, apiKey: apiKey
            )
        }
    }

    // MARK: - OpenAI-compatible request helper (streaming + non-streaming)

    private static func sendOpenAICompatibleChat(
        url: URL,
        model: String,
        messages: [ChatRequest.Message],
        systemPrompt: String? = nil,
        temperature: Double,
        timeout: TimeInterval,
        apiKey: String,
        stream: Bool,
        promptCache: Bool?,
        sessionId: String?
    ) async throws -> (text: String, usage: TokenUsage?) {
        let useStreaming = stream || isCodeBuddyEndpoint(url)
        var apiMessages = messages
        if let sp = systemPrompt, !sp.isEmpty {
            apiMessages.insert(.init(role: "system", content: sp), at: 0)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthorization(apiKey, to: &request)
        request.httpBody = try JSONEncoder().encode(
            ChatRequest(
                model: model,
                messages: apiMessages,
                temperature: temperature,
                prompt_cache: promptCache,
                session_id: sessionId,
                stream: useStreaming ? true : nil
            )
        )

        if useStreaming {
            return try await receiveStreamingChatResponse(request: request)
        }

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NSError(domain: "LLMCommandService", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "LLM request failed with HTTP \(http.statusCode)"
            ])
        }
        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        let usage = decoded.usage.map { TokenUsage(input: $0.prompt_tokens, output: $0.completion_tokens) }
        return (decoded.choices.first?.message.content ?? "", usage)
    }

    private static func isCodeBuddyEndpoint(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return host == "copilot.tencent.com" || host == "www.codebuddy.ai" || host.hasSuffix(".copilot.tencent.com")
    }

    private static func receiveStreamingChatResponse(request: URLRequest) async throws -> (text: String, usage: TokenUsage?) {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NSError(domain: "LLMCommandService", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "LLM request failed with HTTP \(http.statusCode)"
            ])
        }

        var text = ""
        var usage: TokenUsage?
        for try await line in bytes.lines {
            if Task.isCancelled {
                throw CancellationError()
            }
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("data:") else { continue }
            let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespacesAndNewlines)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(ChatStreamChunk.self, from: data) else {
                continue
            }
            if let delta = chunk.choices?.first?.delta.content, !delta.isEmpty {
                text += delta
            }
            if let u = chunk.usage,
               let input = u.prompt_tokens,
               let output = u.completion_tokens {
                usage = TokenUsage(
                    input: input,
                    output: output,
                    cacheRead: u.prompt_cache_hit_tokens ?? 0,
                    cacheWrite: u.prompt_cache_creation_tokens ?? 0
                )
            }
        }
        guard !text.isEmpty else {
            throw NSError(domain: "LLMCommandService", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "LLM returned an empty streaming response."
            ])
        }
        return (text, usage)
    }

    static func endpointURL(baseURL: String, path: String) throws -> URL {
        let normalized = normalizedBaseURL(baseURL)
        guard let url = URL(string: normalized.appending("/\(path)")) else {
            throw URLError(.badURL)
        }
        return url
    }

    static func friendlyError(_ error: Error, baseURL: String) -> String {
        let nsError = error as NSError
        let code = URLError.Code(rawValue: nsError.code)
        if nsError.domain == NSURLErrorDomain {
            switch code {
            case .cannotConnectToHost, .networkConnectionLost, .timedOut, .notConnectedToInternet:
                if !isLikelyLocalEndpoint(baseURL) {
                    return String.safeFormat(L10n.errorRemoteRequest,
                                  baseURL as NSString, nsError.localizedDescription as NSString)
                }
                let tips = baseURL.contains("11434") ? L10n.errorOllamaTips : ""
                return String.safeFormat(L10n.errorCannotConnect, baseURL, tips)
            case .badURL:
                return L10n.errorBadURL
            default:
                break
            }
        }

        if nsError.domain == "LLMCommandService", nsError.code == 401 {
            return String.safeFormat(L10n.errorUnauthorized, baseURL)
        }

        if nsError.localizedDescription.localizedCaseInsensitiveContains("could not connect") {
            if !isLikelyLocalEndpoint(baseURL) {
                return String.safeFormat(L10n.errorRemoteRequest,
                              baseURL as NSString, nsError.localizedDescription as NSString)
            }
            return String.safeFormat(L10n.errorCouldNotConnectLMStudio, baseURL)
        }

        return String.safeFormat(L10n.errorGeneric, error.localizedDescription)
    }

    static func generateInitialModel(
        baseURL: String,
        model: String,
        projectURL: URL,
        runID: String,
        dataFile: String,
        rules: String,
        apiKey: String = "",
        hasLag: Bool = false,
        lagTime: Double = 0,
        elimSimilar: Bool = true,
        elimReliable: Bool = true,
        elimDetail: String = "",
        linearPK: Bool = true,
        exposureDetail: String = "",
        firstDoseElimSimilar: Bool = true,
        firstDoseElimDetail: String = "",
        multiDose: Bool = false,
        route: String = "Unknown",
        doseUnit: String = "mg",
        amtUnit: String = "mg",
        concUnit: String = "μg/mL",
        timeUnit: String = "h",
        compartmentSuspected: Bool = false,
        compartmentShapeDetail: String = "",
        s1Expression: String = "V/1000",
        s1for2CompExpression: String = "V1/1000",
        s2Expression: String = "V/1000",
        s2for2CompExpression: String = "V2/1000",
        derivedVUnit: String = "L",
        derivedCLUnit: String = "L/h",
        apiFormat: APIFormat = .openAICompatible
    ) async throws -> (text: String, usage: TokenUsage?) {
        let url = try endpointURL(baseURL: baseURL, path: "chat/completions")
        let profile = analyzeDataset(projectURL: projectURL, dataFile: dataFile)
        let dataPreview = datasetPreview(projectURL: projectURL, dataFile: dataFile)
        let tableSuffix = runID
        let modelLibrary = modelLibraryText(projectURL: projectURL)
        let recommendedTemplate = recommendedInitialTemplate(for: profile)
        let inputRecord = inputRecordFromDataset(projectURL: projectURL, dataFile: dataFile) ?? defaultInputRecord
        let nca = ncaInitialEstimates(projectURL: projectURL, dataFile: dataFile)

        // Rule/knowledge content is intentionally preserved at the full upstream
        // budget. Speed comes from avoiding duplicate copies, not from trimming rules.
        let ruleLimit = 80_000
        let libraryLimit = 35_000
        // Keep the same leading prefix as evaluation/drafting calls so DeepSeek can
        // reuse the model-library prefix even when this is the first automation call.
        let staticCtx = """
        AutoPMX PopPK model library:
        \(modelLibrary.prefix(libraryLimit))

        AutoPMX rule/knowledge context:
        \(rules.prefix(ruleLimit))
        """

        let routeGuidance: String
        let routeHardRule: String
        switch profile.route {
        case "IV Bolus":
            routeGuidance = """
            IV Bolus administration detected (AMT>0 with CMT=1, no RATE/DUR).
            Start from template: \(recommendedTemplate).
            """
            routeHardRule = """
            ━━━ ROUTE LOCK: IV BOLUS ━━━
            YOU ARE BUILDING AN IV BOLUS MODEL ONLY.
            - ALLOWED templates: iv_bolus_1c_advan1_trans2 → iv_bolus_2c_advan3_trans4 → iv_bolus_3c_advan11_trans4
            - FORBIDDEN: ADVAN2, ADVAN4, ADVAN12 (oral/extravascular). Any mention of KA, oral, depot, extravascular, F1, F2.
            - The dataset has NO oral absorption — do NOT add KA or absorption compartments.
            - If you accidentally write KA or switch to ADVAN2, the model will FAIL because the dataset has no absorption records.
            - Structural escalation path (ONLY this path):
              Run001: 1-comp IV (CL, V)
              Run002+: 2-comp IV (CL, V1, Q, V2) — ONLY if 1-comp GOF shows distribution phase misspecification
              Run00X+: 3-comp IV (CL, V1, Q2, V2, Q3, V3) — ONLY if 2-comp GOF still shows misspecification
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━
            """
        case "IV Infusion":
            routeGuidance = """
            IV Infusion administration detected (CMT=1 with RATE>0 or DUR>0).
            Start from template: \(recommendedTemplate).
            Preserve D1=DUR when DUR is present, and add a tiny positive fallback for non-dose records:
              IF (DUR.GT.0) D1=DUR
              IF (DUR.LE.0) D1=0.0001
            Use RATE only if the dataset relies on RATE.
            """
            routeHardRule = """
            ━━━ ROUTE LOCK: IV INFUSION ━━━
            YOU ARE BUILDING AN IV INFUSION MODEL ONLY.
            - ALLOWED templates: iv_infusion_1c_advan1_trans2 → iv_infusion_2c_advan3_trans4 → iv_infusion_3c_advan11_trans4
            - FORBIDDEN: ADVAN2, ADVAN4, ADVAN12 (oral/extravascular). Any mention of KA, oral, depot, extravascular, F1.
            - The dataset has IV infusion only — do NOT add KA or absorption compartments.
            - If DUR is in the dataset, use D1=DUR in $PK with a tiny positive fallback for non-dose records:
              IF (DUR.GT.0) D1=DUR
              IF (DUR.LE.0) D1=0.0001
              Do not use RATE unless DUR is absent.
            - Structural escalation path (ONLY this path):
              Run001: 1-comp IV infusion (CL, V, D1=DUR)
              Run002+: 2-comp IV infusion (CL, V1, Q, V2, D1=DUR) — ONLY if GOF supports
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            """
        case "Oral":
            routeGuidance = """
            Oral/extravascular administration detected from ROUTE and/or depot->central CMT structure.
            Standard extravascular NONMEM uses CMT=1 for the depot dose and CMT=2 for the central
            observation, so do NOT treat CMT=1 dosing as direct delivery to the central compartment.
            Start from template: \(recommendedTemplate).
            If the CMT convention is nonstandard, use the custom DES template rather than inventing ADVAN syntax.
            """
            routeHardRule = """
            ━━━ ROUTE LOCK: ORAL/EXTRAVASCULAR ━━━
            YOU ARE BUILDING AN ORAL/EXTRAVASCULAR MODEL ONLY.
            - ALLOWED templates: extravascular_1c_advan2_trans2 → extravascular_2c_advan4_trans4 → extravascular_3c_advan12_trans4
            - FORBIDDEN: ADVAN1, ADVAN3, ADVAN11 (IV-only). Do not remove KA.
            - The dataset has absorption — KA must be present in $PK and $THETA.
            - Depot = CMT=1, Central = CMT=2 (use S2=\(s2Expression) for scaling).
            - Structural escalation path (ONLY this path):
              Run001: 1-comp oral (KA, CL, V)
              Run002+: 2-comp oral (KA, CL, V2, Q, V3) — ONLY if GOF supports
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            """
        case "Mixed":
            routeGuidance = """
            Mixed IV + SC/extravascular administration detected from the ROUTE column.
            This dataset needs a depot compartment for SC dosing and a central compartment
            for IV dosing. Start from the extravascular template so SC records use CMT=1
            (depot) and IV records can dose directly to the central compartment.
            SC first-order absorption does NOT need D1 just because DUR exists in the dataset.
            If IV infusion is delivered directly to CMT=2, use D2=DUR for that compartment.
            """
            routeHardRule = """
            ━━━ ROUTE LOCK: MIXED IV + SC/EXTRAVASCULAR ━━━
            YOU ARE BUILDING A FULL-DATASET MODEL WITH BOTH IV AND SC/EXTRAVASCULAR ROUTES.
            - ALLOWED templates: extravascular_1c_advan2_trans2 →
              extravascular_2c_advan4_trans4 → extravascular_3c_advan12_trans4.
            - FORBIDDEN: ADVAN1, ADVAN3, ADVAN11 (IV-only), and any S1-only central scaling.
            - Depot = CMT=1, Central = CMT=2 (use S2=\(s2Expression) / S2=\(s2for2CompExpression)).
            - For first-order SC (CMT=1), do NOT write D1 unless the SC dosing records themselves carry DUR/RATE.
            - For IV infusion directly to central CMT=2 with DUR, write:
              IF (CMT.EQ.2 .AND. DUR.GT.0) D2=DUR
              IF (CMT.EQ.2 .AND. DUR.LE.0) D2=0.0001
            - SC zero-order absorption needs a different depot-dosing implementation; do not approximate it with D1 on a first-order KA model.
            - If you are continuing from an IV mother model, keep the IV THETA/OMEGA estimates
              as starting values, add KA, add F1 when both IV and SC exist, and renumber the
              central/peripheral compartments for the extravascular ADVAN family.
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            """
        default:
            routeGuidance = """
            Route is uncertain. Start from template: \(recommendedTemplate), unless the data preview clearly supports another library template.
            """
            routeHardRule = """
            ━━━ ROUTE: UNCERTAIN ━━━
            Determine route from ROUTE, CMT, RATE/DUR, and the first-dose C-T profile before writing $SUBROUTINES.
            - If ROUTE is present, trust ROUTE as the highest-priority signal.
            - If dosing CMT=2 with AMT>0 → Oral/extravascular (nonstandard CMT).
            - If dosing CMT=1 with RATE>0 or DUR>0 → IV Infusion.
            - If dosing CMT=1, no RATE/DUR, and observations use CMT>=2 without any CMT=1 observation
              → depot + central (Oral/extravascular), not IV bolus.
            - If dosing CMT=1 and observations include CMT=1 → IV Bolus.
            - If still ambiguous, inspect whether early concentrations rise after dosing before choosing.
            ━━━━━━━━━━━━━━━━━━━━
            """
        }

        let prompt = """
        You are an expert NONMEM pharmacometrician building PopPK models for monoclonal antibodies.
        Create the FIRST control stream run\(runID).mod for an automated stepwise model-building project.
        Return ONLY the complete .mod file. No markdown, no explanation outside the file.
        \(Self.responseLanguageDirective)

        PROJECT UNITS (from user configuration):
          Dose unit: \(doseUnit)   |   AMT unit: \(amtUnit)   |   Conc. unit: \(concUnit)   |   Time unit: \(timeUnit)
        Use these units consistently in ALL parameter labels, axis labels, and THETA comments.
        For example: CL should be labelled in L/\(timeUnit), V in \(derivedVUnit) (derived from AMT=\(doseUnit) & DV=\(concUnit)).
        CRITICAL — SCALE PARAMETER SCALING: Based on your AMT & DV units, the correct scale parameter is:
        - IV 1-cpt: S1=\(s1Expression) | IV 2+/3-cpt: S1=\(s1for2CompExpression)
        - Oral / SC / extravascular 1-cpt: S2=\(s2Expression) | Oral / SC / extravascular 2+/3-cpt: S2=\(s2for2CompExpression)
        Do NOT blindly write S1=V/1000 or S2=V/1000 — use the exact expression above.
        Unit examples: mg + ng/mL → /1000; mg + mg/L or mg + µg/mL → V;
        µg + µg/mL → V*1000; µg + ng/mL or µg + µg/L → V.

        RESIDUAL ERROR INITIAL VALUE RULE (DATA-DRIVEN):
        Dataset DV profile: typical (median) concentration = \(profile.typicalDV.map { String(format: "%.3f", $0) } ?? "unknown") \(concUnit)
        DV range: \(profile.dvRange.map { "\(String(format: "%.3f", $0.0)) – \(String(format: "%.3f", $0.1))" } ?? "unknown") \(concUnit)

        Prop.RE (sd): use 0.15 (15% CV) — standard for mAb PK assays.
        Add.RE (sd): use \(profile.typicalDV.map { String(format: "%.4f", min(1.0, $0 * 0.05)) } ?? "1.0") — roughly 1-5% of typical DV, capped at 1.0, NEVER exceed 20% of typical DV.
        CRITICAL: Add.RE must be SMALLER than typical DV, not larger. If typical DV is 10 \(concUnit), Add.RE ≈ 0.5 NOT 5.0.

        AUTOMATION PHASE: Initial 1-Compartment Model.
        This is the FIRST iteration — use the simplest defensible structural model.
        Subsequent iterations will add compartments, IIV, covariates, and error complexity only when diagnostics support it.

        \(routeGuidance)

        \(routeHardRule)

        \(compartmentSuspected ? """
        ━━━ COMPARTMENT SHAPE: MULTI-COMPARTMENT SUSPECTED ━━━
        Semi-log C-T curve shape analysis detected multi-compartment kinetics:
        the early elimination phase is significantly steeper than the terminal phase,
        showing a characteristic distribution + elimination curvature.
        Start from a 1-Comp model as the base, but be prepared to escalate to 2-Comp
        if the 1-Comp GOF (CWRES vs PRED/Time, VPC) shows systematic misspecification.
        \(compartmentShapeDetail.isEmpty ? "" : compartmentShapeDetail)
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """ : "")

        \(hasLag ? """
        ━━━ ABSORPTION LAG DETECTED ━━━
        Dose-normalized C-T analysis detected absorption lag (Tlag ≈ \(String(format: "%.2f", lagTime))).
        Most subjects have near-zero DV at the earliest post-dose time point.
        Include ALAG1 in $PK for ADVAN2/ADVAN4 models, or define TLAG for ADVAN13:
          ALAG1 = THETA(n)   (for ADVAN2/ADVAN4)
          or: TLAG = THETA(n); DADT(1) = KA * A(1) ... with lag logic (for ADVAN13)
        Add THETA for lag time: (0, \(String(format: "%.2f", max(lagTime * 0.5, 0.1)))) FIX ; Tlag
        ━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        """ : "")
        \(elimReliable
          ? (elimSimilar ? """
        ━━━ ELIMINATION (TERMINAL PHASE) ━━━
        Terminal-phase half-life is SIMILAR across dose groups (dose-independent clearance).
        This is consistent with linear PK; a standard compartmental model with dose-independent CL/V is appropriate.
        \(elimDetail)

        """ : """
        ━━━ ELIMINATION (TERMINAL PHASE) ━━━
        Terminal-phase half-life DIFFERS across dose groups (dose-DEPENDENT clearance suspected).
        Consider a clearance mechanism that saturates at higher doses (e.g., TMDD / Michaelis-Menten),
        or a dose- or concentration-dependent CL term, when the data support it.
        \(elimDetail)

        """)
          : """
        ━━━ ELIMINATION (TERMINAL PHASE) ━━━
        Terminal-phase half-life data is insufficient (sparse sampling, low R^2).
        Do NOT assume dose-dependent clearance from elimination data alone — rely on the dose-normalized C-T curve overlap analysis instead.

        """
        )
        \(multiDose && !firstDoseElimDetail.isEmpty ? """
        ━━━ MULTI-DOSE: COMPREHENSIVE ELIMINATION ASSESSMENT ━━━
        This is a MULTI-DOSE study. Repeated dosing accumulates and stacks the terminal phase,
        so the all-dose overlay's elimination reading may be confounded by accumulation.
        You have TWO sources of evidence — use BOTH:
        (1) Full-curve elimination assessment:
            \(elimReliable ? (elimSimilar ? "Half-lives SIMILAR across doses → dose-independent clearance." : "Half-lives DIFFER across doses → dose-dependent clearance suspected (TMDD / saturable CL).") : "Full-curve terminal data insufficient (sparse sampling, low R^2).")
            \(elimDetail)
        (2) First-dose elimination assessment (reflects single-dose kinetics, free of accumulation):
            \(firstDoseElimDetail)
            => \(firstDoseElimSimilar ? "First-dose half-lives SIMILAR → dose-independent clearance." : "First-dose half-lives DIFFER → dose-dependent clearance suspected (TMDD / saturable CL).")

        SYNTHESIS RULE:
        - If (1) and (2) agree → strong signal; follow the consensus.
        - If they disagree → the first-dose view is closer to the true intrinsic clearance (no accumulation confounding), but do NOT ignore the full-curve signal entirely — note the discrepancy in your reasoning.
        - If only one source is assessable → use that one as the primary reference.
        Use this synthesized verdict to choose ADVAN-style, the clearance model, and whether a saturable clearance term is needed.

        """ : "")
        \(linearPK ? """
        ━━━ DOSE-NORMALIZED EXPOSURE ━━━
        Dose-normalized C-T curves overlap across dose groups → LINEAR PK supported.
        Build the base model with standard (non-saturable) clearance; do NOT add TMDD complexity prematurely.
        \(exposureDetail)

        """ : """
        ━━━ DOSE-NORMALIZED EXPOSURE ━━━
        Dose-normalized C-T curves do NOT overlap across dose groups → NONLINEAR PK suspected.
        The data suggest dose-dependent exposure (saturable elimination / TMDD). Plan a base model
        that can represent this: consider a 2-compartment model with a saturable clearance component
        (e.g., TMDD / ADVAN13 with KON/KOFF/KINT and R0) once the parent model runs cleanly.
        Do NOT add TMDD complexity while the parent model cannot compile/run.
        \(exposureDetail)

        """)
        \(profile.summary)

        \(nca.summary)

        TEMPLATE-FIRST RULES:
        - Recommended TEMPLATE_ID for run\(runID): \(recommendedTemplate)
        - Use the AutoPMX PopPK model library below as a fill-in template. Do not write NONMEM from memory.
        - Keep the selected template's $SUBROUTINES/$MODEL/$DES/$PK/$ERROR block shape unless the dataset makes it impossible.
        - IIV IS REQUIRED for run001: every PK parameter MUST include IIV (EXP(ETA)). For 1-comp: CL = TVCL * EXP(ETA(1)), V = TVV * EXP(ETA(2)).
          $OMEGA must define exactly one variance per ETA. NEVER write "No IIV" or empty $OMEGA in the initial model.
        - Default residual model MUST be combined proportional + additive:
          W = SQRT((THETA(k)*IPRED)**2 + THETA(k+1)**2)
          Y = IPRED + W*EPS(1)
          With this error model, $SIGMA is ALWAYS 1 FIX — the residual SDs are estimated as THETAs, NOT as SIGMAs.
          NEVER write $SIGMA 2 or try to estimate SIGMA values — the combined-error THETAs already capture all residual variability.
        - Keep semicolon labels on THETA/OMEGA/SIGMA for parameter extraction.
        - CSV header order is the source of truth for $INPUT. Use this exact record:
          $INPUT \(inputRecord)

        \(ModelRunEvidence.controlStreamBlockContract)

        REQUIRED NONMEM SYNTAX (strict):
        1. $PROBLEM: Brief description including run ID and model type
        2. $INPUT: Must exactly follow the CSV header order:
           $INPUT \(inputRecord)
           Do not invent, rename, omit, or reorder CSV columns. The C column must remain plain C, never C=DROP/C=SKIP.
        3. $DATA \(dataFile) IGNORE=C
        4. $SUBROUTINES: MUST use the EXACT AutoPMX format: $SUBROUTINES ADVAN1 TRANS2
           - NEVER write "$SUBROUTINE PREDPP ADVAN=1 TRANSFORM=2" or any other variant.
           - The only valid format is: $SUBROUTINES <ADVAN> <TRANS> (e.g. $SUBROUTINES ADVAN3 TRANS4).
        5. $PK: Define ALL symbols BEFORE using them. Order matters in NONMEM!
           WRONG:                          CORRECT:
             S1 = V/1000                    TVCL = THETA(1)
             CL = THETA(1) * EXP(ETA(1))    TVV  = THETA(2)
             V  = THETA(2)                  CL = TVCL * EXP(ETA(1))
                                            V  = TVV  * EXP(ETA(2))
                                            S1 = V/1000
           Use TVxx = THETA(n) pattern — define TVCL, TVV etc. first, then CL = TVCL * EXP(ETA(1)).
           Place D1=DUR and S1=\(s1Expression) AFTER all TVxx and parameter definitions (V must be defined before S1 references it).
        6. $ERROR:
           - Define IPRED = F (not PRED)
           - Always use the combined proportional + additive error form from the library.
           - SIGMA(1,1) is fixed residual scale; ETA(i) is individual random effect.
        7. $THETA: EVERY line MUST be exactly `(0, value)` format — lower bound fixed to 0, no upper bound. NEVER write a bare value without parentheses. Example:
              (0, 0.012) ; CL (L/\(timeUnit))
              (0, 4.0)   ; V (L)
              (0, 0.15)  ; Prop.RE (sd)
              (0, 1.0)   ; Add.RE (sd)
            CRITICAL: Every THETA line MUST begin with `(0, ` and end with `)`. Bare values like `0.2` are INVALID NONMEM syntax.
            Use L/\(timeUnit) for clearance. Typical mAb CL: 0.008-0.02 L/\(timeUnit).

             RESIDUAL ERROR INITIAL VALUES — DATA-DRIVEN (see Dataset profile below):
             The initial Prop.RE and Add.RE values MUST be derived from the dataset's DV distribution.
             Prop.RE (sd) ≈ typical CV% of PK assays. For mAb PK, start with Prop.RE = 0.15 (15% CV).
             This means at the typical concentration, the SD is ~15% of the prediction.
             Add.RE (sd) ≈ roughly 1-5% of the typical DV value, but NO LARGER than 20% of typical DV.
             Rationale: Prop.RE captures proportional noise (constant CV) at the typical concentration
             range; Add.RE captures baseline assay noise / model misspecification at very low
             concentrations. If Add.RE is too large, it absorbs the proportional component and the
             model loses identifiability. A common starting point for mAb IV infusion data:
               Typical DV ~ 1-100 µg/mL → Prop.RE = 0.15, Add.RE = MIN(1.0, typicalDV * 0.05)
               Typical DV ~ 0.01-1 µg/mL → Prop.RE = 0.15, Add.RE = MIN(0.05, typicalDV * 0.05)
             NEVER set Add.RE initial > 20% of the median DV — the model will be unidentifiable.
           MANDATORY: Only define THETA for parameters that EXIST in the model.
           ─────────────────────────────────────────────
           ROUTE → COMPARTMENT → PARAMETER MAPPING (STRICT):
           ─────────────────────────────────────────────

           IV Bolus 1-comp (ADVAN1 TRANS2):
             ONLY: CL, V
             THETA labels: CL (sd), V (sd), Prop.RE (sd), Add.RE (sd)
             NEVER: Q, V2, KA, D1, RATE, DUR, F1
             Example: CL ≈ 0.008-0.02 L/h, V ≈ 3-6 L

           IV Infusion 1-comp (ADVAN1 TRANS2):
             ONLY: CL, V
             THETA labels: CL (sd), V (sd), Prop.RE (sd), Add.RE (sd)
             D1=DUR is a data item, NOT a THETA
             NEVER: Q, V2, KA, RATE, F1

           IV Bolus 2-comp (ADVAN3 TRANS4):
             ONLY: CL, V1, Q, V2
             THETA labels: CL (sd), V1 (sd), Q (sd), V2 (sd), Prop.RE (sd), Add.RE (sd)
             NEVER: KA, D1, DUR, RATE, F1

           Oral 1-comp (ADVAN2 TRANS2):
             ONLY: CL, V, KA
             THETA labels: CL (sd), V (sd), KA (sd), Prop.RE (sd), Add.RE (sd)
             NEVER: Q, V2

           Oral 2-comp (ADVAN4 TRANS4):
             ONLY: CL, V2, Q, V3, KA
             THETA labels: CL (sd), V2 (sd), Q (sd), V3 (sd), KA (sd), Prop.RE (sd), Add.RE (sd)
             NEVER: V1, V

           IV Bolus 3-comp (ADVAN11 TRANS4):
             ONLY: CL, V1, Q2, V2, Q3, V3
             THETA labels: CL (sd), V1 (sd), Q2 (sd), V2 (sd), Q3 (sd), V3 (sd), Prop.RE (sd), Add.RE (sd)
             NEVER: KA, Q (use Q2, Q3), V (use V1)

           Oral 3-comp (ADVAN12 TRANS4):
             ONLY: KA, CL, V2, Q3, V3, Q4, V4
             THETA labels: KA (sd), CL (sd), V2 (sd), Q3 (sd), V3 (sd), Q4 (sd), V4 (sd), Prop.RE (sd), Add.RE (sd)
             NEVER: V1, Q (use Q3, Q4)

           ─────────────────────────────────────────────
           SCALE PARAMETER (REQUIRED for ADVAN1-4, ADVAN11, ADVAN12):
           - IV models (ADVAN1/3/11): ALWAYS include S1=\(s1Expression) (1-cpt) or S1=\(s1for2CompExpression) (2+/3-cpt) in $PK.
           - Oral / SC / extravascular models (ADVAN2/4/12): ALWAYS include S2=\(s2Expression) (1-cpt) or S2=\(s2for2CompExpression) (2+/3-cpt) in $PK.
           - Without S1/S2, NONMEM issues WARNING 23 — parameter estimates become unreliable.
           ─────────────────────────────────────────────
           CRITICAL: The $TABLE must ONLY contain the SAME parameters from $PK.
           Before writing $TABLE, verify each parameter exists in $PK.
           If $PK has CL, V → $TABLE has CL, V
           If $PK has CL, V1, Q, V2 → $TABLE has CL, V1, Q, V2
           If $PK has CL, V, KA → $TABLE has CL, V, KA
           NEVER write Q, V2, KA in $TABLE unless they are in $PK.
           ─────────────────────────────────────────────
        8. $OMEGA: The INITIAL model (run001) MUST include IIV on ALL base parameters. Every PK parameter gets its own ETA.
               For 1-comp IV: CL and V both get IIV — CL = TVCL * EXP(ETA(1)), V = TVV * EXP(ETA(2)).
               $OMEGA must have exactly one variance per ETA (e.g., 2 ETAs → 2 lines). Example:
               $OMEGA
               0.08 ; IIV CL
               0.05 ; IIV V
             Each line is ONE variance. Do NOT use BLOCK(1). Values MUST be slightly different (never identical!) to avoid matrix singularity — ALWAYS perturb by at least 0.01.
             Only in LATER runs (run002+) may you consider reducing/fixing IIV based on its %RSE > 50%
             or repeated convergence/covariance failure or a boundary estimate. Do NOT use eta-shrinkage
             as a reason to add, remove, fix, or accept/reject IIV. ETA and PK parameter decisions use
             %RSE only. If a parameter has no ETA, do not report or infer any eta-shrinkage for it.
           9. $SIGMA 1 FIX for residual scale; the residual SDs are THETA labels Prop.RE (sd) and Add.RE (sd).
        10. $EST METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10
        11. $COVARIANCE PRINT=E MATRIX=S
        12. $TABLE records (each on ONE line) — CRITICAL: ONLY list parameters that are DEFINED in this specific model.
            - 1-compartment model (CL, V only): the PK/TABLE parameters are ONLY CL and V.
            - 2-compartment model (CL, V1, Q, V2): the PK/TABLE parameters are CL, V1, Q, V2.
            - Extravascular model (CL, V, KA): the PK/TABLE parameters are CL, V, KA.
            - Extravascular 2-comp (CL, V2, Q, V3, KA): the PK/TABLE parameters are CL, V2, Q, V3, KA.
            - NEVER list Q, V2, or KA in $TABLE for a 1-compartment IV model. These parameters do NOT exist in ADVAN1/ADVAN2 1-comp models.
            - Generate ONLY the ETA(n) that have OMEGA blocks. If only ETA(1) and ETA(2) exist, do NOT list ETA3.

            FIRST determine which compartment model you are writing, then generate $TABLE accordingly:
            $TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES <other $INPUT columns excluding C, e.g. AMT RATE DUR CMT DOSE WT AGE SEX ADA> ONEHEADER NOPRINT NOAPPEND FILE=sdtab\(tableSuffix) FORMAT=s1PE14.7
            $TABLE ID <PK-params-only> <ETA-list-only> NOPRINT NOAPPEND ONEHEADER FILE=patab\(tableSuffix)
            $TABLE ID <ETA-list-only> FIRSTONLY NOAPPEND NOPRINT FILE=run\(tableSuffix).ETA
            $TABLE ID <categorical columns from $INPUT, e.g. SEX STUDY ADA ROUTE CMT EVID MDV> FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=catab\(tableSuffix)
            $TABLE ID <continuous columns from $INPUT, e.g. WT AGE DOSE AMT RATE DUR> FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=cotab\(tableSuffix)

        Use the AutoPMX rule/knowledge context and PopPK model library provided in the
        system context; do not invent NONMEM syntax outside those references.

        Dataset preview:
        \(dataPreview)

        Continue to return only the valid .mod file starting with $PROBLEM.
        """

        let (content, usage) = try await sendChatPrompt(
            url: url, model: model, prompt: prompt,
            systemPrompt: staticCtx,
            temperature: 0.1, timeout: 300, apiKey: apiKey,
            apiFormat: apiFormat
        )
        return (try cleanControlStream(content, projectURL: projectURL, dataFile: dataFile), usage)
    }

    static func evaluateModelRun(
        baseURL: String,
        model: String,
        projectURL: URL,
        runID: String,
        previousRun: String?,
        rules: String,
        diagnosticSummary: String,
        apiKey: String = "",
        sessionId: String? = nil,
        s1Expression: String = "V/1000",
        s1for2CompExpression: String = "V1/1000",
        s2Expression: String = "V/1000",
        s2for2CompExpression: String = "V2/1000",
        derivedVUnit: String = "L",
        derivedCLUnit: String = "L/h",
        isCovariatePhase: Bool = false,
        isInheritedHandoffMode: Bool = false,
        apiFormat: APIFormat = .openAICompatible
    ) async throws -> (text: String, usage: TokenUsage?) {
        let url = try endpointURL(baseURL: baseURL, path: "chat/completions")
        let modelLibrary = modelLibraryText(projectURL: projectURL)
        let diagnosticLimit = contextLimit(baseURL: baseURL, remote: 30_000, local: 18_000)
        // Static library/rules live in the system message so DeepSeek-style prefix
        // caches can reuse the same prefix across evaluation and drafting calls.
        let staticCtx = canonicalRuleContext(rules: rules, modelLibrary: modelLibrary)
        let prompt = """
        You are a PopPK model evaluation AI following FDA guidance. Decide whether the current model should be ACCEPTed as final or REVISEd.

        Start with exactly one word: ACCEPT or REVISE.
        \(Self.responseLanguageDirective)

        \(isInheritedHandoffMode ? """
        ━━━ INHERITED MOTHER-MODEL HANDOFF EVALUATION MODE ━━━
        This is the first full-dataset handoff model built from an IV mother model.
        - Inherited CL/V/Q/V2/V3 THETA/OMEGA entries are intentionally FIXED in this handoff. Their FIX status is NOT a REVISE reason.
        - Do NOT require a stable 1-compartment model or a higher-compartment comparison; the inherited compartment structure is authoritative.
        - If this run is S+C and has no syntax/NMTRAN failure or boundary estimate, answer ACCEPT so the next run can release ALL inherited structural FIXes.
        - Non-zero ETABAR for inherited fixed parameters is expected while those parameters are pinned; the release round addresses it.
        - Do not block acceptance solely because IIV-KA shrinkage is high while structural parameters are still fixed. Re-evaluate RSE after the release round; eta-shrinkage is not an accept/revise criterion.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """ : "")}

        ━━━ SELF-CHECK BEFORE ANY ACCEPT (MANDATORY) ━━━
        Before you are allowed to output ACCEPT, you MUST verify ALL of the following and state the result in your reasoning:
        0. THIS RUN ITSELF MUST BE S+C AND WELL-FITTED (hard gate on the SPECIFIC run you are accepting — not just "some run" in that compartment):
           - MINIMIZATION: its .lst MUST contain "MINIMIZATION SUCCESSFUL". If minimization was NOT successful
             (e.g. "MINIMIZATION TERMINATED", "NO. OF FUNCTION EVALUATIONS EXCEEDED", "MINIMIZATION NOT TESTED", or no
             successful-minimization line), you CANNOT ACCEPT this run — output REVISE and repair WITHIN the same
             compartment count. A run that did not minimize is NEVER acceptable, no matter how good the GOF/VPC plots look.
           - COVARIANCE: its covariance step must be successful — no "COVARIANCE STEP ABORTED/FAILED", no
             "R MATRIX IS NOT POSITIVE DEFINITE", and it must show "COVARIANCE STEP SUCCESSFUL" or "ELAPSED COVARIANCE"
             with a non-empty .cov file. If the covariance step failed, REVISE.
           - BOUNDARY: no parameter may be "PARAMETER IS NEAR ITS BOUNDARY". A boundary estimate means the run is not stable.
           - PARAMETER FITTING (precision): key structural PK parameters (CL, V1, V2, Q and their IIV) must have
             %RSE < 50%. Do NOT use eta-shrinkage as an accept/revise criterion for ETA/PK parameters; use %RSE,
             boundary, covariance, and convergence. A run whose key parameters cannot be estimated with reasonable precision
             is NOT acceptable even if it minimized and its OFV is low.
           - MODEL PERFORMANCE (fit): the run must show a credible fit — successful minimization with a finite, sensible
             OFV and low residual error. Diagnostics (GOF/VPC) ALONE are NEVER sufficient to ACCEPT; you must ALSO confirm
             the estimation + parameter evidence above. If ANY of the above fails, output REVISE, never ACCEPT.
        1. COMPLETENESS OF EXPLORATION: For EVERY compartment count that exists in this project (1-comp, 2-comp, 3-comp),
           at least one STABLE + CONVERGED (S+C) model has been produced. If any compartment count has only failed/unconverged
           runs and was NOT explicitly marked structurally FAILED with numeric evidence, you CANNOT ACCEPT — you must REVISE
           and continue iterating within that compartment count.
        2. IIV FIXING CLOSURE: You have applied the IIV-fixing strategy (fix one peripheral IIV at a time, reduce/perturb
           initial estimates, retry) and only concluded a parameter cannot carry IIV after repeated failed attempts with evidence.
        3. INITIAL ESTIMATE CONTINUITY: New model initial estimates were derived from the PREVIOUS run's post-hoc estimates
           with small perturbations (±10–20%), not invented from scratch.
        If ANY of (0)(1)(2)(3) is not satisfied, output REVISE, never ACCEPT.
        NOTE: Item (0) targets the specific run you are about to ACCEPT. Do NOT use the existence of a DIFFERENT S+C run in the
        same compartment count to justify accepting a run that itself failed minimization/covariance or has imprecise parameters.

        ━━━ OFV DECISION RULE — HARD CONSTRAINT (OVERRIDES ALL ELSE) ━━━
        When the Evidence includes an OFV table or .ext file with OBJ values for BOTH the current run
        and a previous run of a DIFFERENT compartment count, compute ΔOFV = OFV_simpler − OFV_complex.
        This rule is ABSOLUTE — you CANNOT override it with GOF/VPC/subjective judgment:

        ΔOFV > 10.83 (p<0.001, 2 df): The more complex model (2-comp vs 1-comp, or 3-comp vs 2-comp)
            is STATISTICALLY SIGNIFICANTLY better. You MUST REVISE to continue with the MORE COMPLEX model.
            Do NOT say ACCEPT. Do NOT say "1-comp is adequate." The data proves otherwise.
        ΔOFV > 3.84 (p<0.05, 1 df): The improvement is significant. REVISE and favor the complex model.
        ΔOFV ≤ 3.84: The improvement is NOT significant. The simpler model is preferred.

        If the Evidence contains an OFV for the current 2-comp run and you know the 1-comp OFV
        (from Parameter Estimates or the .ext file), you MUST compute and apply this rule.
        If you cannot find both OFV values, note this and proceed with diagnostic evidence.

        EXAMPLE: If 1-comp OFV=850.0 and 2-comp OFV=835.0, then ΔOFV=15.0 > 10.83.
        You MUST output REVISE and continue with the 2-compartment model.

        ━━━ PARAMETER-LEVEL COMPARISON (in addition to OFV) ━━━
        MANDATORY: Every structural candidate (1/2/3-comp) MUST achieve successful minimization (S) AND
        successful covariance (C) before it can be compared or selected as the base model. A candidate
        lacking S or C is INELIGIBLE regardless of its OFV.
        Comparing a simpler vs a more complex model is NOT decided by OFV alone. You MUST also compare
        PARAMETER PRECISION / BEHAVIOR of the two models:
        - Key structural PK parameters (CL, V1, V2, Q and their IIV) must have %RSE < 50%.
          Eta-shrinkage is NOT an accept/revise criterion for ETA/PK parameters; use %RSE, boundary,
          covariance, and convergence. Inspect the ESTIMATION STATUS block in the Evidence.
        - A more complex model is preferred ONLY IF it is BOTH:
            (a) significantly better by ΔOFV (the rule above), AND
            (b) its structural parameters have acceptable precision (RSE < 50%) and no boundary estimates.
        - If the more complex model shows WORSE parameter behavior — e.g., new compartment parameters
          (Q, V2, Q3, V3) with RSE > 50% or estimates near a boundary — despite only a
          BORDERLINE ΔOFV (≤ threshold), you MUST prefer the SIMPLER model. A numerically lower OFV from
          an imprecisely estimated complex model is NOT a real improvement.
        - Never choose a model whose key PK parameters cannot be estimated with reasonable precision,
          even if its OFV is lower.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        ERROR-FIRST DECISION RULE:
        - If the Evidence contains NONMEM/PsN/NMTRAN failure messages, FMSG text, "AN ERROR WAS FOUND", "NMtran failed", "There is no output", "Could not parse the output file", or a non-zero NONMEM/PsN exit code, you MUST start with REVISE.
        - In that case, diagnose the exact failing control-stream block first and give NEXT_ACTION as one code-level repair. Do not recommend GOF/VPC, covariates, extra compartments, or parameter refinement until the model compiles and produces run*.lst/run*.ext.
        - Use the error line, approximate position marker, and named undefined symbol when present.

        CRUCIAL: The model uses combined proportional+additive error: W = SQRT(THETA(k)**2*IPRED**2 + THETA(k+1)**2). With this formulation, $SIGMA is ALWAYS 1 FIX. The residual SDs are estimated as THETA parameters (Prop.RE and Add.RE). NEVER suggest changing $SIGMA to 2 or estimating SIGMA values — the model already captures all residual variability through the THETAs.
        NEVER suggest adding $SIGMA 2 — this is a NONMEM syntax error that will make the model fail.

        SCALE PARAMETER PLACEMENT RULE:
        S1 or S2 MUST be the LAST line of $PK (after all THETA/ETA definitions).
        IV 1-cmt: S1=\(s1Expression). IV 2+/3-cmt: S1=\(s1for2CompExpression).
        Oral / SC / extravascular 1-cmt: S2=\(s2Expression). Oral / SC / extravascular 2+/3-cmt: S2=\(s2for2CompExpression).
        The scale parameter references V or V1/V2 which must be defined BEFORE the S1/S2 line.
        ⚠ CRITICAL: S1/S2 scaling depends on your dataset's AMT & DV units.
        S1=\(s1Expression) / S1=\(s1for2CompExpression) and S2=\(s2Expression) / S2=\(s2for2CompExpression) are correct for your dataset.
        Do NOT blindly write /1000 — use the exact expression above.

        PROGRESSIVE MODELING STRATEGY — follow this priority order:

        ⚠️ ONE-CHANGE-PER-RUN HARD RULE (NO cross-step operations):
        Each new run MUST contain EXACTLY ONE structural change. You are FORBIDDEN from combining
        distinct improvements into a single run:
        
        ❌ WRONG: escalate 1-comp → 2-comp AND fix a problematic parameter (residual or IIV) in the same run.
        ❌ WRONG: fix Add.err AND fix Prop.err in the same run.
        ❌ WRONG: fix an IIV AND fix a residual component in the same run.
        
        ✅ RIGHT: Examine ALL residual error (Add.err, Prop.err) and ALL IIV parameters.
                  Pick the SINGLE parameter with the WORST RSE% (>100% threshold).
                  Fix ONLY that one parameter to 0 at the CURRENT compartment.
                  Re-run to confirm stability. THEN consider escalation in a LATER run.
        
        Examples:
          run001: 1-comp S+C, Add.err RSE=120%, Prop.err RSE=30%, IIV-CL RSE=80%, IIV-V RSE=35%
            → Run002: fix Add.err to 0 (worst RSE = 120% > 100%), keep 1-comp and everything else unchanged.
        
          run001: 1-comp S+C, Add.err RSE=40%, Prop.err RSE=25%, IIV-CL RSE=45%, IIV-V RSE=150%
            → Run002: fix IIV-V (OMEGA for V to its last estimated variance, e.g. 0.08 FIX), keep 1-comp and everything else unchanged.
        
          run002 (after fix): 1-comp proportional-only S+C, IIV-CL RSE=20%, IIV-V fixed.
            → Run003: now stable → escalate to 2-comp.
        
        A run may perform EITHER (a) ONE residual/IIV fix at the CURRENT compartment count,
        OR (b) ONE compartment-level escalation — never both simultaneously.
        Rationale: base models are compared head-to-head to pick the ROBUST one, so each candidate
        must differ from its parent by exactly one change to attribute OFV/behavior differences cleanly.

        1. First establish the best structural model at EACH compartment level — STABILIZE BEFORE YOU ESCALATE:
           - Run 1-comp (ADVAN1 TRANS2 for IV, ADVAN2 TRANS2 for oral) as run001, with combined error + full IIV.
           - ⚠️ DO NOT escalate to 2-comp immediately. First make the CURRENT compartment level STABLE.
             Work at the SAME compartment count, ONE change per run, until the model is robust:
               * If a residual error component has RSE% clearly too large (see step 4), fix it — at the SAME comp.
               * If an IIV component has RSE% clearly too large (see step 2), fix it — at the SAME comp.
           - ONLY after the 1-comp model is STABLE (S+C, key RSE acceptable) do you escalate:
               * next run: test 2-comp and compare via ΔOFV.
           - If 2-comp ΔOFV > 10.83, continue with 2-comp. Then (same rule) stabilize 2-comp first, then test 3-comp.
           - If 2-comp ΔOFV ≤ 3.84, you may return to 1-comp.
           - CRITICAL: The final base model is the SIMPLEST model that is NOT significantly worse than any more complex model.
             Example: 2-comp OFV=7666, 3-comp OFV=7665 (Δ=1.0). 3-comp is NOT significantly better → choose 2-comp.
             Do NOT choose 3-comp just because its OFV is numerically lower by a tiny amount.
           - BASE MODEL COMPARISON: each compartment level (1/2/3-comp) should produce its own stable S+C model.
             At the end, compare these stable base models head-to-head (OFV + parameter precision + GOF/VPC) and
             select the MOST ROBUST one — the simplest model whose key parameters are estimated with good precision.
        2. When escalating compartments (1→2 or 2→3) — IIV WORKFLOW:
           - DEFAULT: every PK parameter gets IIV (OMEGA=0.04). The library templates already include
             IIV on ALL parameters — COPY the template, do NOT strip IIV from new compartments.
           - FIRST, UNFIX/ENABLE IIV on every PK parameter EXCEPT those already fixed in the parent model.
             1-comp→2-comp: enable IIV on CL, V1, Q, V2; only inherit fixes that existed in the 1-comp parent
               (e.g., if 1-comp had V IIV fixed → V1 IIV stays fixed; if CL IIV fixed → CL stays fixed).
             2-comp→3-comp: enable IIV on Q2, V2, Q3, V3; only inherit fixes that existed in the 2-comp parent.
           - CENTRAL→PERIPHERAL IIV CHAIN (HARD): if a CENTRAL parameter's IIV was FIXED in the parent,
             its peripheral relatives MUST ALSO stay fixed (they cannot be estimated reliably):
               • CL IIV fixed in parent → Q (2-comp), Q2 and Q3 (3-comp) IIV stay FIXED.
               • V/V1 IIV fixed in parent → V2 (2-comp), V3 (3-comp) IIV stay FIXED.
             Apply this BEFORE enabling: e.g., if 1-comp had V IIV fixed, do NOT unfix V3 in 3-comp.
           - AFTER the run: for each parameter whose IIV was just ENABLED, check its RSE%:
             if RSE% > 50% → FIX it to the last estimated OMEGA variance (e.g. 0.05 FIX).
             Do NOT fix OMEGA to 0 unless the estimate is already at the zero boundary.
             BEFORE fixing, verify:
               (i) MODEL CHANGE: does fixing cause a large ΔOFV jump (worse fit)?
               (ii) STABILITY: does fixing avoid a near-singular covariance / rounding error?
             Only fix when RSE>50% shows the IIV is unreliable OR it causes instability.
           - NEVER fix two parameters' IIV in the same run — fix ONE, re-run, then judge the next.
           - If the escalated run FAILS minimization: fix peripheral IIV one at a time,
             order: 3-comp Q3→V3→Q2→V2; 2-comp Q→V2. Then accept the lower compartment if only CL+V1 left.
        3. Covariance or minimization failure on higher-compartment model:
           - DO NOT retreat to simpler model immediately.
           - Fix ONE parameter's IIV at a time, in this order:
             a) Fix IIV on Q3 (3-comp) or Q (2-comp) — peripheral clearances FIRST.
             b) Fix IIV on V3 (3-comp) or V2 (2-comp) — peripheral volumes SECOND.
             c) Fix IIV on remaining peripheral parameters one at a time.
             d) Only AFTER all peripheral IIVs are fixed, consider fixing central IIV (CL, V, V1).
           - ⚠️ CHAIN RULE: If central IIV (CL or V/V1) is ALREADY fixed, its peripheral
             relatives (Q/Q2/Q3, V2/V3) MUST also stay fixed — NEVER leave peripheral IIV free
             while central IIV is fixed. Peripheral IIV has no meaning without central variance.
           - Also try: reduce OMEGA BLOCK size, switch to DIAGONAL OMEGA.
           - Only after 3+ single-parameter fix attempts fail, consider retreating.
        4. Within each compartment count, keep iterating until you obtain a STABLE + CONVERGED (S+C) model — do NOT cap the number of attempts:
           - The goal for EACH compartment count (1-comp, 2-comp, 3-comp) is to produce at least one S+C model. Only a model that is S+C counts as a valid result for that compartment.
           - If a model fails minimization or covariance, do NOT immediately move to the next compartment count.
           - Instead, create a new run WITHIN the same compartment count and try fixes:
             a) Fix problematic IIV to its last estimated OMEGA variance in $OMEGA
                (e.g. 0.05 FIX); do not pin an estimable IIV to 0.
             b) Reduce initial estimates by 50%.
             c) Try different TRANS (e.g., TRANS1 vs TRANS4).
             d) Re-seed initial estimates from the PREVIOUS run's post-hoc estimates with small perturbations (±10–20%), then re-fit.
           - NEVER declare a compartment count "FAILED / not viable" just because a few attempts did not converge. Only mark it FAILED if it is NUMERICALLY / STRUCTURALLY impossible to fit (e.g., the peripheral compartment collapses to zero, or every attempt hits a hard boundary / non-positive definite regardless of starting point).
           - When comparing across compartment counts, use the BEST S+C model from each compartment count (lowest OFV among successful runs). If a compartment count has NO S+C model, it is NOT eligible for comparison and MUST NOT be used to justify skipping or down-selecting.
        5. ⚠️ CRITICAL — FIX RESIDUAL ERROR MODEL ON THE CURRENT COMPARTMENT COUNT FIRST ⚠️
           Even if minimization (S) and covariance (C) are successful, you MUST check and
           simplify the residual error model AT THE SAME COMPARTMENT COUNT before escalating.
           Do NOT escalate 1→2 comp or 2→3 comp in the same run that fixes the residual model.
           
           The default combined (proportional + additive) error adds an extra THETA. If one
           component cannot be estimated, fix it to 0 — the compartment structure is not the
           problem, the error model is.
           
           WORKFLOW (1-comp example):
             run001: 1-comp combined error → Add.err RSE = 142% (very high).
             run002: SAME 1-comp, fix Add.err to 0 → proportional-only error. (ONE change: error model only.)
             run003: re-run 1-comp to confirm S+C stable. (NO escalation yet.)
             run004: ONLY NOW, escalate to 2-comp and compare via ΔOFV.
           This keeps each base-model candidate differing by exactly ONE change, so head-to-head
           comparison (which base model is most ROBUST) is clean.
           
           ERROR MODEL SIMPLIFICATION RULES (check in order — execute at SAME compartment count, BEFORE escalating):
          GOAL: Fixing a residual component to ZERO is meant to simplify the COMBINED error
          (W = SQRT(Prop^2*IPRED^2 + Add^2)) into a PURE proportional model (Add→0, drop the
          additive term) or a PURE additive model (Prop→0, drop the proportional term).
          ALWAYS pin the unreliable component to `0 FIX` — never to its initial value, and
          never keep a nonzero fixed value, because that defeats the simplification.
          a) If Add.err (additive residual SD) THETA has RSE > 100% OR estimate ≤ 1e-6
             (at lower boundary):
             → Do NOT modify model structure. Keep $ERROR entirely unchanged.
             → Do NOT remove any THETA lines.
             → PIN THE PARAMETER TO ZERO, not to its initial value. Change the Add.err
               THETA to a fixed near-zero value so the additive term contributes nothing:
                 Change `(0, 1.0)  ; Add.RE (sd)`  →  `0 FIX  ; Add.RE (sd)`
               (or `(0, 0.0001) FIX` if a plain `0 FIX` is rejected by the NONMEM build).
             → The FIX keyword pins the parameter at ZERO, so W reduces to proportional-only:
               W = SQRT(THETA(prop)^2*IPRED^2 + 0) = THETA(prop)*IPRED.  Do NOT fix it at
               the initial value (e.g. 1.0) — that would leave a large additive term intact.
             → Keep $SIGMA 1 FIX. Keep the combined error W expression as-is.
             This effectively makes the error proportional-only while preserving
             the mod structure for easy reversion.
             
             ✅ Example: run001 with CL/V 1-comp S+C has Add.err RSE = 142%.
               → Run002: set Add.err THETA to `0 FIX`, change nothing else in mod structure.
               → Run003: re-run to confirm S+C stable.
               → Run004: NOW escalate to 2-comp.
             
          b) If Prop.err (proportional residual SD) THETA has RSE > 100% OR estimate ≤ 1e-6
             (at lower boundary):
             → Do NOT modify model structure. Keep $ERROR entirely unchanged.
             → Do NOT remove any THETA lines.
             → PIN THE PARAMETER TO ZERO. Change the Prop.err THETA to a fixed zero so the
               proportional term contributes nothing:
                 Change `(0, 0.15)  ; Prop.RE (sd)`  →  `0 FIX  ; Prop.RE (sd)`
               (or `(0, 0.0001) FIX` if a plain `0 FIX` is rejected).
             → W then reduces to the additive-only component. Do NOT fix it at the initial
               value (e.g. 0.15) — that would leave a proportional term intact.
             → Keep $SIGMA 1 FIX.
             This effectively makes the error additive-only while preserving
             the mod structure for easy reversion.
             
          c) If BOTH Add.err AND Prop.err have RSE > 100%:
             → Keep the component with lower RSE, fix the worse one to ZERO.
             → If both equally bad, prefer proportional-only (fix Add.err to 0).
             
          d) RSE threshold for simplification: > 100% (clearly unreliable estimate).
             Boundary threshold: estimate ≤ 1e-6 (effectively zero, at lower bound).
             NOTE: A moderate RSE (e.g. 50–100%) is NOT yet a reason to fix — only flag/monitor it.
             Only fix when RSE > 100% or at the boundary.
             
          e) After simplification, re-run the model at the SAME comp count. If OFV increase
             < 3.84 (1 df, p>0.05), the simpler error model is adequate — accept it at this comp.
             
          - When simplifying error model, do NOT remove THETA lines — only pin to `0 FIX`.
            No renumbering of THETAs needed.
          - Only attempt error model simplification ONCE per run. If the simplified model
            also has issues, accept it and move on.
          - If neither component has RSE > 100% → keep combined error, proceed to step 6.
             
        6. After error model is fixed, refine IIV on existing parameters:
           - Only remove IIV based on %RSE > 100%, repeated convergence/covariance failure, or a boundary
             estimate. Do NOT use eta-shrinkage as a reason to remove IIV.
           - PROACTIVE IIV UNFIXING (CRITICAL — DO NOT SKIP):
             After a model converges successfully (minimization OK, covariance OK):
             Check $OMEGA block: if ANY peripheral parameter (Q, V2, Q3, V3) has a FIXed OMEGA
             → the NEXT run MUST attempt to unfix/re-add IIV for ONE parameter.
             Priority order: Q (or Q2) first, then V2, then Q3, then V3.
             Set OMEGA = 0.04 for the unfixed parameter, add EXP(ETA(n)) in $PK.
             CHAIN GUARD: do NOT attempt to unfix a peripheral parameter whose CENTRAL relative
             was fixed — i.e., do NOT unfix V2/V3 if V/V1 IIV is fixed; do NOT unfix Q/Q2/Q3
             if CL IIV is fixed. They were fixed for a reason and cannot be estimated reliably.
             Only stop trying when ALL eligible peripheral IIV have been attempted (or blocked by chain).
             A converged model with fixed peripheral IIV (due to chain or failed attempts) is acceptable
             as final WITHOUT further unfixing once every eligible param has had one attempt.

        COVARIATES ARE FORBIDDEN IN PHASE 1. Any step 6 (covariate) is a PHASE VIOLATION.
        Covariates begin ONLY after Phase 1 ACCEPT transitions to Phase 2.

        ANTI-OSCILLATION RULES:
        - NEVER propose a change that UNDOES what the previous iteration just did (e.g., if run(N-1) removed IIV on V, do NOT re-add it in runN).
        - If both the current and previous iteration propose toggling the error model, STOP and ACCEPT the simpler model. Accept that some parameters cannot be estimated with the available data.

        If REVISE, provide:
        - NEXT_ACTION: exactly ONE concrete model change (which record/subroutine/parameter changes)
        - TEMPLATE_ID: the AutoPMX template to use if a structural change is needed; otherwise KEEP_CURRENT_TEMPLATE
        - RATIONALE: which diagnostic evidence supports it, WITH @ref[source] citation
        - SAFETY_CHECK: NONMEM syntax rule to preserve

        All RATIONALE lines must include at least one @ref[RULE_ID: description] citation from the rule context.

        📊 EVIDENCE TRACEABILITY — When your RATIONALE claims a parameter is poorly estimated,
        you MUST cite the EXACT .lst row(s) that support the claim:
          - NUMSIGDIG line: e.g. "Add.err has only 2.9 significant digits (NUMSIGDIG < 3)"
          - GRADIENT line:  e.g. "Add.err final gradient = 9.2e-4 (near zero, parameter not moving)"
          - NPARAMETR line: e.g. "Add.err = 1.001 (unchanged from initial 1.0, no information in data)"
          - %RSE line:      e.g. "Add.err RSE = 415838% (from THETA table in .lst)"
        This makes each automated decision fully traceable back to the NONMEM output.

        ACCEPT only when ALL of the following hold (HARD REQUIREMENT — no exceptions):
        - Minimization SUCCESSFUL (S)
        - Covariance step SUCCESSFUL (C) — a .cov file exists, or "COVARIANCE STEP SUCCESSFUL" appears (NOT aborted)
        - Parameter RSE < 50% for key structural parameters (CL, V1, V2, Q)
        - No boundary estimates for primary PK parameters
        - All GOF plots show no systematic bias; CWRES centered around zero without trends
        - (Phase 2 only) ALL available covariates from the Dataset have been tested
        If S or C is MISSING, you MUST output REVISE — never ACCEPT. Diagnose and fix estimation
        (fix unreliable IIV to its last estimated OMEGA variance, widen $THETA bounds,
         try DIAGONAL OMEGA, reduce MAXEVAL) and re-run
        until BOTH S and C are achieved. A model that cannot reach S+C is NOT a valid base model.

        COVARIANCE FAILURE ON HIGHER-COMPARTMENT MODELS:
        - A 2-comp or 3-comp model with successful minimization but FAILED covariance step can NEVER be
          accepted as the final base model. You MUST output REVISE and apply the covariance-failure fixes
          in PROGRESSIVE MODELING STRATEGY step 3 (fix ONE peripheral IIV at a time, widen $THETA bounds,
          switch to DIAGONAL OMEGA) until the covariance step SUCCEEDS (C).
        - Only after the covariance step succeeds AND the new compartment parameters have RSE < 50% may the
          model be considered. If repeated fixes still cannot produce a successful covariance step, the
          data may not support the extra compartment — prefer the simpler model that DID achieve S+C.

        TWO-PHASE MODELING STRATEGY:

        ━━━ IRON RULE: TWO PHASES ARE COMPLETELY SEPARATE ━━━
        Phase 1 = ONLY structural model work. Phase 2 = ONLY covariates.
        You CANNOT work on both in the same run. You CANNOT start Phase 2 until Phase 1 is ACCEPTed.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        \(isCovariatePhase ? """
        ═══ PHASE 2: COVARIATE MODEL BUILDING (ACTIVE NOW) ═══
        The structural model has been ACCEPTed. You are now evaluating covariates.
        - Do NOT change ADVAN, TRANS, compartment count, error model, or IIV.
        - Verify that ALL available covariates from the dataset have been tested.
        - If any covariate is untested, the model is NOT ready to accept.
        """ : """
        ═══ PHASE 1: BASE MODEL SELECTION (ACTIVE NOW) ═══
        The OFV DECISION RULE at the top of this prompt is the FINAL authority.

        ALLOWED changes: compartment count, error model, IIV structure.
        FORBIDDEN: WT, AGE, SEX, STUDY, or ANY covariate relationship.

        ═══ RESIDUAL ERROR MODEL SIMPLIFICATION (DO THIS FIRST) ═══
        Before escalating compartments, fix the residual error model first.
        See ERROR MODEL SIMPLIFICATION RULES in step 4 above.
        ═━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        Compartment escalation (only after error model is fixed):
        1-comp → 2-comp → 3-comp (test ONE level higher each time)

        ═══ HIGH-COMPARTMENT STOP RULE ═══
        Check the COMPARTMENT COMPARISON (ΔOFV) section in the Evidence below.
        If the current 3-comp model's ΔOFV vs the best 2-comp model is NOT significant
        (ΔOFV ≤ 10.83), then 3-comp does NOT improve the fit meaningfully.
        In that case: ACCEPT the 2-comp model as the final base model.
        Only if 3-comp IS significantly better (ΔOFV > 10.83) should you accept 3-comp.
        A 3-comp with high %RSE on peripheral parameters is NOT a valid base model.
        ═━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
        """)}
        NEVER skip a level. After 2-comp is tested vs 1-comp, test 3-comp vs 2-comp before finalizing.
        The ΔOFV computed from the Evidence dictates the decision. No exceptions.
        ONLY output ACCEPT when the structural model is truly finalized — meaning EVERY compartment level (1-comp, 2-comp, 3-comp) has produced at least one STABLE + CONVERGED (S+C) model (or has been explicitly marked structurally FAILED with numeric evidence). A compartment level with only unconverged/failed runs does NOT count as "tested".

        ═══ PHASE 2: COVARIATE MODEL BUILDING ═══
        FORBIDDEN in Phase 2: changing compartment count, error model type, or IIV structure.
        If you suggest a structural change in Phase 2, that is a PHASE VIOLATION.
        ONLY allowed in Phase 2: adding/removing covariate relationships.
        After Phase 1 base model is accepted, IMMEDIATELY begin covariate screening.
        The next run AFTER base model acceptance MUST add at least one covariate.

        ━━━ COVARIATE COMPLETENESS CHECK (HARD RULE) ━━━
        Check the "Dataset:" section at the top of Evidence: "Available covariates: <actual columns>".
        EVERY available covariate MUST be tested. For each covariate, test against EVERY relevant PK param.
        If any listed covariate has NOT been tested, you MUST output REVISE (not ACCEPT).
        Required tests: use the Dataset profile's ACTUAL available covariates (for example
        WT, AGE, SEX, STUDY, DOSE, ROUTE, ADA, RACE, TRT when present in $INPUT). Test each
        available covariate against every relevant PK parameter. Do NOT require covariates
        that are not in the current project's dataset/$INPUT.
        Each covariate is an INDEPENDENT scientific question. One being significant does NOT excuse skipping another.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        Steps:
        1. Read the ACTUAL covariates in the current project's Dataset profile and $INPUT.
           Do not invent or require WT, AGE, SEX, or STUDY unless they are present.
        2. If WT is present, test allometric scaling on all PK params
           (0.75 for CL/Q, 1.0 for V).
        3. For each other continuous covariate present, test on clearance and volume params.
        4. For each categorical covariate present, test on clearance and volume params.
        Keep each if ΔOFV > 3.84 (forward). Remove if ΔOFV < 6.63 (backward).
        5. Clinical significance: PK ratio 0.8–1.25.
        6. Bootstrap (≥200 samples) validates final model.

        Do NOT accept Phase 2 until ALL available covariates from the dataset have been tested.

        Previous run: \(previousRun ?? "none")
        Current run: \(runID)

        Evidence:
        \(diagnosticSummary.prefix(diagnosticLimit))
        """

        return try await sendChatPrompt(
            url: url, model: model, prompt: prompt,
            systemPrompt: staticCtx,
            temperature: 0.1, timeout: 120, apiKey: apiKey, sessionId: sessionId,
            apiFormat: apiFormat
        )
    }

    static func proposeOptimizedModel(
        baseURL: String,
        model: String,
        projectURL: URL,
        sourceRun: String,
        nextRun: String,
        rules: String,
        diagnosticSummary: String,
        isCovariatePhase: Bool = false,
        forceCompartmentEscalation: Bool = false,
        forceSameCompartment: Bool = false,
        forceReleaseInheritedFixes: Bool = false,
        forceReAddDroppedIIV: Bool = false,
        apiKey: String = "",
        sessionId: String? = nil,
        s1Expression: String = "V/1000",
        s1for2CompExpression: String = "V1/1000",
        s2Expression: String = "V/1000",
        s2for2CompExpression: String = "V2/1000",
        derivedVUnit: String = "L",
        derivedCLUnit: String = "L/h",
        apiFormat: APIFormat = .openAICompatible
    ) async throws -> (text: String, usage: TokenUsage?) {
        let source = projectURL.appendingPathComponent("run\(sourceRun).mod")
        let rawSource = ((try? String(contentsOf: source, encoding: .utf8)) ?? "")
        // Strip any accidentally-embedded data rows from the source model BEFORE
        // sending it to the LLM. If the LLM sees data rows in the source, it will
        // learn to copy that pattern into the next model.
        let sourceText = stripInlineDatasetRows(String(rawSource.prefix(20_000)))
        let url = try endpointURL(baseURL: baseURL, path: "chat/completions")
        let modelLibrary = modelLibraryText(projectURL: projectURL)
        let dataFile = dataFileName(from: String(sourceText)) ?? discoverDataset(in: projectURL) ?? "dataset.csv"
        let inputRecord = inputRecordFromDataset(projectURL: projectURL, dataFile: dataFile) ?? defaultInputRecord
        let diagnosticLimit = contextLimit(baseURL: baseURL, remote: 20_000, local: 12_000)
        let staticCtx = canonicalRuleContext(rules: rules, modelLibrary: modelLibrary)

        // Detect current compartment count from source mod to enforce NO DOWNGRADE
        let sourceCompartment = detectCompartmentCount(String(sourceText))
        let noDowngrade = sourceCompartment > 1
        let compWarning = noDowngrade ? """
        🔴 HARD CONSTRAINT — run\(sourceRun) is a \(sourceCompartment)-comp model.
        run\(nextRun) MUST ALSO be \(sourceCompartment)-comp. Do NOT create a lower-comp model.
        """ : ""
        let handoffReleaseBlock: String
        if String(sourceText).uppercased().contains("IV-ANCHOR HANDOFF")
            || String(sourceText).uppercased().contains("INHERITED IV STRUCTURAL THETA/OMEGA ARE FIXED")
            || String(sourceText).uppercased().contains("INHERITED IV THETA/OMEGA ARE FIXED") {
            if hasInheritedStructuralFixes(String(sourceText)) {
                handoffReleaseBlock = """
            ━━━ IV-ANCHOR HANDOFF RELEASE ━━━
            run\(sourceRun) is a full-dataset handoff model built from an IV anchor. The inherited IV
            structural THETA/OMEGA entries are intentionally FIXED so the first full-dataset model can
            estimate residual error and KA (and F1 when both IV and SC routes exist) before releasing
            the structural parameters.
            - If run\(sourceRun) achieved S+C: release ALL inherited THETA/OMEGA FIXes in
              run\(nextRun) at once (CL/V/V1/V2/Q/Q2/Q3/V3). Keep KA/F1 estimated.
              Preserve the source model's ETA/OMEGA architecture exactly: do not add or remove IIV.
            - Residual error (Prop.RE/Add.RE) must NOT be fixed in a mixed full-dataset handoff model.
            - If run\(sourceRun) is NOT S+C: keep the inherited structural FIXes unchanged and repair
              only residual error/KA/F1 or the control stream. Do NOT release more structural parameters
              until S+C is achieved.
            - Do NOT change route, ADVAN family, depot/central compartment numbering, or add covariates.
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

            """
            } else {
                handoffReleaseBlock = """
            ━━━ INHERITED HANDOFF: FIXES ALREADY RELEASED ━━━
            run\(sourceRun) is a full-dataset handoff model built from an IV anchor. Its inherited
            structural FIXes have already been released for full-dataset estimation.
            - Do NOT re-add FIX to CL/V/V1/V2/Q/Q2/Q3/V3.
            - Keep the same route and compartment count; do not add covariates unless Phase 2 is active.
            - Continue refining estimation only.
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

            """
            }
        } else {
            handoffReleaseBlock = ""
        }

        let prompt = """
        You are an expert NONMEM pharmacometrician evolving a PopPK model step by step.
        Create run\(nextRun).mod by applying EXACTLY ONE specific improvement to run\(sourceRun).mod.
        Return ONLY the complete .mod file. No markdown, no explanation.
        \(Self.responseLanguageDirective)

        ━━━ 🔴 ABSOLUTE PROHIBITION: NEVER PASTE DATASET ROWS 🔴 ━━━
        The CSV dataset rows (lines starting with . or numbers) MUST NEVER appear in the
        .mod control stream. Only $INPUT column labels and a $DATA file reference belong here.
        The CSV data is ALREADY available in a separate file — just reference it with $DATA.
        If you write data rows inside the control stream, the model WILL BE REJECTED.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        \(compWarning)
        \(handoffReleaseBlock)

        \(forceReleaseInheritedFixes ? """
        ━━━ INHERITED MOTHER-MODEL MODE: RELEASE ALL INHERITED FIXES ━━━
        run\(sourceRun) is an ACCEPTED full-dataset handoff model built from an IV mother model.
        Do NOT compare or add higher compartments, and do NOT change route/compartment count.
        Your ONLY task: remove FIX from every inherited structural THETA/OMEGA parameter
        (CL/V/V1/V2/Q/Q2/Q3/V3), keep KA/F1 and residual error estimated, and do not add covariates.
        Do NOT add, remove, or fix IIV. Preserve the source model's ETA/OMEGA architecture exactly:
        if a parameter has ETA in run\(sourceRun), keep that ETA; if it has no ETA, keep it bare.
        The deterministic release step will automatically restore or trim any missing/extra IIV.
        The model can then re-estimate the inherited parameters freely on the full mixed dataset.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
        """ : "")}
        \(forceReAddDroppedIIV ? """
        ━━━ INHERITED CHILD IIV RE-EXPLORATION ━━━
        run\(sourceRun) is a stable full-dataset child model whose inherited structural
        THETA/OMEGA FIXes have already been released. Before finalizing the child base model,
        re-add the previously dropped IIV/ETA terms for structural PK parameters that are
        currently bare (e.g. Q and V3 in an extravascular ADVAN4 2-compartment model).
        - Keep ADVAN/TRANS, compartment count, THETA, F1 and residual error unchanged.
        - Add EXP(ETA(n)) to the bare structural PK parameters and one matching $OMEGA row
          with initial 0.04.
        - Keep ETA numbering contiguous ETA1..ETAn and update $OMEGA, PATAB and runXXXX.ETA.
        - Do NOT fix any OMEGA to 0; use 0.04 as the initial estimate.
        - Do not add covariates or change the route/compartment structure.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        """ : "")}

        ━━━ SOURCE MODEL ANALYSIS CHECKLIST ━━━
        Before editing, compare run\(sourceRun).mod with the actual dataset:
        - Check ADVAN/TRANS, CMT numbering, ROUTE, DUR/RATE, S1/S2.
        - Do NOT blindly carry D1/D2 from the mother model when route/CMT changed.
        - For extravascular ADVAN2/4/12: CMT=1 is depot, CMT=2 is central, CMT=3+ are peripheral.
        - SC first-order dosing to CMT=1 must NOT use D1 unless SC dosing records carry DUR/RATE.
        - IV infusion delivered directly to central CMT=2 with DUR must use D2=DUR (with tiny fallback).
        - Preserve parent THETA/OMEGA/IIV unless this run's single intended change requires it.
        - NEVER paste dataset rows into the .mod. Use $DATA to reference the CSV file.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

        ━━━ SOURCE CITATION ━━━
        At the bottom of the .mod file AFTER $TABLE, add a comment block:
        ; --- AutoPMX Decision Rationale ---
        ; @ref[RULE_ID: brief reason]
        Cite the specific rule, template, or evidence that justifies each change you made.
        ━━━━━━━━━━━━━━━━━━━┛

        \(forceCompartmentEscalation ? """
        ━━━ FORCED COMPARTMENT ESCALATION — SYSTEM OVERRIDE ━━━
        The ACCEPT decision was overridden — next compartment MUST be tested before finalizing.
        Your ONLY task: upgrade compartment count while preserving the route.
        1-comp→2-comp: ADVAN1→ADVAN3 (IV) or ADVAN2→ADVAN4 (oral). Add Q, V2.
        2-comp→3-comp: ADVAN3→ADVAN11 (IV) or ADVAN4→ADVAN12 (oral). Add Q3, V3.
        Copy all parent THETA values. Add IIV on ALL new params (OMEGA 0.04-0.09).
        Do NOT change error model, existing IIV, or add covariates.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        """ : "")}
        \(isCovariatePhase ? """
        ━━━ COVARIATE SCREENING PHASE (PHASE 2) — ACTIVE NOW ━━━
        The base structural model has been ACCEPTED. You are NOW in covariate screening.
        Do NOT change the structural model (ADVAN/TRANS), error model, or IIV structure — they are FINALIZED.
        Your ONLY task: add EXACTLY ONE covariate relationship per run, following this order:

        STEP 1: Start with the first covariate present in the ACTUAL dataset profile.
          If WT is present, begin with WT allometric scaling on ALL PK parameters.
          If WT is absent, skip WT and move to the next available covariate.

        ━━━ CORRECT EXPONENTS (FIXED, not estimated) ━━━
        Clearance-related: CL, Q, Q2, Q3 → exponent = 0.75 FIX
        Volume-related:    V, V1, V2, V3   → exponent = 1.0  FIX
        Add EXACTLY 2 new THETAs: (0, 0.75) FIX and (0, 1.0) FIX
        REUSE the same exponent THETA for all params of the same type
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        Example for 2-comp IV model:
          TVCL = THETA(1) * (WT/median_WT)**THETA(NEW_CL_EXP)    → exponent = 0.75 FIX
          TVV1 = THETA(2) * (WT/median_WT)**THETA(NEW_V_EXP)     → exponent = 1.0  FIX
          TVQ  = THETA(3) * (WT/median_WT)**THETA(NEW_CL_EXP)    → SAME 0.75 exponent
          TVV2 = THETA(4) * (WT/median_WT)**THETA(NEW_V_EXP)     → SAME 1.0  exponent
        Do NOT create separate exponents for each parameter.

        Compute median_WT from the dataset's WT column. Use the actual numeric value.

        STEP 2: SCM-style fast screening — test ALL available covariates as univariate additions.
          Check the Dataset profile embedded in the Diagnosis: "Available covariates: ..."
          Use the ACTUAL covariate columns from the current project's $INPUT/data file
          (e.g. WT, AGE, SEX, STUDY, DOSE, ROUTE, ADA, RACE, TRT).
          Test EVERY listed covariate against ALL relevant PK parameters.
          Run each as a SEPARATE model. Rank candidates by ΔOFV.
          Keep entries with ΔOFV > 3.84 (p<0.05, 1 df).
          Do NOT skip any covariate from the dataset profile — each must be tested.

        COVARIATE WRITING RULES BY TYPE:
        ━━━ CONTINUOUS covariates (WT, AGE, BSA, eGFR, etc.) ━━━
        Use POWER function centered at the median:
          TVCL = THETA(CL) * (COV/median_COV)**THETA(COV_exp)
        Initial exponent: 0.75 for WT on clearance, 1.0 for WT on volume.
        For AGE: try linear first → TVCL = THETA(CL) * (1 + THETA(AGE_eff)*(AGE-median_AGE))
        For other continuous covariates: estimate exponent from data (initial 0.1).

        ━━━ CATEGORICAL covariates (SEX, STUDY, RACE, etc.) ━━━
        Use PROPORTIONAL shift with indicator variable:
          IF (SEX.EQ.0) SEXFX = 1 + THETA(SEX_CL)   ! female effect
          IF (SEX.EQ.1) SEXFX = 1                     ! male reference
          TVCL = THETA(CL) * SEXFX
        Initial THETA for categorical: small value like 0.1 (10% difference).
        For STUDY with >2 levels: use nested IF statements or a separate THETA per level.

        ━━━ COMBINATION covariates ━━━
        WT + AGE combined:  TVCL = THETA(CL) * (WT/70)**0.75 * (1 + THETA(AGE)*(AGE-40))
        Only test combinations AFTER univariate screening confirms individual significance.

        STEP 3: Forward inclusion (full model building):
          Add significant covariates one at a time, most significant first.
          After each addition, re-evaluate remaining candidates (they may become non-significant).

        STEP 4: Backward elimination:
          From the full model, remove each covariate one at a time.
          Keep if ΔOFV increase > 6.63 (p<0.01, 1 df).
          Re-evaluate after each removal.

        STEP 5: Clinical significance:
          For each retained covariate, compute the PK parameter ratio at extreme covariate values.
          If ratio stays within 0.8–1.25, the covariate is statistically significant but NOT clinically relevant — remove it.

        Report results after completion: which covariates were kept, which removed, and why.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        """ : "")}
        ━━━ PARAMETER INHERITANCE — CRITICAL STABILITY RULE ━━━
        The NEXT model's initial $THETA values MUST be based on the FINAL estimates from the PREVIOUS run.
        Read the PARAMETER ESTIMATES (.ext file) section below to find the final estimate for each THETA.
        Then apply these rules to produce initial values for the NEXT model:

        RULE 1 — DIRECT COPY (same parameter, same meaning):
          If the parameter has the same meaning in both runs (e.g. CL→CL, V→V1):
            Copy the final estimate, then round UP to 3 significant figures.
            Example: final CL=23.471 → initial CL=23.5
            Example: final V1=87.30  → initial V1=87.3

        RULE 2 — GENTLE PERTURBATION (new parameter introduced):
          When introducing a NEW parameter (e.g. Q when escalating 1→2 comp):
            Use a SMALL fraction of the nearest existing parameter (see STRUCTURAL ESCALATION below).
            Do NOT use large arbitrary values — they WILL cause minimization failure.

        RULE 3 — NEVER REGRESS:
          Do NOT reset parameters to arbitrary round numbers (0.1, 1, 10, 100).
          The model already converged — the final estimates ARE the best starting point for the next iteration.
          If CL converged to 23.5, starting the next run with CL=10 is a guaranteed regression and may crash.

        RULE 4 — UPWARD BIAS (safe side):
          When rounding, always round UP (toward larger values), never down.
          An initial value slightly above the final estimate is safer than one below.
          If the final estimate is exactly on a round number boundary, keep it as-is.

        RULE 5 — $OMEGA AND $SIGMA:
          Copy $OMEGA and $SIGMA initial values from the previous run's $OMEGA/$SIGMA blocks.
          When adding a new ETA, start with modest variance: 0.04-0.09.
          $SIGMA 1 FIX is the default for combined error models — keep it FIXed.

        RULE 6 — BOUNDARY CONSTRAINTS:
          Keep the same (0, value) or (lower, value) boundaries from the previous run.
          Only tighten a boundary when the final estimate is approaching it.
          Do NOT set a lower bound > 0 unless the previous run's final estimate is safely above that bound.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        \(!isCovariatePhase ? """
        ━━━ ═══ PHASE 1: BASE MODEL BUILDING ═════════════════
        ║ NO covariates allowed. Only work on:
        ║ structural model (compartments), error model, IIV.
        ╚══════════════════════════════════════════════════════

        ━━━ COMPARTMENT PROGRESSION — NO DOWNGRADE ━━━
        run\(nextRun)'s compartment count MUST be ≥ run\(sourceRun)'s count.
        NEVER create a run whose compartment count is lower than the source.
        Keep climbing/repairing UP, never DOWN.

        EVOLUTION RULES:
        - FIRST PASS: structural model (1→2→3 comp). Each level must yield at least one S+C model.
          Compare across levels via ΔOFV > 10.83. Final base = simplest NOT significantly worse.
        - SECOND PASS: error model (combined is default, simplify unstable components)
        - THIRD PASS: add/remove IIV one param at a time
        Only move to next pass when current is adequate.

        \(forceSameCompartment ? """
        🔒 OVERRIDE — LOCK COMPARTMENT. DO NOT escalate. Repair estimation at SAME level.
        """ : "")

        ERROR MODEL SIMPLIFICATION (check at CURRENT compartment, BEFORE escalation):
        - If Add.err THETA has RSE>100% or ≤1e-6 → add `FIX` to its line (keep error unchanged)
        - If Prop.err THETA has RSE>100% or ≤1e-6 → add `FIX` to its line (keep error unchanged)
        - If both → fix the worst one. Only fix ONE at a time.
        - Do NOT modify $ERROR block. Do NOT remove THETA lines. Only add `FIX`.

        IIV STRATEGY — Fix Peripheral IIV FIRST, Central IIV LAST:
        - Priority rule: always fix PERIPHERAL IIV (Q, V2, Q2, V3, Q3) BEFORE central
          IIV (CL, V, V1). Rationale: if central IIV is fixed, peripheral IIV loses
          all meaning — the peripheral compartment describes CENTRAL→PERIPHERAL
          distribution, which cannot be estimated if central variance is zero.
        - ETA INDEXING IS CONTIGUOUS (HARD): Never create ETA gaps. When fixing/removing an IIV,
          EITHER keep the ETA in $PK and set its OMEGA to the last estimated variance FIX,
          OR remove that OMEGA line AND
          renumber all remaining ETA references ($PK, $OMEGA, PATAB, runXXXX.ETA) as ETA1..ETAn.
          A model like ETA1, ETA2, ETA4, ETA5 is invalid and must not be written.
        - Chain rule (AUTOMATIC): if central CL IIV is FIXED → Q/Q2/Q3 IIV MUST also
          be FIXED (they share the same clearance pathway). If V/V1 IIV is FIXED →
          V2/V3 IIV MUST also be FIXED (volumes distribute along the same chain).
          NEVER leave peripheral IIV free while central IIV is fixed.
        - Fix order (by priority): Q3 → V3 → Q2 → V2 (3-comp), Q → V2 (2-comp).
          Only fix central IIV (CL, V) if ALL peripherals are already fixed AND
          central IIV still has RSE > 50%.
        - New escalation IIV starts at 0.04. Fix one at a time.

        ═══ HIGH-COMPARTMENT STOP RULE ═══
        3-comp that achieves S+C but has persistent high %RSE (>50%) on peripheral
        parameters (Q, V2, Q3, V3) is NOT a valid base model — the data may not
        support 3 compartments. Stop fixing IIV on this level and let the evaluation
        AI (evaluateModelRun) decide between 2-comp and 3-comp using ΔOFV.
        Do NOT keep trying to repair a 3-comp that has fix-cycled >3 runs.
        ═━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        STRUCTURAL ESCALATION VALUES:
        - 1→2-comp: copy CL,V as CL,V1. V2=V1*0.3~0.5, Q=CL*0.5~0.8.
        - 2→3-comp: copy CL,V1,Q,V2. V3=V1*0.3~0.5, Q3=CL*0.3~0.6.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        """ : """
        ━━━ ═══ PHASE 2: COVARIATE SCREENING ════════════════
        ║ Structural model is FINALIZED. NO changes to ADVAN, TRANS,
        ║ compartment count, error model type, or IIV architecture.
        ║ ONLY add/examine/remove covariates.
        ╚══════════════════════════════════════════════════════

        STEP 1: Start with the first covariate present in the ACTUAL dataset profile.
          If WT is present, apply allometric scaling to ALL PK params:
            CL, Q, Q2, Q3 → exponent = 0.75 FIX
            V, V1, V2, V3 → exponent = 1.0 FIX
            Add EXACTLY 2 new THETAs: (0, 0.75) FIX and (0, 1.0) FIX
            REUSE the same exponent THETA for all clearance/volume params.
          If WT is absent, skip this step and begin with the next available covariate.

        STEP 2: SCM-style univariate screening — test ALL available covariates.
          Check Dataset profile and $INPUT for the ACTUAL covariate columns
          (e.g. WT, AGE, SEX, STUDY, DOSE, ROUTE, ADA, RACE, TRT).
          Test every available covariate against all relevant PK parameters.
          Each as SEPARATE model. Rank by ΔOFV. Keep if ΔOFV>3.84 (p<0.05, 1 df).

        STEP 3: Forward inclusion — add significant covariates one at a time, most significant first.
        STEP 4: Backward elimination — remove each from full model. Keep if ΔOFV>6.63 (p<0.01).
        STEP 5: Clinical significance — compute PK ratio at extreme covariate values.
          If 0.8-1.25, remove (stat sig but not clinically relevant).

        CONTINUOUS covariates (WT, AGE): POWER function centered at median:
          TVCL = THETA(CL) * (COV/median_COV)**THETA(exp)
        CATEGORICAL covariates (SEX, STUDY): proportional shift with indicator:
          IF (SEX.EQ.0) SEXFX = 1 + THETA(SEX_CL); TVCL = THETA(CL) * SEXFX

        Do NOT skip any covariate from the dataset profile.
        Report: which covariates kept, which removed, and why.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
        """)}

        ━━━ ROUTE IS LOCKED — DO NOT CHANGE ROUTE ━━━
        The route (IV/Oral) is FIXED. Do NOT switch routes or add/remove depot.
        Only allowed change: 1→2→3 comp within the same route.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        ━━━ PARAMETER INHERITANCE — CRITICAL STABILITY ━━━
        NEXT model's initial $THETA values MUST be based on FINAL estimates from the PREVIOUS run.
        RULE 1 — DIRECT COPY (same param, same meaning): copy final estimate, round UP to 3 sig figs.
        RULE 2 — GENTLE PERTURBATION (new param): use small fraction of existing param.
        RULE 3 — NEVER REGRESS: do NOT reset to arbitrary round numbers.
        RULE 4 — UPWARD BIAS: always round UP.
        RULE 5 — $OMEGA/$SIGMA: copy from previous. New IIV starts at 0.04. $SIGMA 1 FIX is default.
        RULE 6 — BOUNDARY CONSTRAINTS: keep same bounds. Only tighten if estimate approaches bound.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        Only move to the next pass when the current one is adequate.
        NEVER add a second compartment in run002 unless run001 residuals/GOF clearly show misspecification.
        NEVER add covariates in run002 or run003 — fix structure and error model first.
        When changing structure, switch to the matching AutoPMX library template instead of hand-writing a new SUBROUTINES/PK/ERROR layout.
        Default residual model remains combined proportional + additive unless the user explicitly overrides it.
        CSV header order is locked. Use these dataset records exactly:
        $INPUT \(inputRecord)
        $DATA \(dataFile) IGNORE=C

        ERROR-DRIVEN REPAIR MODE:
        If Diagnosis from run\(sourceRun) contains NONMEM/PsN/NMTRAN errors, FMSG, "AN ERROR WAS FOUND", "NMtran failed", "There is no output", "Could not parse the output file", or an undefined symbol:
        - Your ONLY task is to fix the control-stream code that caused the error.
        - Preserve the same structural model unless the error proves the selected ADVAN/TRANS/block layout is invalid.
        - Do not add covariates, compartments, TMDD, or exploratory model complexity while the parent model cannot compile/run.
        - Use the exact error message to choose the block to edit.
        - PsN 5.x DOES NOT SUPPORT $IRES or $IWRES records. If you see "PsN does not support record $IRES" or "$IWRES", REMOVE those lines (IRES/IWRES are computed automatically by NONMEM without explicit records). These records are OPTIONAL in NONMEM but BLOCK PsN execution.
        - Common repair mapping:
          * $INPUT/$DATA: wrong column label/order, C=DROP, missing C, DROP typo, DUMP typo, dataset path/filter issue.
          * $SUBROUTINES/$MODEL/$DES: incompatible ADVAN/TRANS, missing COMP definitions, ODE DADT mismatch.
          * $PK: undefined symbols such as D1/R1/S1/F1, missing THETA/ETA references, unit scaling, CMT-dependent dosing terms.
          * $ERROR: undefined IPRED/W/Y/EPS, invalid residual model, missing IRES/IWRES.
          * $THETA/$OMEGA/$SIGMA: count/dimension mismatch, invalid BLOCK, impossible fixed/initial values.
          * $TABLE: table item not defined in input, NONMEM, $PK, or $ERROR; invalid FILE naming.

        \(ModelRunEvidence.controlStreamBlockContract)

        SYNTAX CHECKLIST — follow the poppk_model_library.md template exactly:
        1. NO $IRES/$IWRES records. PsN 5.x does not support them. IRES/IWRES go INSIDE $ERROR instead: IRES=F-Y; IWRES=(F-Y)/W.
        2. SCALE PARAMETER: S1 or S2 ALWAYS goes as the LAST line of $PK (after all parameter definitions).
           IV 1-cmt: S1=\(s1Expression). IV 2+/3-cmt: S1=\(s1for2CompExpression).
           Oral / SC / extravascular 1-cmt: S2=\(s2Expression). Oral / SC / extravascular 2+/3-cmt: S2=\(s2for2CompExpression).
           The scale parameter references V or V1/V2 — it MUST appear AFTER the variable is defined.
           ⚠ CRITICAL: Use the EXACT S1/S2 expression above for your dataset — do NOT blindly add /1000.
        3. $TABLE: COPY the exact pattern from the template. PATAB = $PK variables ONLY. No ETA() in PATAB. No FORMAT= needed.
        4. $THETA: EVERY line must be (0, value). $OMEGA: ONE variance per line, NO parentheses, values slightly different.

        ROUTE-COMPARTMENT-PARAMETER CONSTRAINT (ENFORCED):
        The model COMPARTMENT determines ALLOWED $PK parameters — $TABLE MUST mirror $PK EXACTLY.
        ─────────────────────────────────────────────
        ADVAN1 TRANS2   (IV 1-comp):   CL, V             → $TABLE has CL, V.             NEVER Q, V2, KA.
        ADVAN3 TRANS4   (IV 2-comp):   CL, V1, Q, V2     → $TABLE has CL, V1, Q, V2.     NEVER KA.
        ADVAN11 TRANS4  (IV 3-comp):   CL, V1, Q2, V2, Q3, V3 → $TABLE has CL, V1, Q2, V2, Q3, V3.
        ADVAN2 TRANS2   (Oral 1-comp): KA, CL, V         → $TABLE has KA, CL, V.         NEVER Q, V2, V3.
        ADVAN4 TRANS4   (Oral 2-comp): KA, CL, V2, Q, V3 → $TABLE has KA, CL, V2, Q, V3.
        ADVAN12 TRANS4  (Oral 3-comp): KA, CL, V2, Q3, V3, Q4, V4 → $TABLE has KA, CL, V2, Q3, V3, Q4, V4.

        SCALE PARAMETER (REQUIRED for ADVAN1-4, ADVAN11, ADVAN12):
        - IV models: ALWAYS include S1=\(s1Expression) (1-cpt) or S1=\(s1for2CompExpression) (2+/3-cpt) in $PK.
        - Oral / SC / extravascular models: ALWAYS include S2=\(s2Expression) (1-cpt) or S2=\(s2for2CompExpression) (2+/3-cpt) in $PK.
        - Without S1/S2, NONMEM issues WARNING 23 — parameter estimates become unreliable.
        ─────────────────────────────────────────────
        Before writing $TABLE: scan $PK, list every parameter, use THAT list.
        If a parameter (Q, V2, KA etc.) is NOT in $PK, do NOT put it in $TABLE.
        Also check $OMEGA — only list ETA(n) that exist. Each ETA gets its own line (one variance per line).

        Diagnosis from run\(sourceRun):
        \(diagnosticSummary.prefix(diagnosticLimit))

        Source model run\(sourceRun).mod:
        \(sourceText)
        """

        let (content, usage) = try await sendChatPrompt(
            url: url, model: model, prompt: prompt,
            systemPrompt: staticCtx,
            temperature: 0.1, timeout: 120, apiKey: apiKey, sessionId: sessionId,
            apiFormat: apiFormat
        )
        return (try cleanControlStream(content, projectURL: projectURL, dataFile: dataFile), usage)
    }

    static func draftPsNCommand(
        baseURL: String,
        model: String,
        runID: String,
        projectURL: URL,
        currentCommand: String,
        rules: String,
        apiKey: String = "",
        apiFormat: APIFormat = .openAICompatible
    ) async throws -> String {
        let url = try endpointURL(baseURL: baseURL, path: "chat/completions")

        let modURL = projectURL.appendingPathComponent("run\(runID).mod")
        let configURL = projectURL.appendingPathComponent("project_config.json")
        let modPreview = ((try? String(contentsOf: modURL, encoding: .utf8)) ?? "").prefix(16_000)
        let configPreview = ((try? String(contentsOf: configURL, encoding: .utf8)) ?? "").prefix(6_000)
        let fallback = ProjectScanner.psnExecuteCommand(runID: runID)

        let prompt = """
        You are AutoPMX, a local pharmacometrics workbench assistant.
        Draft exactly one safe PsN execute command for running NONMEM.
        Return one shell command only. No Markdown, no explanation.

        Rules:
        - Command must start with execute.
        - It must run run\(runID).mod.
        - Keep all outputs inside the current project folder.
        - Prefer the user's standard command style: execute run\(runID).mod -model_dir_name
        - Use -model_dir_name as a flag; do not assign a value to it.
        - Do not add -directory/-dir unless the current command already uses it.
        - Do not add destructive shell operators.
        - Use this current command as style reference: \(currentCommand)
        - Safe fallback: \(fallback)

        Active AutoPMX rule/knowledge context:
        \(rules.prefix(80_000))

        project_config.json:
        \(configPreview)

        NONMEM control stream:
        \(modPreview)
        """

        let (content, _) = try await sendOpenAICompatibleChat(
            url: url,
            model: model,
            messages: [.init(role: "user", content: prompt)],
            temperature: 0.1,
            timeout: 180,
            apiKey: apiKey,
            stream: apiFormat == .codeBuddy,
            promptCache: false,
            sessionId: nil
        )
        let command = content
            .replacingOccurrences(of: "```", with: "")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? fallback

        guard command.hasPrefix("execute ") else {
            return fallback
        }
        guard !command.contains(" rm "), !command.contains("&& rm"), !command.contains("; rm") else {
            return fallback
        }
        return command
    }

    static func chat(
        baseURL: String,
        model: String,
        messages: [AssistantMessage],
        projectURL: URL,
        currentRun: String,
        rules: String,
        apiKey: String = "",
        personality: String = "",
        knowledgeBaseURL: URL? = nil,
        apiFormat: APIFormat = .openAICompatible
    ) async throws -> (text: String, usage: TokenUsage?) {
        let url = try endpointURL(baseURL: baseURL, path: "chat/completions")

        let modURL = projectURL.appendingPathComponent("run\(currentRun).mod")
        let configURL = projectURL.appendingPathComponent("project_config.json")
        let modPreview = ((try? String(contentsOf: modURL, encoding: .utf8)) ?? "").prefix(10_000)
        let configPreview = ((try? String(contentsOf: configURL, encoding: .utf8)) ?? "").prefix(4_000)
        let ruleLimit = 80_000
        let libraryLimit = 35_000
        let modelLibrary = modelLibraryText(projectURL: projectURL, knowledgeBaseURL: knowledgeBaseURL).prefix(libraryLimit)

        var apiMessages: [ChatRequest.Message] = [
            .init(role: "system", content: """
            You are DuDu PMx, AutoPMX's AI pharmacometrics assistant.

            \(personality)

            Professional rules (always follow these):
            - Help with NONMEM, PsN, diagnostics, model iteration, and PopPK reasoning.
            - When drafting NONMEM, use the AutoPMX PopPK model library first and fill templates instead of inventing syntax.
            - For AutoPMX datasets using IGNORE=C, $INPUT must mirror the CSV header order; the C column must stay as literal C and never be C=DROP.
            - Use the active AutoPMX rule/knowledge context together with the model library when answering.

            ━━━ AUTO-EXECUTION COMMANDS (CRITICAL) ━━━
            You can DIRECTLY trigger workbench tools by including [ACTION:xxx] markers in your reply.
            When you do this, the action runs automatically — the user does NOT need to click anything.
            All actions are confined to the project path for safety.

            Available actions (use EXACT marker names):
              [ACTION:eda <csv_file>]              — EDA analysis on a CSV dataset
              [ACTION:ct_curves <csv_file>]        — C-T curves (individual + population)
              [ACTION:gof <runID>]                 — GOF diagnostic plots
              [ACTION:vpc <runID>]                 — Visual Predictive Check
              [ACTION:individual <runID>]           — Individual DV vs TIME/IPRED plots
              [ACTION:pk_params <runID>]            — PK parameter extraction
              [ACTION:bootstrap <runID>]            — Non-parametric bootstrap
              [ACTION:scm <runID>]                  — SCM covariate screening dialog

            AUTO-EXECUTION RULES:
            1. Include [ACTION:xxx] at the END of your reply, after your explanation.
            2. Use the DEFAULT target when the user doesn't specify: GOF/VPC/etc → current run.
            3. Examples:
               "User: \(LanguageStore.shared.language == .zhCN ? "帮我跑一下run003的GOF诊断" : "Please run the GOF diagnostics for run003")"
               → "\(LanguageStore.shared.language == .zhCN ? "好，正在为 run003 生成 GOF 诊断图。" : "Sure, generating GOF diagnostics for run003.")[ACTION:gof 003]"
            4. Do NOT ask the user to right-click or use the sidebar — you can auto-trigger it.
            5. Limit: ONE action per reply. If multiple needed, ask which to prioritize.
            6. Do NOT generate raw R/Python code — use actions instead.
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

            ━━━ SOURCE CITATION REQUIREMENT ━━━
            For EVERY factual claim or recommendation, cite the source rule ID or knowledge base section
            using the format: @ref[SOURCE_ID: brief label]
            Examples:
              @ref[PMX-COV-001: allometric scaling exponents 0.75/1.0]
              @ref[FDA-PopPK-2022: Section IV.B structural model selection]
              @ref[poppk_model_library.md: ADVAN3 TRANS4 template]
              @ref[NONMEM_RULE: $INPUT must mirror CSV header order]
            Place citations at the END of each paragraph or bullet point.
            If multiple rules support a point, cite all with separate @ref[...] tags.
            Do NOT omit citations — users want to see the evidential basis for your advice.
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
            Current project: \(projectURL.path)
            Current run: \(currentRun)
            project_config.json:
            \(configPreview)
            Current control stream preview:
            \(modPreview)
            Active AutoPMX rule/knowledge context:
            \(rules.prefix(ruleLimit))
            \(ModelRunEvidence.controlStreamBlockContract)
            AutoPMX PopPK model library preview:
            \(modelLibrary)
            """)
        ]
        apiMessages.append(contentsOf: messages.suffix(12).map {
            ChatRequest.Message(role: $0.role == .user ? "user" : "assistant", content: $0.text)
        })

        let (content, usage) = try await sendOpenAICompatibleChat(
            url: url,
            model: model,
            messages: apiMessages,
            temperature: 0.2,
            timeout: 240,
            apiKey: apiKey,
            stream: apiFormat == .codeBuddy,
            promptCache: false,
            sessionId: nil
        )
        return (content.isEmpty ? "No response." : content, usage)
    }

    /// Agent-mode chat. The model only returns a structured action; Swift owns all
    /// file writes and process launches. Uses the canonical rule/library prefix so
    /// DeepSeek can cache the static context across every tool iteration.
    static func agentChat(
        baseURL: String,
        model: String,
        messages: [AssistantMessage],
        projectURL: URL,
        currentRun: String,
        rules: String,
        apiKey: String = "",
        knowledgeBaseURL: URL? = nil,
        sessionId: String? = nil,
        apiFormat: APIFormat = .openAICompatible
    ) async throws -> (text: String, usage: TokenUsage?) {
        let url = try endpointURL(baseURL: baseURL, path: "chat/completions")
        let modelLibrary = modelLibraryText(projectURL: projectURL, knowledgeBaseURL: knowledgeBaseURL)
        let runs = ProjectScanner.discoverRuns(in: projectURL)
            .filter { FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("run\($0).mod").path) }
            .sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }

        let systemPrompt = canonicalRuleContext(rules: rules, modelLibrary: modelLibrary) + """


        ━━━ DuDu AGENT MODE ━━━
        You are DuDu PMx operating as a local agent. You decide WHAT should happen,
        but the app performs every action. Never claim that a file was changed or a
        model was run unless a tool result confirms it.

        Available tools:
        - list_runs
        - read_mod
        - edit_mod
        - validate_mod
        - run_mod
        - read_output
        - chat

        Reply with EXACTLY ONE JSON object. Do not use Markdown fences. Do not add
        explanations outside the JSON. Allowed keys:
        {"tool":"...","runID":"...","fullModelText":"...","patch":"...","autoRun":true,"reason":"...","reply":"..."}

        Rules:
        - For read_mod/validate_mod/run_mod/read_output, provide runID.
        - For edit_mod, put the COMPLETE new .mod file in fullModelText. Never return a partial file.
        - Set autoRun=true only when the user explicitly asks to run the model after editing.
        - Use chat for ordinary conversation or when no tool is needed.
        - Do not invent tool results; use read_output or validate_mod to confirm.
        """

        let conversation = messages.suffix(12).map {
            "\($0.role.rawValue): \($0.text)"
        }.joined(separator: "\n")

        let prompt = """
        Current project: \(projectURL.path)
        Current run: \(currentRun)
        Available runs: \(runs.isEmpty ? "none" : runs.joined(separator: ", "))

        Conversation:
        \(conversation)

        Decide the next action and return exactly one JSON object.
        """

        return try await sendChatPrompt(
            url: url,
            model: model,
            prompt: prompt,
            systemPrompt: systemPrompt,
            temperature: 0.1,
            timeout: 240,
            apiKey: apiKey,
            sessionId: sessionId,
            apiFormat: apiFormat
        )
    }

    static func proposeNextModel(
        baseURL: String,
        model: String,
        projectURL: URL,
        sourceRun: String,
        nextRun: String,
        rules: String,
        apiKey: String = "",
        sessionId: String? = nil,
        apiFormat: APIFormat = .openAICompatible
    ) async throws -> (text: String, usage: TokenUsage?) {
        let source = projectURL.appendingPathComponent("run\(sourceRun).mod")
        let sourceText = ((try? String(contentsOf: source, encoding: .utf8)) ?? "").prefix(18_000)
        let url = try endpointURL(baseURL: baseURL, path: "chat/completions")
        let modelLibrary = modelLibraryText(projectURL: projectURL)
        let dataFile = dataFileName(from: String(sourceText)) ?? discoverDataset(in: projectURL) ?? "dataset.csv"
        let inputRecord = inputRecordFromDataset(projectURL: projectURL, dataFile: dataFile) ?? defaultInputRecord

        let systemPrompt = canonicalRuleContext(rules: rules, modelLibrary: modelLibrary)

        let prompt = """
        You are AutoPMX automated PopPK modeler.
        Create the next NONMEM control stream based on run\(sourceRun).mod.
        Return the complete .mod file only, no Markdown.
        \(Self.responseLanguageDirective)

        Goal:
        - Improve a mAb PopPK model conservatively.
        - Consider common covariate evolution such as WT on V1 or CL if justified.
        - Keep using the project's dataset file (\(dataFile)); do not rename or switch datasets unless the user asks.
        - Update table output filenames to use run \(nextRun): SDTAB\(nextRun), PATAB\(nextRun), run\(nextRun).ETA, CATAB\(nextRun), COTAB\(nextRun).
        - Keep syntax valid NONMEM.
        - CSV header order is locked. Use exactly: $INPUT \(inputRecord)
        - Use exactly: $DATA \(dataFile) IGNORE=C
        - Never use C=DROP, omit C, reorder C, or create typo aliases such as NTIME=DUMP.
        - If the source model failed NONMEM/PsN/NMTRAN, repair the failing control-stream block first. Do not add model complexity until the model compiles and produces usable NONMEM output.
        - Use the AutoPMX PopPK model library as the syntax source. Do not invent a new NONMEM skeleton.
        - Keep combined proportional + additive residual error unless explicitly instructed otherwise.
        - Before editing, check the source model's ADVAN/TRANS, CMT numbering, D1/D2, and S1/S2 against
          the dataset. Do not carry D1/D2 blindly from an IV mother into an extravascular child.
          SC first-order CMT=1 must not use D1; IV infusion to central CMT=2 with DUR should use D2.
        - NEVER paste dataset rows into the .mod. The CSV is loaded through $DATA, not embedded after $INPUT.
        - ETA numbering must remain contiguous. If an IIV is fixed/removed, either keep ETA with
          last estimated OMEGA variance FIX or remove the OMEGA row and renumber all ETA
          references (PK, OMEGA, tables).

        Source model:
        \(sourceText)
        """

        let (raw, usage) = try await sendChatPrompt(
            url: url, model: model, prompt: prompt,
            systemPrompt: systemPrompt,
            temperature: 0.1, timeout: 300, apiKey: apiKey, sessionId: sessionId,
            apiFormat: apiFormat
        )
        return (try cleanControlStream(raw, projectURL: projectURL, dataFile: dataFile), usage)
    }

    /// Ask DuDu to think through the IV-anchor -> full-dataset handoff instead of
    /// blindly using the deterministic template. The deterministic draft is still
    /// provided as a syntax baseline and as a fallback when the LLM call fails.
    static func generateFullDatasetHandoffModel(
        baseURL: String,
        model: String,
        projectURL: URL,
        runID: String,
        parentRunID: String,
        dataFile: String,
        rules: String,
        deterministicDraft: String,
        parentModText: String,
        hasIV: Bool,
        hasExtravascular: Bool,
        apiKey: String = "",
        sessionId: String? = nil,
        apiFormat: APIFormat = .openAICompatible
    ) async throws -> (text: String, usage: TokenUsage?) {
        let url = try endpointURL(baseURL: baseURL, path: "chat/completions")
        let inputRecord = inputRecordFromDataset(projectURL: projectURL, dataFile: dataFile) ?? defaultInputRecord
        let modelLibrary = modelLibraryText(projectURL: projectURL)
        let staticCtx = canonicalRuleContext(rules: rules, modelLibrary: modelLibrary)

        let prompt = """
        You are an expert NONMEM pharmacometrician converting an IV mother model into the first
        full-dataset extravascular handoff model.

        Task:
        Create run\(runID).mod based on run\(parentRunID).mod and the dataset below. Return ONLY
        the complete .mod file. No markdown, no explanation.
        \(Self.responseLanguageDirective)

        Dataset route evidence:
        - Contains IV dosing: \(hasIV ? "YES" : "NO")
        - Contains SC/extravascular dosing: \(hasExtravascular ? "YES" : "NO")

        HARD REQUIREMENTS:
        1. Read the mother model first, then the deterministic draft. Preserve the mother model's
           exact THETA values and OMEGA/IIV structure. Do not replace inherited values with defaults.
        2. Convert IV compartment numbering to the extravascular ADVAN family:
           ADVAN2/4/12 -> depot CMT=1, central CMT=2, peripheral CMT=3 (2-comp) or CMT=4 (3-comp).
        3. Keep inherited IV structural THETA/OMEGA entries FIXED initially. Estimate residual error
           and KA first, and add F1 only when both IV and SC/extravascular routes exist.
           Do NOT fix Prop.RE or Add.RE in the mixed full-dataset handoff.
        4. SC first-order dosing to CMT=1 must NOT use D1 just because DUR exists in the dataset.
        5. IV infusion delivered directly to central CMT=2 with DUR must use:
           IF (CMT.EQ.2 .AND. DUR.GT.0) D2=DUR
           IF (CMT.EQ.2 .AND. DUR.LE.0) D2=0.0001
        6. Use S2 from the deterministic draft, not S1.
        7. Do not add covariates, extra compartments, or extra IIV beyond the mother model plus KA/F1.
        8. $TABLE must mirror $INPUT and $PK exactly, with file names run\(runID).
        9. CSV header order is locked. Use exactly: $INPUT \(inputRecord)
        10. Use exactly: $DATA \(dataFile) IGNORE=C
        11. NEVER paste dataset rows into the .mod. The data file is referenced by $DATA; do not append CSV rows after $INPUT.

        Mother model run\(parentRunID).mod:
        \(parentModText.prefix(18_000))

        Deterministic draft run\(runID).mod (use as syntax baseline, correct it if needed):
        \(deterministicDraft.prefix(18_000))
        """

        let (raw, usage) = try await sendChatPrompt(
            url: url, model: model, prompt: prompt,
            systemPrompt: staticCtx,
            temperature: 0.1, timeout: 300, apiKey: apiKey, sessionId: sessionId,
            apiFormat: apiFormat
        )
        return (try cleanControlStream(raw, projectURL: projectURL, dataFile: dataFile), usage)
    }

    private static func sendChatPrompt(
        url: URL,
        model: String,
        prompt: String,
        systemPrompt: String? = nil,
        temperature: Double,
        timeout: TimeInterval,
        apiKey: String,
        sessionId: String? = nil,
        apiFormat: APIFormat = .openAICompatible
    ) async throws -> (text: String, usage: TokenUsage?) {
        let maxRetries = apiFormat == .codeBuddy ? 3 : 2
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                try Task.checkCancellation()
                var messages: [ChatRequest.Message] = []
                if let sp = systemPrompt, !sp.isEmpty {
                    messages.append(.init(role: "system", content: sp))
                }
                messages.append(.init(role: "user", content: prompt))

                return try await sendOpenAICompatibleChat(
                    url: url,
                    model: model,
                    messages: messages,
                    temperature: temperature,
                    timeout: timeout,
                    apiKey: apiKey,
                    stream: apiFormat == .codeBuddy,
                    promptCache: true,
                    sessionId: sessionId
                )
            } catch is CancellationError {
                throw CancellationError()  // Don't retry — propagate immediately
            } catch {
                // URLSession surfaces task cancellation as URLError.cancelled (-999),
                // not as CancellationError — map it so STOP propagates cleanly.
                let nsError = error as NSError
                if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                    throw CancellationError()
                }
                lastError = error
                let isConnectionError = nsError.domain == NSURLErrorDomain &&
                    (nsError.code == NSURLErrorCannotConnectToHost ||
                     nsError.code == NSURLErrorNetworkConnectionLost ||
                     nsError.code == NSURLErrorTimedOut ||
                     nsError.code == NSURLErrorNotConnectedToInternet)
                let isRetryableHTTP = nsError.domain == "LLMCommandService" &&
                    [408, 429, 500, 502, 503, 504].contains(nsError.code)
                let isEmptyStream = apiFormat == .codeBuddy &&
                    nsError.domain == "LLMCommandService" &&
                    nsError.code == -1

                if (isConnectionError || isRetryableHTTP || isEmptyStream) && attempt < maxRetries {
                    let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000  // 2s, 4s
                    print("[LLM] Transient error (attempt \(attempt)/\(maxRetries)), retrying in \(delay/1_000_000_000)s...")
                    // Don't swallow cancellation — use `try` so a STOP during backoff aborts now.
                    do {
                        try await Task.sleep(nanoseconds: delay)
                    } catch {
                        throw CancellationError()
                    }
                    // Probe local services to see if they are recovering. CodeBuddy has no /models route.
                    if !isCodeBuddyEndpoint(url),
                       let endpoint = URL(string: url.absoluteString.replacingOccurrences(of: "/chat/completions", with: "/models")) {
                        var probe = URLRequest(url: endpoint)
                        probe.httpMethod = "GET"
                        probe.timeoutInterval = 5
                        applyAuthorization(apiKey, to: &probe)
                        do {
                            _ = try await URLSession.shared.data(for: probe)
                        } catch {
                            if error is CancellationError || Task.isCancelled { throw CancellationError() }
                        }
                    }
                    continue
                }
                break
            }
        }
        if let lastError {
            throw lastError
        }
        throw NSError(domain: "LLMCommandService", code: -1, userInfo: [
            NSLocalizedDescriptionKey: L10n.errorRetryExhausted
        ])
    }

    private static func cleanControlStream(_ content: String, projectURL: URL? = nil, dataFile: String? = nil) throws -> String {
        var cleaned = trimmingBeforeProblem(content)
            .replacingOccurrences(of: "```nonmem", with: "")
            .replacingOccurrences(of: "```nmtran", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // [HARD CODE FIX] Force $COVARIANCE to use PRINT=E MATRIX=S.
        // AI often falls back to UNCONDITIONAL (its training data default),
        // which produces less informative covariance output.
        cleaned = cleaned.replacingOccurrences(
            of: "$COVARIANCE UNCONDITIONAL",
            with: "$COVARIANCE PRINT=E MATRIX=S"
        )
        cleaned = stripInlineDatasetRows(cleaned)
        let guarded = enforceDatasetRecords(cleaned, projectURL: projectURL, dataFile: dataFile)
        // When the AI output is incomplete (missing $EST, $PK, etc.) after stripping
        // embedded data rows, we still return the cleaned version rather than throwing.
        // Throwing triggers a fallback that writes an even MORE broken model to disk,
        // making things worse. The cleaned version is at least free of embedded data
        // and the Python validator will report any remaining structural issues.
        let hasMinimalStructure = guarded.contains("$PROBLEM") && guarded.contains("$DATA")
        let isComplete = hasMinimalStructure && guarded.contains("$EST")
        if !isComplete {
            print("[AutoPMX] WARNING: AI returned incomplete control stream — missing required sections. Stripped inline data but model is structurally incomplete.")
        }
        return guarded
    }

    /// Remove CSV rows that an LLM accidentally pasted into a control stream.
    ///
    /// Strategy (two-pass defence):
    /// 1. Between $INPUT and $DATA: use pattern-matching to detect data-like rows.
    /// 2. After $DATA: STRIP EVERYTHING that is not a `$`-prefixed control record,
    ///    a comment, or an empty line.  No pattern-matching — just a whitelist.
    ///    This is the only way to guarantee that NO data rows survive, regardless
    ///    of format (numeric IDs, string IDs, mixed columns, etc.).
    static func stripInlineDatasetRows(_ controlStream: String) -> String {
        let lines = controlStream.components(separatedBy: "\n")
        var output: [String] = []
        var afterInput = false
        var afterData = false
        var droppedCount = 0

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = trimmed.uppercased()

            if upper.hasPrefix("$INPUT") {
                afterInput = true
                afterData = false
                output.append(line)
                continue
            }
            if upper.hasPrefix("$DATA") {
                afterInput = false
                afterData = true
                output.append(line)
                continue
            }

            // --- After $DATA: WHITELIST only ---
            // ONLY control records ($…), comments (;…), and blank lines survive.
            // Everything else is silently stripped — no heuristic, no pattern-match.
            if afterData {
                if trimmed.isEmpty || trimmed.hasPrefix(";") {
                    output.append(line)
                    continue
                }
                if trimmed.hasPrefix("$") {
                    afterData = false  // next control record — exit data section
                    output.append(line)
                    continue
                }
                // All other content after $DATA is presumed to be embedded CSV rows
                droppedCount += 1
                continue
            }

            // --- Between $INPUT and $DATA: pattern-matching ---
            if afterInput {
                if trimmed.isEmpty || trimmed.hasPrefix(";") {
                    output.append(line)
                    continue
                }
                if trimmed.hasPrefix("$") {
                    afterInput = false
                    afterData = (upper.hasPrefix("$DATA"))
                    output.append(line)
                    continue
                }
                if isLikelyInlineDataRow(trimmed) {
                    droppedCount += 1
                    continue
                }
                let tokens = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
                if tokens.count >= 2 {
                    let first = tokens[0]
                    let numericCount = tokens.filter { token in
                        token == "." || Double(token) != nil
                    }.count
                    if first == "." || Double(first) != nil ||
                        numericCount >= max(2, tokens.count / 2) {
                        droppedCount += 1
                        continue
                    }
                }
            }
            output.append(line)
        }

        if droppedCount > 0 {
            print("[AutoPMX] stripInlineDatasetRows: removed \(droppedCount) embedded CSV rows from control stream")
        }

        return compactBlankLines(output).joined(separator: "\n")
    }

    private static func compactBlankLines(_ lines: [String]) -> [String] {
        var output: [String] = []
        var lastWasBlank = false

        for line in lines {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !lastWasBlank && !output.isEmpty {
                    output.append("")
                }
                lastWasBlank = true
            } else {
                if lastWasBlank && !output.isEmpty && output.last != "" {
                    output.append("")
                }
                output.append(line)
                lastWasBlank = false
            }
        }

        while output.last == "" {
            output.removeLast()
        }
        return output
    }

    static func sanitizeControlStream(_ content: String, projectURL: URL?, dataFile: String?) -> String {
        do {
            return try cleanControlStream(content, projectURL: projectURL, dataFile: dataFile)
        } catch {
            return trimmingBeforeProblem(stripInlineDatasetRows(content))
        }
    }

    private static func trimmingBeforeProblem(_ content: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?m)^\s*\$PROBLEM\b"#,
            options: [.caseInsensitive]
        ) else {
            return content
        }
        let ns = content as NSString
        let range = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: content, options: [], range: range) else {
            return content
        }
        guard let problemRange = Range(match.range, in: content) else {
            return content
        }
        return String(content[problemRange.lowerBound...])
    }

    private static func isLikelyInlineDataRow(_ line: String) -> Bool {
        let tokens = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard tokens.count >= 2 else { return false }
        let first = tokens[0]
        if first == "." || Double(first) != nil {
            return true
        }
        let numericCount = tokens.filter { token in
            token == "." || Double(token) != nil
        }.count
        return numericCount >= max(2, tokens.count / 2)
    }

    private static func enforceDatasetRecords(_ controlStream: String, projectURL: URL?, dataFile: String?) -> String {
        guard let projectURL else {
            return enforceCommentColumn(controlStream)
        }

        let resolvedDataFile = dataFile ?? dataFileName(from: controlStream) ?? discoverDataset(in: projectURL) ?? "dataset.csv"
        guard let inputRecord = inputRecordFromDataset(projectURL: projectURL, dataFile: resolvedDataFile) else {
            return enforceCommentColumn(controlStream)
        }

        var output = [String]()
        var wroteInput = false
        var wroteData = false

        for line in controlStream.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let upper = trimmed.uppercased()
            let leadingWhitespace = String(line.prefix { $0 == " " || $0 == "\t" })

            if upper.hasPrefix("$INPUT") {
                output.append("\(leadingWhitespace)$INPUT \(inputRecord)")
                wroteInput = true
            } else if upper.hasPrefix("$DATA") {
                if !wroteInput {
                    output.append("\(leadingWhitespace)$INPUT \(inputRecord)")
                    wroteInput = true
                }
                output.append("\(leadingWhitespace)$DATA \(resolvedDataFile) IGNORE=C")
                wroteData = true
            } else {
                output.append(line)
            }
        }

        if !wroteInput {
            insertControlRecord("$INPUT \(inputRecord)", into: &output, afterRecord: "$PROBLEM")
        }
        if !wroteData {
            insertControlRecord("$DATA \(resolvedDataFile) IGNORE=C", into: &output, afterRecord: "$INPUT")
        }

        return output.joined(separator: "\n")
    }

    private static func insertControlRecord(_ record: String, into lines: inout [String], afterRecord marker: String) {
        if let index = lines.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix(marker) }) {
            lines.insert(record, at: min(index + 1, lines.count))
        } else {
            lines.insert(record, at: 0)
        }
    }

    private static func enforceCommentColumn(_ controlStream: String) -> String {
        let lines = controlStream.components(separatedBy: .newlines)
        let updatedLines = lines.map { line -> String in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.uppercased().hasPrefix("$INPUT") else {
                return line
            }

            let leadingWhitespace = String(line.prefix { $0 == " " || $0 == "\t" })
            let rawTokens = trimmed
                .dropFirst("$INPUT".count)
                .replacingOccurrences(of: ",", with: " ")
                .split(whereSeparator: \.isWhitespace)
                .map(String.init)

            var normalized = [String]()
            var foundCommentColumn = false
            for token in rawTokens {
                let baseName = token.split(separator: "=", maxSplits: 1).first.map(String.init) ?? token
                if baseName.uppercased() == "C" {
                    if !foundCommentColumn {
                        normalized.append("C")
                        foundCommentColumn = true
                    }
                } else {
                    normalized.append(token)
                }
            }

            if !foundCommentColumn {
                normalized.insert("C", at: 0)
            } else {
                let firstBase = normalized.first?
                    .split(separator: "=", maxSplits: 1)
                    .first
                    .map { String($0).uppercased() }
                guard firstBase == "C" else {
                    normalized.removeAll { token in
                        token.split(separator: "=", maxSplits: 1).first.map { String($0).uppercased() } == "C"
                    }
                    normalized.insert("C", at: 0)
                    return "\(leadingWhitespace)$INPUT \(normalized.joined(separator: " "))"
                }
            }

            return "\(leadingWhitespace)$INPUT \(normalized.joined(separator: " "))"
        }
        return updatedLines.joined(separator: "\n")
    }

    private static func recommendedInitialTemplate(for profile: DatasetProfile) -> String {
        switch profile.route {
        case "IV Infusion":
            return "iv_infusion_1c_advan1_trans2"
        case "Oral":
            return "extravascular_1c_advan2_trans2"
        case "Mixed":
            if profile.hasOral && (profile.hasIVBolus || profile.hasIVInfusion) {
                return "extravascular_1c_advan2_trans2"
            }
            return "custom_linear_1c_des"
        default:
            return "iv_bolus_1c_advan1_trans2"
        }
    }

    private static let defaultInputRecord = "C ID TIME DV AMT RATE DUR CMT EVID MDV"

    private static func inputRecordFromDataset(projectURL: URL, dataFile: String) -> String? {
        let url = dataURL(projectURL: projectURL, dataFile: dataFile)
        guard
            let raw = try? String(contentsOf: url, encoding: .utf8),
            let firstLine = raw.split(separator: "\n", omittingEmptySubsequences: false).first
        else {
            return nil
        }

        let headers = parseCSVLine(String(firstLine))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
            .filter { !$0.isEmpty }

        guard !headers.isEmpty else { return nil }
        return headers.map(nonmemInputToken).joined(separator: " ")
    }

    private static func nonmemInputToken(_ header: String) -> String {
        let clean = header.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = clean.split(separator: "=", maxSplits: 1).first.map(String.init) ?? clean
        if base.uppercased() == "C" {
            return "C"
        }
        return clean.uppercased()
    }

    private static func dataURL(projectURL: URL, dataFile: String) -> URL {
        if dataFile.hasPrefix("/") {
            return URL(fileURLWithPath: dataFile)
        }
        return projectURL.appendingPathComponent(dataFile)
    }

    private static func dataFileName(from controlStream: String) -> String? {
        for line in controlStream.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.uppercased().hasPrefix("$DATA") else { continue }
            let parts = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count > 1 else { return nil }
            let token = parts[1]
            return token.hasPrefix("/") ? URL(fileURLWithPath: token).lastPathComponent : token
        }
        return nil
    }

    /// Discover the project's actual modeling dataset when it cannot be parsed from a control stream.
    private static func discoverDataset(in projectURL: URL) -> String? {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(at: projectURL, includingPropertiesForKeys: nil) else { return nil }
        let csvs = contents.filter { $0.pathExtension.lowercased() == "csv" }
        // Prefer files whose header looks like a PK dataset (ID + DV/TIME/AMT)
        for url in csvs {
            guard let raw = try? String(contentsOf: url, encoding: .utf8),
                  let first = raw.split(separator: "\n", omittingEmptySubsequences: false).first else { continue }
            let header = first.uppercased()
            if header.contains("ID") && (header.contains("DV") || header.contains("TIME") || header.contains("AMT")) {
                return url.lastPathComponent
            }
        }
        return csvs.first?.lastPathComponent
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var values = [String]()
        var current = ""
        var inQuotes = false
        var iterator = line.makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                inQuotes.toggle()
            } else if character == "," && !inQuotes {
                values.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        values.append(current)
        return values
    }

    /// Detect compartment count from a .mod file text by checking the ADVAN number.
    /// ADVAN1/2 = 1-comp, ADVAN3/4 = 2-comp, ADVAN11/12 = 3-comp.
    /// Falls back to 1 if undetectable.
    static func detectCompartmentCount(_ modText: String) -> Int {
        let upper = modText.uppercased()
        if upper.contains("ADVAN11") || upper.contains("ADVAN12") { return 3 }
        if upper.contains("ADVAN3")  || upper.contains("ADVAN4")  { return 2 }
        return 1
    }

    /// Keep inherited IV structural THETA/OMEGA fixed on the first full-dataset handoff model.
    /// Residual error must NOT be inherited as fixed, because the mixed full dataset can
    /// change assay/route-specific residual behavior.
    static func enforceIVAnchorHandoffFixes(_ modText: String) -> String {
        let fixesReleased = modText.uppercased().contains("AUTOPMX INHERITED FIXES RELEASED")
        let upperText = modText.uppercased()
        let releaseIntent = fixesReleased
            || upperText.contains("RELEASE ALL INHERITED")
            || upperText.contains("RELEASING ALL INHERITED")
            || upperText.contains("HANDOFF RELEASE")
            || upperText.contains("FIXES RELEASED")
        let fixedThetas: Set<String> = releaseIntent ? [] : ["CL", "V", "V1", "V2", "V3", "Q", "Q2", "Q3", "Q4"]
        let residualThetas = Set(["PROP.RE", "ADD.RE"])
        let fixedOmegas: Set<String> = releaseIntent ? [] : ["CL", "V", "V1", "V2", "V3", "Q", "Q2", "Q3", "Q4"]
        var result: [String] = []
        var inTheta = false
        var inOmega = false

        for line in modText.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = trimmed.uppercased()
            if upper.hasPrefix("$THETA") {
                inTheta = true
                inOmega = false
                result.append(line)
                continue
            }
            if upper.hasPrefix("$OMEGA") {
                inTheta = false
                inOmega = true
                result.append(line)
                continue
            }
            if inOmega && trimmed.hasPrefix("$") {
                inOmega = false
                result.append(line)
                continue
            }
            if inTheta && trimmed.hasPrefix("$") {
                inTheta = false
                result.append(line)
                continue
            }

            let comment = line.components(separatedBy: ";").dropFirst()
                .joined(separator: ";")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let key = normalizedParameterKey(comment)
            var updated = line
            if inTheta, residualThetas.contains(key) {
                result.append(unfixingResidualThetaLine(line, key: key))
                continue
            }
            if inTheta, fixedThetas.contains(key), !upper.contains("FIX") {
                if let semicolon = updated.firstIndex(of: ";") {
                    updated.insert(contentsOf: " FIX", at: semicolon)
                } else {
                    updated += " FIX"
                }
            }
            if inOmega, fixedOmegas.contains(key), !upper.contains("FIX") {
                if let semicolon = updated.firstIndex(of: ";") {
                    updated.insert(contentsOf: " FIX", at: semicolon)
                } else {
                    updated += " FIX"
                }
            }
            result.append(updated)
        }
        return result.joined(separator: "\n")
    }

    static func hasInheritedStructuralFixes(_ modText: String) -> Bool {
        let upper = modText.uppercased()
        guard upper.contains("IV-ANCHOR HANDOFF")
                || upper.contains("INHERITED IV STRUCTURAL THETA/OMEGA ARE FIXED")
                || upper.contains("INHERITED IV THETA/OMEGA ARE FIXED") else {
            return false
        }
        let structuralParams: Set<String> = ["CL", "V", "V1", "V2", "V3", "Q", "Q2", "Q3", "Q4"]
        var inTheta = false
        var inOmega = false
        for line in modText.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let lineUpper = trimmed.uppercased()
            if lineUpper.hasPrefix("$THETA") {
                inTheta = true
                inOmega = false
                continue
            }
            if lineUpper.hasPrefix("$OMEGA") {
                inTheta = false
                inOmega = true
                continue
            }
            if (inTheta || inOmega) && trimmed.hasPrefix("$") {
                break
            }
            guard inTheta || inOmega else { continue }
            let comment = line.components(separatedBy: ";").dropFirst()
                .joined(separator: ";")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let key = normalizedParameterKey(comment)
            if structuralParams.contains(key), lineUpper.contains("FIX") {
                return true
            }
        }
        return false
    }

    static func releasingIVAnchorHandoffFixes(_ modText: String) -> String {
        let structuralParams: Set<String> = ["CL", "V", "V1", "V2", "V3", "Q", "Q2", "Q3", "Q4"]
        var result: [String] = []
        var inTheta = false
        var inOmega = false

        for line in modText.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = trimmed.uppercased()
            if upper.hasPrefix("$THETA") {
                inTheta = true
                inOmega = false
                result.append(line)
                continue
            }
            if upper.hasPrefix("$OMEGA") {
                inTheta = false
                inOmega = true
                result.append(line)
                continue
            }
            if (inTheta || inOmega) && trimmed.hasPrefix("$") {
                inTheta = false
                inOmega = false
                result.append(line)
                continue
            }
            if !inTheta && !inOmega {
                result.append(line)
                continue
            }

            let comment = line.components(separatedBy: ";").dropFirst()
                .joined(separator: ";")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let key = normalizedParameterKey(comment)
            if structuralParams.contains(key), upper.contains("FIX") {
                if inTheta {
                    result.append(releasingFixedThetaLine(line))
                } else {
                    result.append(releasingFixedOmegaLine(line))
                }
                continue
            }
            result.append(line)
        }
        var output = result.joined(separator: "\n")

        let marker = ";; AutoPMX inherited FIXes released; structural parameters estimated on full dataset"
        if !output.uppercased().contains("AUTOPMX INHERITED FIXES RELEASED") {
            var lines = output.components(separatedBy: "\n")
            if let problemIndex = lines.firstIndex(where: {
                $0.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("$PROBLEM")
            }) {
                lines.insert(marker, at: problemIndex + 1)
            } else {
                lines.insert(marker, at: 0)
            }
            output = lines.joined(separator: "\n")
        }
        return output
    }

    static func trimmingAddedIIVForHandoffRelease(_ modText: String, sourceModText: String) -> String {
        let sourceIIV = Set(iivParametersByEtaIndex(from: sourceModText).values)
        guard !sourceIIV.isEmpty else { return modText }

        var result: [String] = []
        var inPK = false
        var inOmega = false
        let bareParamPattern = #"^\s*([A-Z][A-Z0-9_]*)\s*=\s*TV[A-Z][A-Z0-9_]*"#
        let bareParamRegex = try? NSRegularExpression(pattern: bareParamPattern, options: [.caseInsensitive])

        for line in modText.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = trimmed.uppercased()
            if upper.hasPrefix("$PK") {
                inPK = true
                inOmega = false
                result.append(line)
                continue
            }
            if upper.hasPrefix("$OMEGA") {
                inPK = false
                inOmega = true
                result.append(line)
                continue
            }
            if (inPK || inOmega) && trimmed.hasPrefix("$") {
                inPK = false
                inOmega = false
                result.append(line)
                continue
            }

            if inPK {
                if let bareParamRegex {
                    let nsRange = NSRange(line.startIndex..., in: line)
                    let hasETA = line.uppercased().contains("EXP(ETA")
                    if let match = bareParamRegex.firstMatch(in: line, options: [], range: nsRange),
                       match.numberOfRanges > 1,
                       let paramRange = Range(match.range(at: 1), in: line) {
                        let param = String(line[paramRange]).uppercased()
                        let indent = String(line.prefix { $0 == " " || $0 == "\t" })
                        if sourceIIV.contains(param) {
                            if hasETA {
                                result.append(line)
                            } else {
                                result.append("\(indent)\(param)=TV\(param)*EXP(ETA(99))")
                            }
                            continue
                        } else if hasETA {
                            result.append("\(indent)\(param)=TV\(param)")
                            continue
                        }
                    }
                    result.append(line)
                    continue
                }
                result.append(line)
                continue
            }

            if inOmega {
                let comment = line.components(separatedBy: ";").dropFirst()
                    .joined(separator: ";")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !comment.isEmpty {
                    let key = normalizedParameterKey(comment)
                    if !sourceIIV.contains(key) {
                        continue
                    }
                }
                result.append(line)
                continue
            }

            result.append(line)
        }
        return result.joined(separator: "\n")
    }

    private static func releasingFixedThetaLine(_ line: String) -> String {
        let comment = line.components(separatedBy: ";").dropFirst()
            .joined(separator: ";")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let valuePart = line.components(separatedBy: ";").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleaned = valuePart
            .replacingOccurrences(of: #"\s*FIX\s*"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let newValue: String
        if cleaned.contains("(") {
            newValue = cleaned
        } else {
            let valueToken = cleaned.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? "0.04"
            newValue = "(0, \(valueToken))"
        }
        return comment.isEmpty ? newValue : "\(newValue) ; \(comment)"
    }

    private static func releasingFixedOmegaLine(_ line: String) -> String {
        let comment = line.components(separatedBy: ";").dropFirst()
            .joined(separator: ";")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let valuePart = line.components(separatedBy: ";").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleaned = valuePart
            .replacingOccurrences(of: #"\s*FIX\s*"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let valueToken = cleaned.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? "0.04"
        let value = Double(valueToken) ?? 0.04
        let initial = value > 0 ? String(format: "%.6g", value) : "0.04"
        return comment.isEmpty ? initial : "\(initial) ; \(comment)"
    }

    private static func unfixingResidualThetaLine(_ line: String, key: String) -> String {
        let comment = line.components(separatedBy: ";").dropFirst()
            .joined(separator: ";")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let valuePart = line.components(separatedBy: ";").first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let cleaned = valuePart
            .replacingOccurrences(of: #"\s*FIX\s*"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let newValue: String
        if cleaned.contains("(") {
            newValue = cleaned
        } else {
            let initial = key == "PROP.RE" ? "0.15" : "0.01"
            newValue = "(0, \(initial))"
        }
        return comment.isEmpty ? newValue : "\(newValue) ; \(comment)"
    }

    private static func modelLibraryText(projectURL: URL, knowledgeBaseURL: URL? = nil) -> String {
        // Default the knowledge base to the inferred PopPK_Agent location so the
        // model library is found even when no explicit path is supplied by the caller.
        let kb = knowledgeBaseURL ?? ProjectScanner.defaultWorkspaceURL()
        var candidates: [URL] = []
        // Bundled library is authoritative, so a stale project copy cannot silently
        // replace the rules the user expects DuDu PMx to follow.
        if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent("poppk_model_library.md") {
            candidates.append(bundleURL)
        }
        // Also search the configured knowledge base directory (e.g. PopPK_Agent)
        candidates.append(kb.appendingPathComponent("poppk_model_library.md"))
        var cursor = projectURL
        for _ in 0..<6 {
            candidates.append(cursor.appendingPathComponent("poppk_model_library.md"))
            let parent = cursor.deletingLastPathComponent()
            if parent.path == cursor.path { break }
            cursor = parent
        }

        for url in candidates {
            if let text = try? String(contentsOf: url, encoding: .utf8), !text.isEmpty {
                return text
            }
        }

        return """
        AutoPMX PopPK model library fallback:
        - Initial IV bolus: ADVAN1 TRANS2 with CL, V, S1=V/1000.
        - Initial IV infusion: ADVAN1 TRANS2 with D1=DUR, CL, V, S1=V/1000.
        - Initial extravascular: ADVAN2 TRANS2 with KA, CL, V, S2=V (or V/1000 only when units require it).
        - IV two-compartment: ADVAN3 TRANS4 with CL, V1, Q, V2, S1=V1/1000.
        - Extravascular two-compartment: ADVAN4 TRANS4 with KA, CL, V2, Q, V3, S2=V2 (or V2/1000 only when units require it).
        - Custom/nonstandard: ADVAN13 with explicit $MODEL and $DES.
        - $INPUT must mirror the CSV header order exactly (use the project's actual $INPUT above, never assume a fixed column set). A common AutoPMX PK schema is: C ID TIME DV AMT RATE DUR CMT MDV EVID ... — always match the real dataset header.
        - C must remain a literal token and must never be C=DROP when $DATA has IGNORE=C.
        - Default residual model: IPRED=F; W=SQRT((THETA(k)*IPRED)**2 + THETA(k+1)**2); Y=IPRED+W*EPS(1); $SIGMA 1 FIX.
        ⚠ S1/S2 SCALING NOTE: The /1000 factor is only correct when AMT/DV units require it (e.g. mg+ng/mL). When using mg+µg/mL (or units where mg/L=µg/mL numerically), use S1=V / S2=V instead. For AMT=µg + DV=µg/mL, use V*1000; for AMT=µg + DV=ng/mL or µg/L, use V. The correct expression for your dataset is specified in the PROJECT UNITS section above.
        """
    }

    private static var responseLanguageDirective: String {
        LanguageStore.shared.language == .en
            ? "RESPONSE LANGUAGE: Write all narrative, reasoning, and report content in English. Use English for any visible text."
            : "RESPONSE LANGUAGE: Write all narrative, reasoning, and report content in Chinese (中文). Use Chinese for any visible text."
    }

    private static func defaultProfile(hasWT: Bool = false, hasAGE: Bool = false, hasSEX: Bool = false,
                                        hasSTUDY: Bool = false, hasBQL: Bool = false, obs: Int = 0,
                                        additionalCovariates: [String] = []) -> DatasetProfile {
        DatasetProfile(route: "Unknown", hasIVBolus: false, hasIVInfusion: false, hasOral: false,
                       doseLevels: [], subjectCount: 0, observationCount: obs,
                       timeRangeDays: (0, 0), hasWT: hasWT, hasAGE: hasAGE, hasSEX: hasSEX,
                       hasSTUDY: hasSTUDY, hasBQL: hasBQL, typicalDV: nil, dvRange: nil,
                       wtRange: nil, wtMedian: nil, wtMean: nil, ageRange: nil, ageMedian: nil, ageMean: nil,
                       sexLevels: [], studyLevels: [], additionalCovariates: additionalCovariates)
    }

    static func analyzeDataset(projectURL: URL, dataFile: String, log: ((String) -> Void)? = nil) -> DatasetProfile {
        let url = projectURL.appendingPathComponent(dataFile)
        log?("ANA diag: reading \(dataFile) from \(url.path)")
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
            log?("ANA diag: FAILED to read file at \(url.path) — file may not exist or encoding wrong")
            return defaultProfile()
        }
        // Normalize line endings: handle \r\n (Windows), \r (old Mac), \n (Unix)
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
                             .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: true)
        guard let headerLine = lines.first, lines.count > 1 else {
            log?("ANA diag: file has no header or only 1 line (lines=\(lines.count), rawLen=\(raw.count))")
            return defaultProfile()
        }
        let headers = parseCSVLine(String(headerLine)).map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
        log?("ANA diag: CSV headers parsed = \(headers.joined(separator: ", "))")
        let hasWT = headers.contains("WT")
        let hasAGE = headers.contains("AGE")
        let hasSEX = headers.contains("SEX")
        let hasSTUDY = headers.contains("STUDY") || headers.contains("STUD")
        let hasBQL = headers.contains("BQL")
        let additionalCovariates = headers.filter {
            ["STUD", "STUDYID", "STUDYNO", "DOSE", "ROUTE", "ADA", "RACE", "TRT",
             "ARM", "REGION", "TYPE", "GROUP", "COHORT", "TREATMENT",
             "BSA", "HB", "ALB", "CLCR", "EGFR", "BMI"].contains($0)
        }
        log?("ANA diag: hasWT=\(hasWT) hasAGE=\(hasAGE) hasSEX=\(hasSEX) hasSTUDY=\(hasSTUDY) hasBQL=\(hasBQL)")

        // Find column indices
        guard let idIdx = headers.firstIndex(of: "ID"),
              let timeIdx = headers.firstIndex(of: "TIME"),
              let dvIdx = headers.firstIndex(of: "DV") else {
            return defaultProfile(hasWT: hasWT, hasAGE: hasAGE, hasSEX: hasSEX,
                                  hasSTUDY: hasSTUDY, hasBQL: hasBQL, obs: lines.count - 1,
                                  additionalCovariates: additionalCovariates)
        }
        let cmtIdx = headers.firstIndex(of: "CMT")
        let amtIdx = headers.firstIndex(of: "AMT")
        let rateIdx = headers.firstIndex(of: "RATE")
        let durIdx = headers.firstIndex(of: "DUR")
        let doseIdx = headers.firstIndex(of: "DOSE")
        let evidIdx = headers.firstIndex(of: "EVID")
        let routeIdx = headers.firstIndex(of: "ROUTE")

        var subjectIDs = Set<String>()
        var covariateSubjects = Set<String>()  // track which subjects we've extracted covariates from
        var doseValues = Set<Double>()
        var hasIVBolus = false
        var hasIVInfusion = false
        var hasOral = false
        var dosingCmtValues = Set<Int>()
        var observedCmtValues = Set<Int>()
        var minTime = Double.infinity
        var maxTime = -Double.infinity
        // Covariate statistics
        var wtValues = [Double]()
        var ageValues = [Double]()
        var sexValues = Set<Int>()
        var studyValues = Set<Int>()
        let wtIdx = headers.firstIndex(of: "WT")
        let ageIdx = headers.firstIndex(of: "AGE")
        let sexIdx = headers.firstIndex(of: "SEX")
        let studyIdx = headers.firstIndex(of: "STUDY")
        let dataRows = lines.dropFirst()

        for line in dataRows {
            let cols = parseCSVLine(String(line)).map { $0.trimmingCharacters(in: .whitespaces) }
            guard cols.count > max(idIdx, timeIdx, dvIdx) else { continue }
            func stringValue(at index: Int?) -> String? {
                guard let index, index < cols.count else { return nil }
                let value = String(cols[index])
                return value == "." || value.isEmpty ? nil : value
            }
            func doubleValue(at index: Int?) -> Double? {
                stringValue(at: index).flatMap(Double.init)
            }
            func intValue(at index: Int?) -> Int? {
                doubleValue(at: index).map { Int($0) }
            }

            let idStr = String(cols[idIdx])
            if !idStr.isEmpty, idStr != "." { subjectIDs.insert(idStr) }

            if let tVal = Double(cols[timeIdx]) {
                minTime = min(minTime, tVal)
                maxTime = max(maxTime, tVal)
            }

            // Extract covariate values (only once per subject)
            if !idStr.isEmpty, idStr != ".", !covariateSubjects.contains(idStr) {
                covariateSubjects.insert(idStr)
                if let w = doubleValue(at: wtIdx), w > 0 { wtValues.append(w) }
                if let a = doubleValue(at: ageIdx), a > 0 { ageValues.append(a) }
                if let s = intValue(at: sexIdx) { sexValues.insert(s) }
                if let st = intValue(at: studyIdx) { studyValues.insert(st) }
            }

            // Analyze dosing records (EVID=1 or EVID=4 typically)
            let evidVal = intValue(at: evidIdx) ?? 0
            let amtVal = doubleValue(at: amtIdx) ?? 0
            let cmtVal = intValue(at: cmtIdx) ?? 0
            let rateVal = doubleValue(at: rateIdx) ?? 0
            let durVal = doubleValue(at: durIdx) ?? 0
            let doseVal = doubleValue(at: doseIdx) ?? amtVal
            let routeVal = stringValue(at: routeIdx)?
                .uppercased()
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            let isDosingEvent = (evidVal == 1 || evidVal == 4)
            if isDosingEvent || amtVal > 0 {
                if cmtVal > 0 { dosingCmtValues.insert(cmtVal) }
                if doseVal > 0 { doseValues.insert(doseVal) }
                if !routeVal.isEmpty {
                    let isIVRoute = routeVal.contains("IV")
                        || routeVal.contains("INTRAVENOUS")
                        || routeVal.contains("INFUS")
                        || routeVal.contains("BOLUS")
                    let isExtravascularRoute = routeVal.contains("SC")
                        || routeVal.contains("SUBQ")
                        || routeVal.contains("SUBCUT")
                        || routeVal.contains("ORAL")
                        || routeVal.contains("PO")
                        || routeVal.contains("EXTRAVASCULAR")
                        || routeVal.contains("IM ")
                        || routeVal.hasPrefix("IM")
                        || routeVal == "IM"

                    if isIVRoute {
                        if rateVal > 0 || durVal > 0 || routeVal.contains("INFUS") {
                            hasIVInfusion = true
                        } else {
                            hasIVBolus = true
                        }
                    } else if isExtravascularRoute {
                        hasOral = true
                    } else if cmtVal == 1 {
                        if rateVal > 0 || durVal > 0 {
                            hasIVInfusion = true
                        } else if amtVal > 0 {
                            hasIVBolus = true
                        }
                    } else if cmtVal == 2 && amtVal > 0 && isDosingEvent {
                        hasOral = true
                    }
                } else {
                    // Fallback only when the dataset has no ROUTE column.
                    // CMT=1 is IV in classic datasets, but CMT=2 may be a depot for SC/oral.
                    if cmtVal == 1 {
                        if rateVal > 0 || durVal > 0 {
                            hasIVInfusion = true
                        } else if amtVal > 0 {
                            hasIVBolus = true
                        }
                    } else if cmtVal == 2 && amtVal > 0 && isDosingEvent {
                        hasOral = true
                    }
                }
            } else if cmtVal > 0 {
                observedCmtValues.insert(cmtVal)
            }
        }

        // CMT-based fallback for non-IV data. Standard extravascular NONMEM uses
        // CMT=1 for the depot dose and CMT=2 for the central observation, so a
        // CMT=2 dose is also a valid nonstandard signal.
        if !hasOral && !hasIVBolus && !hasIVInfusion {
            if dosingCmtValues.contains(2) {
                hasOral = true
            } else if dosingCmtValues.contains(1),
                      observedCmtValues.contains(2),
                      !observedCmtValues.contains(1) {
                hasOral = true
            }
        }

        // Classify overall route
        var route = "Unknown"
        let routeCount = [hasIVBolus, hasIVInfusion, hasOral].filter { $0 }.count
        if routeCount >= 2 {
            route = "Mixed"
        } else if hasIVBolus {
            route = "IV Bolus"
        } else if hasIVInfusion {
            route = "IV Infusion"
        } else if hasOral {
            route = "Oral"
        } else if amtIdx != nil && cmtIdx != nil {
            route = "IV Bolus" // Default assumption for dosing records with CMT=1
        }

        let sortedDoses = Array(doseValues).sorted()

        // Compute data-driven initial value guidance from DV distribution
        let dvValues = dataRows.compactMap { line -> Double? in
            let cols = parseCSVLine(String(line)).map { $0.trimmingCharacters(in: .whitespaces) }
            guard cols.count > dvIdx, let dv = Double(cols[dvIdx]), dv > 0 else { return nil }
            return dv
        }.sorted()
        let typicalDV: Double? = dvValues.isEmpty ? nil : dvValues[dvValues.count / 2]  // median
        let dvMin = dvValues.first
        let dvMax = dvValues.last
        let dvRange: (Double, Double)? = dvMin != nil && dvMax != nil ? (dvMin!, dvMax!) : nil
        let wtMean: Double? = wtValues.isEmpty ? nil : wtValues.reduce(0, +) / Double(wtValues.count)
        let ageMean: Double? = ageValues.isEmpty ? nil : ageValues.reduce(0, +) / Double(ageValues.count)

        return DatasetProfile(
            route: route,
            hasIVBolus: hasIVBolus,
            hasIVInfusion: hasIVInfusion,
            hasOral: hasOral,
            doseLevels: sortedDoses,
            subjectCount: subjectIDs.count,
            observationCount: dataRows.count,
            timeRangeDays: (minTime.isFinite ? minTime : 0, maxTime.isFinite ? maxTime : 0),
            hasWT: hasWT,
            hasAGE: hasAGE,
            hasSEX: hasSEX,
            hasSTUDY: hasSTUDY,
            hasBQL: hasBQL,
            typicalDV: typicalDV,
            dvRange: dvRange,
            wtRange: wtValues.isEmpty ? nil : (wtValues.min()!, wtValues.max()!),
            wtMedian: wtValues.isEmpty ? nil : wtValues.sorted()[wtValues.count / 2],
            wtMean: wtMean,
            ageRange: ageValues.isEmpty ? nil : (ageValues.min()!, ageValues.max()!),
            ageMedian: ageValues.isEmpty ? nil : ageValues.sorted()[ageValues.count / 2],
            ageMean: ageMean,
            sexLevels: Array(sexValues),
            studyLevels: Array(studyValues),
            additionalCovariates: additionalCovariates
        )
    }

    /// Deterministic first-pass NCA estimates for a simple compartmental model.
    /// Uses each subject's first dosing interval, linear-trapezoidal AUC and a
    /// log-linear terminal slope to derive CL and Vz seeds.
    static func ncaInitialEstimates(projectURL: URL, dataFile: String) -> NCAInitialEstimates {
        let dataURL = projectURL.appendingPathComponent(dataFile)
        guard let raw = try? String(contentsOf: dataURL, encoding: .utf8) else {
            return NCAInitialEstimates(
                clearanceLPerHour: nil,
                volumeLiters: nil,
                terminalHalfLifeHours: nil,
                aucInfMedian: nil,
                subjectCount: 0
            )
        }

        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n").filter {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard lines.count > 1 else {
            return NCAInitialEstimates(
                clearanceLPerHour: nil,
                volumeLiters: nil,
                terminalHalfLifeHours: nil,
                aucInfMedian: nil,
                subjectCount: 0
            )
        }

        let headers = parseCSVLine(lines[0]).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                .uppercased()
        }
        func index(_ name: String) -> Int? {
            headers.firstIndex(where: { $0 == name })
        }

        guard
            let idIdx = index("ID"),
            let timeIdx = index("TIME"),
            let dvIdx = index("DV"),
            let amtIdx = index("AMT")
        else {
            return NCAInitialEstimates(
                clearanceLPerHour: nil,
                volumeLiters: nil,
                terminalHalfLifeHours: nil,
                aucInfMedian: nil,
                subjectCount: 0
            )
        }

        let evidIdx = index("EVID")
        let doseIdx = index("DOSE")
        let iiIdx = index("II")
        let maxColumn = max(idIdx, timeIdx, dvIdx, amtIdx, evidIdx ?? 0, doseIdx ?? 0, iiIdx ?? 0)

        var doseEventsByID: [String: [(time: Double, amount: Double, interval: Double?)]] = [:]
        var observationsByID: [String: [(time: Double, conc: Double)]] = [:]

        for line in lines.dropFirst() {
            let cols = parseCSVLine(line).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            }
            guard cols.count > maxColumn else { continue }

            let id = cols[idIdx]
            guard !id.isEmpty, id != "." else { continue }
            guard let time = Double(cols[timeIdx]) else { continue }

            let evid = evidIdx.flatMap { Double(cols[$0]) } ?? 0
            let amt = Double(cols[amtIdx])
            let isDose = (evid == 1 || evid == 4) || (amt ?? 0) > 0

            if isDose {
                let dose = (amt ?? 0) > 0
                    ? amt!
                    : (doseIdx.flatMap { Double(cols[$0]) } ?? 0)
                let interval = iiIdx.flatMap { Double(cols[$0]) }.flatMap { $0 > 0 ? $0 : nil }
                doseEventsByID[id, default: []].append((time: time, amount: dose, interval: interval))
            } else if let dv = Double(cols[dvIdx]), dv > 0 {
                observationsByID[id, default: []].append((time: time, conc: dv))
            }
        }

        var clearances: [Double] = []
        var volumes: [Double] = []
        var halfLives: [Double] = []
        var aucInfs: [Double] = []

        for id in doseEventsByID.keys {
            guard
                let events = doseEventsByID[id],
                let first = events.sorted(by: { $0.time < $1.time }).first,
                first.amount > 0
            else { continue }
            let dose = first.amount
            let doseTime = first.time
            let nextDoseTime = events
                .sorted(by: { $0.time < $1.time })
                .first(where: { $0.time > doseTime })?
                .time
            let intervalEnd = nextDoseTime ?? first.interval.flatMap { doseTime + $0 }
            guard dose > 0 else { continue }

            let points = (observationsByID[id] ?? [])
                .filter { $0.time > doseTime && (intervalEnd == nil || $0.time < intervalEnd!) }
                .sorted { $0.time < $1.time }
            guard points.count >= 2 else { continue }

            var auc = 0.0
            for i in 0..<(points.count - 1) {
                let t0 = points[i].time
                let t1 = points[i + 1].time
                guard t1 > t0 else { continue }
                auc += (t1 - t0) * (points[i].conc + points[i + 1].conc) / 2.0
            }

            let tail = Array(points.suffix(3)).filter { $0.conc > 0 }
            guard tail.count >= 2 else { continue }
            let n = Double(tail.count)
            let meanTime = tail.reduce(0.0) { $0 + $1.time } / n
            let meanLog = tail.reduce(0.0) { $0 + log($1.conc) } / n
            var numerator = 0.0
            var denominator = 0.0
            for point in tail {
                let dt = point.time - meanTime
                numerator += dt * (log(point.conc) - meanLog)
                denominator += dt * dt
            }
            guard denominator > 0, numerator < 0 else { continue }
            let lambdaZ = -numerator / denominator
            guard lambdaZ > 1e-8 else { continue }

            let clast = points.last?.conc ?? tail.last!.conc
            let aucInf = auc + clast / lambdaZ
            guard aucInf > 0 else { continue }

            let clearance = dose / aucInf
            let volume = clearance / lambdaZ
            let halfLife = log(2.0) / lambdaZ
            guard clearance > 0, volume > 0, halfLife > 0 else { continue }

            clearances.append(clearance)
            volumes.append(volume)
            halfLives.append(halfLife)
            aucInfs.append(aucInf)
        }

        func median(_ values: [Double]) -> Double? {
            guard !values.isEmpty else { return nil }
            let sorted = values.sorted()
            return sorted[sorted.count / 2]
        }

        return NCAInitialEstimates(
            clearanceLPerHour: median(clearances),
            volumeLiters: median(volumes),
            terminalHalfLifeHours: median(halfLives),
            aucInfMedian: median(aucInfs),
            subjectCount: clearances.count
        )
    }

    /// Replace only the base CL/V initial values in a generated model with the
    /// deterministic NCA seeds when they can be derived.
    static func applyingNCAInitialValues(
        _ modText: String,
        projectURL: URL,
        dataFile: String
    ) -> String {
        let nca = ncaInitialEstimates(projectURL: projectURL, dataFile: dataFile)
        guard let clearance = nca.clearanceLPerHour, let volume = nca.volumeLiters else {
            return modText
        }

        let lines = modText.components(separatedBy: "\n")
        var result = lines
        var inTheta = false
        var thetaIndex = 0

        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = trimmed.uppercased()
            if upper.hasPrefix("$THETA") {
                inTheta = true
                thetaIndex = 0
                continue
            }
            if inTheta && trimmed.hasPrefix("$") {
                inTheta = false
                continue
            }
            guard inTheta, !trimmed.isEmpty, !trimmed.hasPrefix(";") else { continue }
            thetaIndex += 1

            let comment = line.components(separatedBy: ";")
                .dropFirst()
                .joined(separator: ";")
                .uppercased()
            let hasCL = comment.range(of: #"\bCL\b"#, options: .regularExpression) != nil
            let hasV = comment.range(of: #"\bV\b"#, options: .regularExpression) != nil
                && comment.range(of: #"\bV[123]\b"#, options: .regularExpression) == nil
                && comment.range(of: #"\bVSS\b"#, options: .regularExpression) == nil
                && comment.range(of: #"\bVZ\b"#, options: .regularExpression) == nil
            let unlabeledBaseTheta = comment.trimmingCharacters(in: .whitespaces).isEmpty && thetaIndex <= 2

            let replacement: Double?
            if hasCL {
                replacement = clearance
            } else if hasV {
                replacement = volume
            } else if unlabeledBaseTheta {
                replacement = thetaIndex == 1 ? clearance : volume
            } else {
                replacement = nil
            }

            if let replacement {
                result[index] = replacingThetaInitialValue(line, value: replacement)
            }
        }

        return result.joined(separator: "\n")
    }

    static func datasetInputRecord(projectURL: URL, dataFile: String) -> String? {
        inputRecordFromDataset(projectURL: projectURL, dataFile: dataFile)
    }

    /// Build the first full-dataset model from an IV anchor model.
    ///
    /// The IV model is copied into the project as the parent run. This initial child
    /// keeps the IV compartment count, converts it to the extravascular ADVAN template,
    /// inherits the IV final structural THETA/OMEGA estimates as FIXED starting values,
    /// estimates residual error, and only fixes KA (plus F1 when the full dataset contains
    /// both IV and SC dosing).
    private static func infusionDurationCMTs(projectURL: URL, dataFile: String) -> Set<Int> {
        let url = dataURL(projectURL: projectURL, dataFile: dataFile)
        guard let raw = try? String(contentsOf: url, encoding: .utf8),
              let headerLine = raw.split(separator: "\n", omittingEmptySubsequences: true).first else {
            return []
        }
        let headers = parseCSVLine(String(headerLine)).map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        }
        guard let cmtIdx = headers.firstIndex(of: "CMT"),
              let durIdx = headers.firstIndex(of: "DUR") else {
            return []
        }
        let evidIdx = headers.firstIndex(of: "EVID")
        let amtIdx = headers.firstIndex(of: "AMT")
        var durationCMTs = Set<Int>()

        for line in raw.split(separator: "\n", omittingEmptySubsequences: true).dropFirst() {
            let cols = parseCSVLine(String(line)).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard cols.count > max(cmtIdx, durIdx),
                  let cmt = Int(cols[cmtIdx]), cmt > 0,
                  let dur = Double(cols[durIdx]), dur > 0 else {
                continue
            }
            let evid = evidIdx.flatMap { idx -> Int? in
                idx < cols.count ? Int(cols[idx]) : nil
            } ?? 0
            let amt = amtIdx.flatMap { idx -> Double? in
                idx < cols.count ? Double(cols[idx]) : nil
            } ?? 0
            if evid == 1 || evid == 4 || amt > 0 {
                durationCMTs.insert(cmt)
            }
        }
        return durationCMTs
    }

    static func fullDatasetIVHandoffModel(
        childRunID: String,
        parentRunID: String,
        projectURL: URL,
        dataFile: String,
        parentModText: String,
        parentRows: [ParameterEstimateRow],
        parentCompartments: Int,
        hasIV: Bool,
        hasExtravascular: Bool,
        timeUnit: String,
        derivedCLUnit: String,
        derivedVUnit: String,
        s2Expression: String,
        s2for2CompExpression: String
    ) -> String {
        let inputRecord = datasetInputRecord(projectURL: projectURL, dataFile: dataFile) ?? defaultInputRecord
        let maps = parentParameterMaps(rows: parentRows, modText: parentModText)
        let thetaMap = maps.theta
        let omegaMap = maps.omega
        let includeF1 = hasIV && hasExtravascular
            && inputRecord.components(separatedBy: .whitespaces).contains("CMT")
        let s2 = parentCompartments <= 1 ? s2Expression : s2for2CompExpression
        let fmt: (Double) -> String = { String(format: "%.6g", $0) }

        let advan: String
        switch parentCompartments {
        case 2: advan = "ADVAN4 TRANS4"
        case 3: advan = "ADVAN12 TRANS4"
        default: advan = "ADVAN2 TRANS2"
        }

        var thetaLines = ["(0, \(fmt(thetaMap["KA"] ?? 0.5))) ; KA (1/\(timeUnit))"]
        var omegaLines = ["0.08 ; IIV KA"]
        var pkLines = ["TVKA=THETA(1)", "KA=TVKA*EXP(ETA(1))"]
        var tableParams = ["KA"]
        var thetaIndex = 2
        var etaIndex = 2

        func addStructural(key: String, sourceKey: String, unit: String, defaultValue: Double) {
            let value = thetaMap[sourceKey] ?? defaultValue
            let inheritedOmega = omegaMap[sourceKey]
            let hasIIV = inheritedOmega != nil && inheritedOmega! > 0
            thetaLines.append("(0, \(fmt(value))) FIX ; \(key) (\(unit))")
            pkLines.append("TV\(key)=THETA(\(thetaIndex))")
            if hasIIV {
                let omega = inheritedOmega ?? 0.04
                omegaLines.append("\(fmt(omega)) FIX ; IIV \(key)")
                pkLines.append("\(key)=TV\(key)*EXP(ETA(\(etaIndex)))")
                etaIndex += 1
            } else {
                pkLines.append("\(key)=TV\(key)")
            }
            tableParams.append(key)
            thetaIndex += 1
        }

        addStructural(key: "CL", sourceKey: "CL", unit: derivedCLUnit, defaultValue: 0.2)

        switch parentCompartments {
        case 2:
            addStructural(key: "V2", sourceKey: "V1", unit: derivedVUnit, defaultValue: 5.0)
            addStructural(key: "Q", sourceKey: "Q", unit: derivedCLUnit, defaultValue: 0.5)
            addStructural(key: "V3", sourceKey: "V2", unit: derivedVUnit, defaultValue: 3.0)
        case 3:
            addStructural(key: "V2", sourceKey: "V1", unit: derivedVUnit, defaultValue: 5.0)
            addStructural(key: "Q3", sourceKey: "Q2", unit: derivedCLUnit, defaultValue: 0.5)
            addStructural(key: "V3", sourceKey: "V2", unit: derivedVUnit, defaultValue: 3.0)
            addStructural(key: "Q4", sourceKey: "Q3", unit: derivedCLUnit, defaultValue: 0.3)
            addStructural(key: "V4", sourceKey: "V3", unit: derivedVUnit, defaultValue: 5.0)
        default:
            addStructural(key: "V", sourceKey: "V", unit: derivedVUnit, defaultValue: 5.0)
        }

        if includeF1 {
            let f1ThetaIndex = thetaIndex
            thetaLines.append("(0, \(fmt(thetaMap["F1"] ?? 0.8))) ; F1 (SC relative to IV)")
            pkLines.append("IF (CMT.EQ.1) F1=THETA(\(f1ThetaIndex))")
            pkLines.append("IF (CMT.NE.1) F1=1")
            thetaIndex += 1
        }

        let propThetaIndex = thetaIndex
        thetaLines.append("(0, \(fmt(thetaMap["PROP.RE"] ?? 0.15))) ; Prop.RE (sd)")
        let addThetaIndex = thetaIndex + 1
        thetaLines.append("(0, \(fmt(thetaMap["ADD.RE"] ?? 1.0))) ; Add.RE (sd)")

        if inputRecord.components(separatedBy: .whitespaces).contains("DUR") {
            if inputRecord.components(separatedBy: .whitespaces).contains("CMT") {
                let durationCMTs = infusionDurationCMTs(projectURL: projectURL, dataFile: dataFile)
                var durationLines: [String] = []
                if durationCMTs.contains(1) {
                    durationLines.append(contentsOf: [
                        "IF (CMT.EQ.1 .AND. DUR.GT.0) D1=DUR",
                        "IF (CMT.EQ.1 .AND. DUR.LE.0) D1=0.0001"
                    ])
                }
                if durationCMTs.contains(2) {
                    durationLines.append(contentsOf: [
                        "IF (CMT.EQ.2 .AND. DUR.GT.0) D2=DUR",
                        "IF (CMT.EQ.2 .AND. DUR.LE.0) D2=0.0001"
                    ])
                } else if hasIV {
                    // Robust fallback for mixed IV + SC: central CMT=2 carries the IV infusion.
                    durationLines.append(contentsOf: [
                        "IF (CMT.EQ.2 .AND. DUR.GT.0) D2=DUR",
                        "IF (CMT.EQ.2 .AND. DUR.LE.0) D2=0.0001"
                    ])
                }
                if !durationLines.isEmpty {
                    pkLines.insert(contentsOf: durationLines, at: 0)
                }
            } else {
                pkLines.insert(contentsOf: [
                    "IF (DUR.GT.0) D1=DUR",
                    "IF (DUR.LE.0) D1=0.0001"
                ], at: 0)
            }
        }
        pkLines.append("S2=\(s2)")

        let etaTerms = (1..<etaIndex).map { "ETA\($0)" }.joined(separator: " ")
        let params = tableParams.joined(separator: " ")
        let inputTokens = inputRecord
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        let inputSet = Set(inputTokens.map { $0.uppercased() })
        let extraSdtab = inputTokens
            .filter { $0 != "C" }
            .joined(separator: " ")
        let categorical = ["SEX", "STUDY", "STUD", "STUDYID", "STUDYNO", "ADA",
                           "ROUTE", "BQL", "TYPE", "CMT", "EVID", "MDV",
                           "RACE", "TRT", "ARM", "REGION", "GROUP",
                           "COHORT", "TREATMENT", "FORM"]
        let continuous = ["WT", "AGE", "BSA", "HB", "ALB", "CLCR", "EGFR",
                          "BMI", "DOSE", "AMT", "RATE", "DUR"]
        let catCols = categorical.filter { inputSet.contains($0) }
        let contCols = continuous.filter { inputSet.contains($0) }

        let lines = [
            "$PROBLEM Run\(childRunID): Full dataset extravascular handoff from IV run\(parentRunID)",
            ";; AutoPMX IV-anchor handoff from run\(parentRunID).mod",
            ";; Inherited IV structural THETA/OMEGA are FIXED; estimate residual error and KA\(includeF1 ? " and F1" : "") first.",
            "$INPUT \(inputRecord)",
            "$DATA \(dataFile) IGNORE=C",
            "$SUBROUTINES \(advan)",
            "$PK"
        ] + pkLines + [
            "$ERROR",
            "IPRED=F",
            "W=SQRT((THETA(\(propThetaIndex))*IPRED)**2 + THETA(\(addThetaIndex))**2)",
            "Y=IPRED+W*EPS(1)",
            "IRES=F-Y",
            "IWRES=(F-Y)/W",
            "$THETA"
        ] + thetaLines + [
            "$OMEGA"
        ] + omegaLines + [
            "$SIGMA",
            "1 FIX",
            "$ESTIMATION METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10",
            "$COVARIANCE PRINT=E MATRIX=S",
            "$TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES \(extraSdtab) ONEHEADER NOPRINT NOAPPEND FILE=sdtab\(childRunID) FORMAT=s1PE14.7",
            "$TABLE ID \(params)\(etaTerms.isEmpty ? "" : " \(etaTerms)") NOPRINT NOAPPEND ONEHEADER FILE=patab\(childRunID)",
            "$TABLE ID \(etaTerms) FIRSTONLY NOAPPEND NOPRINT FILE=run\(childRunID).ETA",
            "$TABLE ID \(catCols.joined(separator: " ")) FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=catab\(childRunID)",
            "$TABLE ID \(contCols.joined(separator: " ")) FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=cotab\(childRunID)"
        ]

        return lines.joined(separator: "\n") + "\n"
    }

    private static func parentParameterMaps(rows: [ParameterEstimateRow], modText: String) -> (theta: [String: Double], omega: [String: Double]) {
        var theta = initialThetaValuesFromMod(modText)
        var omega = initialOmegaValuesFromMod(modText)

        for row in rows {
            guard row.group != "Fit" else { continue }
            let key = normalizedParameterKey(row.name)
            guard !key.isEmpty else { continue }
            if row.group == "IIV" {
                omega[key] = row.estimate
            } else if ["Fixed", "PK Parameter", "Residual"].contains(row.group) {
                theta[key] = row.estimate
            }
        }

        return (theta, omega)
    }

    private static func normalizedParameterKey(_ raw: String) -> String {
        var upper = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if upper.hasPrefix("IIV ") {
            upper = String(upper.dropFirst(4))
        }
        if upper.hasPrefix("TV") {
            upper = String(upper.dropFirst(2))
        }
        if let range = upper.range(of: #"\s*\(.*\)\s*$"#, options: .regularExpression) {
            upper = String(upper[..<range.lowerBound])
        }
        return upper.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func initialThetaValuesFromMod(_ modText: String) -> [String: Double] {
        var result = [String: Double]()
        guard let regex = try? NSRegularExpression(pattern: #"\(\s*[^,]+,\s*([^,)]+)"#, options: []) else {
            return result
        }
        var inTheta = false
        for line in modText.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = trimmed.uppercased()
            if upper.hasPrefix("$THETA") {
                inTheta = true
                continue
            }
            if inTheta && trimmed.hasPrefix("$") {
                break
            }
            guard inTheta, !trimmed.isEmpty, !trimmed.hasPrefix(";") else { continue }
            let comment = line.components(separatedBy: ";").dropFirst().joined(separator: ";")
            let key = normalizedParameterKey(comment)
            guard !key.isEmpty else { continue }
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            guard let match = regex.firstMatch(in: trimmed, options: [], range: range),
                  match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: trimmed),
                  let value = Double(String(trimmed[valueRange])) else {
                continue
            }
            result[key] = value
        }
        return result
    }

    private static func initialOmegaValuesFromMod(_ modText: String) -> [String: Double] {
        var result = [String: Double]()
        var inOmega = false
        for line in modText.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = trimmed.uppercased()
            if upper.hasPrefix("$OMEGA") {
                inOmega = true
                continue
            }
            if inOmega && trimmed.hasPrefix("$") {
                break
            }
            guard inOmega, !trimmed.isEmpty, !trimmed.hasPrefix(";") else { continue }
            let comment = line.components(separatedBy: ";").dropFirst().joined(separator: ";")
            let key = normalizedParameterKey(comment)
            guard !key.isEmpty else { continue }
            let valueToken = trimmed.components(separatedBy: ";").first?
                .split(whereSeparator: \.isWhitespace)
                .first
                .map(String.init) ?? ""
            guard let value = Double(valueToken) else { continue }
            result[key] = value
        }
        return result
    }

    private static func replacingThetaInitialValue(_ line: String, value: Double) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"^(\s*\(\s*0\s*,\s*)[^,)]+"#,
            options: []
        ) else { return line }
        let range = NSRange(line.startIndex..., in: line)
        let formatted = String(format: "%.6g", value)
        return regex.stringByReplacingMatches(
            in: line,
            options: [],
            range: range,
            withTemplate: "$1\(formatted)"
        )
    }

    /// Keep D1 positive for IV-infusion ADVAN models. Observation records often
    /// carry missing DUR, and PREDPP aborts when the duration parameter is 0.
    static func applyingIVInfusionDurationFix(_ modText: String) -> String {
        let upper = modText.uppercased()
        guard upper.contains("ADVAN1") || upper.contains("ADVAN3") || upper.contains("ADVAN11"),
              upper.contains("DUR") else {
            return modText
        }

        let lines = modText.components(separatedBy: "\n")
        var result: [String] = []
        var inserted = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let compact = trimmed.replacingOccurrences(of: " ", with: "").uppercased()

            if compact == "IF(DUR.GT.0)D1=DUR" && !inserted {
                let indent = String(line.prefix { $0 == " " || $0 == "\t" })
                result.append(line)
                result.append("\(indent)IF (DUR.LE.0) D1=0.0001")
                inserted = true
            } else if compact.contains("D1=DUR") && compact.contains("AMT.GT.0") && !inserted {
                let indent = String(line.prefix { $0 == " " || $0 == "\t" })
                result.append(line)
                result.append("\(indent)IF (DUR.LE.0) D1=0.0001")
                inserted = true
            } else if compact == "D1=DUR" && !inserted {
                let indent = String(line.prefix { $0 == " " || $0 == "\t" })
                result.append("\(indent)D1 = MAX(DUR, 0.0001)")
                inserted = true
            } else if compact.contains("IF(DUR.LE.0)D1=0.0001") {
                if inserted { continue }
                inserted = true
                result.append(line)
            } else {
                result.append(line)
            }
        }

        return result.joined(separator: "\n")
    }

    /// Rebuild the standard NONMEM table records from the actual $INPUT and $PK
    /// content so table headers always match the dataset columns and model parameters.
    static func normalizingTableRecords(_ modText: String, runID: String) -> String {
        let normalizedText = synchronizingOmegaBlock(renumberingEtaIndices(trimmingBeforeProblem(modText)))
        let inputTokens = inputTokens(from: normalizedText)
        let pkParams = pkParameterNames(from: normalizedText)
        let etaTerms = etaTermNames(from: normalizedText)

        let categorical = ["SEX", "STUDY", "STUD", "STUDYID", "STUDYNO", "ADA",
                           "ROUTE", "BQL", "TYPE", "CMT", "EVID", "MDV",
                           "RACE", "TRT", "ARM", "REGION", "GROUP",
                           "COHORT", "TREATMENT", "FORM"]
        let continuous = ["WT", "AGE", "BSA", "HB", "ALB", "CLCR", "EGFR",
                          "BMI", "DOSE", "AMT", "RATE", "DUR"]
        let inputSet = Set(inputTokens)
        var catCols = categorical.filter { inputSet.contains($0) }
        var contCols = continuous.filter { inputSet.contains($0) }
        if catCols.isEmpty {
            catCols = ["STUDY", "SEX"].filter { inputSet.contains($0) }
        }
        if contCols.isEmpty {
            contCols = ["WT", "AGE"].filter { inputSet.contains($0) }
        }

        let coreSdtab = Set(["ID", "TIME", "DV", "MDV", "PRED", "IPRED", "CWRES", "CIWRES"])
        let extraSdtab = inputTokens.filter { $0 != "C" && !coreSdtab.contains($0) }
        let params = pkParams.isEmpty ? "CL V" : pkParams.joined(separator: " ")
        let etas = etaTerms.joined(separator: " ")

        let tableBlock = """
        $TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES \(extraSdtab.joined(separator: " ")) ONEHEADER NOPRINT NOAPPEND FILE=sdtab\(runID) FORMAT=s1PE14.7
        $TABLE ID \(params)\(etas.isEmpty ? "" : " \(etas)") NOPRINT NOAPPEND ONEHEADER FILE=patab\(runID)
        $TABLE ID \(etas) FIRSTONLY NOAPPEND NOPRINT FILE=run\(runID).ETA
        $TABLE ID \(catCols.joined(separator: " ")) FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=catab\(runID)
        $TABLE ID \(contCols.joined(separator: " ")) FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=cotab\(runID)
        """

        var lines = normalizedText.components(separatedBy: "\n")
        lines.removeAll { line in
            line.trimmingCharacters(in: .whitespacesAndNewlines)
                .uppercased()
                .hasPrefix("$TABLE")
        }
        lines.append(tableBlock)
        return lines.joined(separator: "\n")
    }

    /// Renumber ETA references so they are always contiguous (ETA1..ETAn) after an IIV
    /// is removed. This prevents invalid models such as ETA1/ETA2/ETA4/ETA5.
    static func renumberingEtaIndices(_ modText: String) -> String {
        guard let regex = try? NSRegularExpression(
            pattern: #"\bETA\s*\(\s*(\d+)\s*\)"#,
            options: [.caseInsensitive]
        ) else {
            return modText
        }

        let ns = modText as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        var mapping = [Int: Int]()
        var nextIndex = 1

        regex.enumerateMatches(in: modText, options: [], range: fullRange) { match, _, _ in
            guard let match, match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: modText),
                  let oldIndex = Int(modText[valueRange]) else {
                return
            }
            if mapping[oldIndex] == nil {
                mapping[oldIndex] = nextIndex
                nextIndex += 1
            }
        }

        let sortedKeys = mapping.keys.sorted()
        if sortedKeys.isEmpty {
            return modText
        }
        let contiguous = sortedKeys == Array(1...sortedKeys.count)
        guard !contiguous else {
            return modText
        }

        let matches = regex.matches(in: modText, options: [], range: fullRange)
        let mutable = NSMutableString(string: modText)
        for match in matches.reversed() {
            guard match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: modText),
                  let oldIndex = Int(modText[valueRange]),
                  let newIndex = mapping[oldIndex] else {
                continue
            }
            mutable.replaceCharacters(in: match.range(at: 1), with: "\(newIndex)")
        }
        return mutable as String
    }

    /// Rebuild $OMEGA in the same order as $PK's ETA references. Missing OMEGA rows
    /// are added (default 0.04), extra rows are dropped, and labels are preserved.
    static func synchronizingOmegaBlock(_ modText: String) -> String {
        let orderedIIV = iivParametersByEtaIndex(from: modText)
        let maxEta = orderedIIV.keys.max() ?? 0
        var existingValues = [String: String]()
        var existingLines: [String] = []
        var inOmega = false

        for line in modText.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = trimmed.uppercased()
            if upper.hasPrefix("$OMEGA") {
                inOmega = true
                continue
            }
            if inOmega && trimmed.hasPrefix("$") {
                break
            }
            guard inOmega else { continue }
            let comment = line.components(separatedBy: ";").dropFirst()
                .joined(separator: ";")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let valuePrefix = line.components(separatedBy: ";").first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !valuePrefix.isEmpty else { continue }
            let key = normalizedParameterKey(comment)
            if !comment.isEmpty {
                existingValues[key] = valuePrefix
            } else {
                existingLines.append(valuePrefix)
            }
        }

        var omegaLines: [String] = []
        if maxEta > 0 {
            for etaIndex in 1...maxEta {
                guard let param = orderedIIV[etaIndex], !param.isEmpty else { continue }
                let value = existingValues[param] ?? "0.04"
                omegaLines.append("\(value) ; IIV \(param)")
            }
        }

        // If the PK block has no ETA references, preserve unlabeled OMEGA rows so a
        // legitimate fixed/empty IIV block is not silently erased.
        if omegaLines.isEmpty {
            omegaLines = existingLines
        }
        omegaLines = diversifiedIIVInitials(omegaLines)

        inOmega = false
        var result: [String] = []
        var omegaAppended = false
        var foundOmega = false
        for line in modText.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = trimmed.uppercased()
            if upper.hasPrefix("$OMEGA") {
                foundOmega = true
                inOmega = true
                result.append(line)
                continue
            }
            if !foundOmega && !omegaAppended && !omegaLines.isEmpty &&
                upper.hasPrefix("$SIGMA") {
                result.append("$OMEGA")
                result.append(contentsOf: omegaLines)
                omegaAppended = true
                result.append(line)
                continue
            }
            if inOmega && trimmed.hasPrefix("$") {
                inOmega = false
                if !omegaAppended {
                    result.append(contentsOf: omegaLines)
                    omegaAppended = true
                }
                result.append(line)
                continue
            }
            if inOmega {
                continue
            }
            result.append(line)
        }
        if inOmega && !omegaAppended {
            result.append(contentsOf: omegaLines)
        }
        return result.joined(separator: "\n")
    }

    /// Perturb identical positive OMEGA initials so covariance estimation is less
    /// likely to hit singular/near-singular curvature.
    private static func diversifiedIIVInitials(_ omegaLines: [String]) -> [String] {
        var positiveIndices: [Int] = []
        var positiveValues: [Double] = []
        for (index, line) in omegaLines.enumerated() {
            let upper = line.uppercased()
            guard !upper.contains("FIX") else { continue }
            let valuePrefix = line.components(separatedBy: ";").first?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let valueToken = valuePrefix.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
            guard let value = Double(valueToken), value > 0 else { continue }
            positiveIndices.append(index)
            positiveValues.append(value)
        }
        guard positiveValues.count >= 2 else { return omegaLines }
        let uniqueValues = Set(positiveValues.map { ($0 * 1_000_000).rounded() / 1_000_000 })
        guard uniqueValues.count == 1 else { return omegaLines }

        let factors: [Double] = [1.0, 1.2, 0.8, 1.4, 0.6, 1.6, 0.9, 1.1]
        let base = positiveValues[0]
        var updated = omegaLines
        for (offset, lineIndex) in positiveIndices.enumerated() {
            let newValue = base * factors[offset % factors.count]
            let newToken = String(format: "%.6g", newValue)
            let line = omegaLines[lineIndex]
            guard let valueRange = line.range(of: #"[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?"#, options: .regularExpression) else {
                continue
            }
            updated[lineIndex] = line.replacingCharacters(in: valueRange, with: newToken)
        }
        return updated
    }

    private static func iivParametersByEtaIndex(from modText: String) -> [Int: String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"(?<!TV)([A-Z][A-Z0-9_]*)\s*=\s*[^\n]*EXP\s*\(\s*ETA\s*\(\s*(\d+)\s*\)"#,
            options: [.caseInsensitive]
        ) else {
            return [:]
        }
        var result = [Int: String]()
        var inPK = false
        for line in modText.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = trimmed.uppercased()
            if upper.hasPrefix("$PK") {
                inPK = true
                continue
            }
            if inPK && trimmed.hasPrefix("$") {
                break
            }
            guard inPK else { continue }
            let ns = line as NSString
            let range = NSRange(location: 0, length: ns.length)
            for match in regex.matches(in: line, options: [], range: range) {
                guard match.numberOfRanges > 2,
                      let etaRange = Range(match.range(at: 2), in: line),
                      let etaIndex = Int(line[etaRange]) else {
                    continue
                }
                let param = ns.substring(with: match.range(at: 1)).uppercased()
                if result[etaIndex] == nil {
                    result[etaIndex] = param
                }
            }
        }
        return result
    }

    private static func inputTokens(from modText: String) -> [String] {
        guard let inputLine = modText.components(separatedBy: "\n")
            .first(where: { $0.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("$INPUT") })
        else { return [] }
        return inputLine
            .dropFirst("$INPUT".count)
            .split(whereSeparator: \.isWhitespace)
            .map { String($0).uppercased() }
    }

    private static func pkParameterNames(from modText: String) -> [String] {
        let pattern = #"\bTV([A-Z][A-Z0-9_]*)\s*=\s*THETA"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }
        var seen = Set<String>()
        var result: [String] = []
        var inPK = false
        for line in modText.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = trimmed.uppercased()
            if upper.hasPrefix("$PK") {
                inPK = true
                continue
            }
            if inPK && trimmed.hasPrefix("$") {
                break
            }
            guard inPK else { continue }
            let ns = line as NSString
            let range = NSRange(location: 0, length: ns.length)
            for match in regex.matches(in: line, options: [], range: range) where match.numberOfRanges > 1 {
                let name = ns.substring(with: match.range(at: 1)).uppercased()
                if seen.insert(name).inserted {
                    result.append(name)
                }
            }
        }
        return result
    }

    private static func etaTermNames(from modText: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: #"\bETA\s*\(\s*(\d+)\s*\)"#, options: [.caseInsensitive]) else {
            return []
        }
        var indices = Set<Int>()
        let ns = modText as NSString
        let range = NSRange(location: 0, length: ns.length)
        for match in regex.matches(in: modText, options: [], range: range) where match.numberOfRanges > 1 {
            if let value = Int(ns.substring(with: match.range(at: 1))) {
                indices.insert(value)
            }
        }
        return indices.sorted().map { "ETA\($0)" }
    }

    /// Detect which of the given continuous covariates are time-varying, i.e. their value
    /// changes across rows for at least one subject (same ID). PsN SCM needs these listed
    /// in the config's `time_varying=` line so it builds the time-varying relation correctly.
    static func detectTimeVaryingCovariates(
        projectURL: URL,
        dataFile: String,
        continuousCovs: [String],
        log: ((String) -> Void)? = nil
    ) -> [String] {
        let candidates = continuousCovs.map { $0.uppercased() }
        guard !candidates.isEmpty else { return [] }
        guard let raw = try? String(contentsOf: projectURL.appendingPathComponent(dataFile), encoding: .utf8) else {
            log?("SCM diag: time_varying detection could not read \(dataFile)")
            return []
        }
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
                            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: true)
        guard let headerLine = lines.first, lines.count > 1 else { return [] }
        let headers = parseCSVLine(String(headerLine)).map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
        guard let idIdx = headers.firstIndex(of: "ID") else {
            log?("SCM diag: time_varying detection — no ID column found")
            return []
        }
        var covIdx: [String: Int] = [:]
        for cov in candidates {
            if let idx = headers.firstIndex(of: cov) { covIdx[cov] = idx }
        }
        guard !covIdx.isEmpty else { return [] }

        // subject -> covariate -> set of distinct values seen
        var subjectValues: [String: [String: Set<Double>]] = [:]
        var timeVarying = Set<String>()
        for line in lines.dropFirst() {
            let cols = parseCSVLine(String(line)).map { $0.trimmingCharacters(in: .whitespaces) }
            guard idIdx < cols.count else { continue }
            let id = cols[idIdx]
            guard !id.isEmpty, id != "." else { continue }
            var subj = subjectValues[id, default: [:]]
            for (cov, idx) in covIdx {
                guard idx < cols.count else { continue }
                let rawValue = cols[idx]
                guard let v = Double(rawValue) else { continue }
                var values = subj[cov, default: []]
                values.insert(v)
                subj[cov] = values
                if values.count >= 2 { timeVarying.insert(cov) }
            }
            subjectValues[id] = subj
            if timeVarying.count >= covIdx.count { break }
        }
        let result = candidates.filter { timeVarying.contains($0) }
        log?("SCM diag: time-varying continuous covariates detected: \(result.isEmpty ? "(none)" : result.joined(separator: ","))")
        return result
    }

    /// Mean of each numeric demographic covariate, using one value per subject when ID exists.
    /// These means are the required denominators for continuous SCM relations.
    private static func continuousCovariateMeans(projectURL: URL, dataFile: String) -> [String: Double] {
        let candidates = ["WT", "AGE", "BSA", "HB", "ALB", "CLCR", "EGFR", "BMI", "DOSE"]
        guard let raw = try? String(contentsOf: projectURL.appendingPathComponent(dataFile), encoding: .utf8) else {
            return [:]
        }
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
                            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: true)
        guard let headerLine = lines.first, lines.count > 1 else { return [:] }
        let headers = parseCSVLine(String(headerLine)).map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
        let idIdx = headers.firstIndex(of: "ID")
        var covIdx: [String: Int] = [:]
        for cov in candidates {
            if let idx = headers.firstIndex(of: cov) { covIdx[cov] = idx }
        }
        guard !covIdx.isEmpty else { return [:] }

        var values: [String: [Double]] = [:]
        var seenSubjects: [String: Set<String>] = [:]
        for line in lines.dropFirst() {
            let cols = parseCSVLine(String(line)).map { $0.trimmingCharacters(in: .whitespaces) }
            let subjectID: String? = idIdx.flatMap { idx -> String? in
                guard idx < cols.count else { return nil }
                let value = cols[idx]
                return (value.isEmpty || value == ".") ? nil : value
            }
            for (cov, idx) in covIdx {
                guard idx < cols.count, let value = Double(cols[idx]), value > 0 else { continue }
                if let subjectID {
                    if seenSubjects[cov, default: []].contains(subjectID) { continue }
                    seenSubjects[cov, default: []].insert(subjectID)
                }
                values[cov, default: []].append(value)
            }
        }
        return values.mapValues { $0.reduce(0, +) / Double($0.count) }
    }

    private static func datasetPreview(projectURL: URL, dataFile: String) -> String {
        let url = projectURL.appendingPathComponent(dataFile)
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
            return "Dataset \(dataFile) could not be read."
        }
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: false)
        let sample = lines.prefix(28).joined(separator: "\n")
        return "\(sample)\n\nRows shown: \(min(lines.count, 28)) of \(lines.count)"
    }

    private static func normalizedBaseURL(_ baseURL: String) -> String {
        let trimmed = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let hasVersionSegment = trimmed.hasSuffix("/v1")
            || trimmed.range(of: #"/v\d+(?:beta)?$"#, options: .regularExpression) != nil
        return hasVersionSegment ? trimmed : trimmed.appending("/v1")
    }

    private static func isLikelyLocalEndpoint(_ baseURL: String) -> Bool {
        let url = baseURL.lowercased()
        return url.contains("127.0.0.1")
            || url.contains("localhost")
            || url.contains("0.0.0.0")
            || url.contains("::1")
    }

    /// Keep prompts within a budget that small local models can actually process.
    /// Cloud providers keep the larger limits so remote quality is not reduced.
    private static func contextLimit(baseURL: String, remote: Int, local: Int) -> Int {
        isLikelyLocalEndpoint(baseURL) ? local : remote
    }

    /// Stable, reusable prefix for DeepSeek-style automatic context caching.
    /// Order must stay identical across every automation call; otherwise the cache
    /// stops at the first changed token and most tokens become cache misses.
    private static func canonicalRuleContext(rules: String, modelLibrary: String) -> String {
        """
        AutoPMX PopPK model library:
        \(modelLibrary.prefix(35_000))

        AutoPMX rule/knowledge context:
        \(rules.prefix(80_000))

        \(ModelRunEvidence.controlStreamBlockContract)
        """
    }

    private static func applyAuthorization(_ apiKey: String, to request: inout URLRequest) {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        request.addValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
    }

    // MARK: - SCM Config Generation

    /// Build a PsN SCM configuration file. Swift builds all the static parts.
    /// AI is only asked to detect PK parameters with IIV from the $PK block.
    static func generateSCMConfig(
        baseURL: String,
        model: String,
        modText: String,
        dataFile: String,
        modFileName: String,       // e.g. "run32.mod"
        projectURL: URL,
        apiKey: String = "",
        pForward: String = "0.01",
        pBackward: String = "0.001",
        includedCovariates: Set<String>? = nil,
        log: ((String) -> Void)? = nil,
        apiFormat: APIFormat = .openAICompatible
    ) async throws -> String {
        let profile = analyzeDataset(projectURL: projectURL, dataFile: dataFile, log: log)

        // ── Find $INPUT line ──
        let rawInputLine = modText.components(separatedBy: "\n")
            .first(where: { $0.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("$INPUT") })?
            .trimmingCharacters(in: .whitespaces) ?? ""
        log?("SCM diag: raw $INPUT line: \(rawInputLine)")

        // Strip $INPUT prefix to get column names only
        let inputLine = rawInputLine.uppercased().hasPrefix("$INPUT")
            ? String(rawInputLine.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            : rawInputLine
        let modelInput = inputLine.uppercased()
        log?("SCM diag: columns from $INPUT: \(modelInput)")

        // ── Pre‑compute covariate lists from dataset profile + $INPUT cross‑check ──
        log?("SCM diag: dataset profile - hasWT:\(profile.hasWT) hasAGE:\(profile.hasAGE) hasSEX:\(profile.hasSEX)")
        log?("SCM diag: modelInput contains AGE:\(modelInput.contains("AGE")), WT:\(modelInput.contains("WT")), SEX:\(modelInput.contains("SEX"))")

        // Fallback: if analyzeDataset() didn't find ANY covariate columns (likely file/parse error),
        // trust the $INPUT line directly — it IS the authoritative source for model columns.
        let modelColumns = Set(inputLine.uppercased().components(separatedBy: .whitespaces))
        let knownContinuous: Set<String> = ["WT", "AGE", "BSA", "HB", "ALB", "CLCR", "EGFR", "BMI", "DOSE"]
        let knownCategorical: Set<String> = [
            "SEX", "STUDY", "STUD", "STUDYID", "STUDYNO", "ROUTE", "ADA",
            "RACE", "TRT", "ARM", "REGION", "TYPE", "GROUP", "COHORT", "TREATMENT"
        ]
        let selected = includedCovariates?.map { $0.uppercased() } ?? []
        let selectedCovs: Set<String> = selected.isEmpty
            ? knownContinuous.union(knownCategorical)
            : Set(selected)
        let available = selectedCovs.intersection(modelColumns)
        let allCovs = available.sorted()
        let contCovs = allCovs.filter { knownContinuous.contains($0) }
        let catCovs = allCovs.filter { knownCategorical.contains($0) }
        let contCovStr = contCovs.joined(separator: ",")
        let catCovStr = catCovs.joined(separator: ",")
        let allCovStr = allCovs.joined(separator: ",")
        log?("SCM diag: contCovs=[\(contCovStr)], catCovs=[\(catCovStr)], allCovs=[\(allCovStr)]")

        // Continuous covariates whose value changes within a subject must be declared as
        // time-varying so PsN SCM uses the per-row value correctly.
        let timeVaryingCovs = detectTimeVaryingCovariates(
            projectURL: projectURL, dataFile: dataFile,
            continuousCovs: contCovs, log: log
        )
        let timeVaryingStr = timeVaryingCovs.joined(separator: ",")
        log?("SCM diag: time_varying=[\(timeVaryingStr)]")

        // valid_states: continuous = 1, {N+3}; categorical = 1, {M+1}
        // Use max() to avoid "1,1" duplicate states error when no covariates
        let contMaxState = max(contCovs.count + 3, 3)
        let catMaxState = max(catCovs.count + 1, 1)
        log?("SCM diag: valid_states → continuous=1,\(contMaxState) categorical=1,\(catMaxState)")

        // ── Ask AI ONLY to detect IIV params from $PK ──
        var iivParams: [String] = []
        do {
            iivParams = try await detectIIVParams(
                baseURL: baseURL, model: model,
                modText: modText, apiKey: apiKey,
                apiFormat: apiFormat
            )
            log?("SCM diag: AI-detected IIV params: \(iivParams)")
        } catch {
            log?("SCM diag: AI IIV detection failed (\(error.localizedDescription)), using fallback")
            iivParams = fallbackIIVDetection(modText: modText)
            log?("SCM diag: fallback IIV detection: \(iivParams)")
        }

        // ── Build the config entirely in Swift ──
        var lines: [String] = []
        lines.append("model = \(modFileName)")
        lines.append("threads =40")
        lines.append("search_direction=\(pForward == pBackward ? "forward" : "both")")
        lines.append("p_forward=\(pForward)")
        lines.append("p_backward=\(pBackward)")
        lines.append("abort_on_fail=0")
        lines.append("")
        lines.append("continuous_covariates=\(contCovStr)")
        lines.append("categorical_covariates=\(catCovStr)")
        if !timeVaryingStr.isEmpty {
            lines.append("time_varying=\(timeVaryingStr)")
        }
        lines.append("")
        lines.append("[test_relations]")
        for param in iivParams {
            lines.append("\(param)=\(allCovStr)")
        }
        lines.append("")
        lines.append("[valid_states]")
        lines.append("continuous = 1,\(contMaxState)")
        lines.append("categorical = 1,\(catMaxState)")

        let config = lines.joined(separator: "\n") + "\n"
        log?("SCM diag: generated config (\(config.count) bytes)")
        return config
    }

    /// DuDu writes the next model in its SCM replication sequence: it starts from the
    /// previous step's run and adds/removes covariate relations EXACTLY following the
    /// PsN SCM forward-inclusion / backward-elimination path, copying SCM's own
    /// parameterization so the result is directly comparable with SCM's final model.
    static func generateSCMStepModel(
        baseURL: String,
        model: String,
        projectURL: URL,
        dataFile: String,
        sourceRun: String,
        nextRun: String,
        targetCovariates: [String],   // relation tokens to be PRESENT, e.g. ["CLWT", "CLAGE"]
        removedCovariates: [String],  // relation tokens to be REMOVED (backward steps), e.g. ["CLAGE"]
        stepType: String,             // "forward" | "backward"
        scmFinalModelText: String,    // SCM's own final model — the parameterization reference
        apiKey: String = "",
        sessionId: String? = nil,
        apiFormat: APIFormat = .openAICompatible
    ) async throws -> (text: String, usage: TokenUsage?) {
        let source = projectURL.appendingPathComponent("run\(sourceRun).mod")
        let fullSourceText = (try? String(contentsOf: source, encoding: .utf8)) ?? ""
        let sourceText = String(fullSourceText.prefix(20_000))
        let profile = analyzeDataset(projectURL: projectURL, dataFile: dataFile)
        var continuousMeans = continuousCovariateMeans(projectURL: projectURL, dataFile: dataFile)
        if continuousMeans["WT"] == nil, let wtMean = profile.wtMean { continuousMeans["WT"] = wtMean }
        if continuousMeans["AGE"] == nil, let ageMean = profile.ageMean { continuousMeans["AGE"] = ageMean }

        // Deterministic path first: rebuild the model with SCM's own `{PARAM}{COV}`
        // parameterization (e.g. V1WT=(WT/62.27)**THETA(7), V1COV=V1WT, TVV1 = V1COV*TVV1),
        // so data columns are never shadowed and the naming always matches PsN.
        if let built = SCMStepModelBuilder.build(
            sourceText: fullSourceText,
            referenceText: scmFinalModelText,
            targetTokens: targetCovariates,
            sourceRun: sourceRun,
            nextRun: nextRun,
            continuousMeans: continuousMeans
        ) {
            return (built, nil)
        }

        let url = try endpointURL(baseURL: baseURL, path: "chat/completions")
        let targetStr = targetCovariates.isEmpty ? "none (keep base model)" : targetCovariates.joined(separator: ", ")
        let removedStr = removedCovariates.isEmpty ? "none" : removedCovariates.joined(separator: ", ")
        let referenceLimit = 12_000
        let meanLines = continuousMeans.isEmpty
            ? "No dataset means are available; if a mean is required, use the mean shown in the parameterization reference."
            : continuousMeans.sorted { $0.key < $1.key }
                .map { "\($0.key) mean = \(String(format: "%.6g", $0.value))" }
                .joined(separator: "\n")

        let prompt = """
        You are an expert NONMEM pharmacometrician reproducing a PsN SCM stepwise covariate selection.

        Create run\(nextRun).mod by editing run\(sourceRun).mod. This is step \(stepType) of the replication.
        \(Self.responseLanguageDirective)

        ━━━ NON-NEGOTIABLE COVARIATE NAMING CONTRACT ━━━
        - NEVER reassign a dataset column (WT, AGE, SEX, STUDY, ...) on the left side of "=".
          Those columns come from the data file and must stay untouched.
        - Every covariate relation MUST be named "{PK parameter}{covariate}", e.g. V1WT, V1AGE,
          V2SEX, CLAGE, QWT. NEVER name a DEFINITION block AGE, WT, SEX, or STUDY alone.
        - For a continuous covariate on V1 you write `V1WT = ((WT/<WT mean>)**THETA(n))`;
          for AGE on CL you write `CLAGE = ((AGE/<AGE mean>)**THETA(n))`. NEVER write `/1`.
        - Wire it through the parameter: `V1COV=V1WT` and `TVV1 = V1COV*TVV1` (multiply, never
          overwrite, and never create a bare `V1=` definition).
        - Use the exact marker blocks from the parameterization reference below
          (`;;; V1WT-DEFINITION START ... END`, `;;; V1-RELATION START ... END`).
        - The target relation tokens below are the ONLY relations allowed in the final $PK.

        ━━━ DATASET CONTINUOUS-COVARIATE MEANS ━━━
        \(meanLines)

        ━━━ EXACT TASK ━━━
        - After this step, the model MUST include EXACTLY these covariate relation tokens: \(targetStr)
        - Covariate relation tokens to remove in this step: \(removedStr)
        - Keep the structural model (ADVAN/TRANS), error model, $OMEGA/$SIGMA, IIV structure, and all non-covariate parameters IDENTICAL to run\(sourceRun).mod.
        - Add or remove ONLY the covariate relations listed above. Do NOT add any other covariate, do NOT "improve" anything else.

        ━━━ PARAMETERIZATION REFERENCE (copy these EXACTLY) ━━━
        SCM's own final model below shows the exact covariate code style PsN used (e.g. `;;; CLWT-DEFINITION` marker blocks, `(WT/median)**THETA(n)` power expressions, `IF(SEX...)` categorical coding, `TVCL = CLCOV*TVCL` wiring).
        Reuse SCM's parameterization verbatim for the relations you add; only renumber $THETA indices as needed.

        \(scmFinalModelText.prefix(referenceLimit))

        ━━━ THETA / OMEGA / TABLE RULES ━━━
        - Every new covariate THETA gets its own line in $THETA with a `; LABEL` comment (label must be the relation token, e.g. `; CLWT`).
        - Copy all existing THETA/OMEGA/SIGMA values from run\(sourceRun).mod unchanged.
        - $TABLE must mirror $PK exactly (same as run\(sourceRun).mod), with the same file names pattern (sdtab/patab/catab/cotab run\(nextRun)).
        - Always include the EBE export table: $TABLE ID ETA1 ... FIRSTONLY NOAPPEND NOPRINT FILE=run\(nextRun).ETA

        Return ONLY the complete run\(nextRun).mod text. No markdown, no explanation.

        Source model run\(sourceRun).mod:
        \(sourceText)
        """

        let (content, usage) = try await sendChatPrompt(
            url: url, model: model, prompt: prompt,
            systemPrompt: "You are a precise NONMEM control-stream editor. You only reproduce SCM's covariate steps — never invent changes.",
            temperature: 0.1, timeout: 120, apiKey: apiKey, sessionId: sessionId,
            apiFormat: apiFormat
        )
        let cleaned = try cleanControlStream(content, projectURL: projectURL, dataFile: nil)
        if let rawCovRegex = try? NSRegularExpression(
            pattern: #"^\s*(WT|AGE|SEX|STUDY|STUD)\s*="#,
            options: []
        ), rawCovRegex.firstMatch(
            in: cleaned,
            options: [],
            range: NSRange(location: 0, length: (cleaned as NSString).length)
        ) != nil {
            throw NSError(
                domain: "LLMCommandService",
                code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "SCM generated model reassigned a dataset covariate column."]
            )
        }
        if let rawMarkerRegex = try? NSRegularExpression(
            pattern: #";{1,3}\s*(WT|AGE|SEX|STUDY|STUD)-DEFINITION\s+START"#,
            options: []
        ), rawMarkerRegex.firstMatch(
            in: cleaned,
            options: [],
            range: NSRange(location: 0, length: (cleaned as NSString).length)
        ) != nil {
            throw NSError(
                domain: "LLMCommandService",
                code: 1003,
                userInfo: [NSLocalizedDescriptionKey: "SCM generated model used a bare dataset covariate definition."]
            )
        }
        if let divisionByOneRegex = try? NSRegularExpression(
            pattern: #"\(\(\s*[A-Za-z0-9_]+\s*/\s*1\s*\)\s*\*\*\s*THETA"#,
            options: [.caseInsensitive]
        ), divisionByOneRegex.firstMatch(
            in: cleaned,
            options: [],
            range: NSRange(location: 0, length: (cleaned as NSString).length)
        ) != nil {
            throw NSError(
                domain: "LLMCommandService",
                code: 1004,
                userInfo: [NSLocalizedDescriptionKey: "SCM generated model normalized a continuous covariate by 1 instead of its dataset mean."]
            )
        }
        for token in targetCovariates where !cleaned.contains(";;; \(token)-DEFINITION START") {
            throw NSError(
                domain: "LLMCommandService",
                code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "SCM generated model is missing required covariate definition \(token)."]
            )
        }
        return (cleaned, usage)
    }

    /// Ask AI ONLY: which PK parameters in the $PK block have IIV (i.e. are multiplied by EXP(ETA)).
    /// Returns a list of parameter names like ["CL", "CLM"].
    private static func detectIIVParams(
        baseURL: String,
        model: String,
        modText: String,
        apiKey: String,
        apiFormat: APIFormat = .openAICompatible
    ) async throws -> [String] {
        let url = try endpointURL(baseURL: baseURL, path: "chat/completions")

        let prompt = """
        You are analyzing a NONMEM $PK block. Find ALL PK parameters that have IIV (inter‑individual variability).
        IIV means the parameter definition contains "EXP(ETA" — for example:
          CL = THETA(1)*EXP(ETA(1))   →  param name = CL
          V2 = THETA(2)*EXP(ETA(2))   →  param name = V2

        ⚠️ CRITICAL: Output ONLY the parameter names, ONE PER LINE. NO markdown, NO explanations, NO commentary.

        $PK block:
        \(modText.prefix(20_000))

        List PK params with IIV (one per line):
        """

        let (raw, _) = try await sendChatPrompt(
            url: url, model: model, prompt: prompt,
            temperature: 0.0, timeout: 60, apiKey: apiKey,
            apiFormat: apiFormat
        )
        let stripped = raw
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse: one param per line, skip empty lines
        let params = stripped.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("//") && !$0.hasPrefix("-") && !$0.hasPrefix("*") }
            .filter { $0.rangeOfCharacter(from: .letters) != nil }

        // Fallback: if AI returned garbage, do a simple regex scan in Swift
        if params.isEmpty {
            return fallbackIIVDetection(modText: modText)
        }
        return params
    }

    /// Simple fallback: scan $PK block for EXP(ETA(...)) and extract the variable name.
    private static func fallbackIIVDetection(modText: String) -> [String] {
        var params: [String] = []
        let lines = modText.components(separatedBy: "\n")
        var inPK = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.uppercased().hasPrefix("$PK") { inPK = true; continue }
            if inPK && trimmed.hasPrefix("$") && !trimmed.uppercased().hasPrefix("$PK") { inPK = false; continue }
            guard inPK else { continue }

            if trimmed.uppercased().contains("EXP(ETA") {
                // Extract the PK param name (left side of first =)
                let eqParts = trimmed.components(separatedBy: "=")
                if let lhs = eqParts.first {
                    let name = lhs.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty, name.rangeOfCharacter(from: .letters) != nil {
                        params.append(name)
                    }
                }
            }
        }
        return params
    }

    /// AI suggests a fix for a failing SCM config. Returns the FIXED config built in Swift.
    static func fixSCMConfig(
        baseURL: String,
        model: String,
        currentConfig: String,
        errorLog: String,
        modelText: String,
        skillMemory: String = "",
        apiKey: String = "",
        pForward: String = "0.01",
        pBackward: String = "0.001",
        apiFormat: APIFormat = .openAICompatible
    ) async throws -> String {
        let url = try endpointURL(baseURL: baseURL, path: "chat/completions")

        // Extract current config values (these are already correct from the initial build)
        let cfgLines = currentConfig.components(separatedBy: "\n")
        var modelFile = "model.mod"
        var contCovs = "WT,AGE"
        var catCovs = "SEX"
        var searchDir = "both"
        var iivParams: [String] = []
        for line in cfgLines {
            let lower = line.trimmingCharacters(in: .whitespaces).lowercased()
            if lower.hasPrefix("model") && line.contains("=") {
                modelFile = line.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? modelFile
            }
            if lower.hasPrefix("continuous_covariates") {
                let val = line.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? ""
                if !val.isEmpty { contCovs = val }
            }
            if lower.hasPrefix("categorical_covariates") {
                let val = line.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? ""
                catCovs = val
            }
            if lower.hasPrefix("search_direction") {
                let val = line.components(separatedBy: "=").last?.trimmingCharacters(in: .whitespaces) ?? "both"
                searchDir = val
            }
        }

        // Ask AI ONLY what to change (remove which covs, change direction, etc.)
        let prompt = """
        A PsN SCM run failed. Based on the error, suggest what to CHANGE (not rewrite the whole config).

        ━━━ CURRENT CONFIG ━━━
        \(currentConfig)

        ━━━ ERROR ━━━
        \(errorLog)

        \(skillMemory)

        ━━━ INSTRUCTIONS ━━━
        Output ONLY the FIXES, one per line. Valid fix lines:
          REMOVE_COV=AGE        → remove AGE from all covariate lists
          REMOVE_COV=WT         → remove WT from all covariate lists
          REMOVE_COV=SEX        → remove SEX from all covariate lists
          SEARCH_DIR=forward    → change search_direction to forward
          SEARCH_DIR=backward   → change search_direction to backward
          SEARCH_DIR=both       → keep both

        For MINIMIZATION TERMINATED: try REMOVE_COV for the least important covariate first.
        For ROUNDING ERROR: REMOVE_COV for the covariate with near-zero variance.
        For Hessian/COVARIANCE STEP: try SEARCH_DIR=forward first, then REMOVE_COV if still failing.

        Output fix lines ONLY:
        """

        let (raw, _) = try await sendChatPrompt(
            url: url, model: model, prompt: prompt,
            temperature: 0.1, timeout: 60, apiKey: apiKey,
            apiFormat: apiFormat
        )
        let stripped = raw
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Parse AI fix instructions
        for line in stripped.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("REMOVE_COV=") {
                let cov = trimmed.replacingOccurrences(of: "REMOVE_COV=", with: "").trimmingCharacters(in: .whitespaces)
                contCovs = contCovs.components(separatedBy: ",").filter { $0.trimmingCharacters(in: .whitespaces) != cov }.joined(separator: ",")
                catCovs = catCovs.components(separatedBy: ",").filter { $0.trimmingCharacters(in: .whitespaces) != cov }.joined(separator: ",")
            }
            if trimmed.hasPrefix("SEARCH_DIR=") {
                let dir = trimmed.replacingOccurrences(of: "SEARCH_DIR=", with: "").trimmingCharacters(in: .whitespaces)
                searchDir = dir
            }
        }

        // Re-detect IIV params (may have changed if model was modified)
        let params = fallbackIIVDetection(modText: modelText)
        if !params.isEmpty { iivParams = params }

        // Rebuild the config with AI‑suggested fixes
        let contCovStr = contCovs.trimmingCharacters(in: CharacterSet(charactersIn: ","))
        let catCovStr = catCovs.trimmingCharacters(in: CharacterSet(charactersIn: ","))
        let allCovStr = [contCovStr, catCovStr].filter { !$0.isEmpty }.joined(separator: ",")
        let contMax = max(contCovStr.split(separator: ",").count + 3, 3)
        let catMax = max(catCovStr.split(separator: ",").count + 1, 1)

        var lines: [String] = []
        lines.append("model = \(modelFile)")
        lines.append("threads =40")
        lines.append("search_direction=\(searchDir)")
        lines.append("p_forward=\(pForward)")
        lines.append("p_backward=\(pBackward)")
        lines.append("abort_on_fail=0")
        lines.append("")
        lines.append("continuous_covariates=\(contCovStr)")
        lines.append("categorical_covariates=\(catCovStr)")
        lines.append("")
        lines.append("[test_relations]")
        for param in iivParams {
            lines.append("\(param)=\(allCovStr)")
        }
        lines.append("")
        lines.append("[valid_states]")
        lines.append("continuous = 1,\(contMax)")
        lines.append("categorical = 1,\(catMax)")

        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - Skill Synthesis (AI-driven generalizable lesson extraction)

    /// Ask the LLM to extract ONE generalizable lesson from a modeling experience
    /// (success / repair / finalization).  The result is stripped of project-specific
    /// details — no run IDs, parameter values, drug names, or units — so it can be
    /// injected as a *critical* global lesson that helps the local model in ANY project.
    /// Returns nil when the LLM cannot produce usable output.
    static func synthesizeSkillLesson(
        baseURL: String,
        model: String,
        apiKey: String,
        phase: String,
        problem: String,
        action: String,
        result: String,
        sessionId: String? = nil,
        apiFormat: APIFormat = .openAICompatible
    ) async throws -> (title: String, lesson: String, category: LessonCategory, severity: LessonSeverity)? {
        let url = try endpointURL(baseURL: baseURL, path: "chat/completions")
        let prompt = """
        You are a PopPK modeling expert. From the experience below, synthesize exactly ONE GENERALIZABLE lesson.

        Phase: \(phase)
        What happened (problem / diagnosis): \(problem)
        What was done (action): \(action)
        Result: \(result)

        Rules for synthesis:
        1. MUST NOT mention project-specific details — no run IDs, dataset names, drug names, units, or raw parameter values.
        2. Identify the CAUSE → EFFECT → FIX pattern in general terms.
           Example of good generalization: "When the additive error SD is initialized above 1% of typical DV for high-concentration data, the optimizer struggles to escape the initial plateau."
           Example of bad (too specific): "run005 had Add.RE=500 so minimization failed."
        3. The lesson MUST be actionable for a future modeling agent working on ANY project — the agent should know exactly what to do or avoid.
        4. Assign exactly ONE category from this list: modelStructure, convergence, covariance, initialEstimates, boundaryIssue, scmConfig, scmError, nonmemError, dataIssue, generalTip, userGuidance
        5. Assign severity: "critical" (must always remind the agent), "high" (important with the right context), "medium" (useful tip).

        Output exactly in this format and nothing else (no markdown, no surrounding text):
        TITLE: <short actionable title, one line>
        LESSON: <single-paragraph generalization, ≤350 chars>
        CATEGORY: <category>
        SEVERITY: <critical|high|medium>
        """

        let (text, _) = try await sendChatPrompt(
            url: url, model: model, prompt: prompt,
            temperature: 0.2, timeout: 30, apiKey: apiKey, sessionId: sessionId,
            apiFormat: apiFormat
        )

        var title = "", lesson = ""
        var category: LessonCategory = .generalTip
        var severity: LessonSeverity = .medium
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("TITLE:") { title = trimmed.replacingOccurrences(of: "TITLE:", with: "").trimmingCharacters(in: .whitespaces) }
            else if trimmed.hasPrefix("LESSON:") { lesson = trimmed.replacingOccurrences(of: "LESSON:", with: "").trimmingCharacters(in: .whitespaces) }
            else if trimmed.hasPrefix("CATEGORY:") {
                let raw = trimmed.replacingOccurrences(of: "CATEGORY:", with: "").trimmingCharacters(in: .whitespaces)
                category = LessonCategory.allCases.first { $0.rawValue.lowercased() == raw.lowercased() } ?? .generalTip
            }
            else if trimmed.hasPrefix("SEVERITY:") {
                let raw = trimmed.replacingOccurrences(of: "SEVERITY:", with: "").trimmingCharacters(in: .whitespaces).lowercased()
                severity = LessonSeverity(rawValue: raw) ?? .medium
            }
        }
        guard !title.isEmpty, !lesson.isEmpty else { return nil }
        return (title: title, lesson: lesson, category: category, severity: severity)
    }
}
