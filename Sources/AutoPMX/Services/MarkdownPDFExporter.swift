import AppKit
import Foundation
import WebKit

/// Renders generated Markdown reports as styled HTML and exports them to PDF.
enum MarkdownPDFExporter {
    static func html(markdown: String, title: String = "AutoPMx Report") -> String {
        let body = renderBlocks(markdown)
        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <title>\(title)</title>
        <style>
          @page { size: A4; margin: 18mm 16mm; }
          body {
            font-family: -apple-system, "PingFang SC", "Helvetica Neue", sans-serif;
            color: #1c1c1e;
            line-height: 1.55;
            margin: 0 auto;
            max-width: 980px;
            padding: 12px;
            font-size: 12px;
          }
          h1 { font-size: 24px; border-bottom: 2px solid #d7d7dc; padding-bottom: 6px; }
          h2 { font-size: 19px; border-bottom: 1px solid #e2e2e7; padding-bottom: 4px; margin-top: 26px; }
          h3 { font-size: 16px; margin-top: 20px; }
          h4 { font-size: 14px; margin-top: 16px; }
          h1, h2, h3, h4 { page-break-after: avoid; }
          p { margin: 8px 0; }
          table {
            border-collapse: collapse;
            width: 100%;
            margin: 14px 0;
            page-break-inside: auto;
          }
          th, td {
            border: 1px solid #d1d1d6;
            padding: 6px 9px;
            text-align: left;
            vertical-align: top;
            font-size: 11px;
            word-break: break-word;
          }
          th.num, td.num {
            text-align: right;
            font-variant-numeric: tabular-nums;
            white-space: nowrap;
          }
          th { background: #f0f0f4; font-weight: 600; }
          tr:nth-child(even) td { background: #fafafa; }
          tr { page-break-inside: avoid; }
          code {
            font-family: "SFMono-Regular", Menlo, monospace;
            background: #f0f0f4;
            padding: 1px 4px;
            border-radius: 4px;
            font-size: 10.5px;
          }
          pre {
            background: #f4f4f7;
            border: 1px solid #e2e2e7;
            border-radius: 8px;
            padding: 12px;
            overflow-x: auto;
            page-break-inside: avoid;
          }
          pre code { background: transparent; padding: 0; }
          ul, ol { margin: 8px 0; padding-left: 24px; }
          li { margin: 3px 0; }
          hr { border: 0; border-top: 1px solid #d1d1d6; margin: 18px 0; }
          blockquote {
            margin: 12px 0;
            padding: 2px 12px;
            border-left: 4px solid #b7b7c4;
            color: #555;
          }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }

    @MainActor
    static func exportPDF(markdown: String, to outputURL: URL, baseURL: URL? = nil) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let id = UUID()
            let task = MarkdownPDFExportTask(
                markdown: markdown,
                baseURL: baseURL,
                outputURL: outputURL
            ) { result in
                DispatchQueue.main.async {
                    Self.activeTasks.removeValue(forKey: id)
                    continuation.resume(with: result.map { _ in () })
                }
            }
            Self.activeTasks[id] = task
        }
    }

    private static var activeTasks: [UUID: MarkdownPDFExportTask] = [:]

    private static func renderBlocks(_ markdown: String) -> String {
        let lines = markdown.components(separatedBy: .newlines)
        var html = ""
        var paragraph: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            html += "<p>\(inline(paragraph.joined(separator: " ")))</p>"
            paragraph = []
        }

        var index = 0
        while index < lines.count {
            let raw = lines[index]
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.hasPrefix("```") {
                flushParagraph()
                var code: [String] = []
                index += 1
                while index < lines.count, !lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(lines[index])
                    index += 1
                }
                index += 1
                html += "<pre><code>\(escape(code.joined(separator: "\n")))</code></pre>"
                continue
            }

            if trimmed.isEmpty {
                flushParagraph()
                index += 1
                continue
            }

            if trimmed.hasPrefix("|") {
                flushParagraph()
                var tableLines: [String] = []
                while index < lines.count, lines[index].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    let tableLine = lines[index].trimmingCharacters(in: .whitespaces)
                    if !isTableSeparator(tableLine) {
                        tableLines.append(tableLine)
                    }
                    index += 1
                }
                html += renderTable(tableLines)
                continue
            }

            if let level = headingLevel(trimmed) {
                flushParagraph()
                let headingText = trimmed
                    .drop(while: { $0 == "#" })
                    .trimmingCharacters(in: .whitespaces)
                html += "<h\(level)>\(inline(headingText))</h\(level)>"
                index += 1
                continue
            }

            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph()
                html += "<hr>"
                index += 1
                continue
            }

            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("+ ") {
                flushParagraph()
                var items: [String] = []
                while index < lines.count {
                    let item = lines[index].trimmingCharacters(in: .whitespaces)
                    if item.hasPrefix("- ") || item.hasPrefix("* ") || item.hasPrefix("+ ") {
                        items.append(String(item.dropFirst(2)))
                        index += 1
                    } else {
                        break
                    }
                }
                html += "<ul>" + items.map { "<li>\(inline($0))</li>" }.joined() + "</ul>"
                continue
            }

            if trimmed.range(of: #"^\d+\.\s+"#, options: .regularExpression) != nil {
                flushParagraph()
                var items: [String] = []
                while index < lines.count {
                    let item = lines[index].trimmingCharacters(in: .whitespaces)
                    if let match = item.range(of: #"^\d+\.\s+"#, options: .regularExpression) {
                        items.append(String(item[match.upperBound...]))
                        index += 1
                    } else {
                        break
                    }
                }
                html += "<ol>" + items.map { "<li>\(inline($0))</li>" }.joined() + "</ol>"
                continue
            }

            if trimmed.hasPrefix("> ") {
                flushParagraph()
                html += "<blockquote>\(inline(String(trimmed.dropFirst(2))))</blockquote>"
                index += 1
                continue
            }

            paragraph.append(trimmed)
            index += 1
        }

        flushParagraph()
        return html
    }

    private static func headingLevel(_ line: String) -> Int? {
        guard line.hasPrefix("#") else { return nil }
        var level = 0
        for character in line {
            guard character == "#", level < 6 else { break }
            level += 1
        }
        return level
    }

    private static func isTableSeparator(_ line: String) -> Bool {
        let content = line
            .trimmingCharacters(in: CharacterSet(charactersIn: "|"))
            .replacingOccurrences(of: "|", with: "")
            .trimmingCharacters(in: .whitespaces)
        return !content.isEmpty && content.allSatisfy { $0 == "-" || $0 == ":" || $0 == " " }
    }

    private static func renderTable(_ lines: [String]) -> String {
        let rows = lines.map { line -> [String] in
            let trimmed = line.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
            return trimmed
                .split(separator: "|", omittingEmptySubsequences: false)
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }
        guard let header = rows.first else { return "" }
        let numericColumns = header.map(isNumericHeader)
        var table = "<table><thead><tr>"
        for (index, heading) in header.enumerated() {
            let alignment = index < numericColumns.count && numericColumns[index] ? " class=\"num\"" : ""
            table += "<th\(alignment)>\(inline(heading))</th>"
        }
        table += "</tr></thead><tbody>"
        for row in rows.dropFirst() {
            table += "<tr>"
            for (index, cell) in row.enumerated() {
                let alignment = index < numericColumns.count && numericColumns[index] ? " class=\"num\"" : ""
                table += "<td\(alignment)>\(inline(cell))</td>"
            }
            table += "</tr>"
        }
        table += "</tbody></table>"
        return table
    }

    private static func isNumericHeader(_ text: String) -> Bool {
        let upper = text.uppercased()
        let terms = [
            "ESTIMATE", "EST.", "SE", "RSE", "MEDIAN", "MEAN", "BIAS",
            "OFV", "2.5%", "97.5%", "VALUE", "%"
        ]
        return terms.contains { upper.contains($0) }
    }

    private static func inline(_ text: String) -> String {
        let segments = text.components(separatedBy: "`")
        var result = ""
        for (offset, segment) in segments.enumerated() {
            if offset % 2 == 1 {
                result += "<code>\(escape(segment))</code>"
            } else {
                var styled = escape(segment)
                styled = replace(pattern: #"\*\*(.+?)\*\*"#, in: styled, with: "<strong>$1</strong>")
                styled = replace(pattern: #"__([^_]+?)__"#, in: styled, with: "<strong>$1</strong>")
                styled = replace(pattern: #"\*([^*]+?)\*"#, in: styled, with: "<em>$1</em>")
                result += styled
            }
        }
        return result
    }

    private static func replace(pattern: String, in text: String, with template: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: template)
    }

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}

@MainActor
private final class MarkdownPDFExportTask: NSObject, WKNavigationDelegate {
    let id = UUID()
    private let webView: WKWebView
    private let outputURL: URL
    private let completion: (Result<URL, Error>) -> Void

    init(markdown: String, baseURL: URL?, outputURL: URL, completion: @escaping (Result<URL, Error>) -> Void) {
        self.webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 1200))
        self.outputURL = outputURL
        self.completion = completion
        super.init()
        webView.navigationDelegate = self
        let html = MarkdownPDFExporter.html(markdown: markdown, title: outputURL.deletingPathExtension().lastPathComponent)
        webView.loadHTMLString(html, baseURL: baseURL)
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            let configuration = WKPDFConfiguration()
            webView.createPDF(configuration: configuration) { [weak self] result in
                Task { @MainActor in
                    self?.handlePDFResult(result)
                }
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            completion(.failure(error))
        }
    }

    @MainActor
    private func handlePDFResult(_ result: Result<Data, Error>) {
        do {
            let data = try result.get()
            try data.write(to: outputURL, options: .atomic)
            completion(.success(outputURL))
        } catch {
            completion(.failure(error))
        }
    }
}
