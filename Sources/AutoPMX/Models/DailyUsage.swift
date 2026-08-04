import Foundation

/// Per-provider token usage tracking for comparing LLM performance.
/// Each instance accumulates stats for one LLM provider (e.g. "DeepSeek", "MLX", "Ollama").
struct ProviderUsageRecord: Identifiable {
    let id = UUID()
    let providerName: String
    let modelName: String
    var requests: Int = 0
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    /// Accumulated wall-clock time in seconds for all requests to this provider.
    var totalDurationSec: TimeInterval = 0

    var totalTokens: Int { inputTokens + outputTokens }

    /// Input tokens per second (human-readable).
    var avgInputSpeed: String {
        guard totalDurationSec > 0 else { return "—" }
        let tps = Double(inputTokens) / totalDurationSec
        return tps >= 1000 ? String(format: "%.1f K/s", tps / 1000) : String(format: "%.0f tok/s", tps)
    }
    /// Output tokens per second (human-readable).
    var avgOutputSpeed: String {
        guard totalDurationSec > 0 else { return "—" }
        let tps = Double(outputTokens) / totalDurationSec
        return tps >= 1000 ? String(format: "%.1f K/s", tps / 1000) : String(format: "%.0f tok/s", tps)
    }
}

/// Aggregated LLM token usage for a single calendar day.
/// Persisted to UserDefaults so the Settings "Tokens 消耗" panel can show
/// historical statistics (request count, token totals, daily bar charts).
struct DailyUsage: Codable, Identifiable {
    var id: String { date }

    /// Calendar day in `yyyy-MM-dd` form.
    let date: String
    var requests: Int
    var inputTokens: Int
    var outputTokens: Int

    var totalTokens: Int { inputTokens + outputTokens }

    init(date: String, requests: Int = 0, inputTokens: Int = 0, outputTokens: Int = 0) {
        self.date = date
        self.requests = requests
        self.inputTokens = inputTokens
        self.outputTokens = outputTokens
    }
}
