import SwiftUI
import AVKit
import AVFoundation
import AppKit

struct PreviewStage: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { geo in
                ZStack {
                    // Stage backdrop
                    CutTheme.bg
                    RadialGradient(
                        colors: [CutTheme.accentPurple.opacity(0.04), Color.clear],
                        center: .center,
                        startRadius: 20,
                        endRadius: 380
                    )

                    let size = fittedSize(in: geo.size, aspect: editor.project.aspect.ratio)
                    ZStack {
                        // Soft glow frame
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(CutTheme.accent.opacity(0.08))
                            .frame(width: size.width + 10, height: size.height + 10)
                            .blur(radius: 16)

                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black)
                            .frame(width: size.width, height: size.height)
                            .shadow(color: .black.opacity(0.55), radius: 24, y: 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(
                                        LinearGradient(
                                            colors: [CutTheme.borderStrong, CutTheme.accent.opacity(0.2), CutTheme.border],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 1
                                    )
                            )

                        PlayerView(player: editor.playback.player)
                            .frame(width: size.width, height: size.height)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                        ForEach(activeTextClips, id: \.id) { clip in
                            Text(clip.textContent)
                                .font(.system(size: CGFloat(clip.textFontSize) * size.height / 1920, weight: clip.textBold ? .bold : .regular, design: .rounded))
                                .foregroundStyle(Color(hex: clip.textColorHex))
                                .shadow(color: .black.opacity(0.65), radius: 4, y: 2)
                                .position(
                                    x: size.width * clip.positionX,
                                    y: size.height * clip.positionY
                                )
                        }

                        if editor.isRebuilding {
                            ProgressView()
                                .scaleEffect(0.85)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Capsule())
                        }

                        if !hasTimelineContent {
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(CutTheme.accent.opacity(0.12))
                                        .frame(width: 64, height: 64)
                                    Image(systemName: "play.rectangle.fill")
                                        .font(.system(size: 28, weight: .light))
                                        .foregroundStyle(CutTheme.accent)
                                }
                                Text("Drop media on the timeline")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(CutTheme.textPrimary)
                                Text("Import → click a clip → press Play")
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(CutTheme.textTertiary)
                            }
                        } else if let err = editor.playback.lastError {
                            VStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(CutTheme.accentOrange)
                                Text(err)
                                    .font(.system(size: 11, design: .rounded))
                                    .foregroundStyle(CutTheme.textSecondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                            }
                            .padding(14)
                            .background(.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .frame(width: size.width, height: size.height)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            PlaybackControls()
        }
        .background(CutTheme.surface.opacity(0.4))
    }

    private var hasTimelineContent: Bool {
        editor.project.tracks.contains { !$0.clips.isEmpty }
    }

    private var activeTextClips: [TimelineClip] {
        let t = editor.playback.currentTime
        return editor.project.tracks
            .filter { $0.kind == .text && !$0.isHidden }
            .flatMap(\.clips)
            .filter { t >= $0.startOnTimeline && t <= $0.endOnTimeline }
    }

    private func fittedSize(in container: CGSize, aspect: CGFloat) -> CGSize {
        let pad: CGFloat = 36
        let maxW = container.width - pad
        let maxH = container.height - pad
        if maxW / maxH > aspect {
            let h = maxH
            return CGSize(width: h * aspect, height: h)
        } else {
            let w = maxW
            return CGSize(width: w, height: w / aspect)
        }
    }
}

struct PlayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspect
        view.showsFullScreenToggleButton = false
        view.allowsPictureInPicturePlayback = false
        if #available(macOS 13.0, *) {
            view.showsTimecodes = false
            view.showsFrameSteppingButtons = false
        }
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if nsView.player !== player {
            nsView.player = player
        }
    }
}

struct PlaybackControls: View {
    @EnvironmentObject private var editor: EditorViewModel

    var body: some View {
        HStack(spacing: 14) {
            transportBtn("backward.end.fill") { editor.playback.seek(to: 0) }
            transportBtn("backward.frame.fill") { editor.playback.step(by: -1.0 / 30.0) }

            Button {
                editor.playback.toggle()
            } label: {
                ZStack {
                    Circle()
                        .fill(CutTheme.accentGradient)
                        .frame(width: 40, height: 40)
                        .shadow(color: CutTheme.accent.opacity(0.45), radius: 10, y: 2)
                    Image(systemName: editor.playback.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: editor.playback.isPlaying ? 0 : 1)
                }
            }
            .buttonStyle(.plain)
            .help(editor.playback.isPlaying ? "Pause" : "Play")
            .opacity(editor.playback.player.currentItem == nil ? 0.45 : 1)

            transportBtn("forward.frame.fill") { editor.playback.step(by: 1.0 / 30.0) }

            Text(formatTime(editor.playback.currentTime))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(CutTheme.textSecondary)
                .frame(width: 66, alignment: .trailing)

            // CapCut-like scrubber
            GeometryReader { geo in
                let dur = max(editor.playback.duration, 0.1)
                let p = min(1, max(0, editor.playback.currentTime / dur))
                ZStack(alignment: .leading) {
                    Capsule().fill(CutTheme.surfaceHover).frame(height: 4)
                    Capsule()
                        .fill(CutTheme.accentGradient)
                        .frame(width: max(4, geo.size.width * p), height: 4)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .shadow(color: CutTheme.accent.opacity(0.5), radius: 4)
                        .offset(x: max(0, geo.size.width * p - 6))
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { g in
                            let np = min(1, max(0, g.location.x / geo.size.width))
                            editor.playback.seek(to: np * dur)
                        }
                )
            }
            .frame(height: 20)

            Text(formatTime(editor.playback.duration))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(CutTheme.textTertiary)
                .frame(width: 66, alignment: .leading)

            if editor.playback.isReady {
                Circle()
                    .fill(CutTheme.accentGreen)
                    .frame(width: 6, height: 6)
                    .shadow(color: CutTheme.accentGreen.opacity(0.6), radius: 3)
                    .help("Player ready")
            } else if editor.playback.player.currentItem != nil {
                ProgressView().controlSize(.mini)
            }

            if let err = editor.playback.lastError {
                Text(err)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(CutTheme.danger)
                    .lineLimit(1)
                    .frame(maxWidth: 140)
            }

            HStack(spacing: 4) {
                Image(systemName: "minus.magnifyingglass").font(.system(size: 10))
                Slider(value: $editor.timelineZoom, in: 0.4...3)
                    .frame(width: 72)
                    .controlSize(.mini)
                    .tint(CutTheme.accent)
                Image(systemName: "plus.magnifyingglass").font(.system(size: 10))
            }
            .foregroundStyle(CutTheme.textTertiary)
        }
        .buttonStyle(.plain)
        .foregroundStyle(CutTheme.textSecondary)
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(
            CutTheme.surface
                .overlay(alignment: .top) {
                    Rectangle().fill(CutTheme.border).frame(height: 1)
                }
        )
    }

    private func transportBtn(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(CutTheme.textSecondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(CutTheme.surfaceHover)
                )
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ t: Double) -> String {
        guard t.isFinite else { return "0:00" }
        let total = Int(t)
        let m = total / 60
        let s = total % 60
        let f = Int((t - Double(total)) * 30)
        return String(format: "%d:%02d.%02d", m, s, f)
    }
}
