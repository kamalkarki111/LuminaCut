import Foundation
import AVFoundation
import AppKit
import UniformTypeIdentifiers

enum MediaImporter {
    @MainActor
    static func importFiles() async -> [MediaAsset] {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            .movie, .mpeg4Movie, .quickTimeMovie,
            .image, .jpeg, .png, .heic, .gif, .webP,
            .audio, .mp3, .wav, .aiff
        ]
        panel.message = "Import media into LuminaCut"
        panel.prompt = "Import"
        guard panel.runModal() == .OK else { return [] }

        var assets: [MediaAsset] = []
        for url in panel.urls {
            do {
                if let asset = try await loadAndIngest(from: url) {
                    assets.append(asset)
                }
            } catch {
                print("[LuminaCut] import failed for \(url.lastPathComponent): \(error)")
            }
        }
        return assets
    }

    /// Ingest path from open panel (or any URL) into local store + MediaAsset.
    static func loadAndIngest(from originalURL: URL) async throws -> MediaAsset? {
        let localURL = try MediaStore.ingest(fileURL: originalURL)
        return await loadAsset(from: localURL, displayName: originalURL.deletingPathExtension().lastPathComponent)
    }

    static func loadAsset(from url: URL, displayName: String? = nil) async -> MediaAsset? {
        let name = displayName ?? url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension.lowercased()
        let imageExts = ["jpg", "jpeg", "png", "heic", "gif", "webp", "bmp", "tiff"]
        let audioExts = ["mp3", "wav", "aiff", "m4a", "aac", "caf"]

        if imageExts.contains(ext) {
            // Convert still → short video so timeline playback works
            do {
                let movieURL = try await StillImageVideoFactory.movie(fromImageURL: url, durationSeconds: 3.0)
                guard let img = NSImage(contentsOf: url) else { return nil }
                let size = img.size
                let movieAsset = AVURLAsset(url: movieURL)
                let movieDur = CMTimeGetSeconds((try? await movieAsset.load(.duration)) ?? .zero)
                let seconds = movieDur.isFinite && movieDur > 0.2 ? movieDur : 3.0
                return MediaAsset(
                    name: name,
                    kind: .image,
                    filePath: movieURL.path, // playable movie generated from image
                    durationSeconds: seconds,
                    width: Int(size.width),
                    height: Int(size.height),
                    hasAudio: false
                )
            } catch {
                print("[LuminaCut] still\u2192video failed: \(error)")
                // Last-resort: try again once with a smaller/safer encode path already handled in factory.
                // Without a video track the clip cannot play — surface a clear failure.
                return nil
            }
        }

        let avAsset = AVURLAsset(url: url)
        do {
            let duration = try await avAsset.load(.duration)
            let seconds = CMTimeGetSeconds(duration)
            let videoTracks = try await avAsset.loadTracks(withMediaType: .video)
            let audioTracks = try await avAsset.loadTracks(withMediaType: .audio)
            let hasVideo = !videoTracks.isEmpty
            let hasAudio = !audioTracks.isEmpty

            var width = 0, height = 0
            if let track = videoTracks.first {
                let size = try await track.load(.naturalSize)
                let transform = try await track.load(.preferredTransform)
                let transformed = size.applying(transform)
                width = Int(abs(transformed.width))
                height = Int(abs(transformed.height))
                if width == 0 { width = Int(abs(size.width)) }
                if height == 0 { height = Int(abs(size.height)) }
            }

            if audioExts.contains(ext) || (!hasVideo && hasAudio) {
                return MediaAsset(
                    name: name,
                    kind: .audio,
                    filePath: url.path,
                    durationSeconds: seconds.isFinite ? max(seconds, 0.1) : 0.1,
                    width: 0, height: 0,
                    hasAudio: true
                )
            }

            return MediaAsset(
                name: name,
                kind: hasVideo ? .video : .audio,
                filePath: url.path,
                durationSeconds: seconds.isFinite && seconds > 0.05 ? seconds : 1,
                width: max(width, 1),
                height: max(height, 1),
                hasAudio: hasAudio
            )
        } catch {
            print("[LuminaCut] loadAsset error: \(error)")
            return nil
        }
    }

    static func generateThumbnail(for asset: MediaAsset, size: CGSize = CGSize(width: 160, height: 90)) async -> NSImage? {
        // Generated movies for images still work with AVAssetImageGenerator
        let avAsset = AVURLAsset(url: asset.url)
        let generator = AVAssetImageGenerator(asset: avAsset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = size
        let time = CMTime(seconds: min(0.5, max(0, asset.durationSeconds * 0.05)), preferredTimescale: 600)
        do {
            let (cg, _) = try await generator.image(at: time)
            return NSImage(cgImage: cg, size: size)
        } catch {
            if asset.kind == .image, let img = NSImage(contentsOf: asset.url) {
                return img
            }
            return nil
        }
    }
}
