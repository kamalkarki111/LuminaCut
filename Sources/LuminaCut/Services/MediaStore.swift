import Foundation
import AppKit
import AVFoundation
import CoreImage
import UniformTypeIdentifiers

/// Copies imported media into Application Support so playback always has readable local files.
enum MediaStore {
    static var rootURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = base.appendingPathComponent("LuminaCut/Media", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static var cacheURL: URL {
        let dir = rootURL.appendingPathComponent("Generated", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Copy a user-selected file into app storage. Starts security-scoped access if needed.
    static func ingest(fileURL: URL) throws -> URL {
        let accessing = fileURL.startAccessingSecurityScopedResource()
        defer { if accessing { fileURL.stopAccessingSecurityScopedResource() } }

        let ext = fileURL.pathExtension.isEmpty ? "bin" : fileURL.pathExtension
        let name = "\(UUID().uuidString).\(ext)"
        let dest = rootURL.appendingPathComponent(name)

        if FileManager.default.fileExists(atPath: dest.path) {
            try FileManager.default.removeItem(at: dest)
        }
        try FileManager.default.copyItem(at: fileURL, to: dest)
        return dest
    }
}

/// Creates a short H.264 movie from a still image so images play on the timeline.
enum StillImageVideoFactory {
    static func movie(fromImageURL imageURL: URL, durationSeconds: Double = 3.0, fps: Int32 = 30) async throws -> URL {
        guard let nsImage = NSImage(contentsOf: imageURL),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw NSError(domain: "LuminaCut", code: 10, userInfo: [NSLocalizedDescriptionKey: "Could not read image"])
        }

        // Cap huge images so encoding stays fast, keep aspect
        var width = cgImage.width
        var height = cgImage.height
        let maxEdge = 1920
        if max(width, height) > maxEdge {
            let scale = CGFloat(maxEdge) / CGFloat(max(width, height))
            width = Int((CGFloat(width) * scale).rounded())
            height = Int((CGFloat(height) * scale).rounded())
        }
        width = max(2, width - (width % 2)) // H.264 likes even dims
        height = max(2, height - (height % 2))

        let outURL = MediaStore.cacheURL.appendingPathComponent("\(UUID().uuidString).mp4")
        try? FileManager.default.removeItem(at: outURL)

        let writer = try AVAssetWriter(outputURL: outURL, fileType: .mp4)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: max(2_000_000, width * height * 3),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264BaselineAutoLevel
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false

        let sourceAttrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: sourceAttrs
        )

        guard writer.canAdd(input) else {
            throw NSError(domain: "LuminaCut", code: 12, userInfo: [NSLocalizedDescriptionKey: "Cannot add writer input"])
        }
        writer.add(input)

        guard writer.startWriting() else {
            throw writer.error ?? NSError(domain: "LuminaCut", code: 13, userInfo: [NSLocalizedDescriptionKey: "startWriting failed"])
        }
        writer.startSession(atSourceTime: .zero)

        // ~2 fps is enough for a still and keeps import snappy
        let writeFPS: Int32 = 2
        let frameCount = max(1, Int((durationSeconds * Double(writeFPS)).rounded(.up)))
        let frameDuration = CMTime(value: 1, timescale: writeFPS)

        guard let pool = adaptor.pixelBufferPool else {
            throw NSError(domain: "LuminaCut", code: 14, userInfo: [NSLocalizedDescriptionKey: "No pixel buffer pool"])
        }

        let ciImage = CIImage(cgImage: cgImage).transformed(by: CGAffineTransform(
            scaleX: CGFloat(width) / CGFloat(cgImage.width),
            y: CGFloat(height) / CGFloat(cgImage.height)
        ))
        let context = CIContext(options: [.useSoftwareRenderer: false])

        for i in 0..<frameCount {
            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 2_000_000)
            }
            var pixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
            guard status == kCVReturnSuccess, let buffer = pixelBuffer else { continue }

            context.render(
                ciImage,
                to: buffer,
                bounds: CGRect(x: 0, y: 0, width: width, height: height),
                colorSpace: CGColorSpaceCreateDeviceRGB()
            )

            let time = CMTimeMultiply(frameDuration, multiplier: Int32(i))
            if !adaptor.append(buffer, withPresentationTime: time) {
                throw writer.error ?? NSError(domain: "LuminaCut", code: 16, userInfo: [NSLocalizedDescriptionKey: "append frame failed"])
            }
        }

        input.markAsFinished()
        await writer.finishWriting()

        if writer.status != .completed {
            throw writer.error ?? NSError(domain: "LuminaCut", code: 15, userInfo: [NSLocalizedDescriptionKey: "finishWriting failed"])
        }

        // Verify playable
        let check = AVURLAsset(url: outURL)
        let playable = (try? await check.load(.isPlayable)) ?? false
        let dur = CMTimeGetSeconds((try? await check.load(.duration)) ?? .zero)
        guard playable, dur > 0.2 else {
            throw NSError(domain: "LuminaCut", code: 17, userInfo: [NSLocalizedDescriptionKey: "Generated still movie is not playable"])
        }
        print("[LuminaCut] still\u2192video \(width)x\(height) dur=\(String(format: \"%.2f\", dur))s \u2192 \(outURL.lastPathComponent)")
        return outURL
    }
}
