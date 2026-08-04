import Foundation

/// Structured action emitted by DuDu Agent mode. Swift is the only component that
/// writes files or launches NONMEM; the model only decides which tool to use.
struct DuDuAgentAction: Codable {
    let tool: String
    let runID: String?
    let fullModelText: String?
    let patch: String?
    let autoRun: Bool?
    let reason: String?
    let reply: String?
}
