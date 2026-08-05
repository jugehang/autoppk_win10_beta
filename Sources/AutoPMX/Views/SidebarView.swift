import SwiftUI

// MARK: - Sidebar

struct SidebarView: View {
    @EnvironmentObject private var store: WorkbenchStore
    @State private var expandedCategories = Set<AssetCategory>()

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
            if asset.category == .models, let markColor = store.modelMarkColor(for: asset) {
                Circle()
                    .fill(markColor)
                    .frame(width: 8, height: 8)
            }

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(asset.title)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                    if asset.category == .models,
                       let runID = asset.relatedRunID,
                       store.isAIRun(runID) {
                        Text("AI")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                in: Capsule()
                            )
                            .help("AI recommended model")
                    }
                    if asset.category == .data,
                       asset.url.pathExtension.lowercased() == "csv",
                       store.dataFile == asset.title {
                        Text(L10n.sidebarDataset)
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.blue)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 3))
                    }
                }
                if asset.relativePath != asset.title {
                    Text(asset.relativePath)
                        .font(.system(size: 10))
                        .foregroundStyle(isHovered ? .secondary : .tertiary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 4)

            if store.isPinned(asset) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.blue.opacity(0.5))
            }
        }
        .padding(.vertical, 8)
        .padding(.leading, 6)
        .padding(.trailing, 4)
        .frame(minHeight: 34)
        .contentShape(Rectangle())
        .liquidGlassHover(cornerRadius: 5)
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
            Menu {
                ForEach(WorkbenchStore.modelMarkPalette, id: \.name) { entry in
                    Button {
                        store.setModelMark(entry.name, for: asset)
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(entry.color)
                                .frame(width: 10, height: 10)
                            Text(entry.label)
                            if store.modelMarkName(for: asset) == entry.name {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                        }
                    }
                }
                if store.modelMarkName(for: asset) != nil {
                    Divider()
                    Button {
                        store.setModelMark(nil, for: asset)
                    } label: {
                        Label(L10n.markClear, systemImage: "xmark.circle")
                    }
                }
            } label: {
                Label(L10n.markTitle, systemImage: "tag")
            }

            Divider()

            Button {
                store.activateRun(withModFileName: asset.title)
                store.runCurrentModel()
            } label: {
                Label("Run NONMEM via PsN", systemImage: "play.fill")
            }

            Button {
                store.duplicateModelAsChild(runID: runID)
            } label: {
                Label("Duplicate as Child Model", systemImage: "doc.on.doc")
            }

            Menu {
                let copyTargets = store.recentProjectURLs.filter {
                    $0.standardizedFileURL != store.projectURL.standardizedFileURL
                }
                if copyTargets.isEmpty {
                    Text("No recent projects")
                } else {
                    ForEach(copyTargets, id: \.self) { target in
                        Button {
                            store.copyModel(asset: asset, toProject: target, openAfterCopy: true)
                        } label: {
                            Text(target.lastPathComponent)
                        }
                    }
                }
                Divider()
                Button {
                    store.chooseCopyTargetAndCopyModel(asset: asset)
                } label: {
                    Label("Choose Folder...", systemImage: "folder")
                }
            } label: {
                Label("Copy Model to Project...", systemImage: "doc.on.doc.fill")
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
            Button {
                store.runETACovariateScreening(for: runID)
            } label: {
                Label(L10n.quickETAScreen, systemImage: "chart.bar.doc.horizontal")
            }

            Divider()

            Button {
                store.analyzeFinalModel(runID: runID)
            } label: {
                Label("Final Model Analysis", systemImage: "doc.text.magnifyingglass")
            }

            Button {
                store.presentBootstrapSheet(for: runID)
            } label: {
                Label("Bootstrap", systemImage: "repeat")
            }
            Button {
                store.presentSCMDialog(runID: runID)
            } label: {
                Label("SCM", systemImage: "point.3.connected.trianglepath.dotted")
            }

            Divider()

            Button {
                store.evaluateModelWithAI(runID)
            } label: {
                Label("AI Evaluate This Model", systemImage: "sparkles")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.15, green: 0.45, blue: 0.95), Color(red: 0.35, green: 0.65, blue: 1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            Divider()
        } else if asset.category == .data, asset.url.pathExtension.lowercased() == "csv" {
            let isCurrent = store.dataFile == asset.title
            Button {
                store.switchDataFile(asset.title)
                store.refreshChecks()
            } label: {
                Label(isCurrent ? "✓ Modeling Dataset" : "Set as Modeling Dataset", systemImage: isCurrent ? "checkmark.circle.fill" : "tablecells")
            }

            Divider()

            Button {
                store.runEDA(dataFile: asset.title)
            } label: {
                Label("EDA Analysis", systemImage: "chart.bar")
            }

            Button {
                store.runCTCurves(dataFile: asset.title)
            } label: {
                Label("C-T Curves", systemImage: "chart.xyaxis.line")
            }

            Divider()
        } else if isInterpretableResult {
            Button {
                store.interpretAssetWithAI(asset)
            } label: {
                Label(aiInterpretTitle, systemImage: "sparkles")
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.15, green: 0.45, blue: 0.95), Color(red: 0.35, green: 0.65, blue: 1.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
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
