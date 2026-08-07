import Foundation

struct ParameterEstimateRow: Identifiable, Hashable {
    let id = UUID()
    let group: String
    let name: String
    let estimate: Double
    let standardError: Double?
    let shrinkage: Double?
    private let displayEstimate: String?
    private let displayStandardError: String?
    private let displayRSE: String?
    private let displayShrinkage: String?

    init(
        group: String,
        name: String,
        estimate: Double,
        standardError: Double?,
        shrinkage: Double? = nil,
        estimateText: String? = nil,
        standardErrorText: String? = nil,
        rseText: String? = nil,
        shrinkageText: String? = nil
    ) {
        self.group = group
        self.name = name
        self.estimate = estimate
        self.standardError = standardError
        self.shrinkage = shrinkage
        self.displayEstimate = estimateText
        self.displayStandardError = standardErrorText
        self.displayRSE = rseText
        self.displayShrinkage = shrinkageText
    }

    var rsePercent: Double? {
        if let displayRSE {
            let normalized = displayRSE
                .replacingOccurrences(of: "%", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return Double(normalized)
        }
        guard let standardError, estimate != 0 else { return nil }
        return abs(standardError / estimate) * 100
    }

    var estimateText: String {
        if let displayEstimate { return displayEstimate }
        return Self.format(estimate)
    }

    var standardErrorText: String {
        if let displayStandardError { return displayStandardError }
        return standardError.map(Self.format) ?? "NA"
    }

    var rseText: String {
        if let displayRSE {
            let normalized = displayRSE.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized == "-" || normalized.uppercased() == "NA" || normalized.isEmpty {
                return "NA"
            }
            return normalized.hasSuffix("%") ? normalized : "\(normalized)%"
        }
        return rsePercent.map { String(format: "%.1f%%", $0) } ?? "NA"
    }

    var shrinkageText: String {
        if let displayShrinkage {
            let normalized = displayShrinkage.trimmingCharacters(in: .whitespacesAndNewlines)
            if normalized == "-" || normalized.uppercased() == "NA" || normalized.isEmpty {
                return "NA"
            }
            return normalized.hasSuffix("%") ? normalized : "\(normalized)%"
        }
        return shrinkage.map { String(format: "%.1f%%", $0) } ?? "NA"
    }

    private static func format(_ value: Double) -> String {
        guard value.isFinite else { return "NA" }
        let absolute = abs(value)
        if absolute > 0, absolute < 0.001 || absolute >= 10_000 {
            return String(format: "%.3E", value)
        }
        return String(format: "%.3g", value)
    }
}

extension ParameterEstimateRow {
    /// Canonical display order for PK parameter tables/reports:
    /// OFV/AIC → PK parameters → IIV → residual → remaining groups.
    static func orderedForDisplay(_ rows: [ParameterEstimateRow]) -> [ParameterEstimateRow] {
        let indexed = rows.enumerated()
        return indexed.sorted { lhs, rhs in
            let lr = displayRank(lhs.element)
            let rr = displayRank(rhs.element)
            if lr != rr { return lr < rr }
            if lhs.element.group == "Fit" {
                let lf = lhs.element.name.uppercased() == "OFV" ? 0 : 1
                let rf = rhs.element.name.uppercased() == "OFV" ? 0 : 1
                if lf != rf { return lf < rf }
            }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    private static func displayRank(_ row: ParameterEstimateRow) -> Int {
        switch row.group {
        case "Fit":
            return 0
        case "PK Parameter", "Fixed", "THETA":
            return 1
        case "IIV", "BSV(%)":
            return 2
        case "Residual", "SIGMA":
            return 3
        default:
            return 4
        }
    }
}

enum ParameterEstimateParser {
    static func parseSemanticCSV(_ text: String) -> [ParameterEstimateRow] {
        let records = text
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map(parseCSVLine)
        guard let header = records.first else { return [] }
        let rows = records.dropFirst()
        let labelIndex = header.firstIndex(of: "Label") ?? 0
        let estimateIndex = header.firstIndex(of: "Estimate") ?? 1
        let seIndex = header.firstIndex(of: "SE") ?? 2
        let rseIndex = header.firstIndex(of: "RSE") ?? 3
        let shrinkIdx = header.firstIndex(where: { $0.lowercased().contains("shrink") })

        return ParameterEstimateRow.orderedForDisplay(rows.compactMap { record in
            guard record.indices.contains(labelIndex), record.indices.contains(estimateIndex) else { return nil }
            let label = record[labelIndex]
            let estimate = record[estimateIndex]
            let se = record.indices.contains(seIndex) ? record[seIndex] : "-"
            let rse = record.indices.contains(rseIndex) ? record[rseIndex] : "-"
            let shrinkStr: String? = shrinkIdx.flatMap { record.indices.contains($0) ? record[$0] : nil }
            let cleanEstimate = normalizeDisplayValue(estimate)
            let cleanSE = normalizeDisplayValue(se)
            let cleanRSE = normalizeDisplayValue(rse)
            let cleanShrink: String? = shrinkStr.map(normalizeDisplayValue)
            return ParameterEstimateRow(
                group: semanticGroup(for: label),
                name: label,
                estimate: Double(cleanEstimate) ?? .nan,
                standardError: Double(cleanSE),
                estimateText: cleanEstimate,
                standardErrorText: cleanSE,
                rseText: cleanRSE,
                shrinkageText: cleanShrink
            )
        })
    }

    /// Parse .ext file. Uses both the table rows (estimates + SE) and the R-matrix when
    /// COVARIANCE STEP ABORTED (no -1000000001 SE line). NONMEM outputs the R-matrix at
    /// -1000000007 (correlation diagonal variances) or -1000000006 (R-matrix diagonals).
    /// The R-matrix diagonal is the variance of each parameter; sqrt(variance) = SE.
    static func parseExt(_ text: String, modText: String? = nil) -> [ParameterEstimateRow] {
        let lines = text.components(separatedBy: .newlines)

        // Find the header line (contains ITERATION and OBJ)
        guard let headerLine = lines.first(where: { $0.contains("ITERATION") && $0.contains("OBJ") }) else {
            return []
        }

        // Parse header names — keep ALL including OBJ (last)
        let allNames = headerLine
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .dropFirst() // drop "ITERATION"
        let names = Array(allNames)

        // Find final estimates (-1000000000 line)
        guard let finalLine = lines.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("-1000000000") }) else {
            return []
        }
        let allValues = numericValuesFromLine(finalLine)
        // Partial fix: keep the full line including OBJ
        let parts = finalLine.split(whereSeparator: \.isWhitespace).map(String.init)
        let objValue = parts.last.flatMap { Double($0) }

        // Primary SE source: -1000000001 line
        let seLine1 = lines.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("-1000000001") })
        let seFromLine1 = seLine1.map { numericValuesFromLine($0) } ?? []

        // Secondary SE source: -1000000006 line (R-matrix diagonals)
        let seLine6 = lines.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("-1000000006") })
        let seFromLine6 = seLine6.map { numericValuesFromLine($0) } ?? []

        // Tertiary SE source: -1000000004 line (correlation matrix diagonals)
        let seLine4 = lines.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("-1000000004") })
        let seFromLine4 = seLine4.map { numericValuesFromLine($0) } ?? []

        var result: [ParameterEstimateRow] = []

        // Always show OFV as the first row (Fit group)
        if let ofv = objValue, ofv > 0 {
            result.append(ParameterEstimateRow(
                group: "Fit", name: "OFV",
                estimate: ofv, standardError: nil
            ))
            // AIC ≈ OFV + 2 * (number_of_estimated_params)
            let nParams = names.count  // conservative estimate of parameter count
            let aic = ofv + 2 * Double(nParams)
            result.append(ParameterEstimateRow(
                group: "Fit", name: "AIC",
                estimate: aic, standardError: nil
            ))
        }

        // Map PK parameters (all columns except the last OBJ column)
        let paramNames = names.dropLast()  // drop OBJ column for parameters
        for (index, name) in paramNames.enumerated() {
            guard index < allValues.count else { continue }
            let estimate = allValues[index]

            var se: Double? = nil
            if index < seFromLine1.count { se = cleanStandardError(seFromLine1[index]) }
            if se == nil, index < seFromLine6.count { se = cleanStandardError(seFromLine6[index]) }
            if se == nil && !seFromLine1.isEmpty {
                let seLine5 = lines.first(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("-1000000005") })
                if let se5 = seLine5.map({ numericValuesFromLine($0) }), index < se5.count { se = cleanStandardError(se5[index]) }
            }
            if se == nil, index < seFromLine4.count {
                let variance = seFromLine4[index]
                if variance > 0 { se = cleanStandardError(sqrt(variance)) }
            }

            if shouldExcludeFromDisplay(name: name, estimate: estimate) { continue }
            if shouldHideSIGMA(name: name, modText: modText) { continue }

            // If the parameter is FIXED in .mod, SE/RSE/shinkage are meaningless → nil
            let isFixed = isParameterFixed(name: name, index: index, modText: modText)
            let finalSE = isFixed ? nil : se

            let displayName = labeledName(for: name, modText: modText) ?? name
            result.append(ParameterEstimateRow(
                group: groupName(for: name, label: displayName, isFixed: isFixed), name: displayName,
                estimate: estimate, standardError: finalSE
            ))
        }
        return ParameterEstimateRow.orderedForDisplay(result)
    }

    /// Parse numeric values from a line, skipping the first and last token (labels)
    private static func numericValuesFromLine(_ line: String) -> [Double] {
        let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
        guard parts.count > 2 else { return [] }
        let middle = parts.dropFirst().dropLast()
        return middle.compactMap { token -> Double? in
            // Skip non-numeric tokens like "........." (NONMEM's "not computed" marker)
            if token.contains(".") && token.filter({ $0 == "." }).count > 5 { return nil }
            return Double(token)
        }
    }

    private static func cleanStandardError(_ value: Double) -> Double? {
        guard value.isFinite, abs(value) < 1_000_000_000, value != 0 else { return nil }
        return value
    }

    private static func groupName(for name: String, label: String, isFixed: Bool) -> String {
        if name.hasPrefix("THETA") {
            if isFixed { return "Fixed" }
            return semanticGroup(for: label) == "Residual" ? "Residual" : "PK Parameter"
        }
        if name.hasPrefix("OMEGA") { return "IIV" }
        if name.hasPrefix("SIGMA") { return "Residual" }
        return "Other"
    }

    /// Skip SIGMA parameters when the model uses $SIGMA 1 FIX.
    /// In combined prop+add error, residual SDs are estimated as THETA
    /// (Prop.RE and Add.RE). SIGMA(1,1) is fixed at 1 — not a parameter.
    private static func shouldHideSIGMA(name: String, modText: String?) -> Bool {
        guard name.uppercased().contains("SIGMA") else { return false }
        // If .mod has $SIGMA 1 FIX, SIGMA is not an estimated parameter
        if let mod = modText?.uppercased(), mod.contains("$SIGMA") {
            let sigmaBlock = mod.components(separatedBy: "$SIGMA").last?
                .components(separatedBy: "$").first ?? ""
            if sigmaBlock.uppercased().contains("FIX") {
                return true
            }
        }
        return false
    }

    /// Check if a THETA or OMEGA parameter at a given logical index is FIXED in the .mod file.
    /// A FIXED parameter still appears in .ext but its SE/RSE/shinkage should show as "NA"
    /// because it was not estimated — it was held constant.
    private static func isParameterFixed(name: String, index: Int, modText: String?) -> Bool {
        guard let mod = modText else { return false }
        let upper = mod.uppercased()
        if name.hasPrefix("THETA") {
            // Find all $THETA blocks (there should be one, but be safe)
            guard let thetaStart = upper.range(of: "$THETA") else { return false }
            // Find the end of $THETA block (next $ block)
            let afterTheta = upper[thetaStart.upperBound...]
            let thetaBlock: Substring
            if let nextDollar = afterTheta.firstIndex(of: "$") {
                thetaBlock = afterTheta[..<nextDollar]
            } else {
                thetaBlock = afterTheta
            }
            // Split by newline, skip empty lines
            let thetaLines = thetaBlock.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            // The index in .ext corresponds to the Nth non-empty THETA line (0-based)
            guard index < thetaLines.count else { return false }
            return thetaLines[index].uppercased().contains("FIX")
        }
        if name.hasPrefix("OMEGA") {
            // Similar logic for OMEGA blocks
            guard let omegaStart = upper.range(of: "$OMEGA") else { return false }
            let afterOmega = upper[omegaStart.upperBound...]
            let omegaBlock: Substring
            if let nextDollar = afterOmega.firstIndex(of: "$") {
                omegaBlock = afterOmega[..<nextDollar]
            } else {
                omegaBlock = afterOmega
            }
            let omegaLines = omegaBlock.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            // For OMEGA, the .ext names are like OMEGA(1,1), OMEGA(2,1), OMEGA(2,2)
            // The line index in .mod should correspond to diagonal elements in reading order
            guard index < omegaLines.count else { return false }
            return omegaLines[index].uppercased().contains("FIX")
        }
        return false
    }

    /// Map a parameter name from .ext to a human-readable label using .mod context when available.
    static func labeledName(for name: String, modText: String?) -> String? {
        if let mod = modText {
            let label = extractLabelFromMod(name, from: mod)
            if let label { return label }
        }
        return nil
    }

    /// Off-diagonal OMEGA elements (i,j where i≠j) with zero estimate should be excluded from display.
    static func shouldExcludeFromDisplay(name: String, estimate: Double) -> Bool {
        guard name.uppercased().contains("OMEGA") else { return false }
        let nums = name.replacingOccurrences(of: "OMEGA", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
        guard nums.count >= 2 else { return false }
        if nums[0] != nums[1] && abs(estimate) < 1e-9 { return true }
        return false
    }

    private static func extractLabelFromMod(_ param: String, from modText: String) -> String? {
        let upper = param.uppercased()

        // THETA(i) → look for semicolon comment on that THETA line
        if upper.hasPrefix("THETA") {
            let thetaNum = Int(param.dropFirst(5).trimmingCharacters(in: CharacterSet(charactersIn: "() "))) ?? 0
            guard thetaNum > 0 else { return nil }
            var idx = 0
            var inTheta = false
            for line in modText.components(separatedBy: .newlines) {
                let stripped = line.trimmingCharacters(in: .whitespaces)
                if stripped.uppercased().hasPrefix("$THETA"), !stripped.uppercased().hasPrefix("$THETAP") {
                    inTheta = true; continue
                }
                if inTheta && stripped.hasPrefix("$") { break }
                if inTheta, !stripped.isEmpty, !stripped.hasPrefix(";") {
                    idx += 1
                    if idx == thetaNum {
                        if let commentStart = stripped.range(of: ";") {
                            let label = String(stripped[commentStart.upperBound...]).trimmingCharacters(in: .whitespaces)
                            if !label.isEmpty { return label }
                        }
                    }
                }
            }
        }

        // OMEGA(i,j) — for diagonal (i,i), find the i-th value and its label
        if upper.contains("OMEGA") {
            let nums = param.replacingOccurrences(of: "OMEGA", with: "")
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
                .split(separator: ",").compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            guard nums.count >= 2, nums[0] == nums[1] else { return nil }
            let etaIndex = nums[0]
            var idx = 0
            var inOmega = false
            for line in modText.components(separatedBy: .newlines) {
                let stripped = line.trimmingCharacters(in: .whitespaces)
                if stripped.uppercased().hasPrefix("$OMEGA"), !stripped.uppercased().hasPrefix("$OMEGAP") {
                    inOmega = true; continue
                }
                if inOmega && stripped.hasPrefix("$") { break }
                if inOmega, !stripped.isEmpty, !stripped.hasPrefix(";") {
                    idx += 1
                    if idx == etaIndex {
                        if let commentStart = stripped.range(of: ";") {
                            var label = String(stripped[commentStart.upperBound...]).trimmingCharacters(in: .whitespaces)
                            if !label.isEmpty {
                                let upperLabel = label.uppercased()
                                if upperLabel.hasPrefix("IIV") || upperLabel.hasPrefix("BSV") {
                                    return label
                                }
                                return "IIV \(label)"
                            }
                        }
                        return "ETA(\(etaIndex))"
                    }
                }
            }
        }

        return nil
    }

    private static func semanticGroup(for label: String) -> String {
        let upper = label.uppercased()
        if upper == "OFV" || upper == "AIC" { return "Fit" }
        if upper.hasPrefix("IIV") || upper.contains("BSV") { return "IIV" }
        if upper.hasPrefix("PROP") || upper.hasPrefix("ADD") || upper.contains("ERROR") || upper.contains("RESIDUAL") || upper.contains("SIGMA") { return "Residual" }
        return "PK Parameter"
    }

    private static func normalizeDisplayValue(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed == "-" || trimmed.isEmpty { return "NA" }
        return trimmed
    }

    private static func parseCSVLine(_ line: String) -> [String] {
        var fields = [String]()
        var field = ""
        var inQuotes = false
        var iterator = line.makeIterator()
        while let character = iterator.next() {
            if character == "\"" {
                inQuotes.toggle()
            } else if character == ",", !inQuotes {
                fields.append(field)
                field = ""
            } else {
                field.append(character)
            }
        }
        fields.append(field)
        return fields
    }

    /// Mark parameters that are FIXed in the .mod as non-estimated even when the
    /// semantic CSV still contains an old estimate/SE from before the fix was applied.
    static func applyingModFixedStatus(_ rows: [ParameterEstimateRow], modText: String?) -> [ParameterEstimateRow] {
        guard let modText, !modText.isEmpty else { return rows }
        let fixedThetaLabels = parameterLabels(in: modText, blockPrefix: "$THETA", fixedOnly: true)
        let fixedOmegaLabels = parameterLabels(in: modText, blockPrefix: "$OMEGA", fixedOnly: true)
        return rows.map { row in
            let label = compactLabel(row.name)
            let isFixedTheta = row.group == "Residual" && fixedThetaLabels.contains(label)
            let isFixedOmega = row.group == "IIV" && fixedOmegaLabels.contains(label)
            guard isFixedTheta || isFixedOmega else { return row }
            return ParameterEstimateRow(
                group: row.group,
                name: row.name,
                estimate: 0,
                standardError: nil,
                shrinkage: nil,
                estimateText: "0",
                standardErrorText: "NA",
                rseText: "NA",
                shrinkageText: "NA"
            )
        }
    }

    private static func parameterLabels(in text: String, blockPrefix: String, fixedOnly: Bool) -> Set<String> {
        var labels: Set<String> = []
        var inBlock = false
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            let upper = trimmed.uppercased()
            if upper.hasPrefix(blockPrefix) {
                inBlock = true
                continue
            }
            if inBlock && upper.hasPrefix("$") {
                inBlock = false
                continue
            }
            guard inBlock, !trimmed.isEmpty, !trimmed.hasPrefix(";") else { continue }
            if fixedOnly && !upper.contains("FIX") { continue }
            let comment = trimmed.components(separatedBy: ";").dropFirst()
                .joined(separator: ";")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !comment.isEmpty else { continue }
            labels.insert(compactLabel(comment))
        }
        return labels
    }

    private static func compactLabel(_ value: String) -> String {
        value.uppercased().filter { $0.isLetter || $0.isNumber }
    }
}
