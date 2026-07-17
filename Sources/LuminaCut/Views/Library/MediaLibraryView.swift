import SwiftUI
import AppKit

struct MediaLibraryView: View {
    @EnvironmentObject private var editor: EditorViewModel
    @State private var thumbnails: [UUID: NSImage] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Media")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(CutTheme.textPrimary)
                Spacer()
                Button {
                    editor.importMedia()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(CutTheme.accentGradient))
                        .shadow(color: CutTheme.accent.opacity(0.4), radius: 6)
                }
                .buttonStyle(.plain)
                .help("Import media")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Rectangle().fill(CutTheme.border).frame(height: 1)

            if editor.project.mediaLibrary.isEmpty {
                VStack(spacing: 14) {
                    Spacer()
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .foregroundStyle(CutTheme.borderStrong)
                            .frame(width: 120, height: 90)
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 26, weight: .light))
                            .foregroundStyle(CutTheme.textTertiary)
                    }
                    Text("Import videos, photos & audio")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(CutTheme.textTertiary)
                        .multilineTextAlignment(.center)
                    Button("Import Media") { editor.importMedia() }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(CutTheme.accentGradient))
                        .shadow(color: CutTheme.accent.opacity(0.35), radius: 8, y: 2)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(editor.project.mediaLibrary) { asset in
                            MediaCard(asset: asset, thumbnail: thumbnails[asset.id]) {
                                editor.addMediaToTimeline(asset)
                            }
                            .onAppear { loadThumb(asset) }
                        }
                    }
                    .padding(12)
                }
            }
        }
        .background(CutTheme.surface)
    }

    private func loadThumb(_ asset: MediaAsset) {
        guard thumbnails[asset.id] == nil else { return }
        Task { @MainActor in
            if let img = await MediaImporter.generateThumbnail(for: asset) {
                thumbnails[asset.id] = img
            }
        }
    }
}

struct MediaCard: View {
    let asset: MediaAsset
    let thumbnail: NSImage?
    let onAdd: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: onAdd) {
            VStack(alignment: .leading, spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(CutTheme.surfaceHover)
                        .aspectRatio(16 / 10, contentMode: .fit)

                    if let thumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .aspectRatio(16 / 10, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        Image(systemName: icon)
                            .font(.system(size: 18))
                            .foregroundStyle(CutTheme.textTertiary)
                    }

                    VStack {
                        Spacer()
                        HStack {
                            Text(timeLabel)
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(.black.opacity(0.55)))
                            Spacer()
                            Image(systemName: "plus")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(4)
                                .background(Circle().fill(CutTheme.accent.opacity(0.9)))
                                .opacity(hover ? 1 : 0)
                        }
                        .padding(5)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(hover ? CutTheme.accent : CutTheme.border, lineWidth: hover ? 1.5 : 1)
                )
                .shadow(color: hover ? CutTheme.accent.opacity(0.25) : .clear, radius: 8)

                Text(asset.name)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(CutTheme.textSecondary)
                    .lineLimit(1)
            }
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
        .help("Click to add to timeline")
    }

    private var icon: String {
        switch asset.kind {
        case .video: return "film"
        case .image: return "photo"
        case .audio: return "waveform"
        }
    }

    private var timeLabel: String {
        if asset.kind == .image { return "IMG" }
        let s = Int(asset.durationSeconds)
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
