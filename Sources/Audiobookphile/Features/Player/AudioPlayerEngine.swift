import Foundation
#if canImport(OSLog)
import OSLog
#endif
#if !SKIP && !os(Android)
import AVFoundation
#if os(iOS)
import UIKit
#endif
#endif

@MainActor
public class AudioPlayerEngine {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Audiobookphile", category: "AudioPlayerEngine")

    #if !SKIP && !os(Android)
    public var player: AVQueuePlayer?
    private var timeObserverToken: Any?
    private var playerItemObserverToken: Any?
    private var playerFailedObserverToken: Any?
    private var playerStalledObserverToken: Any?
    private var timeControlStatusObserver: NSKeyValueObservation?
    private var currentItemObserver: NSKeyValueObservation?
    private var currentItemStatusObserver: NSKeyValueObservation?
    
    private var eqUnit: AVAudioUnitEQ?
    private var reverbUnit: AVAudioUnitReverb?
    #endif

    public var onTimeControlStatusChanged: ((_ isPlaying: Bool, _ isBuffering: Bool) -> Void)?
    public var onCurrentItemChanged: ((AVPlayerItem?) -> Void)?
    public var onItemReady: ((AVPlayerItem) -> Void)?
    public var onItemFailed: ((Error?) -> Void)?
    public var onItemDidPlayToEndTime: ((AVPlayerItem) -> Void)?
    public var onItemStalled: (() -> Void)?
    public var onPeriodicTimeUpdate: ((CMTime) -> Void)?
    public var onAudioRouteLost: (() -> Void)?
    public var onAudioInterruptionBegan: (() -> Void)?
    public var onAudioInterruptionEnded: ((Bool) -> Void)?

    public init() {
        #if os(iOS)
        setupAudioObservers()
        #endif
    }

    public func cleanup() {
        #if !SKIP && !os(Android)
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
        if let token = playerItemObserverToken {
            NotificationCenter.default.removeObserver(token)
            playerItemObserverToken = nil
        }
        if let token = playerFailedObserverToken {
            NotificationCenter.default.removeObserver(token)
            playerFailedObserverToken = nil
        }
        if let token = playerStalledObserverToken {
            NotificationCenter.default.removeObserver(token)
            playerStalledObserverToken = nil
        }
        timeControlStatusObserver = nil
        currentItemObserver = nil
        currentItemStatusObserver = nil
        player?.removeAllItems()
        player = nil
        #endif
    }

    public func initializePlayer() {
        #if !SKIP && !os(Android)
        if player == nil {
            let queuePlayer = AVQueuePlayer()
            queuePlayer.automaticallyWaitsToMinimizeStalling = true
            player = queuePlayer
            setupPlayerObservers()
        }
        player?.removeAllItems()
        #endif
    }

    public func play(rate: Float) {
        #if !SKIP && !os(Android)
        reconfigureAudioSession()
        player?.play()
        player?.rate = rate
        #endif
    }

    public func pause() {
        #if !SKIP && !os(Android)
        player?.pause()
        #endif
    }
    
    public func seek(to time: CMTime, completionHandler: @escaping @Sendable (Bool) -> Void) {
        #if !SKIP && !os(Android)
        if let player = player {
            player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero, completionHandler: completionHandler)
        } else {
            completionHandler(false)
        }
        #else
        completionHandler(true)
        #endif
    }
    
    public func insertItem(_ item: AVPlayerItem) {
        #if !SKIP && !os(Android)
        player?.insert(item, after: nil)
        #endif
    }
    
    public var queuedItemsCount: Int {
        #if !SKIP && !os(Android)
        return player?.items().count ?? 0
        #else
        return 0
        #endif
    }
    
    public var currentItem: Any? {
        #if !SKIP && !os(Android)
        return player?.currentItem
        #else
        return nil
        #endif
    }

    #if !SKIP && !os(Android)
    private func setupPlayerObservers() {
        guard let player = player else { return }

        timeControlStatusObserver = player.observe(\.timeControlStatus, options: [.initial, .new]) { [weak self] player, change in
            // Capture the status that *triggered* the notification. Re-reading
            // `player.timeControlStatus` inside the deferred Task reported
            // whatever the value had drifted to by the time the task ran, so a
            // burst of transitions (playing -> paused -> playing while a queue
            // item is replaced) collapsed onto one arbitrary value and the
            // service acted on a state that never really happened.
            let status: AVPlayer.TimeControlStatus
            if let newValue = change.newValue {
                status = newValue
            } else {
                status = player.timeControlStatus
            }

            Task { @MainActor in
                guard let self = self else { return }
                switch status {
                case .playing:
                    self.onTimeControlStatusChanged?(true, false)
                case .waitingToPlayAtSpecifiedRate:
                    self.onTimeControlStatusChanged?(true, true)
                case .paused:
                    self.onTimeControlStatusChanged?(false, false)
                @unknown default:
                    break
                }
            }
        }

        currentItemObserver = player.observe(\.currentItem, options: [.initial, .new]) { [weak self] player, _ in
            Task { @MainActor in
                if let item = player.currentItem {
                    self?.observeCurrentItemStatus(item)
                }
                self?.onCurrentItemChanged?(player.currentItem)
            }
        }

        if let token = timeObserverToken {
            player.removeTimeObserver(token)
            timeObserverToken = nil
        }
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                self?.onPeriodicTimeUpdate?(time)
            }
        }
    }

    public func observeCurrentItemStatus(_ item: AVPlayerItem) {
        if let token = playerItemObserverToken {
            NotificationCenter.default.removeObserver(token)
            playerItemObserverToken = nil
        }
        if let token = playerFailedObserverToken {
            NotificationCenter.default.removeObserver(token)
            playerFailedObserverToken = nil
        }
        if let token = playerStalledObserverToken {
            NotificationCenter.default.removeObserver(token)
            playerStalledObserverToken = nil
        }

        currentItemStatusObserver = item.observe(\.status, options: [.initial, .new]) { [weak self] item, _ in
            Task { @MainActor in
                guard let self = self else { return }
                switch item.status {
                case .readyToPlay:
                    self.logger.info("AVPlayerItem ready to play")
                    self.onItemReady?(item)
                case .failed:
                    self.logger.error("AVPlayerItem failed: \(item.error?.localizedDescription ?? "Unknown")")
                    self.onItemFailed?(item.error)
                case .unknown:
                    break
                @unknown default:
                    break
                }
            }
        }

        playerItemObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onItemDidPlayToEndTime?(item)
            }
        }

        playerFailedObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] notification in
            let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
            Task { @MainActor in
                self?.onItemFailed?(error)
            }
        }

        playerStalledObserverToken = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled,
            object: item,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.onItemStalled?()
            }
        }
    }
    #endif

    public func reconfigureAudioSession() {
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            let mode: AVAudioSession.Mode = AppState.shared.settings.spokenAudioModeEnabled ? .spokenAudio : .default
            try audioSession.setCategory(
                .playback,
                mode: mode,
                options: [.allowBluetoothA2DP, .allowAirPlay]
            )

            if AppState.shared.settings.highResAudioEnabled {
                try? audioSession.setPreferredSampleRate(48000.0)
                try? audioSession.setPreferredIOBufferDuration(0.005)
            }

            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            logger.info("AVAudioSession configured: mode=\(mode == .spokenAudio ? "spokenAudio" : "default"), highRes=\(AppState.shared.settings.highResAudioEnabled).")
        } catch {
            logger.error("Failed to configure AVAudioSession: \(error)")
        }
        #endif
    }

    private func setupAudioObservers() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            Task { @MainActor in
                guard let self = self,
                      let reasonValue = reasonValue,
                      let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
                    return
                }

                if reason == .oldDeviceUnavailable {
                    self.onAudioRouteLost?()
                }
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            let typeValue = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt
            Task { @MainActor in
                guard let self = self,
                      let typeValue = typeValue,
                      let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                    return
                }

                switch type {
                case .began:
                    self.onAudioInterruptionBegan?()
                case .ended:
                    if let optionsValue = optionsValue {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) {
                            self.onAudioInterruptionEnded?(true)
                        } else {
                            self.onAudioInterruptionEnded?(false)
                        }
                    }
                @unknown default:
                    break
                }
            }
        }
        #endif
    }

    public func applyAudioDSP() {
        #if !SKIP && !os(Android)
        if eqUnit == nil {
            setupAudioEngineDSP()
        }

        guard let eq = eqUnit else { return }
        let settings = AppState.shared.settings
        eq.bands[0].bypass = !settings.lowCutFilterEnabled
        eq.bands[1].bypass = !settings.vocalBoostEnabled
        eq.bands[2].bypass = !settings.deEsserEnabled
        eq.bands[3].bypass = !settings.volumeLevelerEnabled

        if reverbUnit == nil {
            let reverb = AVAudioUnitReverb()
            reverb.loadFactoryPreset(.smallRoom)
            reverb.wetDryMix = 0.0
            self.reverbUnit = reverb
        }
        if let reverb = reverbUnit {
            let presets: [AVAudioUnitReverbPreset] = [.smallRoom, .mediumRoom, .mediumHall]
            let preset = presets[min(max(0, settings.binauralReverbPresetRaw), presets.count - 1)]
            reverb.loadFactoryPreset(preset)
            reverb.wetDryMix = settings.binauralReverbEnabled ? 18.0 : 0.0
        }

        logger.info("Live Audio DSP Filter state updated: lowCut=\(!eq.bands[0].bypass), vocalBoost=\(!eq.bands[1].bypass), deEsser=\(!eq.bands[2].bypass), leveler=\(!eq.bands[3].bypass), reverb=\(settings.binauralReverbEnabled)")
        #endif
    }

    #if !SKIP && !os(Android)
    private func setupAudioEngineDSP() {
        let eq = AVAudioUnitEQ(numberOfBands: 4)

        let b0 = eq.bands[0]
        b0.filterType = .highPass
        b0.frequency = 80.0
        b0.bypass = !AppState.shared.settings.lowCutFilterEnabled

        let b1 = eq.bands[1]
        b1.filterType = .parametric
        b1.frequency = 2500.0
        b1.bandwidth = 1.0
        b1.gain = 3.5
        b1.bypass = !AppState.shared.settings.vocalBoostEnabled

        let b2 = eq.bands[2]
        b2.filterType = .parametric
        b2.frequency = 6500.0
        b2.bandwidth = 0.8
        b2.gain = -3.0
        b2.bypass = !AppState.shared.settings.deEsserEnabled

        let b3 = eq.bands[3]
        b3.filterType = .highShelf
        b3.frequency = 10000.0
        b3.gain = 2.0
        b3.bypass = !AppState.shared.settings.volumeLevelerEnabled

        self.eqUnit = eq
        logger.info("Initialized 4-Band Audiophile Parametric EQ DSP Graph.")
    }
    #endif
}
