import Foundation

struct ModelingBenchmarkRecord: Identifiable, Codable, Equatable {
    enum Status: String, Codable, Equatable {
        case completed
        case stopped
        case failed
        case paused

        var displayName: String {
            switch self {
            case .completed: return "Completed"
            case .stopped: return "Stopped"
            case .failed: return "Failed"
            case .paused: return "Paused"
            }
        }
    }

    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var datasetName: String
    var providerName: String
    var modelName: String
    var status: Status
    var phase1Seconds: TimeInterval
    var thinkingSeconds: TimeInterval
    var executionSeconds: TimeInterval
    var baseModelWaitSeconds: TimeInterval
    var phase2OrSCMSeconds: TimeInterval
    var totalElapsedSeconds: TimeInterval
    var comparableSeconds: TimeInterval
    var notes: String

    init(
        id: UUID = UUID(),
        startedAt: Date,
        endedAt: Date? = nil,
        datasetName: String,
        providerName: String,
        modelName: String,
        status: Status = .completed,
        phase1Seconds: TimeInterval = 0,
        thinkingSeconds: TimeInterval = 0,
        executionSeconds: TimeInterval = 0,
        baseModelWaitSeconds: TimeInterval = 0,
        phase2OrSCMSeconds: TimeInterval = 0,
        totalElapsedSeconds: TimeInterval = 0,
        comparableSeconds: TimeInterval = 0,
        notes: String = ""
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.datasetName = datasetName
        self.providerName = providerName
        self.modelName = modelName
        self.status = status
        self.phase1Seconds = phase1Seconds
        self.thinkingSeconds = thinkingSeconds
        self.executionSeconds = executionSeconds
        self.baseModelWaitSeconds = baseModelWaitSeconds
        self.phase2OrSCMSeconds = phase2OrSCMSeconds
        self.totalElapsedSeconds = totalElapsedSeconds
        self.comparableSeconds = comparableSeconds
        self.notes = notes
    }
}
