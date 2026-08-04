import Foundation

// MARK: - API Format

enum APIFormat: String, Codable, CaseIterable {
    case openAICompatible
    case anthropic
    case gemini
    case codeBuddy

    var displayName: String {
        switch self {
        case .openAICompatible: return "OpenAI Compatible"
        case .anthropic: return "Anthropic API"
        case .gemini: return "Google Gemini"
        case .codeBuddy: return "CodeBuddy (Tencent)"
        }
    }

    var isLocalProvider: Bool {
        self == .openAICompatible
    }

    var requiresStreaming: Bool {
        self == .codeBuddy
    }
}

// MARK: - Provider Profile

struct LLMProviderProfile: Identifiable, Codable, Hashable {
    var id: UUID
    var name: String
    var baseURL: String
    var apiKey: String
    var model: String
    var apiFormat: APIFormat
    var availableModels: [String]
    /// User pin for keeping a provider at the top of the LLM settings list.
    var isPinned: Bool? = false
    /// Optional SF Symbol override. When nil, the app derives an icon from the provider name.
    var customSymbolName: String? = nil

    // MARK: - Vision (multimodal) model — used for GOF/VPC image audits.
    // nil means "reuse the main (text) model config". Empty string also treated as nil.
    var visionBaseURL: String?
    var visionModel: String?
    var visionAPIKey: String?

    var effectiveVisionBaseURL: String? {
        let v = (visionBaseURL ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? nil : v
    }
    var effectiveVisionModel: String? {
        let v = (visionModel ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? nil : v
    }
    var effectiveVisionAPIKey: String? {
        let v = (visionAPIKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return v.isEmpty ? nil : v
    }

    // MARK: - Factory Presets

    static let lmStudio = LLMProviderProfile(
        id: UUID(uuidString: "E1A2B3C4-0001-4000-8000-000000000001")!,
        name: "LM Studio",
        baseURL: "http://127.0.0.1:1234/v1",
        apiKey: "",
        model: "",
        apiFormat: .openAICompatible,
        availableModels: []
    )

    static let mlx = LLMProviderProfile(
        id: UUID(uuidString: "E1A2B3C4-0002-4000-8000-000000000002")!,
        name: "MLX (Apple Silicon)",
        baseURL: "http://127.0.0.1:8080/v1",
        apiKey: "",
        model: "qwen3.6:35b-mlx",
        apiFormat: .openAICompatible,
        availableModels: []
    )

    static let ollama = LLMProviderProfile(
        id: UUID(uuidString: "E1A2B3C4-0003-4000-8000-000000000003")!,
        name: "Ollama (含MLX模型)",
        baseURL: "http://127.0.0.1:11434/v1",
        apiKey: "",
        model: "qwen3.6:35b-mlx",
        apiFormat: .openAICompatible,
        availableModels: []
    )

    static let openAI = LLMProviderProfile(
        id: UUID(uuidString: "E1A2B3C4-0004-4000-8000-000000000004")!,
        name: "OpenAI",
        baseURL: "https://api.openai.com/v1",
        apiKey: "",
        model: "gpt-4o",
        apiFormat: .openAICompatible,
        availableModels: []
    )

    static let anthropic = LLMProviderProfile(
        id: UUID(uuidString: "E1A2B3C4-0005-4000-8000-000000000005")!,
        name: "Anthropic Claude",
        baseURL: "https://api.anthropic.com",
        apiKey: "",
        model: "claude-sonnet-5-20251001",
        apiFormat: .anthropic,
        availableModels: []
    )

    static let claudeCode = LLMProviderProfile(
        id: UUID(uuidString: "E1A2B3C4-0007-4000-8000-000000000007")!,
        name: "Claude Code (CLI)",
        baseURL: "",
        apiKey: "",
        model: "",
        apiFormat: .openAICompatible,
        availableModels: []
    )

    static let ccswitch = LLMProviderProfile(
        id: UUID(uuidString: "E1A2B3C4-0008-4000-8000-000000000008")!,
        name: "cc-switch (Claude Code)",
        baseURL: "http://127.0.0.1:15721/v1",
        apiKey: "",
        model: "Deepseek V4 Flash",
        apiFormat: .openAICompatible,
        availableModels: []
    )

    static let codeBuddyModels = [
        "auto",
        "deepseek-v4-pro",
        "deepseek-v4-flash",
        "deepseek-v3-2-volc",
        "glm-5.1",
        "glm-5.0-turbo",
        "glm-5v-turbo",
        "glm-4.6",
        "kimi-k2.5",
        "kimi-k2.6",
        "hy3-preview-agent"
    ]

    static let codeBuddy = LLMProviderProfile(
        id: UUID(uuidString: "E1A2B3C4-0009-4000-8000-000000000009")!,
        name: "CodeBuddy (Tencent)",
        baseURL: "https://copilot.tencent.com/v2",
        apiKey: "",
        model: "deepseek-v4-flash",
        apiFormat: .codeBuddy,
        availableModels: codeBuddyModels
    )

    var isCLIProvider: Bool {
        name.contains("Claude Code") || name.contains("Terminal")
    }

    static let gemini = LLMProviderProfile(
        id: UUID(uuidString: "E1A2B3C4-0006-4000-8000-000000000006")!,
        name: "Google Gemini",
        baseURL: "https://generativelanguage.googleapis.com/v1beta",
        apiKey: "",
        model: "gemini-2.5-pro",
        apiFormat: .gemini,
        availableModels: []
    )

    static let builtInPresets: [LLMProviderProfile] = [
        .mlx, .lmStudio, .ollama, .openAI, .anthropic, .ccswitch, .codeBuddy, .gemini
    ]

    static func custom() -> LLMProviderProfile {
        LLMProviderProfile(
            id: UUID(),
            name: "Custom",
            baseURL: "http://127.0.0.1:8080/v1",
            apiKey: "",
            model: "",
            apiFormat: .openAICompatible,
            availableModels: []
        )
    }

    // MARK: - Symbol

    var symbolName: String {
        if let custom = customSymbolName?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            return custom
        }
        return inferredSymbolName
    }

    var inferredSymbolName: String {
        switch name.lowercased() {
        case let n where n.contains("lm studio"): return "desktopcomputer"
        case let n where n.contains("mlx"):
            let m = model.lowercased()
            if m.contains("qwen3.5") || m.contains("9b") { return "cpu" }
            if m.contains("qwen3.6") && m.contains("35b") { return "memorychip" }
            if m.contains("qwen3.6") && m.contains("27b") { return "externaldrive.fill" }
            if m.contains("gemma") { return "sparkles" }
            return "memorychip"
        case let n where n.contains("ollama"): return "shippingbox"
        case let n where n.contains("deepseek") || n.contains("deep seek"): return "bolt.horizontal.circle.fill"
        case let n where n.contains("vllm") || n.contains("vllm"): return "bolt.fill"
        case let n where n.contains("cc-switch") || n.contains("cc switch"): return "terminal.fill"
        case let n where n.contains("openai"): return "building.2"
        case let n where n.contains("anthropic") || n.contains("claude"): return "brain.head.profile"
        case let n where n.contains("gemini"): return "sparkles"
        case let n where n.contains("codebuddy"): return "bubble.left.and.bubble.right.fill"
        default: return "server.rack"
        }
    }

    var statusDescription: String {
        if !availableModels.isEmpty {
            return "\(availableModels.count) models found"
        }
        return "Not tested"
    }
}

// MARK: - UserDefaults Persistence

extension LLMProviderProfile {
    private static let providersKey = "AutoPMX.llmProviders.v1"
    private static let activeProviderIDKey = "AutoPMX.activeProviderID.v1"
    private static let codeBuddyAPIKeyDefaultsKey = "AutoPMX.codeBuddyAPIKey.v1"

    static func loadProviders() -> [LLMProviderProfile] {
        guard let data = UserDefaults.standard.data(forKey: providersKey) else {
            return []
        }
        do {
            var providers = try JSONDecoder().decode([LLMProviderProfile].self, from: data)
            injectCodeBuddyAPIKeyIfNeeded(&providers)
            for idx in providers.indices where providers[idx].apiFormat == .codeBuddy {
                if providers[idx].availableModels.isEmpty || !providers[idx].availableModels.contains("hy3-preview-agent") {
                    providers[idx].availableModels = codeBuddyModels
                }
            }
            return providers
        } catch {
            print("AutoPMX: failed to decode LLM providers: \(error)")
            return []
        }
    }

    private static func injectCodeBuddyAPIKeyIfNeeded(_ providers: inout [LLMProviderProfile]) {
        guard let idx = providers.firstIndex(where: { $0.apiFormat == .codeBuddy }),
              providers[idx].apiKey.isEmpty else {
            return
        }
        let storedKey = UserDefaults.standard.string(forKey: codeBuddyAPIKeyDefaultsKey)
            ?? ProcessInfo.processInfo.environment["CODEBUDDY_API_KEY"]
        if let storedKey, !storedKey.isEmpty {
            providers[idx].apiKey = storedKey
        }
    }

    static func saveProviders(_ providers: [LLMProviderProfile]) {
        do {
            let data = try JSONEncoder().encode(providers)
            UserDefaults.standard.set(data, forKey: providersKey)
        } catch {
            print("AutoPMX: failed to encode LLM providers: \(error)")
        }
    }

    static func loadActiveProviderID() -> UUID? {
        guard let str = UserDefaults.standard.string(forKey: activeProviderIDKey),
              let uuid = UUID(uuidString: str) else {
            return nil
        }
        return uuid
    }

    static func saveActiveProviderID(_ id: UUID) {
        UserDefaults.standard.set(id.uuidString, forKey: activeProviderIDKey)
    }
}
