import Foundation
import AVFoundation
import Combine
import AppKit

@MainActor
final class PlaybackController: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isReady = false
    @Published var isSeeking = false
    @Published var lastError: String?

    let player = AVPlayer()
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var itemCancellables = Set<AnyCancellable>()
    private var rateCancellable: AnyCancellable?
    private var playWaitTask: Task<Void, Never>?

    init() {
        player.actionAtItemEnd = .pause
        player.automaticallyWaitsToMinimizeStalling = true
        // Keep UI in sync if something external pauses the player
        rateCancellable = player.publisher(for: \.rate)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rate in
                guard let self else { return }
                if rate == 0, self.isPlaying {
                    // Don't clear isPlaying during seeks
                    if !self.isSeeking {
                        self.isPlaying = false
                    }
                } else if rate > 0 {
                    self.isPlaying = true
                    self.lastError = nil
                }
            }
    }

    func attachTimeObserver() {
        removeTimeObserver()
        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                guard let self, !self.isSeeking else { return }
                let s = CMTimeGetSeconds(time)
                if s.isFinite {
                    self.currentTime = s
                }
            }
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: nil,
            queue: .main
        ) { [weak self] note in
            Task { @MainActor in
                guard let self else { return }
                guard (note.object as? AVPlayerItem) === self.player.currentItem else { return }
                self.isPlaying = false
                self.player.pause()
                // Stay at end so user can scrub; next play() rewinds
                let end = self.duration
                if end.isFinite, end > 0 {
                    self.currentTime = end
                }
            }
        }
    }

    func removeTimeObserver() {
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
    }

    func load(
        composition: AVComposition,
        videoComposition: AVVideoComposition?,
        audioMix: AVAudioMix?,
        duration: CMTime
    ) {
        playWaitTask?.cancel()
        itemCancellables.removeAll()
        lastError = nil
        isReady = false
        pause()

        let item = AVPlayerItem(asset: composition)
        // Prefer composition-driven presentation when provided
        if let videoComposition {
            item.videoComposition = videoComposition
        }
        if let audioMix {
            item.audioMix = audioMix
        }
        // Helps first frame show without waiting for full buffer
        item.preferredForwardBufferDuration = 1.0
        item.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        item.seekingWaitsForVideoCompositionRendering = true

        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                // Ignore stale items
                guard self.player.currentItem === item else { return }
                switch status {
                case .readyToPlay:
                    self.isReady = true
                    self.lastError = nil
                    print("[LuminaCut] player ready")
                case .failed:
                    self.isReady = false
                    let msg = item.error?.localizedDescription ?? "Player item failed"
                    self.lastError = msg
                    print("[LuminaCut] player item failed: \(msg)")
                    if let err = item.error {
                        print("[LuminaCut] underlying: \(err)")
                    }
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
            .store(in: &itemCancellables)

        item.publisher(for: \.error)
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                guard let self, self.player.currentItem === item else { return }
                self.lastError = error.localizedDescription
                print("[LuminaCut] item error: \(error)")
            }
            .store(in: &itemCancellables)

        player.replaceCurrentItem(with: item)
        let seconds = CMTimeGetSeconds(duration)
        self.duration = seconds.isFinite && seconds > 0 ? seconds : 0.1
        currentTime = 0
        attachTimeObserver()

        // Prime first frame so preview isn't black while paused
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)

        Task {
            do {
                let playable = try await composition.load(.isPlayable)
                if !playable {
                    await MainActor.run {
                        if self.player.currentItem === item {
                            self.lastError = "Composition is not playable"
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    if self.player.currentItem === item {
                        self.lastError = error.localizedDescription
                    }
                }
            }
        }
    }

    func clear() {
        playWaitTask?.cancel()
        pause()
        itemCancellables.removeAll()
        player.replaceCurrentItem(with: nil)
        duration = 0
        currentTime = 0
        isReady = false
        lastError = nil
    }

    func play() {
        playWaitTask?.cancel()
        lastError = nil

        // Restart if at end
        if duration > 0, currentTime >= duration - 0.05 {
            seek(to: 0)
        }

        if let item = player.currentItem {
            if item.status == .readyToPlay {
                startPlayback()
                return
            }
            if item.status == .failed {
                lastError = item.error?.localizedDescription ?? "Failed to play"
                isPlaying = false
                return
            }
        }

        // Wait for item (rebuild may still be in flight) then readiness
        isPlaying = true
        playWaitTask = Task { [weak self] in
            guard let self else { return }
            // Phase 1: wait for a current item (up to ~3s)
            if self.player.currentItem == nil {
                for _ in 0..<60 {
                    if Task.isCancelled { return }
                    if self.player.currentItem != nil { break }
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
            }
            guard let item = self.player.currentItem else {
                self.isPlaying = false
                self.lastError = "Nothing to play — add media to the timeline"
                return
            }
            // Phase 2: wait for ready (up to ~5s)
            for _ in 0..<100 {
                if Task.isCancelled { return }
                switch item.status {
                case .readyToPlay:
                    self.startPlayback()
                    return
                case .failed:
                    self.isPlaying = false
                    self.lastError = item.error?.localizedDescription ?? "Failed to play"
                    return
                default:
                    try? await Task.sleep(nanoseconds: 50_000_000)
                }
            }
            if !Task.isCancelled {
                self.startPlayback()
                if self.player.rate == 0 {
                    self.lastError = "Player not ready — try Play again"
                    self.isPlaying = false
                }
            }
        }
    }

    private func startPlayback() {
        if #available(macOS 11.0, *) {
            player.playImmediately(atRate: 1.0)
        } else {
            player.play()
        }
        player.rate = 1.0
        isPlaying = true
        print("[LuminaCut] play rate=\(player.rate) status=\(player.currentItem?.status.rawValue ?? -1)")
    }

    func pause() {
        playWaitTask?.cancel()
        player.pause()
        player.rate = 0
        isPlaying = false
    }

    func toggle() {
        if isPlaying { pause() } else { play() }
    }

    func seek(to seconds: Double) {
        guard player.currentItem != nil else { return }
        let t = max(0, min(max(duration, 0.1), seconds))
        currentTime = t
        isSeeking = true
        let time = CMTime(seconds: t, preferredTimescale: 600)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] finished in
            Task { @MainActor in
                self?.isSeeking = false
                if finished {
                    self?.currentTime = t
                }
            }
        }
    }

    func step(by delta: Double) {
        seek(to: currentTime + delta)
    }
}
