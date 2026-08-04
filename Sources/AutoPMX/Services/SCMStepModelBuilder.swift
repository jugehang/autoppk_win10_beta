import Foundation

/// Deterministic builder for one SCM replication step model.
///
/// Reuses PsN SCM's own covariate code from the reference model (the SCM forward-final
/// model). PsN names every relation `{PARAM}{COV}` (e.g. V1WT, V1AGE, V2SEX) and never
/// reassigns the raw dataset columns (WT/AGE/SEX stay untouched). This builder applies
/// ONLY the requested relation set, renumbers THETAs deterministically and copies the
/// structural model verbatim, so DuDu's replicated runs always match SCM's parameterization.
enum SCMStepModelBuilder {

    private struct Record {
        let header: String
        let body: [String]
    }

    /// Build run{nextRun}.mod from run{sourceRun}.mod so that EXACTLY `targetTokens`
    /// (e.g. ["V1WT","V1AGE"]) are present. Returns nil when the transformation cannot
    /// be performed safely (caller then falls back to the AI writer).
    static func build(
        sourceText: String,
        referenceText: String,
        targetTokens: [String],
        sourceRun: String,
        nextRun: String,
        continuousMeans: [String: Double] = [:]
    ) -> String? {
        let records = parseRecords(sourceText)
        guard let pkRecord = records.first(where: { recordType($0.header) == "$PK" }) else { return nil }

        let params = pkParams(from: sourceText)
        guard !params.isEmpty else { return nil }
        guard targetTokens.allSatisfy({ token in
            let (param, cov) = splitToken(token, params: params)
            return !param.isEmpty && !cov.isEmpty
        }) else { return nil }

        let referenceDefinitions = extractDefinitions(from: referenceText)
        let referenceCovThetas = extractCovariateThetas(from: referenceText)
        let referenceTokens = Set(referenceDefinitions.keys)
        let targetTokens = targetTokens.filter { !$0.isEmpty }
        let unresolvedContinuous = targetTokens.first { token in
            let (_, cov) = splitToken(token, params: params)
            guard !isCategoricalCovariate(cov) else { return false }
            if referenceDefinitions[token] != nil { return false }
            return (continuousMeans[cov.uppercased()] ?? 0) <= 0
        }
        guard unresolvedContinuous == nil else { return nil }

        let baseThetaLines = baseThetaLines(from: records, referenceTokens: referenceTokens)
        let basePKBody = cleanBasePKBody(pkRecord.body)

        // ── Assign new THETA indices to the target relations ──
        let baseThetaCount = baseThetaLines.count
        var thetaIndexByToken: [String: Int] = [:]
        for (i, token) in targetTokens.enumerated() {
            thetaIndexByToken[token] = baseThetaCount + i + 1
        }

        // ── Group target tokens by PK parameter ──
        var tokensByParam: [String: [String]] = [:]
        var paramOrder: [String] = []
        for token in targetTokens {
            let (param, _) = splitToken(token, params: params)
            if tokensByParam[param] == nil {
                tokensByParam[param] = []
                paramOrder.append(param)
            }
            tokensByParam[param]?.append(token)
        }

        // ── Rebuild $PK ──
        var pkLines: [String] = ["$PK"]
        for token in targetTokens {
            guard let idx = thetaIndexByToken[token] else { continue }
            let (_, cov) = splitToken(token, params: params)
            let categorical = isCategoricalCovariate(cov)
            pkLines.append(";;; \(token)-DEFINITION START")
            pkLines.append(contentsOf: definitionBody(
                token: token, cov: cov, thetaIndex: idx,
                categorical: categorical,
                reference: referenceDefinitions,
                continuousMeans: continuousMeans
            ))
            pkLines.append(";;; \(token)-DEFINITION END")
            pkLines.append("")
        }
        for param in paramOrder {
            pkLines.append(";;; \(param)-RELATION START")
            pkLines.append("\(param)COV=" + (tokensByParam[param]?.joined(separator: "*") ?? ""))
            pkLines.append(";;; \(param)-RELATION END")
            pkLines.append("")
        }
        // Base PK body, with `TV{param} = {param}COV*TV{param}` wiring inserted right
        // after the original `TV{param}=THETA(n)` line (PsN's own layout).
        for line in basePKBody {
            pkLines.append(line)
            let compact = line.uppercased().replacingOccurrences(of: " ", with: "")
            for param in paramOrder {
                let prefix = "TV\(param)="
                if compact.hasPrefix(prefix), compact.contains("THETA") {
                    pkLines.append("")
                    pkLines.append("TV\(param) = \(param)COV*TV\(param)")
                }
            }
        }

        // ── Rebuild $THETA (base record + one record per covariate, PsN style) ──
        var thetaText = ""
        if !baseThetaLines.isEmpty {
            thetaText += "$THETA  " + baseThetaLines[0].trimmingCharacters(in: .whitespaces) + "\n"
            for line in baseThetaLines.dropFirst() {
                thetaText += line + "\n"
            }
        }
        for token in targetTokens {
            guard thetaIndexByToken[token] != nil else { continue }
            let valueLine: String
            let label: String
            if let ref = referenceCovThetas[token] {
                valueLine = ref.value
                label = ref.label
            } else {
                valueLine = "(0,1)"
                label = token
            }
            thetaText += "$THETA  \(valueLine) ; \(label)\n"
        }

        // ── Assemble output, preserving record order and skipping rebuilt records ──
        var out: [String] = []
        var thetaWritten = false
        for record in records {
            let type = recordType(record.header)
            if type == "$THETA" {
                if !thetaWritten {
                    out.append(contentsOf: thetaText.components(separatedBy: "\n"))
                    thetaWritten = true
                }
                continue
            }
            if type == "$PK" {
                out.append(contentsOf: pkLines)
                continue
            }
            if type == "$TABLE" {
                out.append(replaceRunRefs(record.header, sourceRun: sourceRun, nextRun: nextRun))
                out.append(contentsOf: record.body)
                continue
            }
            out.append(replaceRunRefs(record.header, sourceRun: sourceRun, nextRun: nextRun))
            out.append(contentsOf: record.body)
        }
        if !thetaWritten {
            out.append(contentsOf: thetaText.components(separatedBy: "\n"))
        }
        return out.joined(separator: "\n")
    }

    // MARK: - Parsing helpers

    private static func parseRecords(_ text: String) -> [Record] {
        var records: [Record] = []
        var header: String?
        var body: [String] = []
        for line in text.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("$") {
                if let h = header { records.append(Record(header: h, body: body)) }
                header = trimmed
                body = []
            } else {
                body.append(line)
            }
        }
        if let h = header { records.append(Record(header: h, body: body)) }
        return records
    }

    private static func recordType(_ header: String) -> String {
        let upper = header.uppercased()
        if upper.hasPrefix("$TABLE") { return "$TABLE" }
        if upper.hasPrefix("$THETA") { return "$THETA" }
        if upper.hasPrefix("$PK") { return "$PK" }
        if upper.hasPrefix("$PROBLEM") { return "$PROBLEM" }
        return upper.components(separatedBy: CharacterSet.whitespaces).first ?? upper
    }

    /// Extract `;;; TOKEN-DEFINITION START ... END` blocks from a reference mod.
    private static func extractDefinitions(from text: String) -> [String: [String]] {
        var result: [String: [String]] = [:]
        var currentToken: String?
        var body: [String] = []
        for line in text.components(separatedBy: "\n") {
            let t = line.trimmingCharacters(in: .whitespaces)
            let upper = t.uppercased()
            if upper.contains("-DEFINITION START"), let token = definitionToken(t) {
                currentToken = token
                body = []
                continue
            }
            if currentToken != nil {
                if upper.contains("-DEFINITION END") {
                    result[currentToken!] = body
                    currentToken = nil
                } else if !t.isEmpty {
                    body.append(t)
                }
            }
        }
        return result
    }

    private static func definitionToken(_ line: String) -> String? {
        let upper = line.uppercased()
        guard let endRange = upper.range(of: "-DEFINITION") else { return nil }
        let prefix = line[..<endRange.lowerBound]
        var cleaned = prefix.trimmingCharacters(in: CharacterSet(charactersIn: "; "))
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        guard !cleaned.isEmpty, cleaned.rangeOfCharacter(from: .letters) != nil else { return nil }
        return cleaned
    }

    /// Extract covariate THETA value+label pairs from the reference model's $THETA
    /// records. Labels like "V1WT1" are matched to relation token "V1WT" (trailing
    /// state digit stripped).
    private static func extractCovariateThetas(from text: String) -> [String: (value: String, label: String)] {
        var result: [String: (value: String, label: String)] = [:]
        for record in parseRecords(text) where recordType(record.header) == "$THETA" {
            var lines = record.body
            let headerRest = String(record.header.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            if !headerRest.isEmpty { lines.insert(headerRest, at: 0) }
            for line in lines {
                let t = line.trimmingCharacters(in: .whitespaces)
                guard let semi = t.firstIndex(of: ";") else { continue }
                let label = t[t.index(after: semi)...].trimmingCharacters(in: .whitespaces)
                let value = t[..<semi].trimmingCharacters(in: .whitespaces)
                guard !label.isEmpty, !value.isEmpty else { continue }
                var token = label
                while let last = token.last, last.isNumber { token.removeLast() }
                if !token.isEmpty { result[token] = (value, label) }
            }
        }
        return result
    }

    /// Base (non-covariate) THETA lines from the source mod. A theta is a covariate
    /// theta when its label matches a relation token from the reference model.
    private static func baseThetaLines(from records: [Record], referenceTokens: Set<String>) -> [String] {
        var result: [String] = []
        for record in records where recordType(record.header) == "$THETA" {
            var lines = record.body
            let headerRest = String(record.header.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            if !headerRest.isEmpty { lines.insert(headerRest, at: 0) }
            for line in lines {
                let t = line.trimmingCharacters(in: .whitespaces)
                guard !t.isEmpty else { continue }
                if let semi = t.firstIndex(of: ";") {
                    let label = t[t.index(after: semi)...].trimmingCharacters(in: .whitespaces)
                    var token = label
                    while let last = token.last, last.isNumber { token.removeLast() }
                    if referenceTokens.contains(token) { continue }
                }
                result.append(line)
            }
        }
        return result
    }

    /// Remove all PsN covariate machinery from the source $PK body: DEFINITION/RELATION
    /// marker blocks, `PARAMCOV=` wiring lines and `TVP = PCOV*TVP` insertions.
    private static func cleanBasePKBody(_ body: [String]) -> [String] {
        var out: [String] = []
        var inDefinition = false
        var inRelation = false
        for line in body {
            let t = line.trimmingCharacters(in: .whitespaces)
            let upper = t.uppercased()
            if upper.contains("-DEFINITION START") { inDefinition = true; continue }
            if inDefinition {
                if upper.contains("-DEFINITION END") { inDefinition = false }
                continue
            }
            if upper.contains("-RELATION START") { inRelation = true; continue }
            if inRelation {
                if upper.contains("-RELATION END") { inRelation = false }
                continue
            }
            if t.range(of: #"^[A-Za-z][A-Za-z0-9]*COV\s*="#, options: .regularExpression) != nil { continue }
            if t.range(of: #"^TV[A-Za-z0-9]+\s*=\s*[A-Za-z0-9]+COV\*TV"#, options: .regularExpression) != nil { continue }
            out.append(line)
        }
        return out
    }

    /// PK parameter names from `TV{param}=THETA(n)` assignments.
    private static func pkParams(from text: String) -> [String] {
        var params: [String] = []
        var seen = Set<String>()
        for line in text.components(separatedBy: "\n") {
            let t = line.uppercased().replacingOccurrences(of: " ", with: "")
            guard t.hasPrefix("TV") else { continue }
            let after = t.dropFirst(2)
            guard let eq = after.firstIndex(of: "=") else { continue }
            let name = String(after[..<eq])
            let rhs = String(after[after.index(after: eq)...])
            guard !name.isEmpty, rhs.hasPrefix("THETA"), seen.insert(name).inserted else { continue }
            params.append(name)
        }
        return params
    }

    /// "V1WT" with params [CL,V1,Q,V2] → (param: "V1", cov: "WT").
    private static func splitToken(_ token: String, params: [String]) -> (param: String, cov: String) {
        let upper = token.uppercased()
        for param in params.sorted(by: { $0.count > $1.count }) {
            if upper.hasPrefix(param.uppercased()) {
                let cov = String(token.dropFirst(param.count))
                if !cov.isEmpty { return (param, cov) }
            }
        }
        return (token, "")
    }

    private static func isCategoricalCovariate(_ cov: String) -> Bool {
        let c = cov.uppercased()
        return c == "SEX" || c == "STUDY" || c == "STUD"
    }

    private static func definitionBody(
        token: String,
        cov: String,
        thetaIndex: Int,
        categorical: Bool,
        reference: [String: [String]],
        continuousMeans: [String: Double]
    ) -> [String] {
        let newIndex = "\(thetaIndex)"
        if let refLines = reference[token] {
            return refLines.map { line in
                let normalized = replaceContinuousMean(in: line, cov: cov, mean: continuousMeans[cov.uppercased()])
                return replaceThetaRefs(normalized, newIndex: newIndex)
            }
        }
        if categorical {
            return [
                "IF(\(cov).EQ.1) \(token) = THETA(\(newIndex))",
                "IF(\(cov).NE.1) \(token) = 1"
            ]
        }
        guard let mean = continuousMeans[cov.uppercased()], mean > 0 else { return [] }
        return ["   \(token) = ((\(cov)/\(String(format: "%.6g", mean)))**THETA(\(newIndex)))"]
    }

    private static func replaceContinuousMean(in line: String, cov: String, mean: Double?) -> String {
        guard let mean, mean > 0 else { return line }
        let escaped = NSRegularExpression.escapedPattern(for: cov)
        guard let regex = try? NSRegularExpression(
            pattern: #"(\(\s*\#(escaped)\s*/\s*[\d.eE+-]+\s*\))"#,
            options: []
        ) else { return line }
        let ns = line as NSString
        let range = NSRange(location: 0, length: ns.length)
        let replacement = "(\(cov)/\(String(format: "%.6g", mean)))"
        return regex.stringByReplacingMatches(in: line, options: [], range: range, withTemplate: replacement)
    }

    private static func replaceThetaRefs(_ line: String, newIndex: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #"THETA\s*\(\s*\d+\s*\)"#, options: [.caseInsensitive]) else { return line }
        let ns = line as NSString
        let range = NSRange(location: 0, length: ns.length)
        return regex.stringByReplacingMatches(in: line, options: [], range: range, withTemplate: "THETA(\(newIndex))")
    }

    private static func replaceRunRefs(_ text: String, sourceRun: String, nextRun: String) -> String {
        var s = text
        s = s.replacingOccurrences(of: "FILE=run\(sourceRun).ETA", with: "FILE=run\(nextRun).ETA")
        s = s.replacingOccurrences(of: "FILE=000\(sourceRun).ETA", with: "FILE=run\(nextRun).ETA")
        for old in ["run\(sourceRun)", "Run\(sourceRun)", "sdtab\(sourceRun)", "patab\(sourceRun)", "catab\(sourceRun)", "cotab\(sourceRun)"] {
            s = s.replacingOccurrences(of: old, with: old.replacingOccurrences(of: sourceRun, with: nextRun))
        }
        return s
    }
}
