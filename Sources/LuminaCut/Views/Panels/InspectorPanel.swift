import SwiftUI

struct InspectorPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    private var tools: [VideoTool] {
        VideoTool.allCases.filter { $0.category == editor.selectedCategory }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text("Tools")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(CutTheme.textPrimary)
                Spacer()
                Text(editor.selectedCategory.title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(CutTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(CutTheme.accent.opacity(0.12)))
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(tools) { tool in
                        let on = editor.selectedTool == tool
                        Button {
                            editor.selectedTool = tool
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: tool.icon)
                                Text(tool.title)
                            }
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(on ? .white : CutTheme.textSecondary)
                            .padding(.horizontal, 11)
                            .padding(.vertical, 7)
                            .background(
                                Capsule(style: .continuous)
                                    .fill(on ? AnyShapeStyle(CutTheme.accentGradient) : AnyShapeStyle(CutTheme.surfaceHover))
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(on ? CutTheme.accent.opacity(0.4) : CutTheme.border, lineWidth: 1)
                            )
                            .shadow(color: on ? CutTheme.accent.opacity(0.3) : .clear, radius: 6, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }

            Rectangle().fill(CutTheme.border).frame(height: 1)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    switch editor.selectedTool {
                    case .select: SelectInfoPanel()
                    case .cut: CutToolPanel()
                    case .trim: TrimPanel()
                    case .speed: SpeedPanel()
                    case .volume: VolumePanel()
                    case .transform: TransformPanel()
                    case .color: ColorPanel()
                    case .looks: LooksPanel()
                    case .transitions: TransitionsPanel()
                    case .effects: EffectsPanel()
                    case .text: TextPanel()
                    case .stickers: OverlayPanel()
                    case .audio: AudioPanel()
                    case .canvas: CanvasPanel()
                    case .export: ExportPanel()
                    }
                }
                .padding(14)
            }
        }
        .background(CutTheme.surface)
    }
}

struct PanelTitle: View {
    let text: String
    var body: some View {
        CutSectionHeader(title: text)
    }
}

struct NeedClipHint: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "cursorarrow.click.2")
                .font(.system(size: 22))
                .foregroundStyle(CutTheme.textTertiary)
            Text("Select a clip on the timeline")
                .font(.system(size: 12))
                .foregroundStyle(CutTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

struct SelectInfoPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        if let clip = editor.selectedClip {
            VStack(alignment: .leading, spacing: 10) {
                PanelTitle(text: "Clip")
                info("Type", clip.kind.rawValue.capitalized)
                info("Start", String(format: "%.2fs", clip.startOnTimeline))
                info("Duration", String(format: "%.2fs", clip.timelineDuration))
                info("Speed", String(format: "%.2f×", clip.speed))
                info("Volume", String(format: "%.0f%%", clip.volume * 100))
                if let look = clip.lookID {
                    info("Look", look)
                }
                HStack(spacing: 8) {
                    actionBtn("Split", icon: "scissors") { editor.splitAtPlayhead() }
                    actionBtn("Copy", icon: "plus.square.on.square") { editor.duplicateSelected() }
                    actionBtn("Delete", icon: "trash") { editor.deleteSelected() }
                }
            }
        } else {
            NeedClipHint()
        }
    }

    private func info(_ k: String, _ v: String) -> some View {
        HStack {
            Text(k).foregroundStyle(CutTheme.textTertiary)
            Spacer()
            Text(v).foregroundStyle(CutTheme.textPrimary)
        }
        .font(.system(size: 12, weight: .medium))
    }

    private func actionBtn(_ t: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                Text(t).font(.system(size: 9, weight: .medium))
            }
            .foregroundStyle(CutTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 10).fill(CutTheme.surfaceHover))
        }
        .buttonStyle(.plain)
    }
}

struct CutToolPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(text: "Split & Edit")
            Text("Place the playhead where you want to cut, then split. Or select the Split tool and click a clip.")
                .font(.system(size: 11))
                .foregroundStyle(CutTheme.textTertiary)

            Button {
                editor.splitAtPlayhead()
            } label: {
                Label("Split at Playhead", systemImage: "scissors")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(RoundedRectangle(cornerRadius: 10).fill(CutTheme.accent.opacity(0.5)))
            }
            .buttonStyle(.plain)

            Button {
                editor.duplicateSelected()
            } label: {
                Label("Duplicate Clip", systemImage: "plus.square.on.square")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(CutTheme.textSecondary)
                    .background(RoundedRectangle(cornerRadius: 10).stroke(CutTheme.border, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                editor.deleteSelected()
            } label: {
                Label("Delete Clip", systemImage: "trash")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(CutTheme.danger)
                    .background(RoundedRectangle(cornerRadius: 10).stroke(CutTheme.danger.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
}

struct TrimPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        if editor.selectedClip != nil {
            VStack(alignment: .leading, spacing: 12) {
                PanelTitle(text: "Trim")
                SliderRow(
                    title: "In Point",
                    value: Binding(
                        get: { editor.selectedClip?.sourceIn ?? 0 },
                        set: { v in editor.updateSelectedClip { $0.sourceIn = min($0.sourceOut - 0.05, max(0, v)) } }
                    ),
                    range: 0...max(editor.selectedClip?.sourceOut ?? 1, 1),
                    defaultValue: 0,
                    displayMultiplier: 1,
                    icon: "arrow.right.to.line"
                )
                SliderRow(
                    title: "Out Point",
                    value: Binding(
                        get: { editor.selectedClip?.sourceOut ?? 1 },
                        set: { v in editor.updateSelectedClip { $0.sourceOut = max($0.sourceIn + 0.05, v) } }
                    ),
                    range: 0...max((editor.selectedClip.map { mediaDuration(for: $0) } ?? 10), 1),
                    defaultValue: 1,
                    displayMultiplier: 1,
                    icon: "arrow.left.to.line"
                )
            }
        } else {
            NeedClipHint()
        }
    }

    private func mediaDuration(for clip: TimelineClip) -> Double {
        guard let id = clip.mediaID,
              let m = editor.project.mediaLibrary.first(where: { $0.id == id }) else {
            return max(clip.sourceOut, 10)
        }
        return m.durationSeconds
    }
}

struct SpeedPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        if editor.selectedClip != nil {
            VStack(alignment: .leading, spacing: 12) {
                PanelTitle(text: "Speed")
                SliderRow(
                    title: "Speed",
                    value: Binding(
                        get: { editor.selectedClip?.speed ?? 1 },
                        set: { v in editor.updateSelectedClip { $0.speed = v } }
                    ),
                    range: 0.25...4,
                    defaultValue: 1,
                    displayMultiplier: 100,
                    icon: "gauge.with.dots.needle.67percent"
                )
                HStack(spacing: 6) {
                    ForEach([0.25, 0.5, 1.0, 1.5, 2.0], id: \.self) { s in
                        Button {
                            editor.updateSelectedClip { $0.speed = s }
                        } label: {
                            Text(s == 1 ? "1×" : String(format: "%.2g×", s))
                                .font(.system(size: 10, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .foregroundStyle(CutTheme.textSecondary)
                                .background(RoundedRectangle(cornerRadius: 8).fill(CutTheme.surfaceHover))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } else {
            NeedClipHint()
        }
    }
}

struct VolumePanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        if editor.selectedClip != nil {
            VStack(alignment: .leading, spacing: 12) {
                PanelTitle(text: "Audio")
                Toggle("Muted", isOn: Binding(
                    get: { editor.selectedClip?.isMuted ?? false },
                    set: { v in editor.updateSelectedClip { $0.isMuted = v } }
                ))
                .tint(CutTheme.accent)

                SliderRow(
                    title: "Volume",
                    value: Binding(
                        get: { editor.selectedClip?.volume ?? 1 },
                        set: { v in editor.updateSelectedClip { $0.volume = v } }
                    ),
                    range: 0...1,
                    defaultValue: 1,
                    icon: "speaker.wave.2"
                )
                SliderRow(
                    title: "Fade In",
                    value: Binding(
                        get: { editor.selectedClip?.fadeIn ?? 0 },
                        set: { v in editor.updateSelectedClip { $0.fadeIn = v } }
                    ),
                    range: 0...2,
                    defaultValue: 0,
                    displayMultiplier: 1,
                    icon: "speaker.plus"
                )
                SliderRow(
                    title: "Fade Out",
                    value: Binding(
                        get: { editor.selectedClip?.fadeOut ?? 0 },
                        set: { v in editor.updateSelectedClip { $0.fadeOut = v } }
                    ),
                    range: 0...2,
                    defaultValue: 0,
                    displayMultiplier: 1,
                    icon: "speaker.minus"
                )
            }
        } else {
            NeedClipHint()
        }
    }
}

struct TransformPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        if editor.selectedClip != nil {
            VStack(alignment: .leading, spacing: 12) {
                PanelTitle(text: "Transform")
                SliderRow(title: "Scale", value: bind(\.scale), range: 0.1...3, defaultValue: 1, icon: "arrow.up.left.and.arrow.down.right")
                SliderRow(title: "Position X", value: bind(\.positionX), range: 0...1, defaultValue: 0.5, icon: "arrow.left.and.right")
                SliderRow(title: "Position Y", value: bind(\.positionY), range: 0...1, defaultValue: 0.5, icon: "arrow.up.and.down")
                SliderRow(title: "Rotation", value: bind(\.rotation), range: -180...180, defaultValue: 0, displayMultiplier: 1, icon: "rotate.right")
                SliderRow(title: "Opacity", value: bind(\.opacity), range: 0...1, defaultValue: 1, icon: "circle.lefthalf.filled")
                HStack {
                    Toggle("Flip H", isOn: boolBind(\.flipH)).tint(CutTheme.accent)
                    Toggle("Flip V", isOn: boolBind(\.flipV)).tint(CutTheme.accent)
                }
                .font(.system(size: 11))
            }
        } else {
            NeedClipHint()
        }
    }

    private func bind(_ path: WritableKeyPath<TimelineClip, Double>) -> Binding<Double> {
        Binding(
            get: { editor.selectedClip?[keyPath: path] ?? 0 },
            set: { v in editor.updateSelectedClip { $0[keyPath: path] = v } }
        )
    }

    private func boolBind(_ path: WritableKeyPath<TimelineClip, Bool>) -> Binding<Bool> {
        Binding(
            get: { editor.selectedClip?[keyPath: path] ?? false },
            set: { v in editor.updateSelectedClip { $0[keyPath: path] = v } }
        )
    }
}

struct ColorPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        if editor.selectedClip != nil {
            VStack(alignment: .leading, spacing: 12) {
                PanelTitle(text: "Color")
                effectSlider("Brightness", \.brightness)
                effectSlider("Contrast", \.contrast)
                effectSlider("Saturation", \.saturation)
                effectSlider("Warmth", \.warmth)
                effectSlider("Highlights", \.highlights)
                effectSlider("Shadows", \.shadows)
                SliderRow(
                    title: "Vignette",
                    value: effectBind(\.vignette),
                    range: 0...1,
                    icon: "circle.dotted"
                )
                SliderRow(
                    title: "Fade",
                    value: effectBind(\.fade),
                    range: 0...1,
                    icon: "aqi.medium"
                )
                Toggle("Black & White", isOn: Binding(
                    get: { editor.selectedClip?.effects.blackAndWhite ?? false },
                    set: { v in editor.updateSelectedClip { $0.effects.blackAndWhite = v } }
                ))
                .tint(CutTheme.accent)

                Button("Reset Color") {
                    editor.updateSelectedClip {
                        $0.effects = .identity
                        $0.lookID = nil
                    }
                }
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(CutTheme.textSecondary)
            }
        } else {
            NeedClipHint()
        }
    }

    private func effectSlider(_ title: String, _ path: WritableKeyPath<ClipEffects, Double>) -> some View {
        SliderRow(title: title, value: effectBind(path), icon: "slider.horizontal.3")
    }

    private func effectBind(_ path: WritableKeyPath<ClipEffects, Double>) -> Binding<Double> {
        Binding(
            get: { editor.selectedClip?.effects[keyPath: path] ?? 0 },
            set: { v in editor.updateSelectedClip { $0.effects[keyPath: path] = v } }
        )
    }
}

struct LooksPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(text: "Looks")
            if editor.selectedClip == nil {
                NeedClipHint()
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(LookPreset.all) { look in
                    Button {
                        editor.applyLook(look)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: look.colorHex), Color(hex: look.colorHex).opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(height: 48)
                            Text(look.name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(CutTheme.textPrimary)
                        }
                        .padding(6)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(CutTheme.surfaceElevated)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(editor.selectedClip?.lookID == look.id ? CutTheme.accentCyan : CutTheme.border, lineWidth: 1)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct TransitionsPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    @State private var mode: Mode = .out

    private enum Mode: String, CaseIterable {
        case `in` = "In"
        case out = "Out"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            PanelTitle(text: "Transitions")

            if editor.selectedClip == nil {
                NeedClipHint()
            } else {
                Text("CapCut-style edge transitions. Blend types auto-overlap adjacent clips.")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(CutTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                // In / Out toggle
                HStack(spacing: 0) {
                    ForEach(Mode.allCases, id: \.self) { m in
                        let on = mode == m
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) { mode = m }
                        } label: {
                            Text(m == .in ? "Fade In" : "Fade Out")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(on ? .white : CutTheme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(on ? CutTheme.accent.opacity(0.85) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(3)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(CutTheme.surfaceHover)
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(TransitionType.allCases) { t in
                        let selected = mode == .in
                            ? editor.selectedClip?.transitionIn == t
                            : editor.selectedClip?.transitionOut == t
                        Button {
                            if mode == .in {
                                editor.setTransitionIn(t)
                            } else {
                                editor.setTransitionOut(t)
                            }
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(selected ? CutTheme.accent.opacity(0.22) : CutTheme.surfaceHover)
                                        .frame(height: 44)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(selected ? CutTheme.accent : CutTheme.border, lineWidth: selected ? 1.5 : 1)
                                        )
                                    Image(systemName: t.icon)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(selected ? CutTheme.accentPink : CutTheme.textSecondary)
                                }
                                Text(t.title)
                                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                                    .foregroundStyle(selected ? CutTheme.textPrimary : CutTheme.textTertiary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                SliderRow(
                    title: "Duration",
                    value: Binding(
                        get: { editor.selectedClip?.transitionDuration ?? 0.5 },
                        set: { v in editor.updateSelectedClip { $0.transitionDuration = v } }
                    ),
                    range: 0.15...2.0,
                    defaultValue: 0.5,
                    displayMultiplier: 1,
                    icon: "timer"
                )

                // Quick presets
                CutSectionHeader(title: "Quick apply")
                HStack(spacing: 6) {
                    quick("Dissolve", .crossDissolve)
                    quick("Fade", .fadeToBlack)
                    quick("Wipe", .wipeLeft)
                    quick("Zoom", .zoomIn)
                }

                if let c = editor.selectedClip {
                    HStack(spacing: 8) {
                        labelChip("In", c.transitionIn.title)
                        labelChip("Out", c.transitionOut.title)
                    }
                }
            }
        }
    }

    private func quick(_ title: String, _ type: TransitionType) -> some View {
        Button {
            editor.setTransitionOut(type)
            editor.setTransitionIn(type == .wipeLeft ? .wipeRight : type)
            mode = .out
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(CutTheme.textSecondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(CutTheme.surfaceHover)
                        .overlay(Capsule().stroke(CutTheme.border, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }

    private func labelChip(_ side: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(side)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(CutTheme.accent)
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(CutTheme.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(CutTheme.surfaceHover))
    }
}

struct EffectsPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(text: "Effects")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(EffectPreset.allCases) { e in
                    Button {
                        editor.updateSelectedClip { $0.effectPreset = e }
                        // Map some effects to color params as approximation
                        switch e {
                        case .vhs:
                            editor.updateSelectedClip {
                                $0.effects.fade = 0.2
                                $0.effects.vignette = 0.35
                                $0.effects.saturation = -0.15
                            }
                        case .filmGrain:
                            editor.updateSelectedClip { $0.effects.fade = 0.1; $0.effects.contrast = 0.1 }
                        case .duotone:
                            editor.updateSelectedClip { $0.effects.saturation = -0.3; $0.effects.contrast = 0.2 }
                        case .neon:
                            editor.updateSelectedClip { $0.effects.saturation = 0.4; $0.effects.contrast = 0.25 }
                        case .blurOut:
                            editor.updateSelectedClip { $0.effects.blur = 0.5 }
                        default: break
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 16))
                            Text(e.title)
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(editor.selectedClip?.effectPreset == e ? .white : CutTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(editor.selectedClip?.effectPreset == e
                                      ? AnyShapeStyle(CutTheme.accentGradient.opacity(0.35))
                                      : AnyShapeStyle(CutTheme.surfaceHover))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct TextPanel: View {
    @EnvironmentObject private var editor: EditorViewModel
    @State private var draft = "Your Title"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(text: "Text")
            Button {
                editor.addTextClip(text: draft, duration: 3)
            } label: {
                Label("Add Text Clip", systemImage: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(RoundedRectangle(cornerRadius: 10).fill(CutTheme.accentPink.opacity(0.5)))
            }
            .buttonStyle(.plain)

            if editor.selectedClip?.kind == .text {
                TextField("Text", text: Binding(
                    get: { editor.selectedClip?.textContent ?? "" },
                    set: { v in editor.updateSelectedClip { $0.textContent = v } }
                ))
                .textFieldStyle(.roundedBorder)

                SliderRow(
                    title: "Size",
                    value: Binding(
                        get: { editor.selectedClip?.textFontSize ?? 48 },
                        set: { v in editor.updateSelectedClip { $0.textFontSize = v } }
                    ),
                    range: 12...120,
                    defaultValue: 48,
                    displayMultiplier: 1,
                    icon: "textformat.size"
                )
                SliderRow(title: "Position X", value: Binding(
                    get: { editor.selectedClip?.positionX ?? 0.5 },
                    set: { v in editor.updateSelectedClip { $0.positionX = v } }
                ), range: 0...1, defaultValue: 0.5)
                SliderRow(title: "Position Y", value: Binding(
                    get: { editor.selectedClip?.positionY ?? 0.5 },
                    set: { v in editor.updateSelectedClip { $0.positionY = v } }
                ), range: 0...1, defaultValue: 0.5)
            } else {
                TextField("New text content", text: $draft)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}

struct OverlayPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(text: "Overlay")
            Text("Add images or clips to the Overlay track for picture-in-picture. Select media and it can be moved to overlay from the timeline context.")
                .font(.system(size: 11))
                .foregroundStyle(CutTheme.textTertiary)

            Button {
                // Move selected to overlay track
                guard let id = editor.selectedClipID else { return }
                editor.commit { project in
                    var clip: TimelineClip?
                    for ti in project.tracks.indices {
                        if let ci = project.tracks[ti].clips.firstIndex(where: { $0.id == id }) {
                            clip = project.tracks[ti].clips.remove(at: ci)
                            break
                        }
                    }
                    guard var clip, let oi = project.tracks.firstIndex(where: { $0.kind == .overlay }) else { return }
                    clip.scale = 0.4
                    clip.positionX = 0.8
                    clip.positionY = 0.2
                    project.tracks[oi].clips.append(clip)
                }
                editor.scheduleRebuild()
            } label: {
                Label("Send Selected → Overlay (PiP)", systemImage: "rectangle.on.rectangle")
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(CutTheme.textPrimary)
                    .background(RoundedRectangle(cornerRadius: 10).fill(CutTheme.surfaceHover))
            }
            .buttonStyle(.plain)
        }
    }
}

struct AudioPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(text: "Audio / Music")
            Text("Import audio files and click them in Media to place on the Music track. Adjust volume on selected clips.")
                .font(.system(size: 11))
                .foregroundStyle(CutTheme.textTertiary)
            Button("Import Audio / Media") { editor.importMedia() }
                .buttonStyle(.borderedProminent)
                .tint(CutTheme.accentGreen)
            VolumePanel()
        }
    }
}

struct CanvasPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(text: "Canvas")
            ForEach(CanvasAspect.allCases) { aspect in
                Button {
                    editor.commit { $0.aspect = aspect }
                    editor.scheduleRebuild()
                    editor.statusMessage = "Canvas \(aspect.title)"
                } label: {
                    HStack {
                        // Mini aspect preview
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(CutTheme.borderStrong, lineWidth: 1)
                            .frame(width: aspect.ratio >= 1 ? 28 : 16, height: aspect.ratio >= 1 ? 16 : 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(aspect.title)
                                .font(.system(size: 12, weight: .semibold))
                            Text(aspect.subtitle)
                                .font(.system(size: 10))
                                .foregroundStyle(CutTheme.textTertiary)
                        }
                        Spacer()
                        if editor.project.aspect == aspect {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(CutTheme.accentCyan)
                        }
                    }
                    .foregroundStyle(CutTheme.textPrimary)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(editor.project.aspect == aspect ? CutTheme.surfaceHover : CutTheme.surfaceElevated)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(CutTheme.border, lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }

            PanelTitle(text: "Frame Rate")
            Picker("FPS", selection: Binding(
                get: { editor.project.frameRate },
                set: { v in editor.commit { $0.frameRate = v }; editor.scheduleRebuild() }
            )) {
                Text("24").tag(24.0)
                Text("30").tag(30.0)
                Text("60").tag(60.0)
            }
            .pickerStyle(.segmented)
        }
    }
}

struct ExportPanel: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(text: "Export")
            Text("Render your timeline to MP4.")
                .font(.system(size: 11))
                .foregroundStyle(CutTheme.textTertiary)

            ForEach(ExportPreset.allCases) { preset in
                Button {
                    editor.exportPreset = preset
                } label: {
                    HStack {
                        Text(preset.title)
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        if editor.exportPreset == preset {
                            Image(systemName: "checkmark")
                                .foregroundStyle(CutTheme.accentCyan)
                        }
                    }
                    .foregroundStyle(CutTheme.textPrimary)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(editor.exportPreset == preset ? CutTheme.surfaceHover : CutTheme.surfaceElevated)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(CutTheme.border, lineWidth: 1))
                    )
                }
                .buttonStyle(.plain)
            }

            Button {
                editor.export()
            } label: {
                Label("Export Video…", systemImage: "square.and.arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(.white)
                    .background(RoundedRectangle(cornerRadius: 12).fill(CutTheme.accentGradient))
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
    }
}
