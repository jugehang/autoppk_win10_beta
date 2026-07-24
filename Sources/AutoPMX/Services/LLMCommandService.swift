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
    let ageRange: (Double, Double)?    // (min, max) of AGE
    let ageMedian: Double?
    let sexLevels: [Int]               // unique SEX values found
    let studyLevels: [Int]             // unique STUDY values found

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
            lines.append("  WT: \(wtRange.map { "\(String(format: "%.0f", $0.0))–\(String(format: "%.0f", $0.1)) kg" } ?? "N/A"), median = \(wtMedian.map { "\(String(format: "%.0f", $0)) kg" } ?? "N/A")")
        }

        // AGE (continuous)
        if hasAGE {
            lines.append("  AGE: \(ageRange.map { "\(String(format: "%.0f", $0.0))–\(String(format: "%.0f", $0.1)) yr" } ?? "N/A"), median = \(ageMedian.map { "\(String(format: "%.0f", $0)) yr" } ?? "N/A")")
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

        if hasBQL { lines.append("  BQL: flag present in dataset") }
        return lines.joined(separator: "\n")
    }
}

struct LLMCommandService {
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
    }

    struct ChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String
            }

            let message: Message
        }

        let choices: [Choice]
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

        let content: [ContentBlock]
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

        let candidates: [Candidate]
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
    ) async throws -> String {
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
        return decoded.content.first(where: { $0.type == "text" })?.text ?? ""
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
    ) async throws -> String {
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
        return decoded.candidates.first?.content.parts.map(\.text).joined(separator: "\n") ?? "No response."
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
    ) async throws -> String {
        switch apiFormat {
        case .openAICompatible:
            let url = try endpointURL(baseURL: baseURL, path: "chat/completions")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = timeout
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            applyAuthorization(apiKey, to: &request)
            var apiMessages = messages
            if let sp = systemPrompt, !sp.isEmpty {
                apiMessages.insert(.init(role: "system", content: sp), at: 0)
            }
            request.httpBody = try JSONEncoder().encode(
                ChatRequest(model: model, messages: apiMessages, temperature: temperature)
            )
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw NSError(domain: "LLMCommandService", code: http.statusCode, userInfo: [
                    NSLocalizedDescriptionKey: "LLM request failed with HTTP \(http.statusCode)"
                ])
            }
            return try JSONDecoder().decode(ChatResponse.self, from: data).choices.first?.message.content ?? ""

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
                let tips = baseURL.contains("11434") ? """

                📌 Ollama 偶发断连是已知问题：大数据量上下文推理时 Ollama 默认 2 分钟超时会导致服务端断开。
                重启时建议：OLLAMA_NUM_PARALLEL=1 OLLAMA_CONTEXT_LENGTH=131072 ollama serve
                也可考虑换成 MLX（Apple Silicon）或 LM Studio，长时间运行更稳定。
                """ : ""
                return """
                无法连接本地 LLM 服务：\(baseURL)。

                请先启动 OpenAI-compatible 本地服务（Ollama / LM Studio / MLX 等），然后在 AutoPMX 里按 Test LLM。\(tips)
                """
            case .badURL:
                return "LLM Base URL 不合法。LM Studio 通常使用 http://127.0.0.1:1234/v1。"
            default:
                break
            }
        }

        if nsError.domain == "LLMCommandService", nsError.code == 401 {
            return """
            本地 LLM 服务返回 401：\(baseURL)。

            这个端口可能不是 LM Studio 的 OpenAI-compatible 服务，或服务启用了鉴权。请确认 LM Studio Local Server 已开启；如使用需要 API Key 的服务，请在 AutoPMX 里填写 Key。
            """
        }

        if nsError.localizedDescription.localizedCaseInsensitiveContains("could not connect") {
            return """
            无法连接本地 LLM 服务：\(baseURL)。

            请启动 LM Studio 的 Local Server，或把 AutoPMX 里的 LLM URL 改成你本地模型实际使用的端口，然后按 Test LLM。
            """
        }

        return "本地 LLM 请求失败：\(error.localizedDescription)"
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
        lagTime: Double = 0
    ) async throws -> String {
        let url = try endpointURL(baseURL: baseURL, path: "chat/completions")
        let profile = analyzeDataset(projectURL: projectURL, dataFile: dataFile)
        let dataPreview = datasetPreview(projectURL: projectURL, dataFile: dataFile)
        let tableSuffix = runID
        let modelLibrary = modelLibraryText(projectURL: projectURL)
        let recommendedTemplate = recommendedInitialTemplate(for: profile)
        let inputRecord = inputRecordFromDataset(projectURL: projectURL, dataFile: dataFile) ?? defaultInputRecord

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
            Preserve D1=DUR when DUR is present; use RATE only if the dataset relies on RATE.
            """
            routeHardRule = """
            ━━━ ROUTE LOCK: IV INFUSION ━━━
            YOU ARE BUILDING AN IV INFUSION MODEL ONLY.
            - ALLOWED templates: iv_infusion_1c_advan1_trans2 → iv_infusion_2c_advan3_trans4 → iv_infusion_3c_advan11_trans4
            - FORBIDDEN: ADVAN2, ADVAN4, ADVAN12 (oral/extravascular). Any mention of KA, oral, depot, extravascular, F1.
            - The dataset has IV infusion only — do NOT add KA or absorption compartments.
            - If DUR is in the dataset, use D1=DUR in $PK. Do not use RATE unless DUR is absent.
            - Structural escalation path (ONLY this path):
              Run001: 1-comp IV infusion (CL, V, D1=DUR)
              Run002+: 2-comp IV infusion (CL, V1, Q, V2, D1=DUR) — ONLY if GOF supports
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            """
        case "Oral":
            routeGuidance = """
            Oral/extravascular administration detected (CMT=2 with AMT>0).
            Start from template: \(recommendedTemplate).
            If the CMT convention is nonstandard, use the custom DES template rather than inventing ADVAN syntax.
            """
            routeHardRule = """
            ━━━ ROUTE LOCK: ORAL/EXTRAVASCULAR ━━━
            YOU ARE BUILDING AN ORAL/EXTRAVASCULAR MODEL ONLY.
            - ALLOWED templates: extravascular_1c_advan2_trans2 → extravascular_2c_advan4_trans4 → extravascular_3c_advan12_trans4
            - FORBIDDEN: ADVAN1, ADVAN3, ADVAN11 (IV-only). Do not remove KA.
            - The dataset has absorption — KA must be present in $PK and $THETA.
            - Depot = CMT=1, Central = CMT=2 (use S2=V/1000 for scaling).
            - Structural escalation path (ONLY this path):
              Run001: 1-comp oral (KA, CL, V)
              Run002+: 2-comp oral (KA, CL, V2, Q, V3) — ONLY if GOF supports
            ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            """
        default:
            routeGuidance = """
            Route is uncertain. Start from template: \(recommendedTemplate), unless the data preview clearly supports another library template.
            """
            routeHardRule = """
            ━━━ ROUTE: UNCERTAIN ━━━
            Determine route from CMT and AMT columns before writing $SUBROUTINES.
            - If CMT=1 with AMT>0 and no RATE/DUR → IV Bolus
            - If CMT=1 with RATE>0 or DUR>0 → IV Infusion
            - If CMT=2 with AMT>0 → Oral
            ━━━━━━━━━━━━━━━━━━━━
            """
        }

        let prompt = """
        You are an expert NONMEM pharmacometrician building PopPK models for monoclonal antibodies.
        Create the FIRST control stream run\(runID).mod for an automated stepwise model-building project.
        Return ONLY the complete .mod file. No markdown, no explanation outside the file.

        RESIDUAL ERROR INITIAL VALUE RULE (DATA-DRIVEN):
        Dataset DV profile: typical (median) concentration = \(profile.typicalDV.map { String(format: "%.3f", $0) } ?? "unknown") µg/mL
        DV range: \(profile.dvRange.map { "\(String(format: "%.3f", $0.0)) – \(String(format: "%.3f", $0.1))" } ?? "unknown") µg/mL

        Prop.RE (sd): use 0.15 (15% CV) — standard for mAb PK assays.
        Add.RE (sd): use \(profile.typicalDV.map { String(format: "%.3f", min($0 * 0.05, max(1.0, $0 * 0.01))) } ?? "1.0") — roughly 1-5% of typical DV, NEVER exceed 20% of typical DV.
        CRITICAL: Add.RE must be SMALLER than typical DV, not larger. If typical DV is 10 µg/mL, Add.RE ≈ 0.5 NOT 5.0.

        AUTOMATION PHASE: Initial 1-Compartment Model.
        This is the FIRST iteration — use the simplest defensible structural model.
        Subsequent iterations will add compartments, IIV, covariates, and error complexity only when diagnostics support it.

        \(routeGuidance)

        \(routeHardRule)

        \(hasLag ? """
        ━━━ ABSORPTION LAG DETECTED ━━━
        Dose-normalized C-T analysis detected absorption lag (Tlag ≈ \(String(format: "%.2f", lagTime))).
        Most subjects have near-zero DV at the earliest post-dose time point.
        Include ALAG1 in $PK for ADVAN2/ADVAN4 models, or define TLAG for ADVAN13:
          ALAG1 = THETA(n)   (for ADVAN2/ADVAN4)
          or: TLAG = THETA(n); DADT(1) = KA * A(1) ... with lag logic (for ADVAN13)
        Add THETA for lag time: (0, \(String(format: "%.2f", max(lagTime * 0.5, 0.1)))) FIX ; Tlag
        ━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        """ : "")}
        \(profile.summary)

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
           Place D1=DUR and S1=V/1000 AFTER all TVxx and parameter definitions (V must be defined before S1 references it).
        6. $ERROR:
           - Define IPRED = F (not PRED)
           - Always use the combined proportional + additive error form from the library.
           - SIGMA(1,1) is fixed residual scale; ETA(i) is individual random effect.
        7. $THETA: EVERY line MUST be exactly `(0, value)` format — lower bound fixed to 0, no upper bound. NEVER write a bare value without parentheses. Example:
               (0, 0.012) ; CL (L/h)
               (0, 4.0)   ; V (L)
               (0, 0.15)  ; Prop.RE (sd)
               (0, 1.0)   ; Add.RE (sd)
             CRITICAL: Every THETA line MUST begin with `(0, ` and end with `)`. Bare values like `0.2` are INVALID NONMEM syntax.
             Use L/h for clearance, NOT L/day. Typical mAb CL: 0.008-0.02 L/h.

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
           - IV models (ADVAN1/3/11): ALWAYS include S1=V/1000 (1-cpt) or S1=V1/1000 (2+/3-cpt) in $PK.
           - Oral models (ADVAN2/4/12): ALWAYS include S2=V/1000 (1-cpt) or S2=V2/1000 (2+/3-cpt) in $PK.
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
             Only in LATER runs (run002+) may you consider reducing IIV if shrinkage > 30% or RSE > 50%.
           9. $SIGMA 1 FIX for residual scale; the residual SDs are THETA labels Prop.RE (sd) and Add.RE (sd).
        10. $EST METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10
        11. $COV UNCONDITIONAL
        12. $TABLE records (each on ONE line) — CRITICAL: ONLY list parameters that are DEFINED in this specific model.
            - 1-compartment model (CL, V only): the PK/TABLE parameters are ONLY CL and V.
            - 2-compartment model (CL, V1, Q, V2): the PK/TABLE parameters are CL, V1, Q, V2.
            - Extravascular model (CL, V, KA): the PK/TABLE parameters are CL, V, KA.
            - Extravascular 2-comp (CL, V2, Q, V3, KA): the PK/TABLE parameters are CL, V2, Q, V3, KA.
            - NEVER list Q, V2, or KA in $TABLE for a 1-compartment IV model. These parameters do NOT exist in ADVAN1/ADVAN2 1-comp models.
            - Generate ONLY the ETA(n) that have OMEGA blocks. If only ETA(1) and ETA(2) exist, do NOT list ETA3.

            FIRST determine which compartment model you are writing, then generate $TABLE accordingly:
            $TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES STUDY ONEHEADER NOPRINT NOAPPEND FILE=sdtab\(tableSuffix) FORMAT=s1PE14.7
            $TABLE ID <PK-params-only> <ETA-list-only> NOPRINT NOAPPEND ONEHEADER FILE=patab\(tableSuffix)
            $TABLE ID <PK-params-only> FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=catab\(tableSuffix)
            $TABLE ID <PK-params-only> FIRSTONLY NOPRINT NOAPPEND ONEHEADER FILE=cotab\(tableSuffix)

        Active AutoPMX rule/knowledge context:
        \(rules.prefix(50_000))

        AutoPMX PopPK model library:
        \(modelLibrary.prefix(35_000))

        Dataset preview:
        \(dataPreview)

        Continue to return only the valid .mod file starting with $PROBLEM.
        """

        let content = try await sendChatPrompt(url: url, model: model, prompt: prompt, temperature: 0.1, timeout: 300, apiKey: apiKey)
        return try cleanControlStream(content, projectURL: projectURL, dataFile: dataFile)
    }

    static func evaluateModelRun(
        baseURL: String,
        model: String,
        projectURL: URL,
        runID: String,
        previousRun: String?,
        rules: String,
        diagnosticSummary: String,
        apiKey: String = ""
    ) async throws -> String {
        let url = try endpointURL(baseURL: baseURL, path: "chat/completions")
        let modelLibrary = modelLibraryText(projectURL: projectURL)
        let prompt = """
        You are a PopPK model evaluation AI following FDA guidance. Decide whether the current model should be ACCEPTed as final or REVISEd.

        Start with exactly one word: ACCEPT or REVISE.

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
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        ERROR-FIRST DECISION RULE:
        - If the Evidence contains NONMEM/PsN/NMTRAN failure messages, FMSG text, "AN ERROR WAS FOUND", "NMtran failed", "There is no output", "Could not parse the output file", or a non-zero NONMEM/PsN exit code, you MUST start with REVISE.
        - In that case, diagnose the exact failing control-stream block first and give NEXT_ACTION as one code-level repair. Do not recommend GOF/VPC, covariates, extra compartments, or parameter refinement until the model compiles and produces run*.lst/run*.ext.
        - Use the error line, approximate position marker, and named undefined symbol when present.

        CRUCIAL: The model uses combined proportional+additive error: W = SQRT(THETA(k)**2*IPRED**2 + THETA(k+1)**2). With this formulation, $SIGMA is ALWAYS 1 FIX. The residual SDs are estimated as THETA parameters (Prop.RE and Add.RE). NEVER suggest changing $SIGMA to 2 or estimating SIGMA values — the model already captures all residual variability through the THETAs.
        NEVER suggest adding $SIGMA 2 — this is a NONMEM syntax error that will make the model fail.

        SCALE PARAMETER PLACEMENT RULE:
        S1 or S2 MUST be the LAST line of $PK (after all THETA/ETA definitions).
        IV 1-cmt: S1=V/1000. IV 2+/3-cmt: S1=V1/1000. Oral: S2=V/1000 or S2=V2/1000.
        The scale parameter references V or V1/V2 which must be defined BEFORE the S1/S2 line.

        PROGRESSIVE MODELING STRATEGY — follow this priority order:
        1. First establish the best structural model:
           - Run 1-comp (ADVAN1 TRANS2 for IV, ADVAN2 TRANS2 for oral) as run001.
           - ALWAYS escalate to 2-comp in the next run to compare. The ΔOFV rule above is the SOLE arbiter.
           - If 2-comp ΔOFV > 10.83, continue with 2-comp. Then test 3-comp to confirm 2-comp is best.
           - If 2-comp ΔOFV ≤ 3.84, you may return to 1-comp.
        2. When escalating compartments (1→2 or 2→3):
           - RESPECT inherited IIV state from parent: if parent removed V IIV, keep it removed.
           - If V (central volume) IIV was fixed → V2, V3 IIV start FIXED (same chain: CL→Q, V→V2/V3).
           - New peripheral parameters (Q, Q3, V2, V3): start with OMEGA FIXED at 0.04 on first 3-comp attempt.
             If the run converges, try unfixing one at a time in subsequent runs. If it fails, keep all peripheral IIV FIXED.
           - Only aggressively unfix all IIV on a 3-comp when the 2-comp had ALL IIV freely estimated.
           - 3-comp models that converge with fixed peripheral IIV are MORE useful than crashed 3-comp models — they still provide structural information (ΔOFV vs 2-comp).
        3. Covariance or minimization failure on higher-compartment model:
           - DO NOT retreat to simpler model immediately.
           - Fix ONE parameter's IIV at a time, in this order:
             a) Fix IIV on Q3 (3-comp) or Q (2-comp) — peripheral clearances first.
             b) Fix IIV on V3 (3-comp) or V2 (2-comp).  
             c) Fix IIV on remaining peripheral parameters one at a time.
           - Also try: reduce OMEGA BLOCK size, switch to DIAGONAL OMEGA.
           - Only after 3+ single-parameter fix attempts fail, consider retreating.
        4. Then refine the residual error model:
           - Combined proportional+additive is default. Simplify only if one component is clearly unsupported (RSE > 100% or estimate at boundary).
        5. Then refine IIV on existing parameters:
           - Only remove IIV if eta-shrinkage > 30% or RSE > 50%.

        COVARIATES ARE FORBIDDEN IN PHASE 1. Any step 6 (covariate) is a PHASE VIOLATION.
        Covariates begin ONLY after Phase 1 ACCEPT transitions to Phase 2.

        ANTI-OSCILLATION RULES:
        - NEVER propose a change that UNDOES what the previous iteration just did (e.g., if run(N-1) removed IIV on V, do NOT re-add it in runN).
        - If both the current and previous iteration propose toggling the error model, STOP and ACCEPT the simpler model. Accept that some parameters cannot be estimated with the available data.

        If REVISE, provide:
        - NEXT_ACTION: exactly ONE concrete model change (which record/subroutine/parameter changes)
        - TEMPLATE_ID: the AutoPMX template to use if a structural change is needed; otherwise KEEP_CURRENT_TEMPLATE
        - RATIONALE: which diagnostic evidence (GOF pattern, VPC misfit, parameter RSE, OFV change) supports it, WITH @ref[source] citation
        - SAFETY_CHECK: NONMEM syntax rule to preserve

        All RATIONALE lines must include at least one @ref[RULE_ID: description] citation from the rule context.

        ACCEPT only when:
        - All GOF plots show no systematic bias
        - VPC prediction intervals capture observed data well
        - Parameter RSE < 50% for key structural parameters (CL, V1, V2, Q)
        - Covariance step successful OR (covariance failed but RSE from $COV UNCONDITIONAL are < 50%)
        - No boundary estimates for primary PK parameters
        - CWRES centered around zero without trends
        - (Phase 2 only) ALL available covariates from the Dataset have been tested

        COVARIANCE FAILURE ON HIGHER-COMPARTMENT MODELS:
        - A 2-comp or 3-comp model with successful minimization but failed covariance step is NOT automatically rejected.
        - First try the covariance-failure fixes listed in PROGRESSIVE MODELING STRATEGY step 3.
        - Standard errors from a $COV UNCONDITIONAL run may still be adequate.
        - Only if RSE > 50% for ALL new compartment parameters (Q, V2, Q3, V3) after trying fixes, consider that the data may not support the extra compartment.

        TWO-PHASE MODELING STRATEGY:

        ━━━ IRON RULE: TWO PHASES ARE COMPLETELY SEPARATE ━━━
        Phase 1 = ONLY structural model work. Phase 2 = ONLY covariates.
        You CANNOT work on both in the same run. You CANNOT start Phase 2 until Phase 1 is ACCEPTed.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        ═══ PHASE 1: BASE MODEL SELECTION ═══
        The OFV DECISION RULE at the top of this prompt is the FINAL authority.

        ALLOWED changes in Phase 1: compartment count, error model, IIV structure.
        FORBIDDEN in Phase 1: WT scaling, AGE, SEX, STUDY, or ANY covariate relationship.
        If you suggest a covariate in Phase 1, that is a PHASE VIOLATION.

        MUST escalate: 1-comp → 2-comp → 3-comp (test ONE level higher each time)
        NEVER skip a level. After 2-comp is tested vs 1-comp, test 3-comp vs 2-comp before finalizing.
        The ΔOFV computed from the Evidence dictates the decision. No exceptions.
        ONLY output ACCEPT when the structural model is truly finalized (all compartment levels tested).

        ═══ PHASE 2: COVARIATE MODEL BUILDING ═══
        FORBIDDEN in Phase 2: changing compartment count, error model type, or IIV structure.
        If you suggest a structural change in Phase 2, that is a PHASE VIOLATION.
        ONLY allowed in Phase 2: adding/removing covariate relationships.
        After Phase 1 base model is accepted, IMMEDIATELY begin covariate screening.
        The next run AFTER base model acceptance MUST add at least one covariate.

        ━━━ COVARIATE COMPLETENESS CHECK (HARD RULE) ━━━
        Check the "Dataset:" section at the top of Evidence: "Available covariates: WT, AGE, SEX, ...".
        EVERY available covariate MUST be tested. For each covariate, test against EVERY relevant PK param.
        If any listed covariate has NOT been tested, you MUST output REVISE (not ACCEPT).
        Required tests per covariate:
        - WT: CL, V, Q (all clearance + all volume params) → mandatory FIRST
        - AGE: CL, V → mandatory SECOND
        - SEX: CL, V → mandatory THIRD
        - STUDY: CL, V (if available) → mandatory FOURTH
        Each covariate is an INDEPENDENT scientific question. One being significant does NOT excuse skipping another.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        Steps:
        1. WT allometric scaling: apply to ALL PK params (0.75 for CL/Q, 1.0 for V).
        2. AGE on CL and V: continuous power/linear. Test separately.
        3. SEX on CL and V: categorical proportional shift (SEXCOV = 1 + THETA * (SEX - ref)).
        4. STUDY on CL and V (if multiple studies): categorical shift.
        Keep each if ΔOFV > 3.84 (forward). Remove if ΔOFV < 6.63 (backward).
        5. Clinical significance: PK ratio 0.8–1.25.
        6. Bootstrap (≥200 samples) validates final model.

        Do NOT accept Phase 2 until ALL available covariates from the dataset have been tested.

        Previous run: \(previousRun ?? "none")
        Current run: \(runID)

        Active AutoPMX rule/knowledge context:
        \(rules.prefix(45_000))

        AutoPMX PopPK model library:
        \(modelLibrary.prefix(18_000))

        \(ModelRunEvidence.controlStreamBlockContract)

        Evidence:
        \(diagnosticSummary.prefix(30_000))
        """

        return try await sendChatPrompt(url: url, model: model, prompt: prompt, temperature: 0.1, timeout: 240, apiKey: apiKey)
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
        apiKey: String = ""
    ) async throws -> String {
        let source = projectURL.appendingPathComponent("run\(sourceRun).mod")
        let sourceText = ((try? String(contentsOf: source, encoding: .utf8)) ?? "").prefix(20_000)
        let url = try endpointURL(baseURL: baseURL, path: "chat/completions")
        let modelLibrary = modelLibraryText(projectURL: projectURL)
        let dataFile = dataFileName(from: String(sourceText)) ?? "NM_dat_new.csv"
        let inputRecord = inputRecordFromDataset(projectURL: projectURL, dataFile: dataFile) ?? defaultInputRecord

        let prompt = """
        You are an expert NONMEM pharmacometrician evolving a PopPK model step by step.
        Create run\(nextRun).mod by applying EXACTLY ONE specific improvement to run\(sourceRun).mod.
        Return ONLY the complete .mod file. No markdown, no explanation.

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

        STEP 1 (mandatory first): WT allometric scaling — APPLY TO ALL PK PARAMETERS.

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
          Test EVERY covariate listed there against ALL relevant PK parameters:
          - WT → CL, Q, V1, V2 (all params)
          - AGE → CL, V1
          - SEX → CL, V1
          - STUDY → CL, V1 (if available)
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

        ━━━ ROUTE IS LOCKED — DO NOT CHANGE ROUTE ━━━
        The route (IV/Oral) was determined from the dataset and is FIXED for the entire modeling run.
        - If source is IV (ADVAN1/ADVAN3/ADVAN11), DO NOT switch to ADVAN2/ADVAN4/ADVAN12 (oral). DO NOT add KA, F1, or depot.
        - If source is oral (ADVAN2/ADVAN4/ADVAN12), DO NOT switch to ADVAN1/ADVAN3/ADVAN11 (IV). DO NOT remove KA.
        - Only allowed structural change: 1-comp → 2-comp → 3-comp within the same route.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        \(isCovariatePhase ? """
        ━━━ PHASE 2 HARD RULE — NO STRUCTURAL CHANGES ━━━
        The structural model is FINALIZED. Do NOT change ADVAN, TRANS, compartment count, error model type, or IIV architecture.
        ONLY add/examine/remove covariates. If you touch $SUBROUTINES or change compartment count, the model is WRONG.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
        """ : """
        ━━━ PHASE 1 HARD RULE — NO COVARIATES ━━━
        Covariates are ONLY allowed in Phase 2. Do NOT add WT scaling, AGE, SEX, or any covariate relationship.
        Only work on: structural model (compartments), error model, and IIV.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
        """)}
        EVOLUTION RULES:
        - FIRST PASS: refine structural model (1-comp → 2-comp → 3-comp, test each level)
        - SECOND PASS: refine error model (combined is default)
        - THIRD PASS: add/remove IIV one parameter at a time

        PHASE 2 — COVARIATE AUTOSTART (WT ALLOMETRIC SCALING):

        ━━━ CRITICAL: CORRECT ALLOMETRIC EXPONENTS ━━━
        Clearance-related parameters (CL, Q, Q2, Q3): exponent = 0.75 (fixed, not estimated)
        Volume-related parameters    (V1, V2, V3, V):  exponent = 1.0  (fixed, not estimated)

        APPLY TO ALL PK PARAMETERS — do NOT skip any:

        For a 1-comp model:
          TVCL = THETA(CL) * (WT/median_WT)**0.75
          TVV  = THETA(V)  * (WT/median_WT)**1.0
          → Add 2 new THETAs: (0, 0.75) FIX for CL exponent, (0, 1.0) FIX for V exponent

        For a 2-comp model:
          TVCL = THETA(CL) * (WT/median_WT)**0.75
          TVV1 = THETA(V1) * (WT/median_WT)**1.0
          TVQ  = THETA(Q)  * (WT/median_WT)**0.75
          TVV2 = THETA(V2) * (WT/median_WT)**1.0
          → Add 2 new THETAs: (0, 0.75) FIX for clearance exponent, (0, 1.0) FIX for volume exponent
          → REUSE the same exponent THETA for ALL clearance params and ALL volume params
          → Do NOT create separate exponents for each parameter

        For a 3-comp model:
          TVCL = THETA(CL) * (WT/median_WT)**0.75
          TVV1 = THETA(V1) * (WT/median_WT)**1.0
          TVQ2 = THETA(Q2) * (WT/median_WT)**0.75
          TVV2 = THETA(V2) * (WT/median_WT)**1.0
          TVQ3 = THETA(Q3) * (WT/median_WT)**0.75
          TVV3 = THETA(V3) * (WT/median_WT)**1.0
          → Same 2 new THETAs: (0, 0.75) FIX and (0, 1.0) FIX

        COMPUTE median_WT from the dataset's WT column. Use the actual value.
        If unavailable, use 70 kg as default.

        VIOLATION CHECK: if any clearance param uses 1.0 or any volume param uses 0.75,
        the model is WRONG. Fix it.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        STRUCTURAL ESCALATION INITIAL VALUES (CRITICAL — prevents minimization failure):
        When escalating 1-comp → 2-comp: copy CL and V directly from parent run's THETA as CL and V1.
        Keep the EXACT same numeric values and units — do not convert or rescale.
        Set peripheral V2 = V1 * 0.3 to 0.5 (smaller peripheral volume).
        Set Q = CL * 0.5 to 0.8 (moderate inter-compartment clearance).
        The model should be a gentle perturbation — large peripheral volumes or high Q will crash.
        When escalating 2-comp → 3-comp: use the 2-comp CL, V1, Q, V2.
        Set V3 = V1 * 0.3 to 0.5. Set Q3 = CL * 0.3 to 0.6 (even smaller for third compartment).

        IIV STRATEGY FOR NEW COMPARTMENTS (CRITICAL):

        RULE 1 — RESPECT PREVIOUS IIV DECISIONS:
        Examine the PARENT run's $OMEGA and $PK blocks. If a parameter's IIV was already REMOVED
        (ETA absent from $PK, or OMEGA row for that parameter is gone/0 FIX):
        → Do NOT re-add IIV on that parameter in the escalated model.
        → For related parameters in new compartments, START WITH IIV FIXED too.

        RULE 2 — CENTRAL → PERIPHERAL IIV CHAIN:
        If central volume V (or V1) IIV could NOT be estimated (removed in previous run due to shrinkage > 30%
        or RSE > 50%), then peripheral volumes V2, V3 MUST also start with FIXED IIV.
        Rationale: if you can't estimate between-subject variability for the central compartment,
        you certainly cannot estimate it for peripheral compartments.
        Same chain applies: if CL IIV was fixed → Q, Q2, Q3 IIV start fixed.

        RULE 3 — 3-COMPARTMENT CONVERGENCE STRATEGY (ONE PARAMETER AT A TIME):
        When a 3-comp model fails minimization:
        a) First fix: remove IIV on Q3 ONLY (keep Q, V2, V3 IIV if they were estimated before).
        b) If still fails: remove IIV on V3 ONLY (re-add Q3 IIV, remove V3 IIV).
        c) If still fails: remove IIV on Q ONLY, keep CL, V1 IIV.
        d) If still fails: remove IIV on V2 ONLY.
        e) If still fails with CL+V1-only IIV: ACCEPT 2-comp as the base model.
        NEVER fix two parameters' IIV in the same run — always one at a time.

        When adding a NEW 3-comp from a stable 2-comp:
        a) First 3-comp run: inherit ALL existing IIV state from 2-comp (keep what was free, keep what was fixed).
           Add new Q3, V3 parameters WITHOUT IIV (no OMEGA rows for them).
        b) If minimization succeeds → add IIV to Q3 in next run (modest 0.04), run again.
        c) If Q3 IIV succeeds → add IIV to V3 in next run.
        d) At each step, if adding IIV causes failure, remove it and keep the model as-is.
        e) A 3-comp model with only CL, V1 IIV is still useful for ΔOFV comparison vs 2-comp.

        RULE 4 — START MODEST:
        When first adding IIV to a new parameter: OMEGA = 0.04 (not estimated yet, fixed or diagonal).
        Only increase to 0.09 and unfix after the model converges with 0.04.
        UNIT CONSISTENCY (CRITICAL): Keep the SAME unit for each parameter as the parent run.
        If run001 has CL in L/h, ALL subsequent runs MUST use L/h — NEVER switch to L/day.
        If run001 has CL in L/day, ALL subsequent runs MUST use L/day — NEVER switch to L/h.
        Copy the initial values and units directly from the parent run's $THETA block.
        Only change values when there is diagnostic evidence supporting the change.

        Only move to the next pass when the current one is adequate.
        NEVER add a second compartment in run002 unless run001 residuals/GOF clearly show misspecification.
        NEVER add covariates in run002 or run003 — fix structure and error model first.
        When changing structure, switch to the matching AutoPMX library template instead of hand-writing a new SUBROUTINES/PK/ERROR layout.
        When keeping structure, preserve the current model's library-compatible block shape and change only the justified section.
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
           IV 1-cmt: S1=V/1000. IV 2+/3-cmt: S1=V1/1000. Oral: S2=V/1000 or S2=V2/1000.
           The scale parameter references V or V1/V2 — it MUST appear AFTER the variable is defined.
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
        - IV models: ALWAYS include S1=V/1000 (1-cpt) or S1=V1/1000 (2+/3-cpt) in $PK.
        - Oral models: ALWAYS include S2=V/1000 (1-cpt) or S2=V2/1000 (2+/3-cpt) in $PK.
        - Without S1/S2, NONMEM issues WARNING 23 — parameter estimates become unreliable.
        ─────────────────────────────────────────────
        Before writing $TABLE: scan $PK, list every parameter, use THAT list.
        If a parameter (Q, V2, KA etc.) is NOT in $PK, do NOT put it in $TABLE.
        Also check $OMEGA — only list ETA(n) that exist. Each ETA gets its own line (one variance per line).

        Active AutoPMX rule/knowledge context:
        \(rules.prefix(45_000))

        AutoPMX PopPK model library:
        \(modelLibrary.prefix(35_000))

        Diagnosis from run\(sourceRun):
        \(diagnosticSummary.prefix(20_000))

        Source model run\(sourceRun).mod:
        \(sourceText)
        """

        let content = try await sendChatPrompt(url: url, model: model, prompt: prompt, temperature: 0.1, timeout: 300, apiKey: apiKey)
        return try cleanControlStream(content, projectURL: projectURL, dataFile: dataFile)
    }

    static func draftPsNCommand(
        baseURL: String,
        model: String,
        runID: String,
        projectURL: URL,
        currentCommand: String,
        rules: String,
        apiKey: String = ""
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
        \(rules.prefix(12_000))

        project_config.json:
        \(configPreview)

        NONMEM control stream:
        \(modPreview)
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthorization(apiKey, to: &request)
        request.httpBody = try JSONEncoder().encode(
            ChatRequest(
                model: model,
                messages: [.init(role: "user", content: prompt)],
                temperature: 0.1
            )
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NSError(domain: "LLMCommandService", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "LLM request failed with HTTP \(http.statusCode)"
            ])
        }

        let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
        let content = decoded.choices.first?.message.content ?? fallback
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
        personality: String = ""
    ) async throws -> String {
        let url = try endpointURL(baseURL: baseURL, path: "chat/completions")

        let modURL = projectURL.appendingPathComponent("run\(currentRun).mod")
        let configURL = projectURL.appendingPathComponent("project_config.json")
        let modPreview = ((try? String(contentsOf: modURL, encoding: .utf8)) ?? "").prefix(10_000)
        let configPreview = ((try? String(contentsOf: configURL, encoding: .utf8)) ?? "").prefix(4_000)
        let modelLibrary = modelLibraryText(projectURL: projectURL).prefix(12_000)

        var apiMessages: [ChatRequest.Message] = [
            .init(role: "system", content: """
            You are DuDu PMx, AutoPMX's AI pharmacometrics assistant.

            \(personality)

            Professional rules (always follow these):
            - Help with NONMEM, PsN, diagnostics, model iteration, and PopPK reasoning.
            - When drafting NONMEM, use the AutoPMX PopPK model library first and fill templates instead of inventing syntax.
            - For AutoPMX datasets using IGNORE=C, $INPUT must mirror the CSV header order; the C column must stay as literal C and never be C=DROP.
            - Use the active AutoPMX rule/knowledge context together with the model library when answering.

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
            \(rules.prefix(30_000))
            \(ModelRunEvidence.controlStreamBlockContract)
            AutoPMX PopPK model library preview:
            \(modelLibrary)
            """)
        ]
        apiMessages.append(contentsOf: messages.suffix(12).map {
            ChatRequest.Message(role: $0.role == .user ? "user" : "assistant", content: $0.text)
        })

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 240
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthorization(apiKey, to: &request)
        request.httpBody = try JSONEncoder().encode(
            ChatRequest(model: model, messages: apiMessages, temperature: 0.2)
        )

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NSError(domain: "LLMCommandService", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "LLM request failed with HTTP \(http.statusCode)"
            ])
        }
        return try JSONDecoder().decode(ChatResponse.self, from: data).choices.first?.message.content ?? "No response."
    }

    static func proposeNextModel(
        baseURL: String,
        model: String,
        projectURL: URL,
        sourceRun: String,
        nextRun: String,
        rules: String,
        apiKey: String = ""
    ) async throws -> String {
        let source = projectURL.appendingPathComponent("run\(sourceRun).mod")
        let sourceText = ((try? String(contentsOf: source, encoding: .utf8)) ?? "").prefix(18_000)
        let url = try endpointURL(baseURL: baseURL, path: "chat/completions")
        let modelLibrary = modelLibraryText(projectURL: projectURL)
        let dataFile = dataFileName(from: String(sourceText)) ?? "NM_dat_new.csv"
        let inputRecord = inputRecordFromDataset(projectURL: projectURL, dataFile: dataFile) ?? defaultInputRecord

        let prompt = """
        You are AutoPMX automated PopPK modeler.
        Create the next NONMEM control stream based on run\(sourceRun).mod.
        Return the complete .mod file only, no Markdown.

        Goal:
        - Improve a mAb PopPK model conservatively.
        - Consider common covariate evolution such as WT on V1 or CL if justified.
        - Keep dataset as NM_dat_new.csv.
        - Update table output filenames to use run \(nextRun): SDTAB\(nextRun), PATAB\(nextRun), 000\(nextRun).ETA, CATAB\(nextRun), COTAB\(nextRun).
        - Keep syntax valid NONMEM.
        - CSV header order is locked. Use exactly: $INPUT \(inputRecord)
        - Use exactly: $DATA \(dataFile) IGNORE=C
        - Never use C=DROP, omit C, reorder C, or create typo aliases such as NTIME=DUMP.
        - If the source model failed NONMEM/PsN/NMTRAN, repair the failing control-stream block first. Do not add model complexity until the model compiles and produces usable NONMEM output.
        - Use the AutoPMX PopPK model library as the syntax source. Do not invent a new NONMEM skeleton.
        - Keep combined proportional + additive residual error unless explicitly instructed otherwise.

        Active AutoPMX rule/knowledge context:
        \(rules.prefix(45_000))

        AutoPMX PopPK model library:
        \(modelLibrary.prefix(30_000))

        \(ModelRunEvidence.controlStreamBlockContract)

        Source model:
        \(sourceText)
        """

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuthorization(apiKey, to: &request)
        request.httpBody = try JSONEncoder().encode(
            ChatRequest(model: model, messages: [.init(role: "user", content: prompt)], temperature: 0.1)
        )
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw NSError(domain: "LLMCommandService", code: http.statusCode, userInfo: [
                NSLocalizedDescriptionKey: "LLM request failed with HTTP \(http.statusCode)"
            ])
        }
        let content = try JSONDecoder().decode(ChatResponse.self, from: data).choices.first?.message.content ?? ""
        return try cleanControlStream(content, projectURL: projectURL, dataFile: dataFile)
    }

    private static func sendChatPrompt(
        url: URL,
        model: String,
        prompt: String,
        temperature: Double,
        timeout: TimeInterval,
        apiKey: String
    ) async throws -> String {
        let maxRetries = 3
        var lastError: Error?

        for attempt in 1...maxRetries {
            do {
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.timeoutInterval = timeout
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                applyAuthorization(apiKey, to: &request)
                request.httpBody = try JSONEncoder().encode(
                    ChatRequest(model: model, messages: [.init(role: "user", content: prompt)], temperature: temperature)
                )

                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    throw NSError(domain: "LLMCommandService", code: http.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "LLM request failed with HTTP \(http.statusCode)"
                    ])
                }
                return try JSONDecoder().decode(ChatResponse.self, from: data).choices.first?.message.content ?? ""
            } catch {
                lastError = error
                let nsError = error as NSError
                let isConnectionError = nsError.domain == NSURLErrorDomain &&
                    (nsError.code == NSURLErrorCannotConnectToHost ||
                     nsError.code == NSURLErrorNetworkConnectionLost ||
                     nsError.code == NSURLErrorTimedOut ||
                     nsError.code == NSURLErrorNotConnectedToInternet)

                if isConnectionError && attempt < maxRetries {
                    let delay = UInt64(pow(2.0, Double(attempt))) * 1_000_000_000  // 2s, 4s, 8s
                    print("[LLM] Connection lost (attempt \(attempt)/\(maxRetries)), retrying in \(delay/1_000_000_000)s...")
                    try? await Task.sleep(nanoseconds: delay)
                    // Quick probe on the base path to see if server is recovering
                    if let endpoint = URL(string: url.absoluteString.replacingOccurrences(of: "/chat/completions", with: "/models")) {
                        var probe = URLRequest(url: endpoint)
                        probe.httpMethod = "GET"
                        probe.timeoutInterval = 5
                        applyAuthorization(apiKey, to: &probe)
                        _ = try? await URLSession.shared.data(for: probe)
                    }
                    continue
                }
                break
            }
        }
        throw NSError(domain: "LLMCommandService", code: (lastError as? NSError)?.code ?? -1, userInfo: [
            NSLocalizedDescriptionKey: """
                无法连接本地 LLM 服务。

                可能原因：
                1. Ollama / MLX / LM Studio 服务意外中断（大数据量推理时偶发）
                2. 模型上下文超载导致服务崩溃

                建议：
                1. 重启本地 LLM 服务后点击 Test LLM
                2. 增加服务的上下文窗口（如 Ollama: ollama serve 时设置 OLLAMA_NUM_PARALLEL=1 OLLAMA_CONTEXT_LENGTH=131072）
                3. 使用更大内存容量的模型或降低并发请求
                4. 在 AutoPMX 中重试
                """
        ])
    }

    private static func cleanControlStream(_ content: String, projectURL: URL? = nil, dataFile: String? = nil) throws -> String {
        let cleaned = content
            .replacingOccurrences(of: "```nonmem", with: "")
            .replacingOccurrences(of: "```nmtran", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let guarded = enforceDatasetRecords(cleaned, projectURL: projectURL, dataFile: dataFile)
        guard guarded.contains("$PROBLEM"), guarded.contains("$DATA"), guarded.contains("$EST") else {
            throw NSError(domain: "LLMCommandService", code: 1001, userInfo: [
                NSLocalizedDescriptionKey: "AI did not return a complete NONMEM control stream"
            ])
        }
        return guarded
    }

    private static func enforceDatasetRecords(_ controlStream: String, projectURL: URL?, dataFile: String?) -> String {
        guard let projectURL else {
            return enforceCommentColumn(controlStream)
        }

        let resolvedDataFile = dataFile ?? dataFileName(from: controlStream) ?? "NM_dat_new.csv"
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
            return "custom_linear_1c_des"
        default:
            return "iv_bolus_1c_advan1_trans2"
        }
    }

    private static let defaultInputRecord = "C ID CYCLE DAY TIME NTIME DV AMT RATE DUR CMT DOSE MDV EVID BQL TYPE STUDY SEX WT AGE"

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

    private static func modelLibraryText(projectURL: URL) -> String {
        var candidates: [URL] = []
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
        - Initial extravascular: ADVAN2 TRANS2 with KA, CL, V, S2=V/1000.
        - IV two-compartment: ADVAN3 TRANS4 with CL, V1, Q, V2, S1=V1/1000.
        - Extravascular two-compartment: ADVAN4 TRANS4 with KA, CL, V2, Q, V3, S2=V2/1000.
        - Custom/nonstandard: ADVAN13 with explicit $MODEL and $DES.
        - $INPUT must mirror the CSV header order exactly. For AutoPMX NM_dat_new.csv: C ID CYCLE DAY TIME NTIME DV AMT RATE DUR CMT DOSE MDV EVID BQL TYPE STUDY SEX WT AGE.
        - C must remain a literal token and must never be C=DROP when $DATA has IGNORE=C.
        - Default residual model: IPRED=F; W=SQRT((THETA(k)*IPRED)**2 + THETA(k+1)**2); Y=IPRED+W*EPS(1); $SIGMA 1 FIX.
        """
    }

    private static func defaultProfile(hasWT: Bool = false, hasAGE: Bool = false, hasSEX: Bool = false,
                                        hasSTUDY: Bool = false, hasBQL: Bool = false, obs: Int = 0) -> DatasetProfile {
        DatasetProfile(route: "Unknown", hasIVBolus: false, hasIVInfusion: false, hasOral: false,
                       doseLevels: [], subjectCount: 0, observationCount: obs,
                       timeRangeDays: (0, 0), hasWT: hasWT, hasAGE: hasAGE, hasSEX: hasSEX,
                       hasSTUDY: hasSTUDY, hasBQL: hasBQL, typicalDV: nil, dvRange: nil,
                       wtRange: nil, wtMedian: nil, ageRange: nil, ageMedian: nil,
                       sexLevels: [], studyLevels: [])
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
        let hasSTUDY = headers.contains("STUDY")
        let hasBQL = headers.contains("BQL")
        log?("ANA diag: hasWT=\(hasWT) hasAGE=\(hasAGE) hasSEX=\(hasSEX) hasSTUDY=\(hasSTUDY) hasBQL=\(hasBQL)")

        // Find column indices
        guard let idIdx = headers.firstIndex(of: "ID"),
              let timeIdx = headers.firstIndex(of: "TIME"),
              let dvIdx = headers.firstIndex(of: "DV") else {
            return defaultProfile(hasWT: hasWT, hasAGE: hasAGE, hasSEX: hasSEX,
                                  hasSTUDY: hasSTUDY, hasBQL: hasBQL, obs: lines.count - 1)
        }
        let cmtIdx = headers.firstIndex(of: "CMT")
        let amtIdx = headers.firstIndex(of: "AMT")
        let rateIdx = headers.firstIndex(of: "RATE")
        let durIdx = headers.firstIndex(of: "DUR")
        let doseIdx = headers.firstIndex(of: "DOSE")
        let evidIdx = headers.firstIndex(of: "EVID")

        var subjectIDs = Set<String>()
        var covariateSubjects = Set<String>()  // track which subjects we've extracted covariates from
        var doseValues = Set<Double>()
        var hasIVBolus = false
        var hasIVInfusion = false
        var hasOral = false
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

            // Only classify route from actual dosing events (EVID=1 or 4).
            // do NOT treat CMT=2 from observation records as oral —
            // in 2-cpt IV datasets, CMT=2 is a peripheral compartment.
            let isDosingEvent = (evidVal == 1 || evidVal == 4)
            if isDosingEvent || amtVal > 0 {
                if doseVal > 0 { doseValues.insert(doseVal) }
                if cmtVal == 1 {
                    if rateVal > 0 || durVal > 0 {
                        hasIVInfusion = true
                    } else if amtVal > 0 {
                        hasIVBolus = true
                    }
                } else if cmtVal == 2 && amtVal > 0 && isDosingEvent {
                    // Only flag as oral when CMT=2 is an explicit dosing event (depot)
                    hasOral = true
                }
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
            ageRange: ageValues.isEmpty ? nil : (ageValues.min()!, ageValues.max()!),
            ageMedian: ageValues.isEmpty ? nil : ageValues.sorted()[ageValues.count / 2],
            sexLevels: Array(sexValues),
            studyLevels: Array(studyValues)
        )
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
        return trimmed.hasSuffix("/v1") ? trimmed : trimmed.appending("/v1")
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
        log: ((String) -> Void)? = nil
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
        let dsAllFalse = !profile.hasWT && !profile.hasAGE && !profile.hasSEX && !profile.hasSTUDY
        let inputHasAny = modelInput.contains("WT") || modelInput.contains("AGE") || modelInput.contains("SEX") || modelInput.contains("STUD")
        let useInputFallback = dsAllFalse && inputHasAny
        if useInputFallback {
            log?("SCM diag: dataset profile returned NO covariates, falling back to $INPUT line")
        }
        let effectiveHasWT  = useInputFallback ? modelInput.contains("WT")  : profile.hasWT
        let effectiveHasAGE = useInputFallback ? modelInput.contains("AGE") : profile.hasAGE
        let effectiveHasSEX = useInputFallback ? modelInput.contains("SEX") : profile.hasSEX
        let effectiveHasSTUDY = useInputFallback ? (modelInput.contains("STUD") || modelInput.contains("STUDY")) : profile.hasSTUDY
        log?("SCM diag: effective — hasWT:\(effectiveHasWT) hasAGE:\(effectiveHasAGE) hasSEX:\(effectiveHasSEX) hasSTUDY:\(effectiveHasSTUDY)")

        let contCovs: [String] = {
            var list: [String] = []
            if effectiveHasAGE && modelInput.contains("AGE") { list.append("AGE") }
            if effectiveHasWT && modelInput.contains("WT") { list.append("WT") }
            return list
        }()
        let catCovs: [String] = {
            var list: [String] = []
            if effectiveHasSEX && modelInput.contains("SEX") { list.append("SEX") }
            if effectiveHasSTUDY && (modelInput.contains("STUD") || modelInput.contains("STUDY")) { list.append("STUD") }
            return list
        }()
        let contCovStr = contCovs.joined(separator: ",")
        let catCovStr = catCovs.joined(separator: ",")
        let allCovs = contCovs + catCovs
        let allCovStr = allCovs.joined(separator: ",")
        log?("SCM diag: contCovs=[\(contCovStr)], catCovs=[\(catCovStr)], allCovs=[\(allCovStr)]")

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
                modText: modText, apiKey: apiKey
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

    /// Ask AI ONLY: which PK parameters in the $PK block have IIV (i.e. are multiplied by EXP(ETA)).
    /// Returns a list of parameter names like ["CL", "CLM"].
    private static func detectIIVParams(
        baseURL: String,
        model: String,
        modText: String,
        apiKey: String
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

        let raw = try await sendChatPrompt(url: url, model: model, prompt: prompt, temperature: 0.0, timeout: 60, apiKey: apiKey)
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
        pBackward: String = "0.001"
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

        let raw = try await sendChatPrompt(url: url, model: model, prompt: prompt, temperature: 0.1, timeout: 60, apiKey: apiKey)
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
}
