import Foundation

// MARK: - Data Types

/// A single lesson / pattern learned during modeling.
struct PPKLesson: Codable, Identifiable {
    var id: String = UUID().uuidString
    var timestamp: Date = Date()
    var category: LessonCategory
    var title: String
    var problem: String           // what went wrong
    var solution: String          // how it was fixed
    var sourceRun: String?        // which run ID triggered this
    var severity: LessonSeverity
    var tags: [String] = []       // e.g. ["SCM", "covariate", "convergence"]
}

enum LessonCategory: String, Codable, CaseIterable {
    case scmConfig       = "SCM Configuration"
    case scmError        = "SCM Runtime Error"
    case nonmemError     = "NONMEM Error"
    case convergence     = "Convergence"
    case covariance      = "Covariance Step"
    case dataIssue       = "Data Issue"
    case modelStructure  = "Model Structure"
    case initialEstimates = "Initial Estimates"
    case boundaryIssue   = "Boundary Issue"
    case generalTip      = "General Tip"
    case userGuidance    = "User Guidance"   // analyst instructions worth remembering
}

enum LessonSeverity: String, Codable {
    case critical  // will always be injected into prompts
    case high      // injected when context is relevant
    case medium    // injected when room allows
    case low       // rarely injected, mostly for record
}

/// A successful modeling decision worth replicating.
struct PPKSuccessPattern: Codable, Identifiable {
    var id: String = UUID().uuidString
    var timestamp: Date = Date()
    var title: String
    var context: String           // what scenario
    var action: String            // what was done
    var result: String            // what improvement (OFV delta, etc.)
    var sourceRun: String?
    var tags: [String] = []
}

/// Optimized parameter patterns learned across runs.
struct PPKParameterInsight: Codable, Identifiable {
    var id: String = UUID().uuidString
    var timestamp: Date = Date()
    var parameter: String         // e.g. "CL", "V2", "KA"
    var typicalValue: Double?
    var typicalOmega: Double?
    var covariates: [String] = [] // e.g. ["WT", "AGE"]
    var sourceRun: String?
    var note: String = ""
}

/// Full skill store persisted as JSON.
struct PPKSkillData: Codable {
    var lessons: [PPKLesson] = []
    var successes: [PPKSuccessPattern] = []
    var insights: [PPKParameterInsight] = []
    var scmErrorPatterns: [SCMErrorPattern] = []
    var lastUpdated: Date = Date()
    var version: Int = 1
}

/// Recognized SCM error pattern for auto-diagnosis.
struct SCMErrorPattern: Codable, Identifiable {
    var id: String = UUID().uuidString
    var pattern: String           // regex or substring to match in scm_log.txt
    var diagnosis: String         // human-readable explanation
    var fix: String               // what to change in the SCM config
    var sourceRun: String?
    var occurrenceCount: Int = 0
}

// MARK: - PPK Skill Store

@MainActor
final class PPKSkillStore: ObservableObject {
    static let shared = PPKSkillStore()

    @Published var skillData = PPKSkillData()
    @Published var lessonCount: Int = 0
    @Published var successCount: Int = 0
    @Published var insightCount: Int = 0

    /// Directory of the project whose skills are currently loaded. Enables auto-persist on every change.
    private var lastDirectory: URL?

    private let maxLessons = 200
    private let maxSuccesses = 100
    private let maxInsights = 100
    private let maxContextInject = 8   // max lessons to inject per prompt

    // MARK: - Persistence

    func load(from directoryURL: URL) {
        lastDirectory = directoryURL
        let globalURL = skillFileURL(directory: directoryURL)
        // Prefer the GLOBAL shared store so generic lessons learned in ANY project are reused everywhere.
        if let data = try? Data(contentsOf: globalURL),
           let decoded = try? JSONDecoder().decode(PPKSkillData.self, from: data) {
            skillData = decoded
        }
        // Migration: if no global store exists yet but a legacy per-project file is present,
        // fold it into the global store so previously accumulated experience is not lost.
        else {
            let legacyURL = directoryURL.appendingPathComponent(".autopmx_ppk_skill.json")
            if let data = try? Data(contentsOf: legacyURL),
               let decoded = try? JSONDecoder().decode(PPKSkillData.self, from: data) {
                skillData = decoded
                save(to: directoryURL)  // re-persists into the global location
            } else {
                skillData = PPKSkillData()
            }
        }
        // Always merge per-project parameter insights on top of global data.
        // Parameter values/ω are project-specific (different drugs, units, populations)
        // and MUST NOT pollute the global store. They are read from a per-project file.
        let localURL = localInsightURL(directory: directoryURL)
        if let data = try? Data(contentsOf: localURL),
           let local = try? JSONDecoder().decode(PPKSkillData.self, from: data),
           !local.insights.isEmpty {
            var existing = skillData.insights
            for ins in local.insights {
                if let idx = existing.firstIndex(where: { $0.parameter == ins.parameter }) {
                    existing[idx] = ins
                } else {
                    existing.append(ins)
                }
            }
            skillData.insights = existing
        }
        updateCounts()
    }

    func save(to directoryURL: URL) {
        lastDirectory = directoryURL
        let url = skillFileURL(directory: directoryURL)
        skillData.lastUpdated = Date()
        trimIfNeeded()
        updateCounts()
        // Write global store WITHOUT parameter insights — those are project-specific
        // (different drugs, units, populations) and MUST stay per-project.
        var globalData = skillData
        globalData.insights = []
        guard let globalBytes = try? JSONEncoder().encode(globalData) else { return }
        try? globalBytes.write(to: url, options: .atomic)
        // Write per-project parameter insights separately.
        saveLocalInsights(directory: directoryURL)
    }

    /// Skill store location. Intentionally GLOBAL (not per-project): the experience worth
    /// remembering is GENERIC modeling discipline (IIV fixing, initial-estimate continuity,
    /// S+C before selection, etc.) that should apply across ALL projects — not project-specific
    /// data quirks. Stored in Application Support so every project/run benefits automatically.
    private func skillFileURL(directory: URL) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("AutoPMX", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("ppk_skill_global.json")
    }

    /// Per-project parameter insights file — parameter values/ω are project-specific
    /// (different drugs, units, populations) and MUST NOT be shared globally.
    private func localInsightURL(directory: URL) -> URL {
        return directory.appendingPathComponent(".autopmx_ppk_insights.json")
    }

    private func trimIfNeeded() {
        if skillData.lessons.count > maxLessons {
            skillData.lessons = Array(skillData.lessons.suffix(maxLessons))
        }
        if skillData.successes.count > maxSuccesses {
            skillData.successes = Array(skillData.successes.suffix(maxSuccesses))
        }
        if skillData.insights.count > maxInsights {
            skillData.insights = Array(skillData.insights.suffix(maxInsights))
        }
    }

    private func updateCounts() {
        lessonCount = skillData.lessons.count
        successCount = skillData.successes.count
        insightCount = skillData.insights.count
    }

    /// Reset all learned skills (in-memory). Caller is responsible for saving.
    func clearAll() {
        skillData = PPKSkillData()
        updateCounts()
    }

    /// Persist only the parameter-insights portion to a project-local file.
    /// Separated from the global store so parameter values from one project
    /// (different drug, unit, population) never pollute another project's context.
    private func saveLocalInsights(directory: URL) {
        var local = PPKSkillData()
        local.insights = skillData.insights
        local.lastUpdated = Date()
        guard let data = try? JSONEncoder().encode(local) else { return }
        try? data.write(to: localInsightURL(directory: directory), options: .atomic)
    }

    /// Persist to the last loaded/saved project directory, if any.
    private func persistIfPossible() {
        guard let dir = lastDirectory else { return }
        save(to: dir)
    }

    /// Save to the currently-loaded project directory (no-op if none loaded yet).
    /// Safe to call before switching projects so unsaved in-memory skills survive.
    func saveCurrent() {
        persistIfPossible()
    }

    /// Export the full skill set to a JSON file (for sharing with others).
    func exportSkills(to url: URL) throws {
        let data = try JSONEncoder().encode(skillData)
        try data.write(to: url, options: .atomic)
    }

    /// Import skills from a JSON file. When `merge` is true, entries are unioned by id
    /// (incoming overrides same-id existing). When false, the current set is replaced.
    /// Persists to the loaded project directory if one is set.
    func importSkills(from url: URL, merge: Bool = true) throws {
        let data = try Data(contentsOf: url)
        let incoming = try JSONDecoder().decode(PPKSkillData.self, from: data)
        if merge {
            skillData.lessons = mergeById(skillData.lessons, incoming.lessons)
            skillData.successes = mergeById(skillData.successes, incoming.successes)
            skillData.insights = mergeById(skillData.insights, incoming.insights)
            skillData.scmErrorPatterns = mergeById(skillData.scmErrorPatterns, incoming.scmErrorPatterns)
        } else {
            skillData = incoming
        }
        skillData.lastUpdated = Date()
        trimIfNeeded()
        updateCounts()
        persistIfPossible()
    }

    private func mergeById<T: Identifiable>(_ current: [T], _ incoming: [T]) -> [T] where T.ID == String {
        var map: [String: T] = [:]
        for item in current + incoming { map[item.id] = item }
        return Array(map.values)
    }

    // MARK: - Add Lessons

    func addLesson(
        category: LessonCategory,
        title: String,
        problem: String,
        solution: String,
        sourceRun: String? = nil,
        severity: LessonSeverity = .medium,
        tags: [String] = []
    ) {
        // De-duplicate identical lessons (same category + problem + title)
        if skillData.lessons.contains(where: { $0.category == category && $0.problem == problem && $0.title == title }) {
            return
        }
        objectWillChange.send()
        let lesson = PPKLesson(
            timestamp: Date(),
            category: category,
            title: title,
            problem: problem,
            solution: solution,
            sourceRun: sourceRun,
            severity: severity,
            tags: tags
        )
        skillData.lessons.append(lesson)
        updateCounts()
        persistIfPossible()
    }

    func addSuccess(
        title: String,
        context: String,
        action: String,
        result: String,
        sourceRun: String? = nil,
        tags: [String] = []
    ) {
        let pattern = PPKSuccessPattern(
            timestamp: Date(),
            title: title,
            context: context,
            action: action,
            result: result,
            sourceRun: sourceRun,
            tags: tags
        )
        skillData.successes.append(pattern)
        updateCounts()
        persistIfPossible()
    }

    func addParameterInsight(
        parameter: String,
        typicalValue: Double? = nil,
        typicalOmega: Double? = nil,
        covariates: [String] = [],
        sourceRun: String? = nil,
        note: String = ""
    ) {
        // Update existing if parameter already tracked
        if let idx = skillData.insights.firstIndex(where: { $0.parameter == parameter }) {
            var existing = skillData.insights[idx]
            existing.timestamp = Date()
            if let v = typicalValue { existing.typicalValue = v }
            if let o = typicalOmega { existing.typicalOmega = o }
            if !covariates.isEmpty { existing.covariates = covariates }
            if let r = sourceRun { existing.sourceRun = r }
            if !note.isEmpty { existing.note = note }
            skillData.insights[idx] = existing
        } else {
            skillData.insights.append(PPKParameterInsight(
                timestamp: Date(),
                parameter: parameter,
                typicalValue: typicalValue,
                typicalOmega: typicalOmega,
                covariates: covariates,
                sourceRun: sourceRun,
                note: note
            ))
        }
        updateCounts()
        guard let dir = lastDirectory else { return }
        saveLocalInsights(directory: dir)
    }

    func addSCMErrorPattern(
        pattern: String,
        diagnosis: String,
        fix: String,
        sourceRun: String? = nil
    ) {
        // Check if pattern already exists
        if let idx = skillData.scmErrorPatterns.firstIndex(where: { $0.pattern == pattern }) {
            skillData.scmErrorPatterns[idx].occurrenceCount += 1
            skillData.scmErrorPatterns[idx].sourceRun = sourceRun
        } else {
            skillData.scmErrorPatterns.append(SCMErrorPattern(
                pattern: pattern,
                diagnosis: diagnosis,
                fix: fix,
                sourceRun: sourceRun,
                occurrenceCount: 1
            ))
        }
        updateCounts()
        persistIfPossible()
    }

    // MARK: - Context Injection (what gets fed to LLM prompts)

    /// Generate a compact context block for LLM prompts.
    func contextBlock(for tags: [String] = [], maxLessons: Int = 6) -> String {
        var lines: [String] = ["### AI PPK Skill Memory (learned from past runs)"]

        // 1. Critical lessons always injected
        let criticalLessons = skillData.lessons.filter { $0.severity == .critical }
        if !criticalLessons.isEmpty {
            lines.append("")
            lines.append("⚠️ Critical Lessons (ALWAYS apply):")
            for l in criticalLessons {
                lines.append("- [\(l.category.rawValue)] \(l.title): \(l.solution)")
            }
        }

        // 2. Recent relevant lessons (matching tags or recent)
        let relevantLessons: [PPKLesson]
        if tags.isEmpty {
            relevantLessons = Array(skillData.lessons
                .filter { $0.severity != .critical }
                .sorted(by: { $0.timestamp > $1.timestamp })
                .prefix(maxLessons))
        } else {
            let tagSet = Set(tags.map { $0.lowercased() })
            relevantLessons = skillData.lessons
                .filter { lesson in
                    lesson.severity != .critical &&
                    lesson.tags.contains(where: { tagSet.contains($0.lowercased()) })
                }
                .sorted(by: { $0.timestamp > $1.timestamp })
                .prefix(maxLessons).map { $0 }
        }

        if !relevantLessons.isEmpty {
            lines.append("")
            lines.append("Recent Relevant Lessons:")
            for l in relevantLessons {
                let runInfo = l.sourceRun.map { " (run\($0))" } ?? ""
                lines.append("- [\(l.category.rawValue)] \(l.title)\(runInfo): Problem: \(l.problem) → Fix: \(l.solution)")
            }
        }

        // 3. SCM error patterns
        if !skillData.scmErrorPatterns.isEmpty {
            let scmPatterns = skillData.scmErrorPatterns.sorted(by: { $0.occurrenceCount > $1.occurrenceCount }).prefix(5)
            lines.append("")
            lines.append("Known SCM Error Patterns (apply fixes when detected):")
            for p in scmPatterns {
                lines.append("- Pattern: \"\(p.pattern)\" → \(p.diagnosis) → Fix: \(p.fix)")
            }
        }

        // 4. Successful patterns
        if !skillData.successes.isEmpty {
            let topSuccesses = skillData.successes.sorted(by: { $0.timestamp > $1.timestamp }).prefix(3)
            lines.append("")
            lines.append("Proven Success Patterns:")
            for s in topSuccesses {
                lines.append("- \(s.title): \(s.action) → \(s.result)")
            }
        }

        // 5. Parameter insights
        if !skillData.insights.isEmpty {
            lines.append("")
            lines.append("Learned Parameter Insights:")
            for ins in skillData.insights.prefix(5) {
                var line = "- \(ins.parameter)"
                if let tv = ins.typicalValue { line += " ≈ \(tv)" }
                if let omega = ins.typicalOmega { line += " (ω=\(omega))" }
                if !ins.covariates.isEmpty { line += " cov: \(ins.covariates.joined(separator: ","))" }
                if !ins.note.isEmpty { line += " — \(ins.note)" }
                lines.append(line)
            }
        }

        guard lines.count > 1 else { return "" }
        return lines.joined(separator: "\n") + "\n"
    }

    // MARK: - SCM Error Diagnosis

    /// Diagnose SCM log content and return fix suggestions.
    func diagnoseSCMError(log: String, runID: String) -> SCMDiagnosis {
        var findings: [String] = []
        var suggestedFixes: [String] = []
        var shouldRetry = false

        // Check known patterns
        for knownPattern in skillData.scmErrorPatterns {
            if log.localizedCaseInsensitiveContains(knownPattern.pattern) {
                findings.append(knownPattern.diagnosis)
                if !knownPattern.fix.isEmpty {
                    suggestedFixes.append(knownPattern.fix)
                }
                shouldRetry = true
            }
        }

        // Built-in pattern detection (always runs)
        let builtInPatterns: [(String, String, String)] = [
            ("AN ERROR WAS FOUND IN THE CONTROL STATEMENTS", "NONMEM control statement syntax error in SCM sub-run", "Check $INPUT, $DATA, $PK syntax in the base model. Ensure no Chinese characters or special symbols in control blocks."),
            ("NMTRAN FAILED", "NMTRAN compilation failed in SCM sub-run", "Check for undefined variables or syntax errors in $PK/$PRED blocks."),
            ("MINIMIZATION TERMINATED", "NONMEM minimization terminated abnormally", "Check initial estimates. Consider simplifying the model or using looser convergence criteria."),
            ("COVARIANCE STEP ABORTED", "Covariance step failed (common in SCM sub-models)", "This is expected in SCM — check if the forward/backward selection still completed. If so, results may still be valid."),
            ("ROUNDING ERROR", "Numerical rounding error (possible overflow/underflow)", "Check parameter bounds ($THETA). Avoid extremely small/large initial estimates."),
            ("PRED error", "PRED error in NONMEM (likely data or parameter issue)", "Check that all required data columns exist and have valid values. Ensure $INPUT matches the CSV."),
            ("Hessian not positive definite", "Hessian not positive definite — model may not be identifiable", "Try simpler model, fix more parameters, or check for over-parameterization."),
            ("could not be opened", "File not found during SCM execution", "Ensure the model file and data file are correctly copied into the SCM directory."),
            ("forrtl", "Fortran runtime error in NONMEM", "Check for illegal operations (division by zero, log of negative, sqrt of negative). Review data for extreme values."),
            ("PARAMETER ESTIMATE IS NEAR ITS BOUNDARY", "Parameter hit boundary during estimation", "Widen the $THETA boundary for the affected parameter, or fix it to a reasonable value."),
            ("scm_log.txt", "", ""), // skip placeholder
        ]

        for (pattern, diagnosis, fix) in builtInPatterns {
            if log.localizedCaseInsensitiveContains(pattern) && pattern != "scm_log.txt" {
                let alreadyFound = findings.contains(diagnosis)
                if !alreadyFound {
                    findings.append(diagnosis)
                    suggestedFixes.append(fix)
                    shouldRetry = true
                    // Also learn this pattern for future
                    addSCMErrorPattern(pattern: pattern, diagnosis: diagnosis, fix: fix, sourceRun: runID)
                }
            }
        }

        // Check exit code from log
        if log.contains("exit code") {
            let exitPattern = try? NSRegularExpression(pattern: "exit code (\\d+)", options: [])
            if let match = exitPattern?.firstMatch(in: log, range: NSRange(log.startIndex..., in: log)) {
                if let range = Range(match.range(at: 1), in: log) {
                    let codeStr = String(log[range])
                    if let code = Int(codeStr), code != 0 {
                        findings.append("SCM process exited with non-zero code \(code)")
                        shouldRetry = true
                    }
                }
            }
        }

        return SCMDiagnosis(
            findings: findings,
            suggestedFixes: suggestedFixes,
            shouldRetry: shouldRetry,
            log: log
        )
    }
}

struct SCMDiagnosis {
    let findings: [String]
    let suggestedFixes: [String]
    let shouldRetry: Bool
    let log: String

    var summary: String {
        if findings.isEmpty {
            return "No obvious errors detected in SCM output. Check if results are complete."
        }
        var lines = ["### SCM Error Diagnosis"]
        lines.append("")
        for (i, f) in findings.enumerated() {
            lines.append("**Finding \(i+1):** \(f)")
            if i < suggestedFixes.count {
                lines.append("  → Fix: \(suggestedFixes[i])")
            }
        }
        return lines.joined(separator: "\n")
    }
}
