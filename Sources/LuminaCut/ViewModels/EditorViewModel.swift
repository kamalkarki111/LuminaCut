import Foundation
import AppKit
import AVFoundation
import Combine
import UniformTypeIdentifiers

@MainActor
final class EditorViewModel: ObservableObject {
    @Published var project = VideoProject()
    @Published var selectedClipID: UUID?
    @Published var selectedTrackID: UUID?
    @Published var selectedTool: VideoTool = .select
    @Published var selectedCategory: ToolCategory = .edit
    @Published var statusMessage = "Import media to start editing"
    @Published var isRebuilding = false
    @Published var exportProgress: Double?
    @Published var exportPreset: ExportPreset = .high1080
    @Published var timelineZoom: CGFloat = 1.0
    @Published var snapEnabled = true
    @Published var showChat = true

    let playback = PlaybackController()
    let history = HistoryManager()

    private var rebuildTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    var canUndo: Bool { history.canUndo }
    var canRedo: Bool { history.canRedo }

    var selectedClip: TimelineClip? {
        guard let id = selectedClipID else { return nil }
        for track in project.tracks {
            if let c = track.clips.first(where: { $0.id == id }) { return c }
        }
        return nil
    }

    var pixelsPerSecond: CGFloat {
        CutTheme.pixelsPerSecond * timelineZoom
    }

    init() {
        project.ensureDefaultTracks()
        history.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        playback.objectWillChange.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
    }

    // MARK: - Media

    func importMedia() {
        Task {
            let assets = await MediaImporter.importFiles()
            guard !assets.isEmpty else { return }
            commit {
                $0.mediaLibrary.append(contentsOf: assets)
            }
            statusMessage = "Imported \(assets.count) item(s)"
        }
    }

    func addMediaToTimeline(_ asset: MediaAsset, at time: Double? = nil) {
        commit { project in
            let start = time ?? playback.currentTime
            // Use the actual media duration (images are converted to short movies on import)
            let mediaDur = max(0.5, asset.durationSeconds)
            var clip = TimelineClip(
                mediaID: asset.id,
                kind: asset.kind == .audio ? .audio : (asset.kind == .image ? .image : .video),
                startOnTimeline: max(0, start),
                sourceIn: 0,
                sourceOut: mediaDur
            )

            let trackKind: TrackKind = {
                switch asset.kind {
                case .video, .image: return .video
                case .audio: return .music
                }
            }()

            if let idx = project.tracks.firstIndex(where: { $0.kind == trackKind }) {
                // Place after last clip if overlapping
                let lastEnd = project.tracks[idx].clips.map(\.endOnTimeline).max() ?? 0
                if project.tracks[idx].clips.contains(where: { rangesOverlap(clip.startOnTimeline, clip.endOnTimeline, $0.startOnTimeline, $0.endOnTimeline) }) {
                    clip.startOnTimeline = lastEnd
                }
                project.tracks[idx].clips.append(clip)
                selectedClipID = clip.id
                selectedTrackID = project.tracks[idx].id
            }
        }
        statusMessage = "Added \(asset.name) — building preview…"
        scheduleRebuild(immediate: true)
    }

    func addTextClip(text: String = "Text", duration: Double = 3) {
        commit { project in
            guard let idx = project.tracks.firstIndex(where: { $0.kind == .text }) else { return }
            let start = playback.currentTime
            let clip = TimelineClip(
                kind: .text,
                startOnTimeline: start,
                sourceIn: 0,
                sourceOut: duration,
                textContent: text
            )
            project.tracks[idx].clips.append(clip)
            selectedClipID = clip.id
            selectedTrackID = project.tracks[idx].id
            selectedTool = .text
        }
        scheduleRebuild()
    }

    // MARK: - Clip ops

    func selectClip(_ id: UUID?, trackID: UUID? = nil) {
        selectedClipID = id
        if let trackID { selectedTrackID = trackID }
    }

    func updateSelectedClip(_ mutate: (inout TimelineClip) -> Void) {
        guard let id = selectedClipID else { return }
        commit { project in
            for t in project.tracks.indices {
                if let c = project.tracks[t].clips.firstIndex(where: { $0.id == id }) {
                    mutate(&project.tracks[t].clips[c])
                    return
                }
            }
        }
        scheduleRebuild()
    }

    func liveUpdateSelectedClip(_ mutate: (inout TimelineClip) -> Void) {
        guard let id = selectedClipID else { return }
        for t in project.tracks.indices {
            if let c = project.tracks[t].clips.firstIndex(where: { $0.id == id }) {
                mutate(&project.tracks[t].clips[c])
                objectWillChange.send()
                return
            }
        }
    }

    func splitAtPlayhead() {
        let t = playback.currentTime
        if selectedClipID == nil {
            for track in project.tracks where track.kind == .video || track.kind == .overlay {
                if let clip = track.clips.first(where: { t > $0.startOnTimeline + 0.05 && t < $0.endOnTimeline - 0.05 }) {
                    selectedClipID = clip.id
                    selectedTrackID = track.id
                    break
                }
            }
        }
        guard let id = selectedClipID else {
            statusMessage = "Select a clip to split"
            return
        }

        commit { project in
            for ti in project.tracks.indices {
                guard let ci = project.tracks[ti].clips.firstIndex(where: { $0.id == id }) else { continue }
                let clip = project.tracks[ti].clips[ci]
                guard t > clip.startOnTimeline + 0.05 && t < clip.endOnTimeline - 0.05 else { return }

                let ratio = (t - clip.startOnTimeline) / clip.timelineDuration
                let sourceSplit = clip.sourceIn + (clip.sourceOut - clip.sourceIn) * ratio

                var left = clip
                left.sourceOut = sourceSplit

                var right = clip
                right.id = UUID()
                right.startOnTimeline = t
                right.sourceIn = sourceSplit

                project.tracks[ti].clips[ci] = left
                project.tracks[ti].clips.append(right)
                selectedClipID = right.id
                return
            }
        }
        statusMessage = "Split clip"
        scheduleRebuild()
    }

    func deleteSelected() {
        guard let id = selectedClipID else { return }
        commit { project in
            for ti in project.tracks.indices {
                project.tracks[ti].clips.removeAll { $0.id == id }
            }
        }
        selectedClipID = nil
        statusMessage = "Deleted clip"
        scheduleRebuild()
    }

    func duplicateSelected() {
        guard let id = selectedClipID else { return }
        commit { project in
            for ti in project.tracks.indices {
                guard let ci = project.tracks[ti].clips.firstIndex(where: { $0.id == id }) else { continue }
                var copy = project.tracks[ti].clips[ci]
                copy.id = UUID()
                copy.startOnTimeline = project.tracks[ti].clips[ci].endOnTimeline
                project.tracks[ti].clips.append(copy)
                selectedClipID = copy.id
                return
            }
        }
        scheduleRebuild()
    }

    func moveClip(_ id: UUID, toTimelineTime start: Double, trackID: UUID?) {
        commit { project in
            var clip: TimelineClip?
            var fromTrack: Int?
            for ti in project.tracks.indices {
                if let ci = project.tracks[ti].clips.firstIndex(where: { $0.id == id }) {
                    clip = project.tracks[ti].clips.remove(at: ci)
                    fromTrack = ti
                    break
                }
            }
            guard var clip else { return }
            clip.startOnTimeline = max(0, start)
            if let trackID, let ti = project.tracks.firstIndex(where: { $0.id == trackID }) {
                project.tracks[ti].clips.append(clip)
            } else if let fromTrack {
                project.tracks[fromTrack].clips.append(clip)
            }
        }
        scheduleRebuild()
    }

    func applyLook(_ look: LookPreset) {
        updateSelectedClip { clip in
            clip.lookID = look.id
            clip.effects.apply(patch: look.patch)
        }
        statusMessage = "Applied look: \(look.name)"
    }

    func setTransitionOut(_ type: TransitionType) {
        updateSelectedClip { $0.transitionOut = type }
    }

    func setTransitionIn(_ type: TransitionType) {
        updateSelectedClip { $0.transitionIn = type }
    }

    // MARK: - AI

    func applyAICommand(_ command: AIVideoCommand) {
        if let toolName = command.openTool, let tool = VideoTool(rawValue: toolName) {
            selectedTool = tool
            selectedCategory = tool.category
        }

        var labels: [String] = []
        for action in command.actions {
            applyAIAction(action, label: &labels)
        }
        if !labels.isEmpty {
            statusMessage = labels.joined(separator: " · ")
            scheduleRebuild()
        }
    }

    private func applyAIAction(_ action: AIVideoCommand.AIAction, label: inout [String]) {
        switch action.type {
        case "split_at_playhead":
            splitAtPlayhead(); label.append("Split")
        case "delete_selected":
            deleteSelected(); label.append("Delete")
        case "duplicate_clip":
            duplicateSelected(); label.append("Duplicate")
        case "set_speed":
            if let v = action.value {
                updateSelectedClip { $0.speed = min(4, max(0.25, v)) }
                label.append(String(format: "Speed %.2f×", v))
            }
        case "set_volume":
            if let v = action.value {
                updateSelectedClip { $0.volume = min(1, max(0, v)) }
                label.append("Volume")
            }
        case "set_opacity":
            if let v = action.value {
                updateSelectedClip { $0.opacity = min(1, max(0, v)) }
                label.append("Opacity")
            }
        case "set_scale":
            if let v = action.value {
                updateSelectedClip { $0.scale = min(3, max(0.1, v)) }
                label.append("Scale")
            }
        case "mute_toggle":
            updateSelectedClip { $0.isMuted.toggle() }
            label.append("Mute toggle")
        case "apply_color":
            if let values = action.values {
                updateSelectedClip { $0.effects.apply(patch: values) }
                label.append("Color grade")
            }
        case "apply_look":
            if let id = action.stringValues?["look_id"], let look = LookPreset.find(id) {
                applyLook(look)
                label.append(look.name)
            }
        case "set_transition_out":
            if let name = action.stringValues?["transition"], let t = TransitionType(rawValue: name) {
                updateSelectedClip {
                    $0.transitionOut = t
                    if let d = action.value { $0.transitionDuration = d }
                }
                label.append("Transition out")
            }
        case "set_transition_in":
            if let name = action.stringValues?["transition"], let t = TransitionType(rawValue: name) {
                updateSelectedClip {
                    $0.transitionIn = t
                    if let d = action.value { $0.transitionDuration = d }
                }
                label.append("Transition in")
            }
        case "add_text":
            let text = action.stringValues?["text"] ?? "Text"
            let dur = action.value ?? 3
            addTextClip(text: text, duration: dur)
            label.append("Text")
        case "set_canvas":
            if let a = action.stringValues?["aspect"], let aspect = CanvasAspect(rawValue: a) {
                commit { $0.aspect = aspect }
                label.append("Canvas \(aspect.title)")
                scheduleRebuild()
            }
        case "trim_start":
            if let v = action.value {
                updateSelectedClip { c in
                    c.sourceIn = min(c.sourceOut - 0.1, c.sourceIn + v)
                }
                label.append("Trim start")
            }
        case "trim_end":
            if let v = action.value {
                updateSelectedClip { c in
                    c.sourceOut = max(c.sourceIn + 0.1, c.sourceOut - v)
                }
                label.append("Trim end")
            }
        case "fade_audio":
            updateSelectedClip { c in
                if let fi = action.values?["fadeIn"] { c.fadeIn = fi }
                if let fo = action.values?["fadeOut"] { c.fadeOut = fo }
            }
            label.append("Audio fade")
        case "reset_color":
            updateSelectedClip {
                $0.effects = .identity
                $0.lookID = nil
            }
            label.append("Reset color")
        case "zoom_to_fill":
            updateSelectedClip { $0.scale = 1.15 }
            label.append("Zoom fill")
        case "export_hint":
            selectedTool = .export
            selectedCategory = .project
        default:
            break
        }
    }

    func projectSummaryForAI() -> String {
        let clipCount = project.tracks.reduce(0) { $0 + $1.clips.count }
        let selected: String = {
            guard let c = selectedClip else { return "none" }
            return "id=\(c.id.uuidString.prefix(8)) kind=\(c.kind.rawValue) start=\(String(format: "%.2f", c.startOnTimeline))s dur=\(String(format: "%.2f", c.timelineDuration))s speed=\(c.speed) vol=\(c.volume)"
        }()
        return """
        Project: \(project.name)
        Canvas: \(project.aspect.rawValue) (\(project.aspect.title))
        FPS: \(project.frameRate)
        Media library: \(project.mediaLibrary.count) items
        Timeline clips: \(clipCount)
        Duration: \(String(format: "%.2f", project.totalDurationSeconds))s
        Playhead: \(String(format: "%.2f", playback.currentTime))s
        Selected clip: \(selected)
        """
    }

    // MARK: - History

    func commit(_ mutate: (inout VideoProject) -> Void) {
        history.push(project)
        mutate(&project)
    }

    func undo() {
        guard let prev = history.undo(current: project) else { return }
        project = prev
        scheduleRebuild()
        statusMessage = "Undo"
    }

    func redo() {
        guard let next = history.redo(current: project) else { return }
        project = next
        scheduleRebuild()
        statusMessage = "Redo"
    }

    // MARK: - Composition / Playback

    /// Debounced rebuild for rapid edits. Use `immediate: true` after adding media
    /// so Play works right away.
    func scheduleRebuild(immediate: Bool = false) {
        rebuildTask?.cancel()
        rebuildTask = Task {
            if !immediate {
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
            guard !Task.isCancelled else { return }
            await rebuildComposition()
        }
    }

    func rebuildComposition() async {
        let hasPlayable = project.tracks.contains { track in
            track.clips.contains { $0.kind == .video || $0.kind == .image || $0.kind == .audio }
        }
        guard hasPlayable else {
            playback.clear()
            statusMessage = "Import media to start editing"
            return
        }
        isRebuilding = true
        let wasPlaying = playback.isPlaying
        do {
            let built = try await CompositionBuilder.shared.build(project: project)
            guard !Task.isCancelled else {
                isRebuilding = false
                return
            }
            let t = playback.currentTime
            print("[LuminaCut] rebuild: \(built.diagnostics)")
            playback.load(
                composition: built.composition,
                videoComposition: built.videoComposition,
                audioMix: built.audioMix,
                duration: built.duration
            )
            // Wait briefly for the player item to become ready
            for _ in 0..<40 {
                if playback.isReady || playback.lastError != nil { break }
                try? await Task.sleep(nanoseconds: 25_000_000)
            }
            if t > 0.05 && t < playback.duration - 0.05 {
                playback.seek(to: t)
            }
            if let err = playback.lastError {
                statusMessage = "Player: \(err)"
            } else {
                statusMessage = "Ready · \(String(format: "%.1fs", playback.duration)) · press Play"
            }
            if wasPlaying {
                playback.play()
            }
        } catch {
            statusMessage = "Preview failed: \(error.localizedDescription)"
            print("[LuminaCut] rebuild error: \(error)")
            playback.clear()
        }
        isRebuilding = false
    }

    // MARK: - Export

    func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.mpeg4Movie]
        panel.nameFieldStringValue = "\(project.name).mp4"
        panel.canCreateDirectories = true
        panel.title = "Export Video"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        Task {
            exportProgress = 0
            statusMessage = "Exporting…"
            do {
                let built = try await CompositionBuilder.shared.build(project: project)
                try await ExportService.export(
                    composition: built.composition,
                    videoComposition: built.videoComposition,
                    audioMix: built.audioMix,
                    preset: exportPreset,
                    to: url
                ) { [weak self] p in
                    self?.exportProgress = p
                }
                exportProgress = nil
                statusMessage = "Exported \(url.lastPathComponent)"
            } catch {
                exportProgress = nil
                statusMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    func newProject() {
        history.clear()
        project = VideoProject()
        project.ensureDefaultTracks()
        selectedClipID = nil
        playback.player.replaceCurrentItem(with: nil)
        playback.currentTime = 0
        playback.duration = 0
        statusMessage = "New project"
    }

}

func rangesOverlap(_ a0: Double, _ a1: Double, _ b0: Double, _ b1: Double) -> Bool {
    a0 < b1 && b0 < a1
}
