import SwiftUI

// MARK: - Inspector View

struct InspectorView: View {
    @EnvironmentObject private var store: WorkbenchStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                InspectorSection("Run Configuration") {
                    Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                        FormRow("Previous", text: $store.previousRun)
                        FormRow("Current", text: $store.currentRun)
                        FormRow("Data", text: $store.dataFile)
                    }
                }

                InspectorSection("PsN Command") {
                    TextEditor(text: $store.commandText)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(height: 64)
                        .scrollContentBackground(.hidden)
                        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(.quaternary.opacity(0.5), lineWidth: 0.5)
                        )

                    HStack(spacing: 4) {
                        InspectorPill("Suggest") {
                            store.commandText = ProjectScanner.psnExecuteCommand(runID: store.currentRun)
                            store.refreshChecks()
                        }

                        Spacer()

                        InspectorPill("Run", emphasis: true) {
                            store.runCurrentModel()
                        }
                    }
                }

                // Convergence status (Pirana-style: minimization / covariance / boundary)
                if !store.convergenceSummary.isEmpty {
                    InspectorSection("Convergence (S/C Check)") {
                        HStack(spacing: 8) {
                            ConvergenceBadge(label: "Minimization", ok: store.minimizationOK)
                            ConvergenceBadge(label: "Covariance", ok: store.covarianceOK)
                            ConvergenceBadge(label: "Boundary", ok: !store.hasBoundaryWarnings)
                        }
                    }
                }

                InspectorSection("Checks") {
                    VStack(spacing: 6) {
                        CheckRow(title: "Model Files", text: store.modelStatus, icon: "doc.text.magnifyingglass")
                        CheckRow(title: "Data Path", text: store.dataStatus, icon: "link")
                        CheckRow(title: "PsN", text: store.executeStatus, icon: "terminal")
                    }
                }

                InspectorSection("Parameter Estimates") {
                    ParameterEstimatesTable(runID: store.parameterRunID, rows: store.parameterRows)

                    Divider().opacity(0.5).padding(.vertical, 4)

                    // GA Optimize button
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            InspectorPill("🧬 GA Optimize") {
                                store.runGAOptimization()
                            }
                            .disabled(store.isRunningGA)
                            if store.isRunningGA {
                                ProgressView().controlSize(.small).scaleEffect(0.6)
                            }
                            Spacer()
                        }
                        Text(store.gaStatus.isEmpty
                             ? "Use genetic algorithm to find better THETA initial estimates."
                             : store.gaStatus)
                            .font(.system(size: 10))
                            .foregroundStyle(store.gaStatus.contains("✅") ? .green : .secondary)
                            .lineLimit(2)
                        if let result = store.gaResultText {
                            Text(result)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(6)
                                .padding(6)
                                .background(.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }

                    Divider().opacity(0.5).padding(.vertical, 4)

                    // GA Structural Search button
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 4) {
                            InspectorPill("🧬 GA Structure") {
                                store.runGAStructuralOptimization()
                            }
                            .disabled(store.isRunningStructuralGA)
                            if store.isRunningStructuralGA {
                                ProgressView().controlSize(.small).scaleEffect(0.6)
                            }
                            Spacer()
                        }
                        Text(store.structuralGAStatus.isEmpty
                             ? "Search model structure (compartments, error model, IIV, covariates) + optimize THETA."
                             : store.structuralGAStatus)
                            .font(.system(size: 10))
                            .foregroundStyle(store.structuralGAStatus.contains("✅") ? .green : .secondary)
                            .lineLimit(2)
                        if let result = store.structuralGAResultText {
                            Text(result)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(6)
                                .padding(6)
                                .background(.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }

                InspectorSection("LLM Provider") {
                    VStack(spacing: 6) {
                        if let provider = store.activeProvider {
                            HStack(spacing: 6) {
                                Image(systemName: provider.symbolName)
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                                Text(provider.name)
                                    .font(.system(size: 11, weight: .semibold))
                                Text("·")
                                    .foregroundStyle(.tertiary)
                                Text(provider.model.isEmpty ? "No model" : provider.model)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        HStack(spacing: 4) {
                            InspectorPill("Test Connection") { store.testLLMConnection() }
                                .disabled(store.isTestingLLM)
                            if store.isTestingLLM {
                                ProgressView().controlSize(.small).scaleEffect(0.6)
                            }
                        }
                        Text(store.llmStatus)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                }
            }
            .padding(12)
        }
        .background(
            Color(nsColor: .controlBackgroundColor)
                .overlay(
                    LinearGradient(
                        colors: [.blue.opacity(0.02), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

// MARK: - Inspector Pill

struct InspectorPill: View {
    let title: String
    let emphasis: Bool
    let action: () -> Void

    init(_ title: String, emphasis: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.emphasis = emphasis
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 8)
                .frame(height: 22)
                .foregroundStyle(emphasis ? .white : .primary)
                .background(
                    emphasis
                        ? Color.accentColor.opacity(0.85)
                        : Color.primary.opacity(0.04),
                    in: RoundedRectangle(cornerRadius: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.white.opacity(0.08), lineWidth: emphasis ? 1 : 0.5)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .help(title)
    }
}

// MARK: - Check Row

struct CheckRow: View {
    let title: String
    let text: String
    let icon: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                Text(text)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Parameter Estimates

struct ParameterEstimatesTable: View {
    let runID: String
    let rows: [ParameterEstimateRow]

    private var hasAnyShrinkage: Bool {
        rows.contains { row in
            if row.group == "Residual", let s = row.shrinkage { return s.isFinite }
            return false
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("run\(runID)")
                    .font(.system(size: 11, weight: .semibold))
                Spacer()
                Text(rows.isEmpty ? "No estimates" : "\(rows.count) parameters")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            if rows.isEmpty {
                Text("Run NONMEM for this model to populate the final THETA/OMEGA/SIGMA estimate table from run\(runID).ext.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
            } else {
                VStack(spacing: 0) {
                    ParameterHeader(showShrinkage: hasAnyShrinkage)
                    Divider().opacity(0.5)
                    ForEach(rows) { row in
                        ParameterRow(row: row, showShrinkageColumn: hasAnyShrinkage)
                        if row.id != rows.last?.id {
                            Divider().opacity(0.3)
                        }
                    }
                }
                .background(.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 6))
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.quaternary.opacity(0.5), lineWidth: 0.5)
                )
            }
        }
    }
}

struct ParameterHeader: View {
    let showShrinkage: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text("Param").frame(maxWidth: .infinity, alignment: .leading)
            Text("Estimate").frame(width: 52, alignment: .trailing)
            Text("RSE").frame(width: 38, alignment: .trailing)
            if showShrinkage {
                Text("Shrink").frame(width: 46, alignment: .trailing)
            }
        }
        .font(.system(size: 9, weight: .semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
}

struct ParameterRow: View {
    let row: ParameterEstimateRow
    let showShrinkageColumn: Bool

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(row.name)
                    .font(.system(size: 10, weight: .medium))
                Text(row.group)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(row.estimateText).frame(width: 52, alignment: .trailing)
            Text(row.rseText).frame(width: 38, alignment: .trailing)
                .foregroundStyle(rseColor)
            // Always show Shrinkage column if header shows it — use "NA" for non-residual rows
            if showShrinkageColumn {
                Text(row.group == "Residual" ? row.shrinkageText : "NA")
                    .frame(width: 46, alignment: .trailing)
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(size: 10, design: .monospaced))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var rseColor: Color {
        guard let rse = row.rsePercent else { return .secondary }
        if rse >= 50 { return .red }
        if rse >= 30 { return .orange }
        return .secondary
    }
}

// MARK: - Supporting Views

struct InspectorSection<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: 3, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 1.5, style: .continuous))
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 1)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FormRow: View {
    let title: String
    @Binding var text: String

    init(_ title: String, text: Binding<String>) {
        self.title = title
        self._text = text
    }

    var body: some View {
        GridRow {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(title, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
        }
    }
}

struct SecureFormRow: View {
    let title: String
    @Binding var text: String

    init(_ title: String, text: Binding<String>) {
        self.title = title
        self._text = text
    }

    var body: some View {
        GridRow {
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            SecureField(title, text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
        }
    }
}

// MARK: - Convergence Badge (Pirana-style S/C check)

struct ConvergenceBadge: View {
    let label: String
    let ok: Bool

    var body: some View {
        HStack(spacing: 4) {
            if label == "Boundary" {
                Circle()
                    .fill(ok ? Color.green : Color.orange)
                    .frame(width: 6, height: 6)
                Text(ok ? "No boundary" : "Has boundary")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ok ? .green : .orange)
            } else {
                Circle()
                    .fill(ok ? Color.green : Color.red)
                    .frame(width: 6, height: 6)
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(ok ? .green : .red)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(ok ? Color.green.opacity(0.08) : Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
