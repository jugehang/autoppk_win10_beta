import Foundation

// MARK: - API Format

enum APIFormat: String, Codable, CaseIterable {
    case openAICompatible
    case anthropic
    case gemini

    var displayName: String {
        switch self {
        case .openAICompatible: return "OpenAI Compatible"
        case .anthropic: return "Anthropic API"
        case .gemini: return "Google Gemini"
        }
    }

    var isLocalProvider: Bool {
        self == .openAICompatible
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
        .mlx, .lmStudio, .ollama, .openAI, .anthropic, .ccswitch, .gemini
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
        switch name.lowercased() {
        case let n where n.contains("lm studio"): return "desktopcomputer"
        case let n where n.contains("mlx"): return "memorychip"
        case let n where n.contains("ollama"): return "shippingbox"
        case let n where n.contains("openai"): return "building.2"
        case let n where n.contains("anthropic") || n.contains("claude"): return "brain.head.profile"
        case let n where n.contains("gemini"): return "sparkles"
        default: return "gearshape.2"
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

    static func loadProviders() -> [LLMProviderProfile] {
        guard let data = UserDefaults.standard.data(forKey: providersKey) else {
            return []
        }
        do {
            return try JSONDecoder().decode([LLMProviderProfile].self, from: data)
        } catch {
            print("AutoPMX: failed to decode LLM providers: \(error)")
            return []
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
