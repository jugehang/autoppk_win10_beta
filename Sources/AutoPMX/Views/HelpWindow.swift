import SwiftUI
import AppKit
import WebKit

// MARK: - Help Window

final class HelpWindowController: NSObject {
    private static var window: NSWindow?

    static func show(store: WorkbenchStore) {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let helpWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        helpWindow.title = "AutoPMx Help"
        helpWindow.titlebarAppearsTransparent = false
        helpWindow.titleVisibility = .visible
        helpWindow.isMovableByWindowBackground = true
        helpWindow.isReleasedWhenClosed = false
        helpWindow.delegate = HelpWindowDelegate.shared
        helpWindow.center()
        helpWindow.contentView = NSHostingView(rootView: HelpView().environmentObject(store))
        helpWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = helpWindow
    }
}

final class HelpWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = HelpWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        HelpWindowController.releaseWindow()
    }
}

extension HelpWindowController {
    fileprivate static func releaseWindow() {
        window = nil
    }
}

// MARK: - Help View

struct HelpView: View {
    @EnvironmentObject private var store: WorkbenchStore

    private let suggestions: [String] = [L10n.helpQ1, L10n.helpQ2, L10n.helpQ3]

    var body: some View {
        ZStack(alignment: .bottom) {
            HelpWebView()

            liquidGlassToolbar
        }
        .frame(minWidth: 760, minHeight: 560)
    }

    /// Floating liquid-glass toolbar: lets users ask DuDu about the Help content.
    private var liquidGlassToolbar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Group {
                    if let img = duDuThumb {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(colors: [Color(red: 0.45, green: 0.68, blue: 1.0),
                                                        Color(red: 0.70, green: 0.35, blue: 1.0)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                    }
                }
                .frame(width: 26, height: 26)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1))
                Text(L10n.helpAskDuDuTitle)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Spacer()
                Button {
                    store.askDuDuAboutHelp(nil)
                } label: {
                    Label(L10n.helpAskDuDuCta, systemImage: "sparkles")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).padding(.vertical, 5)
                        .background(
                            Capsule().fill(
                                LinearGradient(colors: [Color(red: 0.20, green: 0.50, blue: 1.0), Color.cyan.opacity(0.9)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        )
                        .shadow(color: .blue.opacity(0.3), radius: 3, y: 1)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 6) {
                ForEach(suggestions, id: \.self) { question in
                    Button {
                        store.askDuDuAboutHelp(question)
                    } label: {
                        Text(question)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(.white.opacity(0.16), in: Capsule())
                            .overlay(Capsule().strokeBorder(.white.opacity(0.25), lineWidth: 0.8))
                    }
                    .buttonStyle(.plain)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                )
                .overlay(
                    LinearGradient(colors: [.white.opacity(0.22), .clear],
                                   startPoint: .top, endPoint: .center)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.14), radius: 12, y: 4)
        )
        .padding(16)
    }

    private var duDuThumb: NSImage? {
        let candidates = [
            BundledResource.url(forResource: "DuDuPMxButton", withExtension: "png"),
            BundledResource.url(forResource: "DuDuPMxSource", withExtension: "png")
        ]
        for url in candidates {
            if let url, let img = NSImage(contentsOf: url) { return img }
        }
        return nil
    }
}

// MARK: - Help Web View (WKWebView)

struct HelpWebView: NSViewRepresentable {
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.allowsMagnification = true
        if let helpURL = BundledResource.url(forResource: "Help", withExtension: "html") {
            webView.loadFileURL(helpURL, allowingReadAccessTo: helpURL.deletingLastPathComponent())
        }
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}
