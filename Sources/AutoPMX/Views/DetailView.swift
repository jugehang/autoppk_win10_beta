import SwiftUI
import AppKit
import Quartz
import WebKit

// MARK: - Detail View

struct DetailView: View {
    @EnvironmentObject private var store: WorkbenchStore

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.previewTitle)
                        .font(.system(size: 14, weight: .semibold))
                    Text(store.selectedAsset?.relativePath ?? "Workspace")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if let asset = store.selectedAsset {
                    if asset.url.pathExtension.lowercased() == "md" {
                        detailActionButton("PDF", "doc.richtext") { store.exportMarkdownAsPDF(asset) }
                    }
                    detailActionButton("Open", "arrow.up.forward.app") { store.openAsset(asset) }
                    detailActionButton("Reveal", "finder") { NSWorkspace.shared.activateFileViewerSelecting([asset.url]) }
                    Menu {
                        SidebarAssetContextMenu(asset: asset)
                    } label: {
                        Label("Actions", systemImage: "ellipsis.circle")
                            .font(.system(size: 13))
                            .labelStyle(.iconOnly)
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 28, height: 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Color(nsColor: .controlBackgroundColor)
                    .shadow(color: .black.opacity(0.03), radius: 1, y: 1)
            )
            .overlay(Divider().opacity(0.6), alignment: .bottom)

            if let asset = store.selectedAsset {
                previewContent(for: asset)
            } else {
                TextEditor(text: $store.previewText)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
            }
        }
    }

    @ViewBuilder
    private func previewContent(for asset: ProjectAsset) -> some View {
        let ext = asset.url.pathExtension.lowercased()

        if asset.isTextPreviewable {
            let ext = asset.url.pathExtension.lowercased()
            if ext == "csv" {
                CSVTablePreview(asset: asset)
            } else if ext == "md" {
                MarkdownWebPreview(url: asset.url)
                    .id(asset.id)
            } else {
                TextEditor(text: $store.previewText)
                    .font(.system(size: 12, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor))
            }
        } else if asset.isImage {
            ScalableImageView(url: asset.url)
                .id(asset.id)  // Force refresh when switching images
        } else if isQuickLookPreviewable(ext) {
            QuickLookPreview(url: asset.url)
                .id(asset.id)
        } else {
            ArtifactOpenPreview(asset: asset)
        }
    }

    private func isQuickLookPreviewable(_ ext: String) -> Bool {
        ["pdf", "docx", "doc", "xlsx", "xls", "pptx", "ppt",
         "html", "rtf", "rtfd", "pages", "numbers", "key",
         "svg", "eps", "ai"].contains(ext)
    }

    private func detailActionButton(_ label: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(.primary.opacity(0.06), lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Scalable Image View

struct ScalableImageView: NSViewRepresentable {
    let url: URL
    typealias NSViewType = NSScrollView

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = CenteredScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.backgroundColor = NSColor.textBackgroundColor
        scrollView.allowsMagnification = true
        scrollView.minMagnification = 0.02
        scrollView.maxMagnification = 20.0

        let imageView = NSImageView()
        imageView.imageScaling = .scaleNone  // We manage sizing ourselves
        scrollView.documentView = imageView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let imageView = scrollView.documentView as? NSImageView,
              let image = NSImage(contentsOf: url) else { return }

        let loadedURL = context.coordinator.lastLoadedURL
        let needsReset = loadedURL != url

        imageView.image = image
        let imageSize = image.size
        imageView.frame = NSRect(origin: .zero, size: imageSize)

        if needsReset {
            context.coordinator.lastLoadedURL = url
            // Schedule fit after layout is complete
            DispatchQueue.main.async {
                fitImageToScrollView(imageView: imageView, scrollView: scrollView, imageSize: imageSize)
            }
        }
    }

    private func fitImageToScrollView(imageView: NSImageView, scrollView: NSScrollView, imageSize: NSSize) {
        let clipSize = scrollView.documentVisibleRect.size
        guard clipSize.width > 0, clipSize.height > 0, imageSize.width > 0, imageSize.height > 0 else { return }

        // Fit to visible area exactly
        let scaleX = clipSize.width / imageSize.width
        let scaleY = clipSize.height / imageSize.height
        let fitScale = min(scaleX, scaleY)

        // Apply magnification and center
        scrollView.magnification = fitScale
        scrollView.magnification = fitScale  // set twice to override default
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var lastLoadedURL: URL?
    }
}

// MARK: - Centered ScrollView

final class CenteredScrollView: NSScrollView {
    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        centerDocumentIfNeeded()
    }

    private func centerDocumentIfNeeded() {
        guard let docView = documentView else { return }
        let docSize = docView.frame.size
        let clipSize = documentVisibleRect.size
        let mag = magnification

        let scaledW = docSize.width * mag
        let scaledH = docSize.height * mag

        let offsetX = max(0, (clipSize.width - scaledW) / 2)
        let offsetY = max(0, (clipSize.height - scaledH) / 2)

        if offsetX > 0 || offsetY > 0 {
            docView.frame.origin = NSPoint(x: 0, y: 0)
            contentView.bounds.origin = NSPoint(x: -offsetX, y: -offsetY)
        }
    }
}

// MARK: - Markdown Preview

struct MarkdownWebPreview: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.allowsMagnification = true
        webView.setValue(false, forKey: "drawsBackground")
        load(url: url, into: webView)
        context.coordinator.loadedURL = url
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard context.coordinator.loadedURL != url else { return }
        load(url: url, into: nsView)
        context.coordinator.loadedURL = url
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func load(url: URL, into webView: WKWebView) {
        guard let markdown = try? String(contentsOf: url, encoding: .utf8) else { return }
        let html = MarkdownPDFExporter.html(markdown: markdown, title: url.deletingPathExtension().lastPathComponent)
        webView.loadHTMLString(html, baseURL: url.deletingLastPathComponent())
    }

    final class Coordinator {
        var loadedURL: URL?
    }
}

// MARK: - QuickLook Preview

struct QuickLookPreview: NSViewRepresentable {
    let url: URL
    typealias NSViewType = QLPreviewView

    func makeNSView(context: Context) -> QLPreviewView {
        let view = QLPreviewView()
        view.shouldCloseWithWindow = false
        view.autostarts = true
        return view
    }

    func updateNSView(_ nsView: QLPreviewView, context: Context) {
        nsView.previewItem = url as QLPreviewItem
    }
}

// MARK: - Artifact Preview

private struct ArtifactOpenPreview: View {
    @EnvironmentObject private var store: WorkbenchStore
    let asset: ProjectAsset

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: iconName)
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 80, height: 80)
                .background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            VStack(spacing: 4) {
                Text(asset.title).font(.system(size: 14, weight: .semibold)).lineLimit(2)
                Text(asset.relativePath).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(2)
            }.frame(maxWidth: 500)
            HStack(spacing: 10) {
                Button { store.openAsset(asset) } label: {
                    Label(openTitle, systemImage: "arrow.up.forward.app")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent).controlSize(.small)
                Button { NSWorkspace.shared.activateFileViewerSelecting([asset.url]) } label: {
                    Label("Reveal", systemImage: "finder")
                        .font(.system(size: 12, weight: .medium))
                }.controlSize(.small)
            }
            Text(helpText).font(.system(size: 11)).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).frame(maxWidth: 480)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).padding(32)
        .background(Color(nsColor: .textBackgroundColor))
    }

    private var iconName: String {
        switch asset.url.pathExtension.lowercased() {
        case "docx": return "doc.richtext"
        case "pdf": return "doc.text.magnifyingglass"
        default: return asset.category.symbolName
        }
    }
    private var openTitle: String {
        asset.url.pathExtension.lowercased() == "docx" ? "Open DOCX" : "Open"
    }
    private var helpText: String {
        asset.url.pathExtension.lowercased() == "docx"
            ? "DOCX reports open with your system default app."
            : "This file is indexed by AutoPMx and can be opened with the default macOS application."
    }
}

// MARK: - CSV Table Preview (Excel-style grid)

private struct CSVTablePreview: View {
    @EnvironmentObject private var store: WorkbenchStore
    let asset: ProjectAsset

    struct ParsedCSV {
        var headers: [String] = []
        var rows: [[String]] = []
    }

    @State private var parsed = ParsedCSV()
    @State private var hoveredRow = -1

    var body: some View {
        let colWidths = columnWidths
        VStack(spacing: 0) {
            headerBar
            ScrollView([.vertical, .horizontal]) {
                LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                    Section {
                        ForEach(Array(parsed.rows.prefix(200).enumerated()), id: \.offset) { ri, row in
                            HStack(spacing: 0) {
                                Text("\(ri + 1)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 42, alignment: .trailing)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(ri % 2 == 0 ? .clear : Color.blue.opacity(0.02))
                                ForEach(Array(row.prefix(colWidths.count).enumerated()), id: \.offset) { ci, val in
                                    Text(val)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.primary)
                                        .frame(width: colWidths[ci], alignment: val.first?.isNumber == true ? .trailing : .leading)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(ri % 2 == 0 ? .clear : Color.blue.opacity(0.02))
                                }
                            }
                            .background(hoveredRow == ri ? Color.blue.opacity(0.08) : .clear)
                            .onHover { h in hoveredRow = h ? ri : -1 }
                            Divider().opacity(0.25)
                        }
                    } header: {
                        HStack(spacing: 0) {
                            Text("#")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 42, alignment: .trailing)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 6)
                                .background(.regularMaterial)
                            ForEach(Array(parsed.headers.enumerated()), id: \.offset) { ci, h in
                                Text(h)
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: colWidths[ci], alignment: .leading)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                                    .background(.regularMaterial)
                            }
                        }
                        Divider()
                    }
                }
                if parsed.rows.count > 200 {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                        Text("\(parsed.rows.count - 200) more rows hidden")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 12)
                }
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
        .onAppear { parsed = parseCSV() }
    }

    private var columnWidths: [CGFloat] {
        guard !parsed.headers.isEmpty else { return [] }
        var widths: [CGFloat] = parsed.headers.map { h in
            max(70, min(CGFloat(h.count) * 7.5 + 28, 130))
        }
        for row in parsed.rows.prefix(80) {
            for i in 0..<min(row.count, widths.count) {
                let cw = CGFloat(row[i].count) * 7.5 + 28
                widths[i] = max(widths[i], min(cw, 130))
            }
        }
        return widths
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "tablecells")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text("\(parsed.rows.count.formatted()) rows x \(parsed.headers.count) cols")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(asset.title)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .overlay(Divider().opacity(0.5), alignment: .bottom)
    }

    private func parseCSV() -> ParsedCSV {
        guard let raw = try? String(contentsOf: asset.url, encoding: .utf8) else {
            return ParsedCSV(headers: ["Error"], rows: [["Could not read file"]])
        }
        let lines = raw.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard let first = lines.first else { return ParsedCSV() }
        let headers = first.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let rows = lines.dropFirst().map { parseLine($0) }
        return ParsedCSV(headers: headers, rows: Array(rows))
    }

    private func parseLine(_ line: String) -> [String] {
        var vals: [String] = []
        var cur = ""; var q = false
        for ch in line {
            if ch == "\"" { q.toggle() }
            else if ch == "," && !q { vals.append(cur.trimmingCharacters(in: .whitespaces)); cur = "" }
            else { cur.append(ch) }
        }
        vals.append(cur.trimmingCharacters(in: .whitespaces))
        return vals
    }
}
