import Foundation

enum AssetCategory: String, CaseIterable, Identifiable {
    case models
    case data
    case outputs
    case figures
    case reports
    case scripts

    static var allCases: [AssetCategory] {
        [.models, .data, .outputs, .figures, .reports]
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .models: return "Models"
        case .data: return "Data"
        case .outputs: return "NONMEM Outputs"
        case .figures: return "Figures"
        case .reports: return "Reports"
        case .scripts: return "Scripts"
        }
    }

    var symbolName: String {
        switch self {
        case .models: return "doc.text"
        case .data: return "tablecells"
        case .outputs: return "terminal"
        case .figures: return "photo"
        case .reports: return "doc.richtext"
        case .scripts: return "chevron.left.forwardslash.chevron.right"
        }
    }
}

struct ProjectAsset: Identifiable, Hashable {
    let url: URL
    let category: AssetCategory
    let relativePath: String

    var id: String { url.path }
    var title: String { url.lastPathComponent }

    var detail: String {
        if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
            return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
        }
        return relativePath
    }

    var runID: String? {
        let name = url.lastPathComponent
        let lower = name.lowercased()

        // GA001.mod → "001"
        if lower.hasPrefix("ga"), lower.hasSuffix(".mod") {
            let start = name.index(name.startIndex, offsetBy: 2)
            let end = name.index(name.endIndex, offsetBy: -4)
            let id = String(name[start..<end])
            if id.allSatisfy(\.isNumber) { return id }
        }

        guard lower.hasPrefix("run"), lower.hasSuffix(".mod") else { return nil }
        let start = name.index(name.startIndex, offsetBy: 3)
        let end = name.index(name.endIndex, offsetBy: -4)
        var id = String(name[start..<end])
        // Strip _ga_opt suffix so run001_ga_opt → "001"
        id = id.replacingOccurrences(of: "_ga_opt", with: "")
        return id.allSatisfy(\.isNumber) ? id : nil
    }

    var relatedRunID: String? {
        if let runID { return runID }
        let text = relativePath
        let patterns = [
            #"run(\d+)\.(lst|ext|cov|mod)"#,
            #"run(\d+)"#,
            #"Run(\d+)"#,
            #"mod(\d+)"#,
            #"vpc_dir_(\d+)"#,
            #"SDTAB(\d+)"#
        ]
        for pattern in patterns {
            if let match = Self.firstCapture(in: text, pattern: pattern) {
                return match
            }
        }
        return nil
    }

    var isTextPreviewable: Bool {
        let ext = url.pathExtension.lowercased()
        return ["mod", "lst", "ext", "cov", "md", "py", "r", "json", "csv", "txt", ""].contains(ext)
    }

    var isImage: Bool {
        ["jpg", "jpeg", "png"].contains(url.pathExtension.lowercased())
    }

    private static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, options: [], range: range),
            match.numberOfRanges > 1,
            let captureRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[captureRange])
    }
}

struct ModelFileStatus {
    let runID: String
    let mod: Bool
    let lst: Bool
    let ext: Bool
    let cov: Bool

    var summary: String {
        [("mod", mod), ("lst", lst), ("ext", ext), ("cov", cov)]
            .map { "\($0.0):\($0.1 ? "ok" : "missing")" }
            .joined(separator: "  ")
    }
}

struct DataPathCheck {
    let current: String?
    let expected: String
    let matches: Bool
}

struct RuleContext {
    let text: String
    let loadedSources: [String]
    let missingSources: [String]

    var summary: String {
        if loadedSources.isEmpty {
            return "No rule/knowledge sources loaded"
        }
        var parts = ["Loaded: \(loadedSources.joined(separator: ", "))"]
        if !missingSources.isEmpty {
            parts.append("Missing/skipped: \(missingSources.joined(separator: ", "))")
        }
        return parts.joined(separator: " | ")
    }
}

struct AssistantMessage: Identifiable, Hashable {
    enum Role: String {
        case user
        case assistant
        case system
    }

    let id = UUID()
    let role: Role
    let text: String
    let date = Date()
}
