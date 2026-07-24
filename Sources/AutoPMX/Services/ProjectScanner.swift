import Foundation

struct ProjectScanner {
    static let defaultLLMRuleSources = [
        "poppk_rules.json",
        "poppk_model_library.md",
        "PopPK_Expert_Audit_Report.md",
        "NONMEM_RULE_KNOWLEDGE_AUDIT_20260512.md"
    ]

    static func defaultLLMRuleSourcesText() -> String {
        defaultLLMRuleSources.joined(separator: ", ")
    }

    static func defaultWorkspaceURL() -> URL {
        let bundleURL = Bundle.main.bundleURL
        let inferred = bundleURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("PopPK_Agent")

        if FileManager.default.fileExists(atPath: inferred.path) {
            return inferred
        }

        let desktopCandidate = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/AutoPMX_Test/PopPK_Agent")
        if FileManager.default.fileExists(atPath: desktopCandidate.path) {
            return desktopCandidate
        }

        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    static func ensureDemoProject(workspaceURL: URL) -> URL {
        let demoURL = workspaceURL.appendingPathComponent("AutoPMX_Projects").appendingPathComponent("Demo_mAb_Run41")
        do {
            if !FileManager.default.fileExists(atPath: demoURL.appendingPathComponent(".autopmx_project.json").path) {
                _ = try createProjectFromRun(
                    workspaceURL: workspaceURL,
                    sourceURL: workspaceURL,
                    name: "Demo_mAb_Run41",
                    runID: "41",
                    dataFile: "NM_dat_new.csv"
                )
            }
            try ensureDemoFiles(demoURL: demoURL, sourceURL: workspaceURL)
            return demoURL
        } catch {
            return workspaceURL
        }
    }

    static func discoverRuns(in projectURL: URL) -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(at: projectURL, includingPropertiesForKeys: nil)) ?? []
        let ids = files.compactMap { url -> String? in
            runIDString(from: url.lastPathComponent)
        }
        return Array(Set(ids)).sorted { left, right in
            let leftInt = Int(left) ?? 0
            let rightInt = Int(right) ?? 0
            if leftInt == rightInt {
                return left.localizedStandardCompare(right) == .orderedAscending
            }
            return leftInt < rightInt
        }
    }

    static func scanAssets(in projectURL: URL) -> [AssetCategory: [ProjectAsset]] {
        var result = Dictionary(uniqueKeysWithValues: AssetCategory.allCases.map { ($0, [ProjectAsset]()) })
        // Collect files from project root only (depth 0), filter out directories
        let rootFiles = ((try? FileManager.default.contentsOfDirectory(at: projectURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []).filter { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            return values?.isDirectory != true
        }
        // Also collect NONMEM table outputs from run directories (catab, cotab, etc.)
        let subdirArtifacts = recursiveFiles(in: projectURL, maxDepth: 1).filter { url in
            let name = url.lastPathComponent
            let upper = name.uppercased()
            return upper.hasPrefix("SDTAB") || upper.hasPrefix("PATAB") ||
                   upper.hasPrefix("CATAB") || upper.hasPrefix("COTAB") ||
                   upper.hasPrefix("000")
        }
        // Also collect SCM output files from SCM_run*/ subdirectories (exclude raw data copies like NM_dat.csv)
        let scmArtifacts = recursiveFiles(in: projectURL, maxDepth: 1).filter { url in
            let name = url.lastPathComponent.lowercased()
            let path = url.path.lowercased()
            guard path.contains("/scm_run") || path.contains("/scm_") else { return false }
            // Skip raw data copies (original dataset files copied into SCM dir)
            if name == "nm_dat.csv" || name == "nm_dat_new.csv" { return false }
            return name.hasPrefix("scm_") || name == "scm_log.txt"
                || name == "scm_final.xml" || name == "scm_results.csv"
                || name.hasPrefix("runconcov") || name.hasSuffix(".scm")
        }

        let allFiles = rootFiles + subdirArtifacts + scmArtifacts
        var seenPaths = Set<String>()

        for url in allFiles {
            let dedupKey = url.standardizedFileURL.path
            guard seenPaths.insert(dedupKey).inserted else { continue }
            guard let category = category(for: url) else { continue }
            let relative = relativePath(url, from: projectURL)
            result[category, default: []].append(ProjectAsset(url: url, category: category, relativePath: relative))
        }

        for category in AssetCategory.allCases {
            result[category]?.sort { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
        }
        return result
    }

    static func status(for runID: String, in projectURL: URL) -> ModelFileStatus {
        func exists(_ ext: String) -> Bool {
            FileManager.default.fileExists(atPath: projectURL.appendingPathComponent("run\(runID).\(ext)").path)
        }
        return ModelFileStatus(runID: runID, mod: exists("mod"), lst: exists("lst"), ext: exists("ext"), cov: exists("cov"))
    }

    static func parameterEstimates(runID: String, in projectURL: URL) -> [ParameterEstimateRow] {
        let semanticURL = projectURL.appendingPathComponent("data_run\(runID).csv")
        let epsilonShrinkage = parseEpsilonShrinkage(runID: runID, in: projectURL)
        let etaShrinkages = parseEtaShrinkages(runID: runID, in: projectURL)

        if let text = try? String(contentsOf: semanticURL, encoding: .utf8) {
            var rows = ParameterEstimateParser.parseSemanticCSV(text)
            if !rows.isEmpty {
                // Inject shrinkage into IIV and Residual group rows
                rows = rows.map { row in
                    if row.group == "Residual" {
                        return ParameterEstimateRow(
                            group: row.group, name: row.name,
                            estimate: row.estimate, standardError: row.standardError,
                            shrinkage: epsilonShrinkage,
                            estimateText: row.estimateText, standardErrorText: row.standardErrorText,
                            rseText: row.rseText
                        )
                    }
                    if row.group == "IIV", let s = etaShrinkages[row.name.uppercased()] ?? etaShrinkages["ETA" + row.name.dropFirst("ETA".count)] {
                        return ParameterEstimateRow(
                            group: row.group, name: row.name,
                            estimate: row.estimate, standardError: row.standardError,
                            shrinkage: s,
                            estimateText: row.estimateText, standardErrorText: row.standardErrorText,
                            rseText: row.rseText
                        )
                    }
                    return row
                }
                return rows
            }
        }

        let extURL = projectURL.appendingPathComponent("run\(runID).ext")
        guard let text = try? String(contentsOf: extURL, encoding: .utf8) else {
            return []
        }
        // Also read .mod to extract semicolon labels for THETA/OMEGA
        let modURL = projectURL.appendingPathComponent("run\(runID).mod")
        let modText = try? String(contentsOf: modURL, encoding: .utf8)
        var rows = ParameterEstimateParser.parseExt(text, modText: modText)
        // Inject shrinkage into IIV and Residual rows
        rows = rows.map { row in
            if row.group == "Residual" {
                return ParameterEstimateRow(
                    group: row.group, name: row.name,
                    estimate: row.estimate, standardError: row.standardError,
                    shrinkage: epsilonShrinkage,
                    estimateText: row.estimateText, standardErrorText: row.standardErrorText,
                    rseText: row.rseText
                )
            }
            if row.group == "IIV", let s = etaShrinkages[row.name.uppercased()] ?? etaShrinkages["ETA" + row.name.dropFirst("ETA".count)] {
                return ParameterEstimateRow(
                    group: row.group, name: row.name,
                    estimate: row.estimate, standardError: row.standardError,
                    shrinkage: s,
                    estimateText: row.estimateText, standardErrorText: row.standardErrorText,
                    rseText: row.rseText
                )
            }
            return row
        }
        return rows
    }

    /// Parse epsilon-shrinkage from PsN raw_results CSV. Falls back to parsing
    /// the .lst output for EPSSHRINKSD(%) when the CSV has NA (COV step abort).
    static func parseEpsilonShrinkage(runID: String, in projectURL: URL) -> Double? {
        // Primary: PsN raw_results CSV
        // PsN 5.7 outputs to run{N}.dir{M}/raw_results_run{N}.csv
        let dirs = (try? FileManager.default.contentsOfDirectory(
            at: projectURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let runDirs = dirs.filter { url in
            let name = url.lastPathComponent
            return name.hasPrefix("run\(runID).dir") && name.dropFirst("run\(runID).dir".count).allSatisfy(\.isNumber)
        }.sorted {
            let aNum = Int($0.lastPathComponent.replacingOccurrences(of: "run\(runID).dir", with: "")) ?? 0
            let bNum = Int($1.lastPathComponent.replacingOccurrences(of: "run\(runID).dir", with: "")) ?? 0
            return aNum > bNum
        }
        for dir in runDirs {
            let csvURL = dir.appendingPathComponent("raw_results_run\(runID).csv")
            if FileManager.default.fileExists(atPath: csvURL.path),
               let text = try? String(contentsOf: csvURL, encoding: .utf8),
               let shrinkage = extractShrinkageFromRawResults(text) {
                return shrinkage
            }
        }

        // Fallback: parse .lst for EPSSHRINKSD(%) line
        let lstURL = projectURL.appendingPathComponent("run\(runID).lst")
        if let lstText = try? String(contentsOf: lstURL, encoding: .utf8) {
            // Pattern: "EPSSHRINKSD(%)  8.7614E+00"
            let pattern = try? NSRegularExpression(
                pattern: #"EPSSHRINKSD\(%\)\s+([\d.]+(?:[Ee][+-]?\d+)?)"#,
                options: []
            )
            let nsText = lstText as NSString
            if let match = pattern?.firstMatch(in: lstText, options: [], range: NSRange(location: 0, length: nsText.length)),
               match.numberOfRanges > 1 {
                let valStr = nsText.substring(with: match.range(at: 1))
                if let val = Double(valStr), val.isFinite, val > 0 {
                    return val
                }
            }
        }

        return nil
    }

    private static func extractShrinkageFromRawResults(_ text: String) -> Double? {
        let lines = text.components(separatedBy: .newlines)
        guard lines.count >= 2 else { return nil }
        let header = lines[0].replacingOccurrences(of: "\"", with: "").components(separatedBy: ",")
        let data = lines[1].replacingOccurrences(of: "\"", with: "").components(separatedBy: ",")
        guard header.count == data.count else { return nil }
        for (idx, col) in header.enumerated() {
            let trimmed = col.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.lowercased().contains("shrinkage_iwres") || trimmed.lowercased().contains("epsilon_shrinkage") {
                let value = data[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                if let pct = Double(value), pct.isFinite {
                    return pct
                }
            }
        }
        return nil
    }

    /// Parse ETA-shrinkage from .lst file. Returns a dict mapping ETA name → shrinkage %.
    static func parseEtaShrinkages(runID: String, in projectURL: URL) -> [String: Double] {
        let lstURL = projectURL.appendingPathComponent("run\(runID).lst")
        guard let text = try? String(contentsOf: lstURL, encoding: .utf8) else { return [:] }
        var result: [String: Double] = [:]
        // Pattern: "ETASHRINKSD(%)  1.2345E+01  4.5678E+00  ..."
        // NONMEM prints ETASHRINKSD(%) then the shrinkage % for each ETA
        let pattern = try? NSRegularExpression(
            pattern: #"ETASHRINKSD\(%\)((?:\s+[\d.]+(?:[Ee][+-]?\d+)?)+)"#,
            options: []
        )
        let nsText = text as NSString
        if let match = pattern?.firstMatch(in: text, options: [], range: NSRange(location: 0, length: nsText.length)),
           match.numberOfRanges > 1 {
            let valStr = nsText.substring(with: match.range(at: 1))
            let values = valStr.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
            for (i, v) in values.enumerated() {
                if let pct = Double(v), pct.isFinite {
                    result["ETA\(i+1)"] = pct
                }
            }
        }
        return result
    }

    static func dataPathCheck(runID: String, dataFile: String, in projectURL: URL) -> DataPathCheck {
        let modURL = projectURL.appendingPathComponent("run\(runID).mod")
        let expected = projectURL.appendingPathComponent(dataFile).path
        guard let text = try? String(contentsOf: modURL, encoding: .utf8) else {
            return DataPathCheck(current: nil, expected: expected, matches: false)
        }
        let current = text
            .components(separatedBy: .newlines)
            .first { $0.trimmingCharacters(in: .whitespaces).uppercased().hasPrefix("$DATA") }?
            .split(separator: " ")
            .dropFirst()
            .first
            .map(String.init)
        let currentURL = current.map { URL(fileURLWithPath: $0, relativeTo: projectURL).standardizedFileURL.path }
        return DataPathCheck(current: current, expected: expected, matches: currentURL == URL(fileURLWithPath: expected).standardizedFileURL.path)
    }

    static func psnExecuteCommand(runID: String) -> String {
        "execute run\(runID).mod -model_dir_name"
    }

    static func ruleContext(projectURL: URL, workspaceURL: URL, sourcesText: String) -> RuleContext {
        let sources = splitRuleSources(sourcesText)
        let requested = sources.isEmpty ? defaultLLMRuleSources : sources
        var loaded = [String]()
        var missing = [String]()
        var sections = [String]()
        var seenPaths = Set<String>()

        for source in requested {
            let candidates = ruleSourceCandidates(source: source, projectURL: projectURL, workspaceURL: workspaceURL)
            guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
                missing.append(source)
                continue
            }

            guard isRuleSourceAllowed(url, projectURL: projectURL, workspaceURL: workspaceURL) else {
                missing.append("\(source) (outside AutoPMX workspace)")
                continue
            }

            let path = url.standardizedFileURL.path
            guard seenPaths.insert(path).inserted else { continue }

            guard let text = try? String(contentsOf: url, encoding: .utf8), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                missing.append("\(source) (unreadable)")
                continue
            }

            loaded.append(url.lastPathComponent)
            let clipped = text.count > 80_000 ? String(text.prefix(80_000)) + "\n[AutoPMX clipped long rule source]" : text
            sections.append("""
            ### AutoPMX Rule Source: \(url.lastPathComponent)
            Path: \(path)

            \(clipped)
            """)
        }

        if sections.isEmpty {
            sections.append("""
            ### AutoPMX Built-in Rule Fallback
            Use conservative PopPK/NONMEM decisions, keep $INPUT aligned with the CSV header, keep C as a literal token with $DATA IGNORE=C, use template-first model writing, and require successful minimization/covariance plus GOF/VPC support before accepting a model.
            """)
        }

        return RuleContext(text: sections.joined(separator: "\n\n---\n\n"), loadedSources: loaded, missingSources: missing)
    }

    static func createProjectFromRun(workspaceURL: URL, sourceURL: URL, name: String, runID: String, dataFile: String) throws -> URL {
        let projectURL = try createBlankProject(workspaceURL: workspaceURL, name: name)

        let names = [
            "run\(runID).mod", "run\(runID).lst", "run\(runID).ext", "run\(runID).cov",
            dataFile, "project_config.json", "poppk_rules.json"
        ]
        for fileName in names {
            let source = sourceURL.appendingPathComponent(fileName)
            let destination = projectURL.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: source.path) {
                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }
                try FileManager.default.copyItem(at: source, to: destination)
            }
        }

        return projectURL
    }

    static func createAutomationDemoProject(workspaceURL: URL, sourceURL: URL) throws -> URL {
        let stamp = DateFormatter.automationStamp.string(from: Date())
        let projectURL = try createBlankProject(workspaceURL: workspaceURL, name: "AutoModel_NMData_\(stamp)")
        try copyModelingInputs(to: projectURL, sourceURL: sourceURL)
        try removeModelArtifacts(in: projectURL)
        let automationMetadata = """
        {
          "kind": "AutoPMX automated model-building project",
          "data_file": "NM_dat_new.csv",
          "created_at": "\(stamp)",
          "start_run": "001"
        }
        """
        try automationMetadata.write(to: projectURL.appendingPathComponent(".autopmx_automation.json"), atomically: true, encoding: .utf8)
        return projectURL
    }

    static func pythonExecutable(projectURL: URL, workspaceURL: URL) -> String {
        let candidates = [
            projectURL.appendingPathComponent(".venv/bin/python").path,
            workspaceURL.appendingPathComponent(".venv/bin/python").path,
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) } ?? "python3"
    }

    static func createBlankProject(workspaceURL: URL, name: String) throws -> URL {
        let safeName = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[^A-Za-z0-9_.-]+"#, with: "_", options: .regularExpression)
        let projectName = safeName.isEmpty ? "AutoPMX_Project" : safeName
        let projectURL = workspaceURL.appendingPathComponent("AutoPMX_Projects").appendingPathComponent(projectName)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let configURL = projectURL.appendingPathComponent("project_config.json")
        if !FileManager.default.fileExists(atPath: configURL.path) {
            let config = """
            {
              "project_name": "\(projectName)",
              "units": {
                "time": "Time (h)",
                "conc": "Concentration"
              },
              "grouping": {
                "factor": "STUDY",
                "labels": {}
              },
              "psn_settings": {
                "vpc_samples": 500,
                "bootstrap_samples": 200,
                "stratify_var": "STUDY"
              }
            }
            """
            try config.write(to: configURL, atomically: true, encoding: .utf8)
        }

        let metadata = #"{"name":"\#(projectName)","kind":"AutoPMX native project"}"#
        try metadata.write(to: projectURL.appendingPathComponent(".autopmx_project.json"), atomically: true, encoding: .utf8)
        try? copyModelingInputs(to: projectURL, sourceURL: workspaceURL)
        return projectURL
    }

    private static func category(for url: URL) -> AssetCategory? {
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        let upper = name.uppercased()
        if ext == "mod" { return .models }
        if ["lst", "ext", "cov"].contains(ext), runIDString(from: name) != nil { return .outputs }

        // ── SCM output files (check BEFORE data to capture scm_results.csv etc.) ──
        let lowerName = name.lowercased()
        let lowerPath = url.path.lowercased()
        let isInSCMDir = lowerPath.contains("/scm_run") || lowerPath.contains("/scm_")
        if lowerName.hasPrefix("scm_") ||
           ext == "scm" ||
           (isInSCMDir && (ext == "csv" || ext == "xml" || ext == "txt" || ext == "html")) { return .scm }

        // CSV/XLSX files AND NONMEM table files all go under Data
        if ["csv", "xlsx"].contains(ext) ||
           upper.hasPrefix("SDTAB") || upper.hasPrefix("PATAB") ||
           upper.hasPrefix("CATAB") || upper.hasPrefix("COTAB") ||
           upper.hasPrefix("000") { return .data }
        if ["jpg", "jpeg", "png", "pdf"].contains(ext) { return .figures }
        if ["md", "docx"].contains(ext) { return .reports }
        return nil
    }

    private static func splitRuleSources(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func ruleSourceCandidates(source: String, projectURL: URL, workspaceURL: URL) -> [URL] {
        if source.hasPrefix("/") {
            return [URL(fileURLWithPath: source)]
        }
        var candidates: [URL] = [
            projectURL.appendingPathComponent(source),
            workspaceURL.appendingPathComponent(source)
        ]
        // Also search in app bundle Resources for built-in rule files
        if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent(source) {
            candidates.append(bundleURL)
        }
        return candidates
    }

    private static func isRuleSourceAllowed(_ url: URL, projectURL: URL, workspaceURL: URL) -> Bool {
        if isInside(url, root: projectURL) || isInside(url, root: workspaceURL) { return true }
        // Allow rule files bundled in the app's Resources
        if let bundleRes = Bundle.main.resourceURL, isInside(url, root: bundleRes) { return true }
        return false
    }

    private static func isInside(_ url: URL, root: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let rootPath = root.standardizedFileURL.path
        return path == rootPath || path.hasPrefix(rootPath + "/")
    }

    private static func recursiveFiles(in root: URL, maxDepth: Int) -> [URL] {
        func walk(_ url: URL, depth: Int) -> [URL] {
            guard depth <= maxDepth else { return [] }
            let children = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])) ?? []
            return children.flatMap { child -> [URL] in
                let values = try? child.resourceValues(forKeys: [.isDirectoryKey])
                if values?.isDirectory == true {
                    return walk(child, depth: depth + 1)
                }
                return [child]
            }
        }
        return walk(root, depth: 0)
    }

    private static func relativePath(_ url: URL, from root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        if path.hasPrefix(rootPath + "/") {
            return String(path.dropFirst(rootPath.count + 1))
        }
        return url.lastPathComponent
    }

    private static func runID(from fileName: String) -> Int? {
        guard let value = runIDString(from: fileName) else { return nil }
        return Int(value)
    }

    private static func runIDString(from fileName: String) -> String? {
        let lower = fileName.lowercased()
        let ext = URL(fileURLWithPath: lower).pathExtension
        let stem = URL(fileURLWithPath: lower).deletingPathExtension().lastPathComponent

        // Accept standard mod/lst/ext/cov extensions
        guard ["mod", "lst", "ext", "cov"].contains(ext) else { return nil }

        // Accept GA-prefixed mods: GA001.mod → run ID "001"
        if lower.hasPrefix("ga") {
            let after = String(stem.dropFirst(2))
            if after.allSatisfy(\.isNumber) {
                return after
            }
            // Also accept GA001_structural etc.
            if let match = firstCapture(in: lower, pattern: #"ga(\d+)"#) {
                return match
            }
            return nil
        }

        // Must start with "run"
        guard lower.hasPrefix("run") else { return nil }

        // "run" followed by pure digits: run32.mod → "32"
        let afterRun = String(stem.dropFirst(3))
        if afterRun.allSatisfy(\.isNumber) {
            return afterRun
        }

        // "run" followed by digits then underscore (descriptive naming): run_32_Dofetilide_Oct_ad3.mod → "32"
        if let match = firstCapture(in: lower, pattern: #"^run[\W_]?(\d+)"#) {
            return match
        }

        // "run" + arbitrary text with embedded digits: run_Dofetilide_Oct_ad3.mod → "3"
        // use the last digit group in the stem as fallback run ID
        if let match = firstCapture(in: stem, pattern: #"(\d+)"#) {
            return match
        }

        return nil
    }

    private static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }

    private static func copyModelingInputs(to projectURL: URL, sourceURL: URL) throws {
        let fileNames = [
            "NM_dat_new.csv", "project_config.json", "poppk_rules.json"
        ]
        for fileName in fileNames {
            let src = sourceURL.appendingPathComponent(fileName)
            let dst = projectURL.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: src.path) {
                if FileManager.default.fileExists(atPath: dst.path) {
                    try FileManager.default.removeItem(at: dst)
                }
                try FileManager.default.copyItem(at: src, to: dst)
            }
        }
    }

    private static func removeModelArtifacts(in projectURL: URL) throws {
        let files = (try? FileManager.default.contentsOfDirectory(at: projectURL, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        for file in files {
            let values = try? file.resourceValues(forKeys: [.isDirectoryKey])
            let isDirectory = values?.isDirectory == true
            let name = file.lastPathComponent
            let lower = name.lowercased()
            let isRunArtifact = lower.range(of: #"^run\d+\.(mod|lst|ext|cov|coi|cor|phi)$"#, options: .regularExpression) != nil
            let isNonmemTable = lower.range(of: #"^(sdtab|patab|catab|cotab)\d+$"#, options: .regularExpression) != nil
                || lower.range(of: #"^\d+\.eta$"#, options: .regularExpression) != nil
            let isRunDirectory = isDirectory && (
                lower.range(of: #"^nonmem_run_\d+$"#, options: .regularExpression) != nil
                    || lower.range(of: #"^vpc_dir_\d+$"#, options: .regularExpression) != nil
            )
            let isDiagnosticFigure = lower.range(of: #"^(gof_mod|vpc_mod|vpc_stratified_mod)\d+\.(jpg|jpeg|png|pdf)$"#, options: .regularExpression) != nil
                || lower.range(of: #"^individual_plots_run\d+\.pdf$"#, options: .regularExpression) != nil
            if isRunArtifact || isNonmemTable || isRunDirectory || isDiagnosticFigure {
                try FileManager.default.removeItem(at: file)
            }
        }
    }

    private static func ensureDemoFiles(demoURL: URL, sourceURL: URL) throws {
        let fileNames = [
            "run38.mod", "run38.lst", "run38.ext", "run38.cov",
            "run41.mod", "run41.lst", "run41.ext", "run41.cov",
            "NM_dat_new.csv", "project_config.json", "poppk_rules.json"
        ]
        for fileName in fileNames {
            let src = sourceURL.appendingPathComponent(fileName)
            let dst = demoURL.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: src.path), !FileManager.default.fileExists(atPath: dst.path) {
                try FileManager.default.copyItem(at: src, to: dst)
            }
        }
        let run31URL = demoURL.appendingPathComponent("run31.mod")
        if !FileManager.default.fileExists(atPath: run31URL.path) {
            let sourceRun38 = sourceURL.appendingPathComponent("run38.mod")
            let base = (try? String(contentsOf: sourceRun38, encoding: .utf8)) ?? defaultRun31ControlStream()
            let run31 = base
                .replacingOccurrences(of: "Based on: run33", with: "Based on: Demo baseline")
                .replacingOccurrences(of: "Description: PK Basic model QC FIX_add", with: "Description: Demo starting model for AI automation")
                .replacingOccurrences(of: #"FILE=SDTAB\d+"#, with: "FILE=SDTAB31", options: .regularExpression)
                .replacingOccurrences(of: #"FILE=PATAB\d+"#, with: "FILE=PATAB31", options: .regularExpression)
                .replacingOccurrences(of: #"FILE=000\d+\.ETA"#, with: "FILE=00031.ETA", options: .regularExpression)
                .replacingOccurrences(of: #"FILE=CATAB\d+"#, with: "FILE=CATAB31", options: .regularExpression)
                .replacingOccurrences(of: #"FILE=COTAB\d+"#, with: "FILE=COTAB31", options: .regularExpression)
                .replacingOccurrences(of: #"\$DATA\s+\S+"#, with: "$DATA NM_dat_new.csv", options: .regularExpression)
            try run31.write(to: run31URL, atomically: true, encoding: .utf8)
        }
    }

    private static func defaultRun31ControlStream() -> String {
        """
        $PROBLEM
        ;; Demo starting model for AutoPMX AI automation

        $INPUT C ID CYCLE DAY TIME NTIME DV AMT RATE DUR CMT DOSE MDV EVID BQL TYPE STUDY SEX WT AGE
        $DATA NM_dat_new.csv IGNORE=C
        $SUBROUTINES ADVAN3 TRANS4

        $PK
        D1=DUR
        CL = THETA(1) * EXP(ETA(1))
        V1 = THETA(2) * EXP(ETA(2))
        Q  = THETA(3) * EXP(ETA(3))
        V2 = THETA(4) * EXP(ETA(4))
        S1 = V1/1000

        $ERROR
        IPRED = F
        W = SQRT(THETA(5)**2*IPRED**2 + THETA(6)**2)
        Y = IPRED + W*EPS(1)

        $THETA
        (0, 0.0122)
        (0, 4.36)
        (0, 0.0207)
        (0, 2)
        (0, 0.141)
        (0) FIX

        $OMEGA
        0.222
        0.0521
        0 FIX
        0 FIX

        $SIGMA
        1 FIX

        $EST METHOD=1 INTER MAXEVAL=9999 NOABORT SIG=3 PRINT=10
        $COV
        $TABLE ID TIME DV MDV PRED IPRED CWRES CIWRES STUDY ONEHEADER NOPRINT NOAPPEND FILE=SDTAB31 FORMAT=s1PE14.7
        $TABLE ID CL V1 Q V2 ETA1 ETA2 ETA3 ETA4 NOPRINT NOAPPEND ONEHEADER FILE=PATAB31
        """
    }
}

private extension DateFormatter {
    static let automationStamp: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter
    }()
}
