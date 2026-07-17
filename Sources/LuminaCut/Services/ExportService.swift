import Foundation
import AVFoundation
import AppKit

enum ExportPreset: String, CaseIterable, Identifiable {
    case high1080
    case high720
    case medium
    case hevc

    var id: String { rawValue }

    var title: String {
        switch self {
        case .high1080: return "1080p High"
        case .high720: return "720p"
        case .medium: return "Medium (faster)"
        case .hevc: return "HEVC 1080p"
        }
    }

    var avPreset: String {
        switch self {
        case .high1080: return AVAssetExportPresetHighestQuality
        case .high720: return AVAssetExportPreset1280x720
        case .medium: return AVAssetExportPresetMediumQuality
        case .hevc: return AVAssetExportPresetHighestQuality
        }
    }
}

enum ExportService {
    static func export(
        composition: AVMutableComposition,
        videoComposition: AVVideoComposition?,
        audioMix: AVAudioMix?,
        preset: ExportPreset,
        to url: URL,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws {
        try? FileManager.default.removeItem(at: url)

        guard let session = AVAssetExportSession(asset: composition, presetName: preset.avPreset) else {
            throw NSError(domain: "LuminaCut", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])
        }
        session.outputURL = url
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        if let videoComposition {
            session.videoComposition = videoComposition
        }
        if let audioMix {
            session.audioMix = audioMix
        }

        let progressTask = Task { @MainActor in
            while !Task.isCancelled {
                progress(Double(session.progress))
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }

        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            session.exportAsynchronously {
                cont.resume()
            }
        }
        progressTask.cancel()

        if session.status == .completed {
            await progress(1.0)
            return
        }
        if let error = session.error {
            throw error
        }
        throw NSError(domain: "LuminaCut", code: 2, userInfo: [NSLocalizedDescriptionKey: "Export failed: \(session.status.rawValue)"])
    }
}
