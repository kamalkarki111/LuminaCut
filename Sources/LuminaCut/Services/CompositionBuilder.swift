import Foundation
import AVFoundation
import AppKit

/// Builds a playable AVMutableComposition from the project timeline.
final class CompositionBuilder {
    static let shared = CompositionBuilder()

    struct BuiltTimeline {
        let composition: AVMutableComposition
        let videoComposition: AVMutableVideoComposition?
        let audioMix: AVAudioMix?
        let duration: CMTime
        let renderSize: CGSize
        let diagnostics: String
    }

    enum BuildError: LocalizedError {
        case noPlayableClips
        var errorDescription: String? { "No playable video/audio on the timeline" }
    }

    private struct Placed {
        let clip: TimelineClip
        let media: MediaAsset
        let track: AVMutableCompositionTrack
        let preferredTransform: CGAffineTransform
        let naturalSize: CGSize
        /// Where this clip is placed on the composition timeline (may be pulled earlier for dissolves).
        let timelineStart: Double
        let timelineEnd: Double
    }

    func build(project: VideoProject) async throws -> BuiltTimeline {
        let composition = AVMutableComposition()
        let renderSize = project.aspect.renderSize()
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(max(1, Int32(project.frameRate.rounded()))))

        var notes: [String] = []
        var maxEnd: Double = 0
        var videoCount = 0
        var audioCount = 0
        var placed: [Placed] = []

        // MARK: Video — one composition track per clip so transitions can blend
        let visualTracks = project.tracks.filter { ($0.kind == .video || $0.kind == .overlay) && !$0.isHidden }

        for track in visualTracks {
            let clips = track.clips
                .filter { $0.kind == .video || $0.kind == .image }
                .sorted { $0.startOnTimeline < $1.startOnTimeline }
            guard !clips.isEmpty else { continue }

            // Auto-overlap adjacent clips when a blend-style transition is set
            var effectiveStart: [UUID: Double] = [:]
            var effectiveEnd: [UUID: Double] = [:]
            for c in clips {
                effectiveStart[c.id] = c.startOnTimeline
                effectiveEnd[c.id] = c.endOnTimeline
            }
            for i in 0..<clips.count {
                let c = clips[i]
                guard Self.isBlendTransition(c.transitionOut), i + 1 < clips.count else { continue }
                let next = clips[i + 1]
                let fade = Self.fadeDuration(for: c, peer: next)
                let gap = next.startOnTimeline - c.endOnTimeline
                if gap < 0.12, fade > 0.04 {
                    // Pull next clip earlier so both layers exist during the dissolve
                    let pull = next.startOnTimeline - fade
                    effectiveStart[next.id] = min(effectiveStart[next.id] ?? next.startOnTimeline, max(0, pull))
                    notes.append("overlap \(c.transitionOut.title) \(String(format: "%.2f", fade))s")
                }
            }

            for clip in clips {
                guard let mediaID = clip.mediaID,
                      let media = project.mediaLibrary.first(where: { $0.id == mediaID }) else {
                    notes.append("Missing media ref")
                    continue
                }
                guard FileManager.default.fileExists(atPath: media.filePath) else {
                    notes.append("Missing file \(media.name)")
                    continue
                }

                let asset = AVURLAsset(url: media.url)
                guard let srcTrack = try? await asset.loadTracks(withMediaType: .video).first else {
                    notes.append("No video in \(media.name)")
                    continue
                }

                let preferred = (try? await srcTrack.load(.preferredTransform)) ?? .identity
                let natural = (try? await srcTrack.load(.naturalSize))
                    ?? CGSize(width: CGFloat(max(media.width, 1)), height: CGFloat(max(media.height, 1)))
                let assetDur = CMTimeGetSeconds((try? await asset.load(.duration)) ?? .zero)
                let safeDur = assetDur.isFinite && assetDur > 0.05 ? assetDur : media.durationSeconds

                let srcIn = min(max(0, clip.sourceIn), max(0, safeDur - 0.05))
                let srcOut = min(max(srcIn + 0.05, clip.sourceOut), safeDur)
                let sourceStart = CMTime(seconds: srcIn, preferredTimescale: 600)
                let sourceDuration = CMTime(seconds: max(0.05, srcOut - srcIn), preferredTimescale: 600)

                let tStart = effectiveStart[clip.id] ?? clip.startOnTimeline
                let tEnd = effectiveEnd[clip.id] ?? clip.endOnTimeline
                let insertAt = CMTime(seconds: max(0, tStart), preferredTimescale: 600)

                // Own track per clip → opacity/transform blends work during overlaps
                guard let compTrack = composition.addMutableTrack(
                    withMediaType: .video,
                    preferredTrackID: kCMPersistentTrackID_Invalid
                ) else { continue }

                do {
                    try compTrack.insertTimeRange(
                        CMTimeRange(start: sourceStart, duration: sourceDuration),
                        of: srcTrack,
                        at: insertAt
                    )
                    let targetTimelineDur = max(0.05, tEnd - tStart)
                    let rawSourceDur = max(0.05, srcOut - srcIn)
                    // Scale so source fills the effective timeline window (includes speed + overlap stretch)
                    let desired = targetTimelineDur / max(0.05, clip.speed) * clip.speed
                    // After insert, segment duration = sourceDuration; scale to timeline duration
                    if abs(CMTimeGetSeconds(sourceDuration) - targetTimelineDur) > 0.01 || abs(clip.speed - 1.0) > 0.01 {
                        let scaled = CMTime(seconds: targetTimelineDur, preferredTimescale: 600)
                        compTrack.scaleTimeRange(
                            CMTimeRange(start: insertAt, duration: sourceDuration),
                            toDuration: scaled
                        )
                    }
                    _ = rawSourceDur
                    _ = desired
                    compTrack.preferredTransform = preferred

                    maxEnd = max(maxEnd, tEnd)
                    videoCount += 1
                    placed.append(Placed(
                        clip: clip,
                        media: media,
                        track: compTrack,
                        preferredTransform: preferred,
                        naturalSize: natural,
                        timelineStart: tStart,
                        timelineEnd: tEnd
                    ))
                    let tin = clip.transitionIn != .none ? clip.transitionIn.title : "-"
                    let tout = clip.transitionOut != .none ? clip.transitionOut.title : "-"
                    notes.append("OK \(media.name) in=\(tin) out=\(tout)")
                } catch {
                    notes.append("Insert fail \(media.name): \(error.localizedDescription)")
                }
            }
        }

        // MARK: Audio
        var mixInputs: [AVMutableAudioMixInputParameters] = []
        let audioTracks = project.tracks.filter {
            !$0.isMuted && ($0.kind == .video || $0.kind == .audio || $0.kind == .music)
        }

        for track in audioTracks {
            let clips = track.clips.sorted { $0.startOnTimeline < $1.startOnTimeline }
            guard !clips.isEmpty else { continue }

            var pending: [(TimelineClip, MediaAsset, AVAssetTrack, CMTime, CMTime, CMTime)] = []

            for clip in clips {
                if clip.isMuted || clip.volume < 0.001 { continue }
                guard let mediaID = clip.mediaID,
                      let media = project.mediaLibrary.first(where: { $0.id == mediaID }),
                      media.hasAudio || media.kind == .audio else { continue }
                guard FileManager.default.fileExists(atPath: media.filePath) else { continue }

                let asset = AVURLAsset(url: media.url)
                guard let src = try? await asset.loadTracks(withMediaType: .audio).first else { continue }
                let assetDur = CMTimeGetSeconds((try? await asset.load(.duration)) ?? .zero)
                let safeDur = assetDur.isFinite && assetDur > 0.05 ? assetDur : media.durationSeconds

                let srcIn = min(max(0, clip.sourceIn), max(0, safeDur - 0.05))
                let srcOut = min(max(srcIn + 0.05, clip.sourceOut), safeDur)
                let insertAt = CMTime(seconds: max(0, clip.startOnTimeline), preferredTimescale: 600)
                let sourceDuration = CMTime(seconds: max(0.05, srcOut - srcIn), preferredTimescale: 600)
                pending.append((clip, media, src, CMTime(seconds: srcIn, preferredTimescale: 600), sourceDuration, insertAt))
            }

            guard !pending.isEmpty else { continue }
            guard let compAudio = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else { continue }

            let params = AVMutableAudioMixInputParameters(track: compAudio)
            var any = false

            for (clip, media, src, srcStart, sourceDuration, insertAt) in pending {
                do {
                    try compAudio.insertTimeRange(
                        CMTimeRange(start: srcStart, duration: sourceDuration),
                        of: src,
                        at: insertAt
                    )
                    if abs(clip.speed - 1.0) > 0.01 {
                        compAudio.scaleTimeRange(
                            CMTimeRange(start: insertAt, duration: sourceDuration),
                            toDuration: CMTime(seconds: clip.timelineDuration, preferredTimescale: 600)
                        )
                    }
                    // Soft audio fades matching video transitions
                    let vol = Float(min(1, max(0, clip.volume)))
                    params.setVolume(vol, at: insertAt)
                    if clip.transitionIn != .none || clip.fadeIn > 0.02 {
                        let fade = max(clip.fadeIn, clip.transitionIn != .none ? min(clip.transitionDuration, 0.8) : 0)
                        if fade > 0.02 {
                            let t0 = insertAt
                            let t1 = CMTime(seconds: CMTimeGetSeconds(insertAt) + fade, preferredTimescale: 600)
                            params.setVolumeRamp(fromStartVolume: 0, toEndVolume: vol, timeRange: CMTimeRange(start: t0, end: t1))
                        }
                    }
                    if clip.transitionOut != .none || clip.fadeOut > 0.02 {
                        let fade = max(clip.fadeOut, clip.transitionOut != .none ? min(clip.transitionDuration, 0.8) : 0)
                        if fade > 0.02 {
                            let end = clip.endOnTimeline
                            let t0 = CMTime(seconds: end - fade, preferredTimescale: 600)
                            let t1 = CMTime(seconds: end, preferredTimescale: 600)
                            params.setVolumeRamp(fromStartVolume: vol, toEndVolume: 0, timeRange: CMTimeRange(start: t0, end: t1))
                        }
                    }
                    any = true
                    audioCount += 1
                    maxEnd = max(maxEnd, clip.endOnTimeline)
                } catch {
                    notes.append("Audio fail \(media.name): \(error.localizedDescription)")
                }
            }
            if any { mixInputs.append(params) }
        }

        for track in project.tracks where track.kind == .text {
            for clip in track.clips { maxEnd = max(maxEnd, clip.endOnTimeline) }
        }

        guard videoCount > 0 || audioCount > 0 else { throw BuildError.noPlayableClips }

        let duration = CMTime(seconds: max(maxEnd, 0.1), preferredTimescale: 600)

        // MARK: Video composition + transitions
        var videoComposition: AVMutableVideoComposition?
        if videoCount > 0, !placed.isEmpty {
            let vcomp = AVMutableVideoComposition()
            vcomp.renderSize = renderSize
            vcomp.frameDuration = frameDuration

            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
            instruction.backgroundColor = CGColor(gray: 0, alpha: 1)

            // Layer order: later clips on top (higher index draws above)
            var layers: [AVVideoCompositionLayerInstruction] = []
            for item in placed {
                let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: item.track)
                let base = fitTransform(
                    naturalSize: item.naturalSize,
                    preferredTransform: item.preferredTransform,
                    renderSize: renderSize,
                    clip: item.clip
                )
                let start = CMTime(seconds: item.timelineStart, preferredTimescale: 600)
                let end = CMTime(seconds: item.timelineEnd, preferredTimescale: 600)

                layer.setTransform(base, at: start)
                layer.setOpacity(Float(item.clip.opacity), at: start)

                // Hide outside clip range (empty edits already empty, but opacity safety)
                if item.timelineStart > 0.01 {
                    layer.setOpacity(0, at: .zero)
                    layer.setOpacity(Float(item.clip.opacity), at: start)
                }

                applyTransitionIn(
                    layer: layer,
                    type: item.clip.transitionIn,
                    duration: item.clip.transitionDuration,
                    clipStart: item.timelineStart,
                    clipEnd: item.timelineEnd,
                    baseTransform: base,
                    opacity: Float(item.clip.opacity),
                    renderSize: renderSize
                )
                applyTransitionOut(
                    layer: layer,
                    type: item.clip.transitionOut,
                    duration: item.clip.transitionDuration,
                    clipStart: item.timelineStart,
                    clipEnd: item.timelineEnd,
                    baseTransform: base,
                    opacity: Float(item.clip.opacity),
                    renderSize: renderSize
                )

                _ = end
                layers.append(layer)
            }

            // Later layers on top for correct dissolve stacking
            instruction.layerInstructions = layers
            vcomp.instructions = [instruction]
            videoComposition = vcomp
        }

        var audioMix: AVAudioMix?
        if !mixInputs.isEmpty {
            let mix = AVMutableAudioMix()
            mix.inputParameters = mixInputs
            audioMix = mix
        }

        notes.append("built v=\(videoCount) a=\(audioCount) dur=\(String(format: "%.2f", maxEnd)) \(Int(renderSize.width))x\(Int(renderSize.height))")

        return BuiltTimeline(
            composition: composition,
            videoComposition: videoComposition,
            audioMix: audioMix,
            duration: duration,
            renderSize: renderSize,
            diagnostics: notes.joined(separator: " · ")
        )
    }

    // MARK: - Transition helpers

    private static func isBlendTransition(_ t: TransitionType) -> Bool {
        switch t {
        case .crossDissolve, .wipeLeft, .wipeRight, .slideUp, .zoomIn:
            return true
        default:
            return false
        }
    }

    private static func fadeDuration(for clip: TimelineClip, peer: TimelineClip? = nil) -> Double {
        var d = min(clip.transitionDuration, clip.timelineDuration * 0.45)
        if let peer {
            d = min(d, peer.timelineDuration * 0.45)
        }
        return max(0, d)
    }

    private func applyTransitionIn(
        layer: AVMutableVideoCompositionLayerInstruction,
        type: TransitionType,
        duration: Double,
        clipStart: Double,
        clipEnd: Double,
        baseTransform: CGAffineTransform,
        opacity: Float,
        renderSize: CGSize
    ) {
        guard type != .none else { return }
        let fade = min(duration, (clipEnd - clipStart) * 0.45)
        guard fade > 0.03 else { return }
        let t0 = CMTime(seconds: clipStart, preferredTimescale: 600)
        let t1 = CMTime(seconds: clipStart + fade, preferredTimescale: 600)
        let range = CMTimeRange(start: t0, end: t1)
        let full = CGRect(origin: .zero, size: renderSize)

        switch type {
        case .none:
            break
        case .crossDissolve, .fadeToBlack:
            layer.setOpacityRamp(fromStartOpacity: 0, toEndOpacity: opacity, timeRange: range)
        case .fadeToWhite:
            // Approximate white fade-in via overscale bloom + opacity
            layer.setOpacityRamp(fromStartOpacity: 0, toEndOpacity: opacity, timeRange: range)
            let big = baseTransform.concatenating(CGAffineTransform(scaleX: 1.15, y: 1.15)
                .concatenating(CGAffineTransform(translationX: -renderSize.width * 0.075, y: -renderSize.height * 0.075)))
            layer.setTransformRamp(fromStart: big, toEnd: baseTransform, timeRange: range)
        case .wipeLeft:
            // Reveal from left → right
            let empty = CGRect(x: 0, y: 0, width: 0.001, height: renderSize.height)
            layer.setCropRectangleRamp(fromStartCropRectangle: empty, toEndCropRectangle: full, timeRange: range)
            layer.setOpacity(opacity, at: t0)
        case .wipeRight:
            let empty = CGRect(x: renderSize.width, y: 0, width: 0.001, height: renderSize.height)
            layer.setCropRectangleRamp(fromStartCropRectangle: empty, toEndCropRectangle: full, timeRange: range)
            layer.setOpacity(opacity, at: t0)
        case .slideUp:
            let off = baseTransform.concatenating(CGAffineTransform(translationX: 0, y: renderSize.height))
            layer.setTransformRamp(fromStart: off, toEnd: baseTransform, timeRange: range)
            layer.setOpacityRamp(fromStartOpacity: 0, toEndOpacity: opacity, timeRange: range)
        case .zoomIn:
            let zoomed = scaleAroundCenter(baseTransform, scale: 1.6, renderSize: renderSize)
            layer.setTransformRamp(fromStart: zoomed, toEnd: baseTransform, timeRange: range)
            layer.setOpacityRamp(fromStartOpacity: 0, toEndOpacity: opacity, timeRange: range)
        case .flash:
            // Quick flash-in: full opacity after short black
            let mid = CMTime(seconds: clipStart + fade * 0.35, preferredTimescale: 600)
            layer.setOpacityRamp(fromStartOpacity: 0, toEndOpacity: opacity, timeRange: CMTimeRange(start: t0, end: mid))
            let bloom = scaleAroundCenter(baseTransform, scale: 1.08, renderSize: renderSize)
            layer.setTransformRamp(fromStart: bloom, toEnd: baseTransform, timeRange: CMTimeRange(start: t0, end: mid))
        }
    }

    private func applyTransitionOut(
        layer: AVMutableVideoCompositionLayerInstruction,
        type: TransitionType,
        duration: Double,
        clipStart: Double,
        clipEnd: Double,
        baseTransform: CGAffineTransform,
        opacity: Float,
        renderSize: CGSize
    ) {
        guard type != .none else { return }
        let fade = min(duration, (clipEnd - clipStart) * 0.45)
        guard fade > 0.03 else { return }
        let t0 = CMTime(seconds: clipEnd - fade, preferredTimescale: 600)
        let t1 = CMTime(seconds: clipEnd, preferredTimescale: 600)
        let range = CMTimeRange(start: t0, end: t1)
        let full = CGRect(origin: .zero, size: renderSize)

        switch type {
        case .none:
            break
        case .crossDissolve, .fadeToBlack:
            layer.setOpacityRamp(fromStartOpacity: opacity, toEndOpacity: 0, timeRange: range)
        case .fadeToWhite:
            layer.setOpacityRamp(fromStartOpacity: opacity, toEndOpacity: 0, timeRange: range)
            let big = scaleAroundCenter(baseTransform, scale: 1.2, renderSize: renderSize)
            layer.setTransformRamp(fromStart: baseTransform, toEnd: big, timeRange: range)
        case .wipeLeft:
            // Wipe away toward left
            let empty = CGRect(x: 0, y: 0, width: 0.001, height: renderSize.height)
            layer.setCropRectangleRamp(fromStartCropRectangle: full, toEndCropRectangle: empty, timeRange: range)
        case .wipeRight:
            let empty = CGRect(x: renderSize.width, y: 0, width: 0.001, height: renderSize.height)
            layer.setCropRectangleRamp(fromStartCropRectangle: full, toEndCropRectangle: empty, timeRange: range)
        case .slideUp:
            let off = baseTransform.concatenating(CGAffineTransform(translationX: 0, y: -renderSize.height))
            layer.setTransformRamp(fromStart: baseTransform, toEnd: off, timeRange: range)
            layer.setOpacityRamp(fromStartOpacity: opacity, toEndOpacity: 0, timeRange: range)
        case .zoomIn:
            let zoomed = scaleAroundCenter(baseTransform, scale: 1.8, renderSize: renderSize)
            layer.setTransformRamp(fromStart: baseTransform, toEnd: zoomed, timeRange: range)
            layer.setOpacityRamp(fromStartOpacity: opacity, toEndOpacity: 0, timeRange: range)
        case .flash:
            // Hold, then snap to white-ish (scale + fade)
            let hold = CMTime(seconds: clipEnd - fade * 0.4, preferredTimescale: 600)
            let flashRange = CMTimeRange(start: hold, end: t1)
            layer.setOpacityRamp(fromStartOpacity: opacity, toEndOpacity: 0, timeRange: flashRange)
            let bloom = scaleAroundCenter(baseTransform, scale: 1.25, renderSize: renderSize)
            layer.setTransformRamp(fromStart: baseTransform, toEnd: bloom, timeRange: flashRange)
        }
    }

    private func scaleAroundCenter(_ t: CGAffineTransform, scale: CGFloat, renderSize: CGSize) -> CGAffineTransform {
        let cx = renderSize.width / 2
        let cy = renderSize.height / 2
        return t
            .concatenating(CGAffineTransform(translationX: -cx, y: -cy))
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: cx, y: cy))
    }

    /// Correct orientation + aspect-fill into render canvas.
    func fitTransform(
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        renderSize: CGSize,
        clip: TimelineClip
    ) -> CGAffineTransform {
        let raw = CGSize(width: max(abs(naturalSize.width), 1), height: max(abs(naturalSize.height), 1))
        let orientedRect = CGRect(origin: .zero, size: raw).applying(preferredTransform)
        let upright = CGSize(width: max(abs(orientedRect.width), 1), height: max(abs(orientedRect.height), 1))

        let scale = max(renderSize.width / upright.width, renderSize.height / upright.height) * CGFloat(max(0.05, clip.scale))

        var t = preferredTransform
        t = t.concatenating(CGAffineTransform(translationX: -orientedRect.origin.x, y: -orientedRect.origin.y))
        t = t.concatenating(CGAffineTransform(scaleX: scale, y: scale))

        let displayW = upright.width * scale
        let displayH = upright.height * scale
        let ox = (renderSize.width - displayW) / 2 + (CGFloat(clip.positionX) - 0.5) * renderSize.width
        let oy = (renderSize.height - displayH) / 2 + (0.5 - CGFloat(clip.positionY)) * renderSize.height
        t = t.concatenating(CGAffineTransform(translationX: ox, y: oy))

        if abs(clip.rotation) > 0.01 {
            let cx = renderSize.width / 2
            let cy = renderSize.height / 2
            t = t
                .concatenating(CGAffineTransform(translationX: -cx, y: -cy))
                .concatenating(CGAffineTransform(rotationAngle: CGFloat(clip.rotation) * .pi / 180))
                .concatenating(CGAffineTransform(translationX: cx, y: cy))
        }
        if clip.flipH || clip.effects.mirror {
            t = CGAffineTransform(translationX: renderSize.width, y: 0)
                .scaledBy(x: -1, y: 1)
                .concatenating(t)
        }
        if clip.flipV {
            t = CGAffineTransform(translationX: 0, y: renderSize.height)
                .scaledBy(x: 1, y: -1)
                .concatenating(t)
        }
        return t
    }
}
