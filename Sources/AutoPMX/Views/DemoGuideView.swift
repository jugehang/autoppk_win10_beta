import SwiftUI
import AppKit

// MARK: - Demo Guide Popover

struct DemoGuideView: View {
    @EnvironmentObject private var store: WorkbenchStore
    @State private var selectedCaseIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 10) {
                if let logo = duDuLogo {
                    Image(nsImage: logo)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 1) {
                    Text("AutoPMx Demo")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                    Text("AI 辅助 PPK 建模实战演示")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        store.showDemoGuide = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            // Body - scrollable
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    // Case overview + stats
                    caseOverviewRow

                    Divider()

                    // Guided workflow tabs
                    guidedWorkflowSection

                    // Quick prompts
                    quickStartRow
                }
                .padding(16)
            }
            .frame(maxHeight: 320)
        }
        .frame(width: 420)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.primary.opacity(0.1), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 20, y: 6)
    }

    // MARK: - Case Overview Row

    private var caseOverviewRow: some View {
        HStack(alignment: .top, spacing: 14) {
            // Icon
            Image(systemName: "cross.vial")
                .font(.system(size: 22))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.15, green: 0.45, blue: 0.95), Color(red: 0.35, green: 0.65, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text("mAb 单抗药物 PopPK 建模")
                    .font(.system(size: 12, weight: .semibold))

                Text("包含真实 PK 数据集（NM_dat_new.csv, NM_dat.csv）与多个 NONMEM 控制流（run31 / run32 / run38 / run41），涵盖基础建模、SCM 协变量筛选到最终模型的完整工作流。")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)

                HStack(spacing: 10) {
                    statTag("3+ 模型")
                    statTag("1,000+ 观测")
                    statTag("IV Infusion")
                }
                .padding(.top, 4)
            }
        }
        .padding(10)
        .background(.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Guided Workflow

    private var guidedWorkflowSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(red: 0.15, green: 0.45, blue: 0.95), Color(red: 0.35, green: 0.65, blue: 1.0)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("AI 功能实操指引")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }

            // Tab selector
            HStack(spacing: 4) {
                ForEach(Array(demoCases.enumerated()), id: \.offset) { index, demoCase in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) { selectedCaseIndex = index }
                    } label: {
                        Text(demoCase.tabTitle)
                            .font(.system(size: 10, weight: selectedCaseIndex == index ? .semibold : .regular))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .foregroundStyle(selectedCaseIndex == index ? .white : .primary.opacity(0.7))
                            .background(
                                selectedCaseIndex == index
                                    ? AnyShapeStyle(
                                        LinearGradient(
                                            colors: [Color(red: 0.15, green: 0.45, blue: 0.95), Color(red: 0.35, green: 0.65, blue: 1.0)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    : AnyShapeStyle(.clear),
                                in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Selected case content
            if selectedCaseIndex < demoCases.count {
                let demoCase = demoCases[selectedCaseIndex]
                VStack(alignment: .leading, spacing: 6) {
                    Text(demoCase.description)
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)

                    ForEach(Array(demoCase.prompts.enumerated()), id: \.offset) { index, prompt in
                        promptButton(index: index + 1, text: prompt)
                    }
                }
                .padding(10)
                .background(.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
    }

    // MARK: - Quick Prompts

    private var quickStartRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "hand.tap")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Text("快速提问")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)], spacing: 6) {
                ForEach(quickPrompts, id: \.self) { prompt in
                    Button {
                        store.sendUserMessage(prompt)
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.showDemoGuide = false
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 8))
                            Text(prompt)
                                .font(.system(size: 10))
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.15, green: 0.45, blue: 0.95), Color(red: 0.35, green: 0.65, blue: 1.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .background(
                            LinearGradient(
                                colors: [Color(red: 0.15, green: 0.45, blue: 0.95), Color(red: 0.35, green: 0.65, blue: 1.0)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .opacity(0.06),
                            in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [Color(red: 0.15, green: 0.45, blue: 0.95), Color(red: 0.35, green: 0.65, blue: 1.0)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    .opacity(0.12),
                                    lineWidth: 0.5
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Subviews

    private func promptButton(index: Int, text: String) -> some View {
        Button {
            store.sendUserMessage(text)
            withAnimation(.easeInOut(duration: 0.2)) {
                store.showDemoGuide = false
            }
        } label: {
            HStack(spacing: 6) {
                Text("\(index)")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 16, height: 16)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(red: 0.15, green: 0.45, blue: 0.95), Color(red: 0.35, green: 0.65, blue: 1.0)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )

                Text(text)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                Spacer()

                Image(systemName: "arrow.up.forward.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary.opacity(0.3))
            }
            .padding(8)
            .background(.primary.opacity(0.03), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func statTag(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 9, weight: .medium, design: .monospaced))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
    }

    private var duDuLogo: NSImage? {
        let candidates = [
            BundledResource.url(forResource: "DuDuPMxButton", withExtension: "png"),
            BundledResource.url(forResource: "DuDuPMxSource", withExtension: "png"),
        ]
        for url in candidates {
            if let url, let image = NSImage(contentsOf: url) { return image }
        }
        return nil
    }

    // MARK: - Data

    private struct DemoCase {
        let tabTitle: String
        let description: String
        let prompts: [String]
    }

    private let demoCases: [DemoCase] = [
        DemoCase(
            tabTitle: "模型评估",
            description: "让 DuDu PMx 用 PopPK 规则库标准，从 OFV、参数精度、协方差、Shrinkage 等维度检查模型质量，给出 ACCEPT 或 REVISE 建议。",
            prompts: [
                "帮我评估 run38.mod 的 NONMEM 结果，分析参数估计是否合理，GOF 图是否达标",
                "查看 run31.mod 的诊断结果，用 PopPK 规则库的标准给出改进建议",
            ]
        ),
        DemoCase(
            tabTitle: "模型比较",
            description: "一键对比两个模型的 OFV、参数估计、残差诊断、模型复杂度，AI 自动生成多维度对比报告，帮你选择更优模型。",
            prompts: [
                "帮我比较 run31 和 run38 的模型结果，哪个更优？给出详细理由",
                "比较 run38 和 run41 的参数估计、GOF 和 VPC，推荐最终模型",
            ]
        ),
        DemoCase(
            tabTitle: "自动建模",
            description: "DuDu Auto 从数据集出发，自动完成结构模型探索（Phase 1）→ 协变量筛选（Phase 2），支持 SCM 快速筛选 + AI 验证。",
            prompts: [
                "用 NM_dat_new.csv 开始 DuDu Auto 自动建模，从1房室 IV Infusion 模型开始",
                "对 run32.mod 启动 SCM 协变量筛选",
            ]
        ),
        DemoCase(
            tabTitle: "SCM 协变量",
            description: "用 PsN SCM 工具快速筛选协变量（WT, AGE, SEX, STUDY）。选中 run32.mod → 右键 → SCM，或直接对 DuDu 说「对 run32 进行 SCM」。",
            prompts: [
                "分析 run32.mod，帮我用 SCM 筛选对 CL, V 有影响的协变量",
                "SCM 结果中保留的协变量帮我用 AI 验证：手动构建加入 WT SEX 的 run33.mod",
            ]
        ),
        DemoCase(
            tabTitle: "诊断解读",
            description: "DuDu PMx 解读每个模型输出文件（LST, EXT, COV）和诊断图（GOF, VPC），提炼关键信息，无需手动翻看 NONMEM 报告。",
            prompts: [
                "帮我解读 run41 的 GOF 图，CWRES vs PRED 和 CWRES vs TIME 有没有趋势性问题？",
                "查看 run38 的 VPC 图，预测区间是否覆盖了观测数据？",
            ]
        ),
    ]

    private let quickPrompts: [String] = [
        "评估 run38 模型",
        "比较 run31 vs run38",
        "DuDu Auto 自动建模",
        "SCM 协变量筛选",
        "解读 GOF 诊断图",
        "查看 VPC 拟合情况",
    ]
}

// #Preview {
//     DemoGuideView()
//         .environmentObject(WorkbenchStore())
//         .padding(40)
// }
