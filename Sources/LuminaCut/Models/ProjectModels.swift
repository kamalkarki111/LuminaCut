import Foundation
import CoreGraphics
import AVFoundation
import AppKit

// MARK: - Canvas / Project

enum CanvasAspect: String, CaseIterable, Identifiable, Codable {
    case landscape16x9
    case portrait9x16
    case square1x1
    case landscape4x3
    case portrait4x5
    case cinematic21x9

    var id: String { rawValue }

    var title: String {
        switch self {
        case .landscape16x9: return "16:9"
        case .portrait9x16: return "9:16"
        case .square1x1: return "1:1"
        case .landscape4x3: return "4:3"
        case .portrait4x5: return "4:5"
        case .cinematic21x9: return "21:9"
        }
    }

    var subtitle: String {
        switch self {
        case .landscape16x9: return "YouTube / Landscape"
        case .portrait9x16: return "Reels / TikTok / Shorts"
        case .square1x1: return "Instagram Feed"
        case .landscape4x3: return "Classic"
        case .portrait4x5: return "IG Portrait"
        case .cinematic21x9: return "Cinema"
        }
    }

    /// Width / height
    var ratio: CGFloat {
        switch self {
        case .landscape16x9: return 16/9
        case .portrait9x16: return 9/16
        case .square1x1: return 1
        case .landscape4x3: return 4/3
        case .portrait4x5: return 4/5
        case .cinematic21x9: return 21/9
        }
    }

    func renderSize(longEdge: CGFloat = 1920) -> CGSize {
        if ratio >= 1 {
            return CGSize(width: longEdge, height: (longEdge / ratio).rounded())
        } else {
            return CGSize(width: (longEdge * ratio).rounded(), height: longEdge)
        }
    }
}

struct VideoProject: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String = "Untitled Project"
    var createdAt: Date = Date()
    var aspect: CanvasAspect = .portrait9x16
    var frameRate: Double = 30
    var mediaLibrary: [MediaAsset] = []
    var tracks: [TimelineTrack] = TimelineTrack.defaultTracks()
    var backgroundColorHex: String = "000000"

    var totalDuration: CMTime {
        tracks.map(\.duration).max() ?? .zero
    }

    var totalDurationSeconds: Double {
        CMTimeGetSeconds(totalDuration)
    }

    mutating func ensureDefaultTracks() {
        if tracks.isEmpty { tracks = TimelineTrack.defaultTracks() }
    }
}

// MARK: - Media

enum MediaKind: String, Codable, CaseIterable {
    case video, image, audio
}

struct MediaAsset: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var name: String
    var kind: MediaKind
    var filePath: String
    var durationSeconds: Double
    var width: Int
    var height: Int
    var hasAudio: Bool
    var thumbnailPath: String?

    var url: URL { URL(fileURLWithPath: filePath) }

    var duration: CMTime {
        CMTime(seconds: durationSeconds, preferredTimescale: 600)
    }
}

// MARK: - Tracks & Clips

enum TrackKind: String, Codable, CaseIterable, Identifiable {
    case video
    case overlay
    case text
    case audio
    case music
    case effect

    var id: String { rawValue }

    var title: String {
        switch self {
        case .video: return "Video"
        case .overlay: return "Overlay"
        case .text: return "Text"
        case .audio: return "Audio"
        case .music: return "Music"
        case .effect: return "Effects"
        }
    }

    var colorHex: String {
        switch self {
        case .video: return "5B8CFF"
        case .overlay: return "A78BFA"
        case .text: return "F472B6"
        case .audio: return "34D399"
        case .music: return "FBBF24"
        case .effect: return "22D3EE"
        }
    }

    var icon: String {
        switch self {
        case .video: return "film"
        case .overlay: return "rectangle.on.rectangle"
        case .text: return "textformat"
        case .audio: return "waveform"
        case .music: return "music.note"
        case .effect: return "sparkles"
        }
    }
}

struct TimelineTrack: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var kind: TrackKind
    var name: String
    var isLocked: Bool = false
    var isMuted: Bool = false
    var isHidden: Bool = false
    var clips: [TimelineClip] = []

    var duration: CMTime {
        clips.map(\.endTime).max() ?? .zero
    }

    static func defaultTracks() -> [TimelineTrack] {
        [
            TimelineTrack(kind: .video, name: "Main Video"),
            TimelineTrack(kind: .overlay, name: "Overlay"),
            TimelineTrack(kind: .text, name: "Text"),
            TimelineTrack(kind: .effect, name: "Effects"),
            TimelineTrack(kind: .audio, name: "Audio"),
            TimelineTrack(kind: .music, name: "Music")
        ]
    }
}

struct TimelineClip: Identifiable, Equatable, Codable {
    var id: UUID = UUID()
    var mediaID: UUID?
    var kind: ClipKind = .video

    /// Position on the timeline (seconds)
    var startOnTimeline: Double = 0
    /// Source in-point (seconds into media)
    var sourceIn: Double = 0
    /// Source out-point (seconds into media)
    var sourceOut: Double = 0
    /// Playback speed (1.0 = normal)
    var speed: Double = 1.0
    /// Volume 0...1 (audio/video with audio)
    var volume: Double = 1.0
    var fadeIn: Double = 0
    var fadeOut: Double = 0
    var isMuted: Bool = false

    // Transform
    var scale: Double = 1.0
    var positionX: Double = 0.5   // 0...1 normalized
    var positionY: Double = 0.5
    var rotation: Double = 0      // degrees
    var opacity: Double = 1.0
    var flipH: Bool = false
    var flipV: Bool = false
    var cropLeft: Double = 0
    var cropRight: Double = 0
    var cropTop: Double = 0
    var cropBottom: Double = 0

    // Color / filter
    var effects: ClipEffects = .identity
    var lookID: String? = nil
    var transitionIn: TransitionType = .none
    var transitionOut: TransitionType = .none
    var transitionDuration: Double = 0.4

    // Text-specific
    var textContent: String = ""
    var textFontSize: Double = 48
    var textColorHex: String = "FFFFFF"
    var textAlignment: TextAlign = .center
    var textBold: Bool = true

    // Effect clip
    var effectPreset: EffectPreset = .none

    enum ClipKind: String, Codable {
        case video, image, audio, text, effect
    }

    enum TextAlign: String, Codable, CaseIterable {
        case left, center, right
    }

    /// Duration on timeline after speed adjustment
    var timelineDuration: Double {
        let sourceDur = max(0.01, sourceOut - sourceIn)
        return sourceDur / max(0.05, speed)
    }

    var endOnTimeline: Double {
        startOnTimeline + timelineDuration
    }

    var startTime: CMTime {
        CMTime(seconds: startOnTimeline, preferredTimescale: 600)
    }

    var endTime: CMTime {
        CMTime(seconds: endOnTimeline, preferredTimescale: 600)
    }

    var sourceDuration: CMTime {
        CMTime(seconds: max(0.01, sourceOut - sourceIn), preferredTimescale: 600)
    }
}

// MARK: - Effects

struct ClipEffects: Equatable, Codable {
    var brightness: Double = 0      // -1...1
    var contrast: Double = 0
    var saturation: Double = 0
    var warmth: Double = 0
    var highlights: Double = 0
    var shadows: Double = 0
    var vignette: Double = 0
    var blur: Double = 0
    var sharpen: Double = 0
    var fade: Double = 0
    var blackAndWhite: Bool = false
    var mirror: Bool = false

    static let identity = ClipEffects()
    var isIdentity: Bool { self == .identity }

    mutating func apply(patch: [String: Double]) {
        func c(_ v: Double, _ a: Double, _ b: Double) -> Double { min(b, max(a, v)) }
        for (k, v) in patch {
            switch k {
            case "brightness": brightness = c(v, -1, 1)
            case "contrast": contrast = c(v, -1, 1)
            case "saturation": saturation = c(v, -1, 1)
            case "warmth": warmth = c(v, -1, 1)
            case "highlights": highlights = c(v, -1, 1)
            case "shadows": shadows = c(v, -1, 1)
            case "vignette": vignette = c(v, 0, 1)
            case "blur": blur = c(v, 0, 1)
            case "sharpen": sharpen = c(v, 0, 1)
            case "fade": fade = c(v, 0, 1)
            case "blackAndWhite": blackAndWhite = v >= 0.5
            case "mirror": mirror = v >= 0.5
            case "volume": break
            case "speed": break
            case "opacity": break
            case "scale": break
            default: break
            }
        }
    }
}

enum TransitionType: String, CaseIterable, Identifiable, Codable {
    case none
    case crossDissolve
    case fadeToBlack
    case fadeToWhite
    case wipeLeft
    case wipeRight
    case slideUp
    case zoomIn
    case flash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .crossDissolve: return "Dissolve"
        case .fadeToBlack: return "Fade Black"
        case .fadeToWhite: return "Fade White"
        case .wipeLeft: return "Wipe Left"
        case .wipeRight: return "Wipe Right"
        case .slideUp: return "Slide Up"
        case .zoomIn: return "Zoom"
        case .flash: return "Flash"
        }
    }

    var icon: String {
        switch self {
        case .none: return "xmark"
        case .crossDissolve: return "circle.lefthalf.filled"
        case .fadeToBlack: return "moon.fill"
        case .fadeToWhite: return "sun.max.fill"
        case .wipeLeft: return "arrow.left"
        case .wipeRight: return "arrow.right"
        case .slideUp: return "arrow.up"
        case .zoomIn: return "plus.magnifyingglass"
        case .flash: return "bolt.fill"
        }
    }
}

enum EffectPreset: String, CaseIterable, Identifiable, Codable {
    case none
    case glitch
    case vhs
    case filmGrain
    case blurOut
    case shake
    case flash
    case zoomPulse
    case duotone
    case neon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "None"
        case .glitch: return "Glitch"
        case .vhs: return "VHS"
        case .filmGrain: return "Film Grain"
        case .blurOut: return "Blur Out"
        case .shake: return "Shake"
        case .flash: return "Flash"
        case .zoomPulse: return "Zoom Pulse"
        case .duotone: return "Duotone"
        case .neon: return "Neon"
        }
    }
}

struct LookPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let patch: [String: Double]
    let colorHex: String

    static let all: [LookPreset] = [
        LookPreset(id: "cinematic", name: "Cinematic", patch: ["contrast": 0.2, "saturation": -0.05, "warmth": 0.1, "vignette": 0.3, "shadows": 0.1], colorHex: "38BDF8"),
        LookPreset(id: "vivid", name: "Vivid", patch: ["saturation": 0.35, "contrast": 0.15, "brightness": 0.05], colorHex: "F472B6"),
        LookPreset(id: "noir", name: "Noir", patch: ["blackAndWhite": 1, "contrast": 0.35, "vignette": 0.4], colorHex: "A1A1AA"),
        LookPreset(id: "warm_film", name: "Warm Film", patch: ["warmth": 0.4, "fade": 0.2, "saturation": -0.05, "vignette": 0.15], colorHex: "FB923C"),
        LookPreset(id: "cool", name: "Cool", patch: ["warmth": -0.35, "contrast": 0.1, "saturation": 0.05], colorHex: "67E8F9"),
        LookPreset(id: "vintage", name: "Vintage", patch: ["fade": 0.35, "warmth": 0.2, "saturation": -0.15, "vignette": 0.25], colorHex: "FCD34D"),
        LookPreset(id: "drama", name: "Drama", patch: ["contrast": 0.35, "shadows": -0.15, "highlights": -0.1, "vignette": 0.35], colorHex: "F87171"),
        LookPreset(id: "pastel", name: "Pastel", patch: ["saturation": -0.2, "fade": 0.2, "brightness": 0.08], colorHex: "F0ABFC"),
        LookPreset(id: "teal_orange", name: "Teal & Orange", patch: ["contrast": 0.18, "warmth": 0.08, "saturation": 0.1, "shadows": 0.1], colorHex: "2DD4BF"),
        LookPreset(id: "matte", name: "Matte", patch: ["fade": 0.4, "contrast": -0.05, "saturation": -0.1], colorHex: "94A3B8"),
        LookPreset(id: "bright", name: "Bright Pop", patch: ["brightness": 0.15, "saturation": 0.25, "contrast": 0.1], colorHex: "FDE68A"),
        LookPreset(id: "moody", name: "Moody", patch: ["brightness": -0.1, "contrast": 0.2, "saturation": -0.15, "vignette": 0.4, "shadows": 0.15], colorHex: "818CF8"),
    ]

    static func find(_ id: String?) -> LookPreset? {
        guard let id else { return nil }
        return all.first { $0.id == id }
    }
}

// MARK: - Editor tools

enum VideoTool: String, CaseIterable, Identifiable {
    case select, cut, trim, speed, volume
    case transform, color, looks, transitions, effects
    case text, stickers, audio, canvas, export

    var id: String { rawValue }

    var title: String {
        switch self {
        case .select: return "Select"
        case .cut: return "Split"
        case .trim: return "Trim"
        case .speed: return "Speed"
        case .volume: return "Volume"
        case .transform: return "Transform"
        case .color: return "Color"
        case .looks: return "Looks"
        case .transitions: return "Transitions"
        case .effects: return "Effects"
        case .text: return "Text"
        case .stickers: return "Overlay"
        case .audio: return "Audio"
        case .canvas: return "Canvas"
        case .export: return "Export"
        }
    }

    var icon: String {
        switch self {
        case .select: return "cursorarrow"
        case .cut: return "scissors"
        case .trim: return "timeline.selection"
        case .speed: return "gauge.with.dots.needle.67percent"
        case .volume: return "speaker.wave.2"
        case .transform: return "arrow.up.left.and.arrow.down.right"
        case .color: return "slider.horizontal.3"
        case .looks: return "camera.filters"
        case .transitions: return "rectangle.on.rectangle.angled"
        case .effects: return "sparkles"
        case .text: return "textformat"
        case .stickers: return "face.smiling"
        case .audio: return "music.note.list"
        case .canvas: return "aspectratio"
        case .export: return "square.and.arrow.up"
        }
    }

    var category: ToolCategory {
        switch self {
        case .select, .cut, .trim, .speed, .volume: return .edit
        case .transform, .color, .looks: return .adjust
        case .transitions, .effects, .text, .stickers: return .creative
        case .audio, .canvas, .export: return .project
        }
    }
}

enum ToolCategory: String, CaseIterable, Identifiable {
    case edit, adjust, creative, project

    var id: String { rawValue }

    var title: String {
        switch self {
        case .edit: return "Edit"
        case .adjust: return "Adjust"
        case .creative: return "Creative"
        case .project: return "Project"
        }
    }

    var icon: String {
        switch self {
        case .edit: return "scissors"
        case .adjust: return "slider.horizontal.3"
        case .creative: return "paintbrush.pointed"
        case .project: return "folder"
        }
    }
}

// MARK: - Chat / AI

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date
    var appliedActions: [String]

    enum Role: String, Codable { case user, assistant, system }

    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date(), appliedActions: [String] = []) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.appliedActions = appliedActions
    }
}

struct AIVideoCommand: Codable, Equatable {
    var reply: String
    var actions: [AIAction]
    var openTool: String?

    enum CodingKeys: String, CodingKey {
        case reply, actions
        case openTool = "open_tool"
    }

    init(reply: String = "", actions: [AIAction] = [], openTool: String? = nil) {
        self.reply = reply
        self.actions = actions
        self.openTool = openTool
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reply = try c.decodeIfPresent(String.self, forKey: .reply) ?? ""
        actions = try c.decodeIfPresent([AIAction].self, forKey: .actions) ?? []
        openTool = try c.decodeIfPresent(String.self, forKey: .openTool)
    }

    struct AIAction: Codable, Equatable {
        var type: String
        var clipID: String?
        var track: String?
        var value: Double?
        var stringValue: String?
        var values: [String: Double]?
        var stringValues: [String: String]?

        enum CodingKeys: String, CodingKey {
            case type
            case clipID = "clip_id"
            case track, value
            case stringValue = "string_value"
            case values
            case stringValues = "string_values"
        }

        init(type: String, clipID: String? = nil, track: String? = nil, value: Double? = nil, stringValue: String? = nil, values: [String: Double]? = nil, stringValues: [String: String]? = nil) {
            self.type = type
            self.clipID = clipID
            self.track = track
            self.value = value
            self.stringValue = stringValue
            self.values = values
            self.stringValues = stringValues
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            type = try c.decode(String.self, forKey: .type)
            clipID = try c.decodeIfPresent(String.self, forKey: .clipID)
            track = try c.decodeIfPresent(String.self, forKey: .track)
            value = try c.decodeIfPresent(Double.self, forKey: .value)
            stringValue = try c.decodeIfPresent(String.self, forKey: .stringValue)
            values = try c.decodeIfPresent([String: Double].self, forKey: .values)
            stringValues = try c.decodeIfPresent([String: String].self, forKey: .stringValues)
        }
    }
}

// MARK: - CMTime Codable helpers via seconds only in models above

extension VideoProject {
    enum CodingKeys: String, CodingKey {
        case id, name, createdAt, aspect, frameRate, mediaLibrary, tracks, backgroundColorHex
    }
}
