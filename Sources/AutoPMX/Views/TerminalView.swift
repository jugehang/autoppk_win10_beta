import SwiftUI

// MARK: - Terminal View

struct TerminalView: View {
    @EnvironmentObject private var store: WorkbenchStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "terminal")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Text("Terminal")
                        .font(.system(size: 11, weight: .semibold))
                }
                if store.runner.isRunning {
                    HStack(spacing: 4) {
                        ProgressView()
                            .controlSize(.small)
                            .scaleEffect(0.6)
                        Text("Running...")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    store.runner.clear()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "trash")
                            .font(.system(size: 9))
                        Text("Clear")
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Color(nsColor: .controlBackgroundColor)
                    .shadow(color: .black.opacity(0.02), radius: 1, y: 1)
            )
            .overlay(Divider().opacity(0.6), alignment: .bottom)

            TextEditor(text: Binding(
                get: { store.runner.logText },
                set: { store.runner.logText = $0 }
            ))
            .font(.system(size: 11, design: .monospaced))
            .scrollContentBackground(.hidden)
            .background(Color(nsColor: .textBackgroundColor))
        }
    }
}
