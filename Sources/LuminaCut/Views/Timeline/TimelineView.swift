import SwiftUI

struct TimelineView: View {
    @EnvironmentObject private var editor: EditorViewModel

    private let trackHeight: CGFloat = 40
    private let headerWidth: CGFloat = 104

    var body: some View {
        VStack(spacing: 0) {
            // CapCut-style tool strip
            HStack(spacing: 8) {
                Text("TIMELINE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .tracking(1.1)
                    .foregroundStyle(CutTheme.textTertiary)

                toolChip(.select)
                toolChip(.cut)
                toolChip(.speed)
                toolChip(.volume)
                toolChip(.transitions)
                toolChip(.text)

                Spacer()

                Toggle(isOn: $editor.snapEnabled) {
                    Text("Snap")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(CutTheme.textTertiary)
                }
                .toggleStyle(.switch)
                .controlSize(.mini)
                .tint(CutTheme.accent)

                Text(String(format: "%.1f×", editor.timelineZoom))
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(CutTheme.textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(CutTheme.surfaceHover))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(CutTheme.surfaceElevated)

            Rectangle().fill(CutTheme.border).frame(height: 1)

            GeometryReader { geo in
                let contentWidth = max(geo.size.width, timelineWidth + headerWidth + 40)

                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    HStack(alignment: .top, spacing: 0) {
                        VStack(spacing: 5) {
                            Color.clear.frame(height: 24)
                            ForEach(editor.project.tracks) { track in
                                TrackHeader(track: track)
                                    .frame(height: trackHeight)
                            }
                        }
                        .frame(width: headerWidth)

                        ZStack(alignment: .topLeading) {
                            VStack(spacing: 5) {
                                TimeRuler(
                                    duration: max(editor.playback.duration, editor.project.totalDurationSeconds, 10),
                                    pps: editor.pixelsPerSecond
                                )
                                .frame(height: 24)
                                .frame(width: max(timelineWidth, 800))

                                ForEach(editor.project.tracks) { track in
                                    TrackLane(track: track, pps: editor.pixelsPerSecond)
                                        .frame(height: trackHeight)
                                        .frame(width: max(timelineWidth, 800))
                                }
                            }

                            let x = CGFloat(editor.playback.currentTime) * editor.pixelsPerSecond
                            // Playhead line + cap
                            VStack(spacing: 0) {
                                Capsule()
                                    .fill(CutTheme.playhead)
                                    .frame(width: 12, height: 12)
                                    .shadow(color: CutTheme.playhead.opacity(0.6), radius: 4)
                                Rectangle()
                                    .fill(CutTheme.playhead)
                                    .frame(width: 2)
                                    .frame(height: CGFloat(editor.project.tracks.count) * (trackHeight + 5) + 12)
                                    .shadow(color: CutTheme.playhead.opacity(0.4), radius: 3)
                            }
                            .offset(x: x - 6, y: 6)
                            .allowsHitTesting(false)
                        }
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { g in
                                    let t = max(0, g.location.x / editor.pixelsPerSecond)
                                    editor.playback.seek(to: Double(t))
                                }
                        )
                    }
                    .padding(.trailing, 40)
                    .frame(minWidth: contentWidth, minHeight: geo.size.height)
                }
            }
        }
        .background(CutTheme.timelineBg)
    }

    private var timelineWidth: CGFloat {
        let dur = max(editor.playback.duration, editor.project.totalDurationSeconds, 10)
        return CGFloat(dur) * editor.pixelsPerSecond + 100
    }

    private func toolChip(_ tool: VideoTool) -> some View {
        let on = editor.selectedTool == tool
        return Button {
            editor.selectedTool = tool
            editor.selectedCategory = tool.category
        } label: {
            Image(systemName: tool.icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(on ? .white : CutTheme.textSecondary)
                .frame(width: 30, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(on ? CutTheme.accent : CutTheme.surfaceHover)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(on ? CutTheme.accentPink.opacity(0.5) : CutTheme.border, lineWidth: 1)
                )
                .shadow(color: on ? CutTheme.accent.opacity(0.35) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
        .help(tool.title)
    }
}

struct TrackHeader: View {
    let track: TimelineTrack
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(Color(hex: track.kind.colorHex))
                .frame(width: 6, height: 6)
                .shadow(color: Color(hex: track.kind.colorHex).opacity(0.6), radius: 3)
            Image(systemName: track.kind.icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Color(hex: track.kind.colorHex))
            Text(track.name)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(CutTheme.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            if track.isMuted {
                Image(systemName: "speaker.slash.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(CutTheme.danger)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(CutTheme.surfaceElevated.opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(CutTheme.border, lineWidth: 1)
        )
    }
}

struct TimeRuler: View {
    let duration: Double
    let pps: CGFloat

    var body: some View {
        Canvas { context, size in
            let step: Double = pps > 60 ? 1 : (pps > 30 ? 2 : 5)
            var t: Double = 0
            while t <= duration + step {
                let x = CGFloat(t) * pps
                let major = Int(t) % Int(step * 5) == 0
                let h: CGFloat = major ? 12 : 5
                var path = Path()
                path.move(to: CGPoint(x: x, y: size.height - h))
                path.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(path, with: .color(Color.white.opacity(major ? 0.32 : 0.12)), lineWidth: 1)
                if major {
                    let text = Text(String(format: "%d:%02d", Int(t) / 60, Int(t) % 60))
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.38))
                    context.draw(text, at: CGPoint(x: x + 4, y: 5), anchor: .leading)
                }
                t += step
            }
        }
        .background(CutTheme.surface)
    }
}

struct TrackLane: View {
    let track: TimelineTrack
    let pps: CGFloat
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(CutTheme.surface.opacity(0.55))
                .overlay(
                    GeometryReader { g in
                        Path { p in
                            let step = pps
                            var x: CGFloat = 0
                            while x < g.size.width {
                                p.move(to: CGPoint(x: x, y: 0))
                                p.addLine(to: CGPoint(x: x, y: g.size.height))
                                x += step
                            }
                        }
                        .stroke(Color.white.opacity(0.025), lineWidth: 1)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(CutTheme.border, lineWidth: 1)
                )

            ForEach(track.clips) { clip in
                ClipBlock(clip: clip, track: track, pps: pps)
            }
        }
    }
}

struct ClipBlock: View {
    let clip: TimelineClip
    let track: TimelineTrack
    let pps: CGFloat
    @EnvironmentObject private var editor: EditorViewModel
    @State private var dragOffset: CGFloat = 0

    private var selected: Bool { editor.selectedClipID == clip.id }

    var body: some View {
        let w = max(10, CGFloat(clip.timelineDuration) * pps)
        let x = CGFloat(clip.startOnTimeline) * pps + dragOffset
        let color = Color(hex: track.kind.colorHex)

        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .bold))
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if abs(clip.speed - 1) > 0.01 {
                    Text(String(format: "%.1f×", clip.speed))
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(.black.opacity(0.25)))
                }
            }
            .foregroundStyle(.white.opacity(0.95))

            HStack(spacing: 3) {
                if clip.transitionIn != .none {
                    Image(systemName: "arrow.right.to.line.compact")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer(minLength: 0)
                if clip.transitionOut != .none {
                    Image(systemName: clip.transitionOut.icon)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(3)
                        .background(Circle().fill(.black.opacity(0.25)))
                }
            }
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .frame(width: w, height: 34, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.95), color.opacity(0.65)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(selected ? Color.white : Color.white.opacity(0.18), lineWidth: selected ? 2 : 1)
                )
        )
        .shadow(color: selected ? color.opacity(0.55) : color.opacity(0.15), radius: selected ? 8 : 3, y: 1)
        .offset(x: x)
        .gesture(
            DragGesture()
                .onChanged { g in
                    dragOffset = g.translation.width
                    editor.selectClip(clip.id, trackID: track.id)
                }
                .onEnded { g in
                    let newStart = max(0, clip.startOnTimeline + Double(g.translation.width / pps))
                    dragOffset = 0
                    editor.moveClip(clip.id, toTimelineTime: newStart, trackID: track.id)
                }
        )
        .onTapGesture {
            editor.selectClip(clip.id, trackID: track.id)
            if editor.selectedTool == .cut {
                editor.splitAtPlayhead()
            }
        }
        .contextMenu {
            Button("Split at Playhead") { editor.selectClip(clip.id); editor.splitAtPlayhead() }
            Button("Duplicate") { editor.selectClip(clip.id); editor.duplicateSelected() }
            Menu("Transition Out") {
                ForEach(TransitionType.allCases) { t in
                    Button(t.title) {
                        editor.selectClip(clip.id, trackID: track.id)
                        editor.setTransitionOut(t)
                    }
                }
            }
            Divider()
            Button("Delete", role: .destructive) { editor.selectClip(clip.id); editor.deleteSelected() }
        }
    }

    private var icon: String {
        switch clip.kind {
        case .video: return "film"
        case .image: return "photo"
        case .audio: return "waveform"
        case .text: return "textformat"
        case .effect: return "sparkles"
        }
    }

    private var label: String {
        if clip.kind == .text { return clip.textContent.isEmpty ? "Text" : clip.textContent }
        if let mid = clip.mediaID, let m = editor.project.mediaLibrary.first(where: { $0.id == mid }) {
            return m.name
        }
        return clip.kind.rawValue.capitalized
    }
}
