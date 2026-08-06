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
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser

        // Running from source or an extracted workspace: keep the existing root.
        let cwd = URL(fileURLWithPath: fm.currentDirectoryPath)
        if looksLikeWorkspaceRoot(cwd) {
            return cwd
        }

        // Legacy development/test workspace on the Desktop.
        let desktopCandidate = home.appendingPathComponent("Desktop/AutoPMX_Test/PopPK_Agent")
        if fm.fileExists(atPath: desktopCandidate.path) {
            return desktopCandidate
        }

        // Installed-app default: a writable per-user Documents location. Other Macs
        // should never fall back to cwd, which can be "/" or an unwritable location.
        return home.appendingPathComponent("Documents/AutoPMX")
    }

    private static func looksLikeWorkspaceRoot(_ url: URL) -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: url.appendingPathComponent("AutoPMX_Projects").path)
            || fm.fileExists(atPath: url.appendingPathComponent("PopPK_Agent").path)
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

        // Include the app-generated Reports/ folder so final PopPK reports appear immediately.
        let reportsDir = projectURL.appendingPathComponent("Reports")
        let reportArtifacts = ((try? FileManager.default.contentsOfDirectory(
            at: reportsDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []).filter { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            return values?.isDirectory != true
        }

        // Include the app-generated Figures/ folder so ETA/SCM/diagnostic plots appear immediately.
        let figuresDir = projectURL.appendingPathComponent("Figures")
        let figureArtifacts = ((try? FileManager.default.contentsOfDirectory(
            at: figuresDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []).filter { url in
            let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
            return values?.isDirectory != true
        }

        let allFiles = rootFiles + subdirArtifacts + scmArtifacts + reportArtifacts + figureArtifacts
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

        if let text = try? String(contentsOf: semanticURL, encoding: .utf8) {
            var rows = ParameterEstimateParser.parseSemanticCSV(text)
            if !rows.isEmpty {
                // Inject residual epsilon-shrinkage only. ETA/PK decisions use %RSE, not eta-shrinkage.
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
        // Inject residual epsilon-shrinkage only. ETA/PK decisions use %RSE, not eta-shrinkage.
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

    /// Filter poppk_rules.json rules by modeling phase, returning only
    /// rules whose "phase" matches (or "both" matches any phase).
    /// - Parameter phase: "phase1" for base model building, "phase2" for covariate screening, nil for all rules.
    static func filterRulesByPhase(_ text: String, phase: String?) -> String {
        guard let phase = phase,
              let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let lib = json["rule_library"] as? [String: Any],
              let namespaces = lib["namespaces"] as? [String: Any] else { return text }
        var filtered = lib
        filtered["namespaces"] = namespaces.compactMapValues { rules -> [[String: Any]]? in
            guard let ruleList = rules as? [[String: Any]] else { return nil }
            let matched = ruleList.filter { r in
                (r["phase"] as? String) == phase || (r["phase"] as? String) == "both"
            }
            return matched.isEmpty ? nil : matched
        }
        var outLib = lib
        outLib["namespaces"] = filtered["namespaces"]
        if let data2 = try? JSONSerialization.data(withJSONObject: ["rule_library": outLib], options: [.prettyPrinted]),
           let filteredText = String(data: data2, encoding: .utf8) {
            return filteredText
        }
        return text
    }

    static func ruleContext(projectURL: URL, workspaceURL: URL, sourcesText: String, knowledgeBaseURL: URL? = nil, phase: String? = nil) -> RuleContext {
        // Default the knowledge base to the inferred PopPK_Agent location so rule
        // sources are found even when no explicit path is supplied by the caller.
        let effectiveKB = knowledgeBaseURL ?? defaultWorkspaceURL()
        let sources = splitRuleSources(sourcesText)
        let requested = sources.isEmpty ? defaultLLMRuleSources : sources
        var loaded = [String]()
        var missing = [String]()
        var sections = [String]()
        var seenPaths = Set<String>()

        for source in requested {
            let candidates = ruleSourceCandidates(source: source, projectURL: projectURL, workspaceURL: workspaceURL, knowledgeBaseURL: effectiveKB)
            guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
                missing.append(source)
                continue
            }

            guard isRuleSourceAllowed(url, projectURL: projectURL, workspaceURL: workspaceURL, knowledgeBaseURL: effectiveKB) else {
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
            var clipped = text.count > 80_000 ? String(text.prefix(80_000)) + "\n[AutoPMX clipped long rule source]" : text
            // Phase filter for poppk_rules.json — only include relevant rules
            if url.lastPathComponent == "poppk_rules.json", let phase {
                clipped = filterRulesByPhase(clipped, phase: phase)
            }
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

    static func createProjectFromRun(workspaceURL: URL, sourceURL: URL, name: String, runID: String, dataFile: String, parentDirectory: URL? = nil) throws -> URL {
        let projectURL = try createBlankProject(workspaceURL: workspaceURL, name: name, parentDirectory: parentDirectory)

        let names = [
            "run\(runID).mod", "run\(runID).lst", "run\(runID).ext", "run\(runID).cov",
            dataFile, "project_config.json"
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

        let modDestination = projectURL.appendingPathComponent("run\(runID).mod")
        if let modText = try? String(contentsOf: modDestination, encoding: .utf8) {
            let sanitized = LLMCommandService.stripInlineDatasetRows(modText)
            if sanitized != modText {
                try sanitized.write(to: modDestination, atomically: true, encoding: .utf8)
            }
        }

        return projectURL
    }

    static func createAutomationDemoProject(workspaceURL: URL, sourceURL: URL, dataFileName: String) throws -> URL {
        let stamp = DateFormatter.automationStamp.string(from: Date())
        let projectURL = try createBlankProject(workspaceURL: workspaceURL, name: "AutoModel_NMData_\(stamp)")
        try removeModelArtifacts(in: projectURL)

        // Copy the user's actual dataset into the project (not a hardcoded demo file)
        let copied = try copyDataFile(dataFileName, to: projectURL, sourceURL: sourceURL)

        let automationMetadata = """
        {
          "kind": "AutoPMX automated model-building project",
          "data_file": "\(dataFileName)",
          "created_at": "\(stamp)",
          "start_run": "001"
        }
        """
        try automationMetadata.write(to: projectURL.appendingPathComponent(".autopmx_automation.json"), atomically: true, encoding: .utf8)

        if !copied {
            // Write a placeholder message so the user knows to import their dataset
            let readme = "AutoPMX automated modeling project — created \(stamp)\n\nPlease place your modeling dataset as \(dataFileName) in this directory before starting the run."
            try readme.write(to: projectURL.appendingPathComponent("README.txt"), atomically: true, encoding: .utf8)
        }

        // Update project_config.json with the actual data file name
        updateProjectConfig(projectURL: projectURL, dataFileName: dataFileName)

        return projectURL
    }

    /// Insert or update the `data_file` field in the project's project_config.json.
    private static func updateProjectConfig(projectURL: URL, dataFileName: String) {
        let configURL = projectURL.appendingPathComponent("project_config.json")
        guard let data = try? Data(contentsOf: configURL),
              let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        var config = raw
        config["data_file"] = dataFileName

        let csvURL = projectURL.appendingPathComponent(dataFileName)
        if let header = try? String(contentsOf: csvURL, encoding: .utf8).split(separator: "\n").first {
            let columns = header.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                    .uppercased()
            }
            let candidates = ["STUDY", "STUDYID", "STUDYNO", "DOSE", "ARM", "TRT", "ROUTE", "SEX", "RACE", "REGION"]
            if let factor = candidates.first(where: { columns.contains($0) }) {
                var grouping = config["grouping"] as? [String: Any] ?? [:]
                let currentFactor = (grouping["factor"] as? String ?? "").uppercased()
                if !columns.contains(currentFactor) {
                    grouping["factor"] = factor
                    grouping["labels"] = [:]
                    config["grouping"] = grouping
                }
                var psnSettings = config["psn_settings"] as? [String: Any] ?? [:]
                psnSettings["stratify_var"] = factor
                let vpcStratify: String
                if columns.contains("ROUTE"), factor != "ROUTE" {
                    vpcStratify = "\(factor),ROUTE"
                } else if factor == "ROUTE", columns.contains("DOSE") {
                    vpcStratify = "ROUTE,DOSE"
                } else {
                    vpcStratify = factor
                }
                psnSettings["vpc_stratify"] = vpcStratify
                config["psn_settings"] = psnSettings
            }
        }

        if let updated = try? JSONSerialization.data(withJSONObject: config, options: .prettyPrinted) {
            try? updated.write(to: configURL)
        }
    }

    static func pythonExecutable(projectURL: URL, workspaceURL: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            projectURL.appendingPathComponent(".venv/bin/python").path,
            workspaceURL.appendingPathComponent(".venv/bin/python").path,
            home.appendingPathComponent("miniconda3/bin/python3").path,
            home.appendingPathComponent("anaconda3/bin/python3").path,
            home.appendingPathComponent("mambaforge/bin/python3").path,
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3",
            "/usr/bin/python3"
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) } ?? "python3"
    }

    static func createBlankProject(workspaceURL: URL, name: String, parentDirectory: URL? = nil) throws -> URL {
        let safeName = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"[^A-Za-z0-9_.-]+"#, with: "_", options: .regularExpression)
        let projectName = safeName.isEmpty ? "AutoPMX_Project" : safeName
        let baseDir = parentDirectory ?? workspaceURL.appendingPathComponent("AutoPMX_Projects")
        let projectURL = baseDir.appendingPathComponent(projectName)
        try FileManager.default.createDirectory(at: projectURL, withIntermediateDirectories: true)

        let configURL = projectURL.appendingPathComponent("project_config.json")
        if !FileManager.default.fileExists(atPath: configURL.path) {
            let config = """
            {
              "project_name": "\(projectName)",
              "units": {
                "dose": "mg",
                "amt": "mg",
                "conc": "µg/mL",
                "time": "h",
                "lloq_value": "",
                "lloq_unit": "µg/mL"
              },
              "grouping": {
                "factor": "STUDY",
                "labels": {}
              },
              "psn_settings": {
                "vpc_samples": 500,
                "bootstrap_samples": 200,
                "stratify_var": "STUDY",
                "vpc_stratify": "STUDY"
              }
            }
            """
            try config.write(to: configURL, atomically: true, encoding: .utf8)
        }

        let metadata = #"{"name":"\#(projectName)","kind":"AutoPMX native project"}"#
        try metadata.write(to: projectURL.appendingPathComponent(".autopmx_project.json"), atomically: true, encoding: .utf8)
        try? copyKnowledgeBase(to: projectURL, sourceURL: workspaceURL)
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
           upper.hasPrefix("000") ||
           (ext == "eta" && upper.hasPrefix("RUN")) { return .data }
        if lowerPath.contains("/reports/"), ["md", "pdf"].contains(ext) { return .reports }
        if ["jpg", "jpeg", "png"].contains(ext) { return .figures }
        if ext == "pdf" { return .figures }
        if ext == "md" { return .reports }
        return nil
    }

    private static func splitRuleSources(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func ruleSourceCandidates(source: String, projectURL: URL, workspaceURL: URL, knowledgeBaseURL: URL? = nil) -> [URL] {
        // User-uploaded rule: an explicit absolute path the user chose. Respect it as-is.
        if source.hasPrefix("/") {
            return [URL(fileURLWithPath: source)]
        }
        // Built-in rule (e.g. "poppk_rules.json"): resolve ONLY from the app's bundled
        // Resources. It must NOT be picked up from any project / workspace / knowledge-base
        // path — those files are not rules we authored and belong in the user's workspace.
        if let bundleURL = Bundle.main.resourceURL?.appendingPathComponent(source) {
            return [bundleURL]
        }
        return []
    }

    private static func isRuleSourceAllowed(_ url: URL, projectURL: URL, workspaceURL: URL, knowledgeBaseURL: URL? = nil) -> Bool {
        // Built-in rules bundled with the app are always allowed.
        if let bundleRes = Bundle.main.resourceURL, isInside(url, root: bundleRes) { return true }
        // User-uploaded rules are explicit absolute paths the user chose — allowed.
        if url.path.hasPrefix("/") { return true }
        // Project / workspace / knowledge-base paths are NOT allowed as rule sources.
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

    /// Resolve a demo seed file: prefer the user's workspace copy, but fall back
    /// to the bundled DemoSeed folder so the demo works on a fresh install where
    /// the workspace has not been populated yet.
    private static func resolveDemoSource(_ fileName: String, workspace: URL) -> URL? {
        let ws = workspace.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: ws.path) { return ws }
        if let res = Bundle.main.resourceURL?
            .appendingPathComponent("DemoSeed")
            .appendingPathComponent(fileName),
           FileManager.default.fileExists(atPath: res.path) {
            return res
        }
        return nil
    }

    /// Copy knowledge-base files (rules, model library) into a project.
    /// Note: poppk_rules.json is NOT copied — it is always resolved from the app bundle
    /// at runtime via ruleSourceCandidates(). Copying it to every project is unnecessary.
    /// Does NOT copy dataset files — the caller is responsible for providing the dataset separately.
    private static func copyKnowledgeBase(to projectURL: URL, sourceURL: URL) throws {
        let fileNames = [
            "project_config.json"
        ]
        for fileName in fileNames {
            guard let src = resolveDemoSource(fileName, workspace: sourceURL) else { continue }
            let dst = projectURL.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: dst.path) {
                try FileManager.default.removeItem(at: dst)
            }
            try FileManager.default.copyItem(at: src, to: dst)
        }
    }

    /// Copy the user's modeling dataset into the project.
    /// Looks for the file at sourceURL first; falls back to DemoSeed only for demo cases.
    private static func copyDataFile(_ dataFileName: String, to projectURL: URL, sourceURL: URL) throws -> Bool {
        let srcFile = sourceURL.appendingPathComponent(dataFileName)
        if FileManager.default.fileExists(atPath: srcFile.path) {
            let dst = projectURL.appendingPathComponent(dataFileName)
            if FileManager.default.fileExists(atPath: dst.path) {
                try FileManager.default.removeItem(at: dst)
            }
            try FileManager.default.copyItem(at: srcFile, to: dst)
            return true
        }
        return false
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
                || lower.range(of: #"^(?:\d+|run\d+)\.eta$"#, options: .regularExpression) != nil
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
            "NM_dat_new.csv", "project_config.json"
        ]
        for fileName in fileNames {
            guard let src = resolveDemoSource(fileName, workspace: sourceURL) else { continue }
            let dst = demoURL.appendingPathComponent(fileName)
            if !FileManager.default.fileExists(atPath: dst.path) {
                try FileManager.default.copyItem(at: src, to: dst)
                if fileName.hasSuffix(".mod"),
                   let text = try? String(contentsOf: dst, encoding: .utf8) {
                    let sanitized = LLMCommandService.stripInlineDatasetRows(text)
                    if sanitized != text {
                        try sanitized.write(to: dst, atomically: true, encoding: .utf8)
                    }
                }
            }
        }
        let run31URL = demoURL.appendingPathComponent("run31.mod")
        if !FileManager.default.fileExists(atPath: run31URL.path) {
            let sourceRun38 = resolveDemoSource("run38.mod", workspace: sourceURL)
            let base = (try? String(contentsOf: sourceRun38 ?? URL(fileURLWithPath: "/dev/null"), encoding: .utf8)) ?? defaultRun31ControlStream()
            let run31 = base
                .replacingOccurrences(of: "Based on: run33", with: "Based on: Demo baseline")
                .replacingOccurrences(of: "Description: PK Basic model QC FIX_add", with: "Description: Demo starting model for AI automation")
                .replacingOccurrences(of: #"FILE=SDTAB\d+"#, with: "FILE=SDTAB31", options: .regularExpression)
                .replacingOccurrences(of: #"FILE=PATAB\d+"#, with: "FILE=PATAB31", options: .regularExpression)
                .replacingOccurrences(of: #"FILE=(?:000|run)\d+\.ETA"#, with: "FILE=run31.ETA", options: .regularExpression)
                .replacingOccurrences(of: #"FILE=CATAB\d+"#, with: "FILE=CATAB31", options: .regularExpression)
                .replacingOccurrences(of: #"FILE=COTAB\d+"#, with: "FILE=COTAB31", options: .regularExpression)
                .replacingOccurrences(of: #"\$DATA\s+\S+"#, with: "$DATA NM_dat_new.csv", options: .regularExpression)
            try LLMCommandService.stripInlineDatasetRows(run31)
                .write(to: run31URL, atomically: true, encoding: .utf8)
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
        $TABLE ID ETA1 ETA2 ETA3 ETA4 FIRSTONLY NOAPPEND NOPRINT FILE=run31.ETA
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
