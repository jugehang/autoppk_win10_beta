import Foundation

struct ModelRunEvidence {
    static let controlStreamBlockContract = """
    AutoPMX NONMEM control-stream block contract:
    - $PROBLEM: One short human-readable model description. Include run ID, route, structural model, and the single intended change from the parent run.
    - $INPUT: Dataset column labels in exact CSV header order. Do not invent, omit, or reorder labels. C must remain literal C with $DATA IGNORE=C.
    - $DATA: Dataset file plus filtering rule. Use $DATA <dataset.csv> IGNORE=C for the project's dataset file unless the user changes it.
    - $SUBROUTINES: PREDPP ADVAN/TRANS choice. Use library templates; choose ADVAN1/2 for 1-compartment, ADVAN3/4 for 2-compartment, ADVAN13 only for explicit ODEs.
    - $MODEL: Only when required by the selected ADVAN or custom ODE. Define COMP names and dosing/observation compartments consistently with CMT.
    - $DES: Only for custom ODE models. Define each DADT(n) and all rates used by the ODE before use.
    - $PK: Define all structural parameters, covariate effects, IIV terms, bioavailability/duration/rate terms, and scaling S1/S2. Every symbol used later must be defined here or be a valid NONMEM/PREDPP item.
    - $ERROR: Define IPRED=F, residual SD W, Y, IRES, and IWRES. Default residual model is combined proportional plus additive with $SIGMA 1 FIX.
    - $THETA: Fixed-effect initial estimates with labels. Use lower/initial/upper when bounds matter. THETA count must match all THETA references.
    - $OMEGA: ETA variances or blocks. ETA count and OMEGA dimensions must match ETA references in $PK/$ERROR. Values are variances, not SDs.
    - $SIGMA: EPS residual-error variances or fixed residual scale. EPS count and SIGMA dimensions must match EPS references in $ERROR.
    - $ESTIMATION: Estimation method and runtime controls. AutoPMX default is METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10.
    - $COVARIANCE: Request covariance after estimation. Use PRINT=E MATRIX=S for AutoPMX default unless diagnostics justify otherwise.
    - $TABLE: Output variables for diagnostics. Every table item must be a valid input item, NONMEM item, or variable defined in $PK/$ERROR. Use run-specific FILE names.
    """

    static func hasFailureEvidence(projectURL: URL, runID: String) -> Bool {
        !failureArtifactURLs(projectURL: projectURL, runID: runID).isEmpty
    }

    static func failureEvidence(projectURL: URL, runID: String, maxArtifacts: Int = 8) -> String {
        let artifacts = Array(failureArtifactURLs(projectURL: projectURL, runID: runID).prefix(maxArtifacts))
        guard !artifacts.isEmpty else {
            return "No nested PsN/NONMEM failure artifacts were found for run\(runID)."
        }

        return artifacts.map { url in
            let relative = relativePath(url, from: projectURL)
            let text = (try? String(contentsOf: url, encoding: .utf8)) ?? "\(url.lastPathComponent) could not be read."
            return """
            --- \(relative) ---
            \(focusedPreview(text, limit: 7_000))
            """
        }.joined(separator: "\n\n")
    }

    private static func failureArtifactURLs(projectURL: URL, runID: String) -> [URL] {
        let fm = FileManager.default
        var candidates = [URL]()

        let topLevelLST = projectURL.appendingPathComponent("run\(runID).lst")
        if fm.fileExists(atPath: topLevelLST.path), fileLooksLikeFailure(topLevelLST) {
            candidates.append(topLevelLST)
        }

        let children = (try? fm.contentsOfDirectory(
            at: projectURL,
            includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        let runDirectoryPrefixes = [
            "run\(runID).dir",
            "nonmem_run_\(runID)"
        ]

        for child in children {
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey])
            guard values?.isDirectory == true else { continue }
            let name = child.lastPathComponent
            guard runDirectoryPrefixes.contains(where: { name.hasPrefix($0) }) else { continue }
            candidates.append(contentsOf: recursiveFailureFiles(in: child, depth: 0, maxDepth: 4))
        }

        return candidates
            .filter(fileLooksLikeFailure)
            .sorted { left, right in
                let leftDate = (try? left.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rightDate = (try? right.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                if leftDate == rightDate {
                    return left.path.localizedStandardCompare(right.path) == .orderedAscending
                }
                return leftDate > rightDate
            }
    }

    private static func recursiveFailureFiles(in directory: URL, depth: Int, maxDepth: Int) -> [URL] {
        guard depth <= maxDepth else { return [] }
        let children = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return children.flatMap { child -> [URL] in
            let values = try? child.resourceValues(forKeys: [.isDirectoryKey])
            if values?.isDirectory == true {
                return recursiveFailureFiles(in: child, depth: depth + 1, maxDepth: maxDepth)
            }
            let interestingNames: Set<String> = [
                "FMSG",
                "psn_nonmem_error_messages.txt",
                "psn.lst",
                "nmfe_output.txt",
                "intermediate_raw_results.csv",
                "intermediate_nonp_results.csv"
            ]
            return interestingNames.contains(child.lastPathComponent) ? [child] : []
        }
    }

    static func fileLooksLikeFailure(_ url: URL) -> Bool {
        let name = url.lastPathComponent
        // FMSG and psn_nonmem_error_messages.txt often exist even for successful runs
        // — they contain warnings, not failures. Only treat them as failure if they
        // actually contain fatal-level content.
        if name == "psn_nonmem_error_messages.txt" { return true }

        guard let text = try? String(contentsOf: url, encoding: .utf8) else {
            return false
        }
        let upper = text.uppercased()
        // Only hard / fatal failures. "UNDEFINED" is a common NONMEM output keyword
        // (e.g. in NM-TRAN table headers) and must NOT be treated as a failure signal.
        let failureKeywords = [
            "AN ERROR WAS FOUND IN THE CONTROL STATEMENTS",
            "NMTRAN FAILED",
            "THERE IS NO OUTPUT",
            "COULD NOT PARSE",
            "NEITHER NAME IS A NONMEM OR PREDPP DATA ITEM"
        ]
        // Check for real failure keywords (not just $ERROR or 0ERROR)
        return failureKeywords.contains { upper.contains($0) }
    }

    private static func focusedPreview(_ text: String, limit: Int) -> String {
        let lines = text.components(separatedBy: .newlines)
        let keywords = [
            "ERROR", "FAILED", "FMSG", "NMTRAN", "NM-TRAN", "ABORT",
            "COULD NOT PARSE", "THERE IS NO OUTPUT", "UNDEFINED",
            "NEITHER NAME", "CONTROL STATEMENTS", "DATA ITEM"
        ]
        var selected = Set<Int>()

        for (index, line) in lines.enumerated() {
            let upper = line.uppercased()
            if keywords.contains(where: { upper.contains($0) }) {
                for nearby in max(0, index - 3)...min(lines.count - 1, index + 6) {
                    selected.insert(nearby)
                }
            }
        }

        let preview: String
        if selected.isEmpty {
            preview = String(text.prefix(limit))
        } else {
            var chunks = [String]()
            var previous: Int?
            for index in selected.sorted() {
                if let previous, index > previous + 1 {
                    chunks.append("[...]")
                }
                chunks.append(lines[index])
                previous = index
            }
            preview = chunks.joined(separator: "\n")
        }

        return preview.count > limit ? String(preview.prefix(limit)) + "\n[truncated]" : preview
    }

    private static func relativePath(_ url: URL, from root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        if path.hasPrefix(rootPath + "/") {
            return String(path.dropFirst(rootPath.count + 1))
        }
        return url.lastPathComponent
    }
}
