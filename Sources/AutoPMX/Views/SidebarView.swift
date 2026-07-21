import SwiftUI

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject private var store: WorkbenchStore
    @State private var expandedCategories = Set(AssetCategory.allCases)

    var body: some View {
        List(selection: Binding(
            get: { store.selectedAsset?.id },
            set: { id in
                guard let id, let asset = store.asset(withID: id) else { return }
                store.select(asset)
            }
        )) {
            Section {
                ForEach(AssetCategory.allCases) { category in
                    DisclosureGroup(isExpanded: expandedBinding(for: category)) {
                        ForEach(store.sidebarAssets(for: category)) { asset in
                            SidebarAssetRow(asset: asset)
                                .tag(asset.id)
                        }
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    } label: {
                        HStack(spacing: 7) {
                            Image(systemName: category.symbolName)
                                .font(.system(size: 12, weight: .medium))
                                .frame(width: 18)
                                .foregroundStyle(.blue.opacity(0.7))
                            Text(category.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.primary)
                            Spacer(minLength: 4)
                            Text("\(store.sidebarAssets(for: category).count)")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.blue.opacity(0.6))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.blue.opacity(0.08), in: Capsule())
                        }
                        .contentShape(Rectangle())
                    }
                }
            } header: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "sidebar.left")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text("Project Explorer")
                            .font(.system(size: 12, weight: .bold))
                    }
                    Text("Models, diagnostics, reports")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                        .padding(.leading, 18)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .background(sidebarBackground)
        .animation(.easeInOut(duration: 0.2), value: store.sidebarAssets(for: .models).count)
    }

    @ViewBuilder
    private var sidebarBackground: some View {
        Color(nsColor: .controlBackgroundColor)
            .overlay(
                LinearGradient(
                    colors: [Color.blue.opacity(0.03), Color.blue.opacity(0.01)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    private func expandedBinding(for category: AssetCategory) -> Binding<Bool> {
        Binding {
            expandedCategories.contains(category)
        } set: { isExpanded in
            if isExpanded {
                expandedCategories.insert(category)
            } else {
                expandedCategories.remove(category)
            }
        }
    }
}

// MARK: - Row

struct SidebarAssetRow: View {
    @EnvironmentObject private var store: WorkbenchStore
    let asset: ProjectAsset
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: asset.category.symbolName)
                .font(.system(size: 11))
                .foregroundStyle(isHovered ? Color.blue.opacity(0.6) : Color.secondary.opacity(0.6))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(asset.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    if asset.category == .data,
                       asset.url.pathExtension.lowercased() == "csv",
                       store.dataFile == asset.title {
                        Text("Dataset")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 3))
                    }
                }
                Text(asset.relativePath)
                    .font(.system(size: 10))
                    .foregroundStyle(isHovered ? .secondary : .tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if store.isPinned(asset) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.blue.opacity(0.5))
            }
        }
        .padding(.vertical, 3)
        .padding(.leading, 4)
        .padding(.trailing, 2)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .contextMenu {
            SidebarAssetContextMenu(asset: asset)
        }
    }
}

// MARK: - Context Menu

struct SidebarAssetContextMenu: View {
    @EnvironmentObject private var store: WorkbenchStore
    let asset: ProjectAsset

    var body: some View {
        if asset.category == .models, let runID = asset.relatedRunID {
            Button {
                store.activateRun(withModFileName: asset.title)
                store.runCurrentModel()
            } label: {
                Label("Run NONMEM via PsN", systemImage: "play.fill")
            }

            Divider()

            Button {
                store.activateRun(runID)
                store.runGAOptimization()
            } label: {
                Label("🧬 GA Optimize", systemImage: "cpu")
            }

            Button {
                store.activateRun(runID)
                store.runGAStructuralOptimization()
            } label: {
                Label("🧬 GA Structure Search", systemImage: "cpu.fill")
            }

            Divider()

            Button {
                store.runGOF(for: runID)
            } label: {
                Label("Run GOF", systemImage: "chart.xyaxis.line")
            }
            Button {
                store.runPsNVPC(for: runID)
            } label: {
                Label("Run VPC", systemImage: "chart.line.uptrend.xyaxis")
            }
            Button {
                store.runIndividualDVTime(for: runID)
            } label: {
                Label("Run Individual DV-Time", systemImage: "person.text.rectangle")
            }
            Button {
                store.runFullDiagnosticSuite(for: runID)
            } label: {
                Label("Run All Diagnostics", systemImage: "checklist.checked")
            }
            Button {
                store.runPKParameterExtraction(for: runID)
            } label: {
                Label("Extract PK Parameters", systemImage: "tablecells")
            }

            Divider()

            Button {
                store.runBootstrap(for: runID)
            } label: {
                Label("Bootstrap", systemImage: "repeat")
            }
            Button {
                store.runSCM(for: runID)
            } label: {
                Label("SCM", systemImage: "point.3.connected.trianglepath.dotted")
            }

            Divider()

            Button {
                store.evaluateModelWithAI(runID)
            } label: {
                Label("AI Evaluate This Model", systemImage: "sparkles")
            }

            Divider()
        } else if asset.category == .data, asset.url.pathExtension.lowercased() == "csv" {
            let isCurrent = store.dataFile == asset.title
            Button {
                store.dataFile = asset.title
                store.refreshChecks()
            } label: {
                Label(isCurrent ? "✓ Modeling Dataset" : "Set as Modeling Dataset", systemImage: isCurrent ? "checkmark.circle.fill" : "tablecells")
            }

            Divider()
        } else if isInterpretableResult {
            Button {
                store.interpretAssetWithAI(asset)
            } label: {
                Label(aiInterpretTitle, systemImage: "sparkles")
            }

            Divider()
        }

        Button {
            store.openAsset(asset)
        } label: {
            Label("Open", systemImage: "arrow.up.forward.app")
        }

        Button {
            store.togglePinned(asset)
        } label: {
            Label(store.isPinned(asset) ? "Unpin" : "Pin to Top", systemImage: store.isPinned(asset) ? "pin.slash" : "pin")
        }

        Button {
            NSWorkspace.shared.activateFileViewerSelecting([asset.url])
        } label: {
            Label("Reveal in Finder", systemImage: "finder")
        }

        Button(role: .destructive) {
            store.requestDelete(asset)
        } label: {
            Label("Move to Trash", systemImage: "trash")
        }
    }

    private var isInterpretableResult: Bool {
        [.outputs, .figures, .reports].contains(asset.category) && asset.relatedRunID != nil
    }

    private var aiInterpretTitle: String {
        let lower = asset.relativePath.lowercased()
        if lower.contains("gof") { return "AI Interpret GOF" }
        if lower.contains("vpc") { return "AI Interpret VPC" }
        if ["lst", "ext", "cov"].contains(asset.url.pathExtension.lowercased()) { return "AI Interpret NONMEM Output" }
        return "AI Interpret Result"
    }
}
