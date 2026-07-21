import Foundation

struct DatasetProfile {
    let route: String              // "IV Bolus", "IV Infusion", "Oral", "Mixed"
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
    let typicalDV: Double?         // median non-zero DV in the dataset
    let dvRange: (Double, Double)? // (min, max) of non-zero DV values

    var summary: String {
        var lines = ["Dataset Profile:"]
        lines.append("  Administration route: \(route)")
        if !doseLevels.isEmpty { lines.append("  Dose levels: \(doseLevels.map { String($0) }.joined(separator: ", "))") }
        lines.append("  Subjects: \(subjectCount), Observations: \(observationCount)")
        lines.append("  Time range: \(String(format: "%.1f", timeRangeDays.0))–\(String(format: "%.1f", timeRangeDays.1)) days")
        var covs = [String]()
        if hasWT { covs.append("WT") }
        if hasAGE { covs.append("AGE") }
        if hasSEX { covs.append("SEX") }
        if hasSTUDY { covs.append("STUDY") }
        if !covs.isEmpty { lines.append("  Available covariates: \(covs.joined(separator: ", "))") }
        if hasBQL { lines.append("  BQL flag present") }
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
                return """
                无法连接本地 LLM 服务：\(baseURL)。

                请先启动 OpenAI-compatible 本地服务（Ollama / LM Studio / MLX 等），然后在 AutoPMX 里按 Test LLM。
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
        apiKey: String = ""
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

        PROGRESSIVE MODELING STRATEGY — follow this priority order. All criteria below apply ONLY once the model compiles and the covariance step succeeds:
        1. First establish the best structural model:
           - ALWAYS start with 1-compartment (ADVAN1 TRANS2 for IV, ADVAN2 TRANS2 for oral). Do NOT jump to 2-comp directly in run002.
           - Even if 1-comp GOF looks excellent, you MUST escalate to 2-comp to confirm the simpler model is truly better. The OFV drop criterion (>10.83) is used to judge whether the extra compartment is justified.
           - Only add a second compartment if GOF/VPC clearly show distribution-phase misspecification OR as a deliberate escalation test per Phase 1 of the TWO-PHASE STRATEGY below.
        2. Then refine the residual error model:
           - Combined proportional+additive is default. Simplify only if one component is clearly unsupported (RSE > 100% or estimate at boundary). Do NOT toggle prop↔comb in consecutive iterations — oscillating proposals waste runs.
        3. Then add inter-individual variability (IIV):
           - Start with IIV on ALL PK parameters (including newly added Q, V2, Q3, V3 when escalating compartments).
           - Use modest initial OMEGA values (0.04-0.09) for newly added parameters.
           - Only remove IIV if eta-shrinkage > 30% or RSE > 50%.
           - Use eta-shrinkage < 30% to confirm the data supports the random effect.
        4. Last, screen covariates:
           - WT on CL or V1, AGE, SEX, STUDY only when supported by eta-covariate plots or OFV drop > 3.84.
           - Use power function allometric scaling for WT: (WT/median_WT)^THETA.

        ANTI-OSCILLATION RULES:
        - NEVER propose a change that UNDOES what the previous iteration just did (e.g., if run(N-1) removed IIV on V, do NOT re-add it in runN).
        - If both the current and previous iteration propose toggling the error model, STOP and ACCEPT the simpler model. Accept that some parameters cannot be estimated with the available data.

        If REVISE, provide:
        - NEXT_ACTION: exactly ONE concrete model change (which record/subroutine/parameter changes)
        - TEMPLATE_ID: the AutoPMX template to use if a structural change is needed; otherwise KEEP_CURRENT_TEMPLATE
        - RATIONALE: which diagnostic evidence (GOF pattern, VPC misfit, parameter RSE, OFV change) supports it
        - SAFETY_CHECK: NONMEM syntax rule to preserve

        ACCEPT only when:
        - All GOF plots show no systematic bias
        - VPC prediction intervals capture observed data well
        - Parameter RSE < 50%, covariance step successful
        - No boundary estimates
        - CWRES centered around zero without trends

        TWO-PHASE MODELING STRATEGY:

        ═══ PHASE 1: BASE MODEL SELECTION ═══
        You must test the NEXT compartment level before accepting the current one.

        ACCEPT 1-comp: ONLY AFTER 2-comp was tested and fails OFV drop (>10.83) or fails covariance.
        ACCEPT 2-comp: ONLY AFTER 3-comp was tested and fails OFV drop (>10.83) or fails covariance.
        NEVER accept at 1-comp without testing 2-comp. NEVER accept at 2-comp without testing 3-comp.

        OFV THRESHOLD:
        - ΔOFV > 10.83 (p<0.001, 2 df): the more complex model is SIGNIFICANTLY better. You MUST continue.
        - ΔOFV > 3.84 (p<0.05, 1 df): improvement is significant. Favor the complex model.
        - Do NOT prefer simpler model just because it's simpler. Use the ΔOFV threshold.

        ═══ PHASE 2: COVARIATE MODEL BUILDING ═══
        After Phase 1 base model is accepted (usually at 2-comp or 3-comp), IMMEDIATELY begin covariate screening.
        The next run AFTER base model acceptance MUST add at least one covariate. Do NOT stop — the project
        continues automatically into Phase 2.

        When the base model is accepted (structural + error + IIV finalized):
        - If REVISEd because compartment escalation is incomplete, continue Phase 1.
        - If ACCEPTed and base model is truly finalized: NEXT run MUST start Phase 2 covariate screening.

        Steps:
        1. WT allometric scaling on CL, V (mandatory first step): add (WT/median_WT)^THETA to CL and V.
        2. Forward inclusion: add covariates one at a time (OFV drop > 3.84 keeps)
        3. Backward elimination: remove each, keep if OFV increase > 6.63
        4. Clinical significance: PK ratio must be outside 0.8-1.25 to keep
        5. Bootstrap (≥200 samples) validates final model

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

        ━━━ ROUTE IS LOCKED — DO NOT CHANGE ROUTE ━━━
        The route (IV/Oral) was determined from the dataset and is FIXED for the entire modeling run.
        - If source is IV (ADVAN1/ADVAN3/ADVAN11), DO NOT switch to ADVAN2/ADVAN4/ADVAN12 (oral). DO NOT add KA, F1, or depot.
        - If source is oral (ADVAN2/ADVAN4/ADVAN12), DO NOT switch to ADVAN1/ADVAN3/ADVAN11 (IV). DO NOT remove KA.
        - Only allowed structural change: 1-comp → 2-comp → 3-comp within the same route.
        ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛

        EVOLUTION RULES:
        - FIRST PASS: refine structural model within SAME route (1-comp → 2-comp if evidence supports it)
        - SECOND PASS: refine error model (combined is default; consider proportional-only or additive-only if justified)
        - THIRD PASS: add IIV to one parameter at a time (start with CL then V)
        - FOURTH+ PASS: screen covariates (WT on CL/V1, then SEX, AGE, STUDY)
        - FIFTH PASS (only when oral+IV data both exist): fit bioavailability F1 relative to IV reference

        PHASE 2 — COVARIATE AUTOSTART:
        When the AI evaluation says ACCEPT and the base model is finalized (structural + error + IIV done),
        the NEXT run you produce MUST begin covariate screening. Do NOT generate another copy of the same
        base model. Add WT allometric scaling on CL and V as the first covariate step:
          TVCL = THETA(1) * (WT/median_WT)**THETA(5)
          TVV  = THETA(2) * (WT/median_WT)**THETA(6)
        Then continue with SEX, AGE, STUDY one at a time in subsequent runs.

        STRUCTURAL ESCALATION INITIAL VALUES (CRITICAL — prevents minimization failure):
        When escalating 1-comp → 2-comp: copy CL and V directly from parent run's THETA as CL and V1.
        Keep the EXACT same numeric values and units — do not convert or rescale.
        Set peripheral V2 = V1 * 0.3 to 0.5 (smaller peripheral volume).
        Set Q = CL * 0.5 to 0.8 (moderate inter-compartment clearance).
        The model should be a gentle perturbation — large peripheral volumes or high Q will crash.
        When escalating 2-comp → 3-comp: use the 2-comp CL, V1, Q, V2.
        Set V3 = V1 * 0.3 to 0.5. Set Q3 = CL * 0.3 to 0.6 (even smaller for third compartment).

        IIV STRATEGY FOR NEW COMPARTMENTS (CRITICAL):
        When adding new compartments (1→2 or 2→3), START WITH IIV ON ALL PK PARAMETERS.
        This includes the newly added Q, V2, Q3, V3 — give every parameter a chance to be estimated with IIV.
        Use modest initial OMEGA values: 0.04-0.09 for each new ETA (smaller than CL/V IIV).
        Only REMOVE IIV on a parameter if RSE > 50% or eta-shrinkage > 30% in the NEXT iteration.
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
        apiKey: String = ""
    ) async throws -> String {
        let url = try endpointURL(baseURL: baseURL, path: "chat/completions")

        let modURL = projectURL.appendingPathComponent("run\(currentRun).mod")
        let configURL = projectURL.appendingPathComponent("project_config.json")
        let modPreview = ((try? String(contentsOf: modURL, encoding: .utf8)) ?? "").prefix(10_000)
        let configPreview = ((try? String(contentsOf: configURL, encoding: .utf8)) ?? "").prefix(4_000)
        let modelLibrary = modelLibraryText(projectURL: projectURL).prefix(12_000)

        var apiMessages: [ChatRequest.Message] = [
            .init(role: "system", content: """
            You are DuDu PMx, AutoPMX's local AI pharmacometrics assistant.
            Help with NONMEM, PsN, diagnostics, model iteration, and PopPK reasoning.
            Keep answers concise, practical, and safety-aware.
            When drafting NONMEM, use the AutoPMX PopPK model library first and fill templates instead of inventing syntax.
            For AutoPMX datasets using IGNORE=C, $INPUT must mirror the CSV header order; the C column must stay as literal C and never be C=DROP.
            Use the active AutoPMX rule/knowledge context together with the model library when answering.
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

    static func analyzeDataset(projectURL: URL, dataFile: String) -> DatasetProfile {
        let url = projectURL.appendingPathComponent(dataFile)
        guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
            return DatasetProfile(route: "Unknown", hasIVBolus: false, hasIVInfusion: false, hasOral: false,
                                  doseLevels: [], subjectCount: 0, observationCount: 0,
                                  timeRangeDays: (0, 0), hasWT: false, hasAGE: false, hasSEX: false,
                                  hasSTUDY: false, hasBQL: false, typicalDV: nil, dvRange: nil)
        }
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: true)
        guard let headerLine = lines.first, lines.count > 1 else {
            return DatasetProfile(route: "Unknown", hasIVBolus: false, hasIVInfusion: false, hasOral: false,
                                  doseLevels: [], subjectCount: 0, observationCount: 0,
                                  timeRangeDays: (0, 0), hasWT: false, hasAGE: false, hasSEX: false,
                                  hasSTUDY: false, hasBQL: false, typicalDV: nil, dvRange: nil)
        }
        let headers = parseCSVLine(String(headerLine)).map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
        let hasWT = headers.contains("WT")
        let hasAGE = headers.contains("AGE")
        let hasSEX = headers.contains("SEX")
        let hasSTUDY = headers.contains("STUDY")
        let hasBQL = headers.contains("BQL")

        // Find column indices
        guard let idIdx = headers.firstIndex(of: "ID"),
              let timeIdx = headers.firstIndex(of: "TIME"),
              let dvIdx = headers.firstIndex(of: "DV") else {
            return DatasetProfile(route: "Unknown", hasIVBolus: false, hasIVInfusion: false, hasOral: false,
                                  doseLevels: [], subjectCount: 0, observationCount: lines.count - 1,
                                  timeRangeDays: (0, 0), hasWT: hasWT, hasAGE: hasAGE, hasSEX: hasSEX,
                                  hasSTUDY: hasSTUDY, hasBQL: hasBQL, typicalDV: nil, dvRange: nil)
        }
        let cmtIdx = headers.firstIndex(of: "CMT")
        let amtIdx = headers.firstIndex(of: "AMT")
        let rateIdx = headers.firstIndex(of: "RATE")
        let durIdx = headers.firstIndex(of: "DUR")
        let doseIdx = headers.firstIndex(of: "DOSE")
        let evidIdx = headers.firstIndex(of: "EVID")

        var subjectIDs = Set<String>()
        var doseValues = Set<Double>()
        var hasIVBolus = false
        var hasIVInfusion = false
        var hasOral = false
        var minTime = Double.infinity
        var maxTime = -Double.infinity
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
            dvRange: dvRange
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
}
