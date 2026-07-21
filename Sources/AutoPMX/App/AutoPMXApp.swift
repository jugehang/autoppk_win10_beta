import SwiftUI
import AppKit

@main
struct AutoPMXApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = WorkbenchStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .frame(minWidth: 1180, minHeight: 760)
                .onAppear {
                    NSApp.activate(ignoringOtherApps: true)
                }
        }
        .commands {
            // File menu additions
            CommandGroup(after: .newItem) {
                Button("Refresh Workspace") {
                    store.refreshWorkspace()
                }
                .keyboardShortcut("r", modifiers: [.command])

                Button("Run Current Model") {
                    store.runCurrentModel()
                }
                .keyboardShortcut(.return, modifiers: [.command])

                Divider()

                Menu("Open Recent Project") {
                    ForEach(store.recentProjectURLs, id: \.path) { url in
                        Button(url.lastPathComponent) {
                            store.openProject(url: url)
                        }
                    }
                    if store.recentProjectURLs.isEmpty {
                        Text("No recent projects").foregroundStyle(.secondary)
                    }
                }
            }

            // Help menu
            CommandGroup(replacing: .help) {
                Button("AutoPMX Help") {
                    if let helpURL = Bundle.main.url(forResource: "Help", withExtension: "html") {
                        NSWorkspace.shared.open(helpURL)
                    }
                }
            }

            // App menu (About)
            CommandGroup(replacing: .appInfo) {
                Button("About AutoPMX") {
                    AboutWindowController.show()
                }
            }
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - About Window

final class AboutWindowController: NSObject {
    private static var window: NSWindow?

    static func show() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let aboutWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 480),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        aboutWindow.title = "About AutoPMX"
        aboutWindow.titlebarAppearsTransparent = true
        aboutWindow.titleVisibility = .hidden
        aboutWindow.isMovableByWindowBackground = true
        aboutWindow.isReleasedWhenClosed = false
        aboutWindow.delegate = AboutWindowDelegate.shared
        aboutWindow.center()
        aboutWindow.contentView = NSHostingView(rootView: AboutView())
        aboutWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        window = aboutWindow
    }
}

final class AboutWindowDelegate: NSObject, NSWindowDelegate {
    static let shared = AboutWindowDelegate()

    func windowWillClose(_ notification: Notification) {
        AboutWindowController.releaseWindow()
    }
}

extension AboutWindowController {
    fileprivate static func releaseWindow() {
        window?.delegate = nil
        window?.contentView = nil
        window = nil
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // App icon
            if let icon = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: icon)
                    .resizable().scaledToFit()
                    .frame(width: 80, height: 80)
                    .shadow(color: .blue.opacity(0.12), radius: 12, y: 4)
            }

            Spacer().frame(height: 16)

            Text("AutoPMX")
                .font(.system(size: 24, weight: .bold, design: .rounded))
            Text("DuDu PMx Workbench")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            Spacer().frame(height: 8)

            Text("Version 1.1.0 (Build 2)")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer().frame(height: 24)

            // Description
            VStack(alignment: .leading, spacing: 8) {
                featureLine("🧬", "NONMEM & PsN execution with real-time terminal")
                featureLine("🤖", "AI-driven automated PopPK model building (DuDu Auto)")
                featureLine("🧠", "Genetic algorithm for parameter & structural optimization")
                featureLine("📊", "Integrated GOF, VPC, individual plot diagnostics")
                featureLine("🌐", "Multi-LLM: MLX, LM Studio, Ollama, OpenAI, Gemini")
                featureLine("🎨", "Liquid-glass design with dark mode support")
            }

            Spacer().frame(height: 20)

            Text("Built for pharmacometricians, by pharmacometricians.")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)

            Spacer().frame(height: 24)

            Divider()
                .frame(width: 160)
                .overlay(.quaternary)

            Spacer().frame(height: 14)

            VStack(spacing: 4) {
                Text("Graham Ju")
                    .font(.system(size: 13, weight: .medium))
                Text("Changsha Duxact Biotechnology Co., Ltd.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer().frame(height: 10)

            Text("© 2025–2026 Graham Ju. All rights reserved.")
                .font(.system(size: 10))
                .foregroundStyle(.quaternary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }

    private func featureLine(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Text(icon)
                .font(.system(size: 11))
                .frame(width: 20)
            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(.primary.opacity(0.85))
        }
    }
}
