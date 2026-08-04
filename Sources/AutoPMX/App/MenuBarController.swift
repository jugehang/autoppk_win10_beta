import AppKit
import SwiftUI

/// Manages the macOS menu bar (NSStatusItem) — icon in the top-right, dropdown
/// menu with quick stats (context, tokens, active model), System Stats submenu
/// (CPU / GPU / Memory), and shortcuts (Chat, Settings, About, Quit).
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    static let shared = MenuBarController()

    private var statusItem: NSStatusItem?
    private var workbenchStore: WorkbenchStore?

    // Menu items that need live refresh — kept as references so we don't
    // walk the whole menu tree every tick.
    private struct LiveItem {
        let identifier: String
        let resolve: @MainActor () -> (text: String, imageName: String?)
    }
    private var liveItems: [(NSMenuItem, LiveItem)] = []
    private var liveSubmenus: [(NSMenu, [LiveItem])] = []
    private var headerItem: NSMenuItem?
    private var rootMenu: NSMenu?

    private override init() {
        super.init()
    }

    /// Install the status item and start refreshing stats. Safe to call once.
    func attach(to store: WorkbenchStore) {
        workbenchStore = store
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = appIconImage()
        item.button?.toolTip = "AutoPMx (DuDu PMx)"
        item.button?.imageScaling = .scaleProportionallyDown

        statusItem = item

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false
        rootMenu = menu

        rebuildMenu(menu)

        item.menu = menu

    }

    func detach() {
        statusItem?.menu = nil
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
    }

    // MARK: - NSMenuDelegate

    func menuNeedsUpdate(_ menu: NSMenu) {
        MemoryMonitor.shared.refresh()
        refreshLiveItems()
    }

    // MARK: - Menu construction

    private func rebuildMenu(_ menu: NSMenu) {
        menu.removeAllItems()
        liveItems.removeAll()
        liveSubmenus.removeAll()

        // ── Status header (green, shows active state) ──
        let header = makeItem(
            text: "AutoPMx — DuDu PMx",
            image: "pills.circle.fill",
            color: .systemGreen
        )
        header.action = nil
        header.isEnabled = false  // disabled items render with the colored title
        menu.addItem(header)
        headerItem = header

        menu.addItem(.separator())

        // ── Model status submenu ──
        let modelStatusSubmenu = NSMenu(title: "Model Status")
        modelStatusSubmenu.autoenablesItems = false
        registerLive(in: modelStatusSubmenu) { ctx in [
            ctx.statusItem(text: "Context Window", image: "chart.pie.fill", live: true),
            ctx.statusItem(text: "Tokens", image: "number.circle.fill", live: true),
            ctx.statusItem(text: "Active Model", image: "cpu.fill", live: true),
            ctx.statusItem(text: "Local LLM", image: "memorychip", live: true)
        ] }
        let modelStatus = makeItem(text: "Model Status", image: "gauge.with.needle.fill", color: .labelColor)
        modelStatus.submenu = modelStatusSubmenu
        menu.addItem(modelStatus)

        // ── System Stats submenu ──
        let systemSubmenu = NSMenu(title: "System Stats")
        systemSubmenu.autoenablesItems = false
        registerLive(in: systemSubmenu) { ctx in [
            ctx.statusItem(text: "CPU", image: "cpu", live: true),
            ctx.statusItem(text: "GPU", image: "display", live: true),
            ctx.statusItem(text: "Memory", image: "memorychip", live: true)
        ] }
        let sysStats = makeItem(text: "System Stats", image: "chart.bar.xaxis", color: .labelColor)
        sysStats.submenu = systemSubmenu
        menu.addItem(sysStats)

        menu.addItem(.separator())

        // ── Quick actions ──
        let chat = makeActionItem(text: "Chat with DuDu…", image: "bubble.left.and.bubble.right.fill", color: .labelColor)
        chat.target = self
        chat.action = #selector(openChat)
        chat.keyEquivalent = "d"
        chat.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(chat)

        let settings = makeActionItem(text: "Settings…", image: "gearshape.fill", color: .labelColor)
        settings.target = self
        settings.action = #selector(openSettings)
        settings.keyEquivalent = ","
        menu.addItem(settings)

        let tokensPanel = makeActionItem(text: "Open Tokens Panel", image: "chart.bar.xaxis", color: .labelColor)
        tokensPanel.target = self
        tokensPanel.action = #selector(openTokens)
        tokensPanel.keyEquivalent = "t"
        tokensPanel.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(tokensPanel)

        menu.addItem(.separator())

        // ── Footer ──
        let about = makeActionItem(text: "About AutoPMx", image: "info.circle.fill", color: .labelColor)
        about.target = self
        about.action = #selector(openAbout)
        menu.addItem(about)

        let quit = makeActionItem(text: "Quit AutoPMx", image: "power.circle.fill", color: .labelColor)
        quit.target = self
        quit.action = #selector(quitApp)
        quit.keyEquivalent = "q"
        menu.addItem(quit)
    }

    // MARK: - Live text providers

    private struct ResolveCtx {
        let store: WorkbenchStore?
        let mem: MemoryMonitor

        func statusItem(text: String, image: String, live: Bool) -> MenuBarController.LiveItem {
            // `live` is a hint for the caller; the closure is rebuilt every tick.
            switch text {
            case "Context Window":
                return .init(identifier: "ctx", resolve: {
                    guard let store = self.store else { return ("Context Window: —", image) }
                    let used = max(store.lastTokenUsage.input, store.contextTokenEstimate)
                    let limit = store.contextWindowLimitTokens
                    let pct = limit > 0 ? Int(Double(used) / Double(limit) * 100) : 0
                    return ("Context Window: \(pct)%  (\(used) / \(limit) tok)", image)
                })
            case "Tokens":
                return .init(identifier: "tokens", resolve: {
                    guard let store = self.store else { return ("Tokens: —", image) }
                    let req = store.providerUsageRecords.reduce(0) { $0 + $1.requests }
                    return ("Tokens: in \(store.totalInputTokens) · out \(store.totalOutputTokens) · req \(req)", image)
                })
            case "Active Model":
                return .init(identifier: "model", resolve: {
                    guard let store = self.store else { return ("Active Model: —", image) }
                    let provider = store.activeProvider?.name ?? "Unknown"
                    let model = store.activeProvider?.model ?? store.llmModel
                    return ("Active Model: \(provider) · \(model)", image)
                })
            case "Local LLM":
                return .init(identifier: "llmmem", resolve: {
                    if self.mem.llmProcessName.isEmpty {
                        return ("Local LLM: not running", image)
                    }
                    return ("Local LLM: \(self.mem.llmProcessName) · \(self.mem.formatBytes(self.mem.llmProcessBytes))", image)
                })
            case "CPU":
                return .init(identifier: "cpu", resolve: {
                    (String(format: "CPU: %.0f%%", self.mem.cpuUsageRatio * 100), image)
                })
            case "GPU":
                return .init(identifier: "gpu", resolve: {
                    if self.mem.gpuDeviceName.isEmpty {
                        return ("GPU: unavailable", image)
                    }
                    let vram = self.mem.formatBytes(self.mem.gpuVramBytes)
                    return ("GPU: \(self.mem.gpuDeviceName) · \(vram)", image)
                })
            case "Memory":
                return .init(identifier: "mem", resolve: {
                    let pct = Int(self.mem.snapshot.usageRatio * 100)
                    let used = self.mem.formatBytes(self.mem.snapshot.usedBytes)
                    let total = self.mem.formatBytes(self.mem.snapshot.totalBytes)
                    return ("Memory: \(pct)%  (\(used) / \(total))", image)
                })
            default:
                return .init(identifier: text.lowercased(), resolve: { (text, image) })
            }
        }
    }

    private func registerLive(in submenu: NSMenu, factory: (ResolveCtx) -> [LiveItem]) {
        let ctx = ResolveCtx(store: workbenchStore, mem: MemoryMonitor.shared)
        let items = factory(ctx)
        var pairs: [(NSMenuItem, LiveItem)] = []
        for live in items {
            let item = makeItem(text: live.resolve().text, image: live.resolve().imageName ?? "", color: .secondaryLabelColor)
            item.isEnabled = false  // show info, not clickable
            submenu.addItem(item)
            pairs.append((item, live))
        }
        liveSubmenus.append((submenu, items))
    }

    // MARK: - Refresh

    private func refreshLiveItems() {
        // Refresh submenu items in place
        for (submenu, items) in liveSubmenus {
            // The items list here is a snapshot; the submenu's own items may differ
            // if user navigated menus. Use identifier-based lookup.
            for live in items {
                let resolved = live.resolve()
                for subItem in submenu.items {
                    // Match by index (factory built in same order).
                    if subItem.title.hasPrefix(prefixForIdentifier(live.identifier)) {
                        subItem.title = resolved.text
                        break
                    }
                }
            }
        }
        // Update header status
        if let header = headerItem {
            let title: String
            if let store = workbenchStore, store.activeProvider != nil {
                title = "●  AutoPMx — running"
            } else {
                title = "○  AutoPMx — idle"
            }
            header.attributedTitle = NSAttributedString(
                string: title,
                attributes: [
                    .foregroundColor: NSColor.systemGreen,
                    .font: NSFont.systemFont(ofSize: 12, weight: .semibold)
                ]
            )
        }
    }

    private func prefixForIdentifier(_ id: String) -> String {
        switch id {
        case "ctx": return "Context Window:"
        case "tokens": return "Tokens:"
        case "model": return "Active Model:"
        case "llmmem": return "Local LLM:"
        case "cpu": return "CPU:"
        case "gpu": return "GPU:"
        case "mem": return "Memory:"
        default: return ""
        }
    }

    // MARK: - Actions

    @objc private func openChat() {
        NSApp.activate(ignoringOtherApps: true)
        // If the main window was "closed" (hidden by our interceptor), bring it back.
        if let main = MainWindowKeeper.shared.window {
            main.makeKeyAndOrderFront(nil)
        } else {
            // Fallback: search any known window.
            for window in NSApp.windows where window.canBecomeMain || window.isVisible {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    @objc private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func openTokens() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NotificationCenter.default.post(name: .init("AutoPMXOpenTokensPane"), object: nil)
    }

    @objc private func openAbout() {
        NSApp.activate(ignoringOtherApps: true)
        AboutWindowController.show()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Menu item helpers

    private func makeItem(text: String, image: String?, color: NSColor) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        if let imageName = image {
            let img = NSImage(systemSymbolName: imageName, accessibilityDescription: text)
            img?.isTemplate = true
            item.image = img
        }
        return item
    }

    private func makeActionItem(text: String, image: String, color: NSColor) -> NSMenuItem {
        let item = NSMenuItem(title: text, action: nil, keyEquivalent: "")
        let img = NSImage(systemSymbolName: image, accessibilityDescription: text)
        img?.isTemplate = true
        item.image = img
        return item
    }

    // MARK: - App icon

    private func appIconImage() -> NSImage? {
        if let icon = NSImage(named: NSImage.applicationIconName) {
            icon.size = NSSize(width: 22, height: 22)
            icon.isTemplate = false
            return icon
        }
        if let path = Bundle.main.path(forResource: "AutoPMX", ofType: "icns"),
           let img = NSImage(contentsOfFile: path) {
            img.size = NSSize(width: 22, height: 22)
            return img
        }
        return NSImage(systemSymbolName: "pills.circle.fill", accessibilityDescription: "AutoPMx")
    }
}
