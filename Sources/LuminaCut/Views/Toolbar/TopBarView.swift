import SwiftUI

struct TopBarView: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        HStack(spacing: 14) {
            // Brand — CapCut-like mark + CRED glow
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(CutTheme.accentGradient)
                        .frame(width: 30, height: 30)
                        .shadow(color: CutTheme.accent.opacity(0.45), radius: 10, y: 2)
                    Image(systemName: "film.stack.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("LuminaCut")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(CutTheme.textPrimary)
                    Text("Pro Video Editor")
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(CutTheme.textTertiary)
                }
            }
            .padding(.leading, 12)

            TextField("Project name", text: $editor.project.name)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(CutTheme.textSecondary)
                .frame(width: 150)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: CutTheme.radiusSm, style: .continuous)
                        .fill(CutTheme.surfaceHover)
                        .overlay(
                            RoundedRectangle(cornerRadius: CutTheme.radiusSm, style: .continuous)
                                .stroke(CutTheme.border, lineWidth: 1)
                        )
                )

            Spacer()

            HStack(spacing: 6) {
                barBtn("plus.rectangle.on.folder", "Import") { editor.importMedia() }
                barBtn("arrow.uturn.backward", "Undo", disabled: !editor.canUndo) { editor.undo() }
                barBtn("arrow.uturn.forward", "Redo", disabled: !editor.canRedo) { editor.redo() }
                barBtn("scissors", "Split") { editor.splitAtPlayhead() }
                barBtn("trash", "Delete", disabled: editor.selectedClipID == nil) { editor.deleteSelected() }

                Rectangle()
                    .fill(CutTheme.border)
                    .frame(width: 1, height: 18)
                    .padding(.horizontal, 4)

                Button { editor.export() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 11, weight: .bold))
                        Text("Export")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(CutTheme.accentGradient)
                    )
                    .shadow(color: CutTheme.accent.opacity(0.4), radius: 8, y: 2)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            HStack(spacing: 10) {
                if editor.isRebuilding {
                    ProgressView().controlSize(.small)
                }
                Text(editor.statusMessage)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(CutTheme.textTertiary)
                    .lineLimit(1)
                    .frame(maxWidth: 200, alignment: .trailing)

                Text(editor.project.aspect.title)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundStyle(CutTheme.accentCyan)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(CutTheme.accentCyan.opacity(0.12))
                            .overlay(Capsule().stroke(CutTheme.accentCyan.opacity(0.25), lineWidth: 1))
                    )

                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        editor.showChat.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 11, weight: .bold))
                        Text("AI")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(editor.showChat ? .white : CutTheme.textSecondary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 7)
                    .background(
                        Capsule(style: .continuous)
                            .fill(editor.showChat
                                  ? AnyShapeStyle(CutTheme.accentGradient)
                                  : AnyShapeStyle(CutTheme.surfaceHover))
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(editor.showChat ? CutTheme.accent.opacity(0.5) : CutTheme.border, lineWidth: 1)
                    )
                    .shadow(color: editor.showChat ? CutTheme.accent.opacity(0.35) : .clear, radius: 8, y: 2)
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 14)
        }
        .frame(height: CutTheme.topBarHeight)
        .background(
            CutTheme.surface.opacity(0.98)
                .background(.ultraThinMaterial.opacity(0.3))
        )
    }

    private func barBtn(_ icon: String, _ label: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold))
                Text(label).font(.system(size: 11, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(disabled ? CutTheme.textTertiary : CutTheme.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: CutTheme.radiusSm, style: .continuous)
                    .fill(CutTheme.surfaceHover)
                    .overlay(
                        RoundedRectangle(cornerRadius: CutTheme.radiusSm, style: .continuous)
                            .stroke(CutTheme.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
    }
}

struct ToolRail: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        VStack(spacing: 6) {
            ForEach(ToolCategory.allCases) { cat in
                let on = editor.selectedCategory == cat
                Button {
                    editor.selectedCategory = cat
                    if let first = VideoTool.allCases.first(where: { $0.category == cat }) {
                        editor.selectedTool = first
                    }
                } label: {
                    VStack(spacing: 5) {
                        ZStack {
                            if on {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(CutTheme.accent.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(CutTheme.accent.opacity(0.45), lineWidth: 1)
                                    )
                                    .shadow(color: CutTheme.accent.opacity(0.25), radius: 8)
                            }
                            Image(systemName: cat.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(on ? CutTheme.accent : CutTheme.textSecondary)
                                .frame(width: 44, height: 44)
                        }
                        Text(cat.title)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(on ? CutTheme.textPrimary : CutTheme.textTertiary)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()

            // Brand accent bar
            RoundedRectangle(cornerRadius: 2)
                .fill(CutTheme.accentGradient)
                .frame(width: 28, height: 3)
                .padding(.bottom, 14)
        }
        .padding(.vertical, 14)
        .frame(maxHeight: .infinity)
        .background(CutTheme.surface)
    }
}
