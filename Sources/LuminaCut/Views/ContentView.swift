import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var editor: EditorViewModel
    @EnvironmentObject private var chat: ChatViewModel

    var body: some View {
        ZStack {
            // CapCut/CRED deep background with soft vignette
            CutTheme.bg.ignoresSafeArea()
            RadialGradient(
                colors: [CutTheme.accent.opacity(0.06), Color.clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 520
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [CutTheme.accentPurple.opacity(0.05), Color.clear],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 480
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                TopBarView()

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [CutTheme.accent.opacity(0.35), CutTheme.accentPurple.opacity(0.2), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)

                HStack(spacing: 0) {
                    ToolRail()
                        .frame(width: CutTheme.toolRailWidth)

                    panelDivider

                    MediaLibraryView()
                        .frame(width: CutTheme.sidebarWidth)

                    panelDivider

                    VStack(spacing: 0) {
                        PreviewStage()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        Rectangle()
                            .fill(CutTheme.border)
                            .frame(height: 1)

                        TimelineView()
                            .frame(height: 268)
                    }

                    panelDivider

                    InspectorPanel()
                        .frame(width: CutTheme.inspectorWidth)

                    if editor.showChat {
                        panelDivider
                        AIChatPanel()
                            .frame(width: CutTheme.chatWidth)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
            }

            if let progress = editor.exportProgress {
                ExportOverlay(progress: progress)
            }
        }
    }

    private var panelDivider: some View {
        Rectangle()
            .fill(CutTheme.border)
            .frame(width: 1)
    }
}

struct ExportOverlay: View {
    let progress: Double
    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(CutTheme.surfaceHover, lineWidth: 4)
                        .frame(width: 56, height: 56)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(CutTheme.accentGradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))
                    Text("\(Int(progress * 100))")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Text("Exporting Video")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Keep LuminaCut open until export finishes")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(CutTheme.textTertiary)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: CutTheme.radiusXl, style: .continuous)
                    .fill(CutTheme.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: CutTheme.radiusXl, style: .continuous)
                            .stroke(CutTheme.borderStrong, lineWidth: 1)
                    )
                    .shadow(color: CutTheme.accent.opacity(0.2), radius: 30, y: 10)
            )
        }
    }
}
