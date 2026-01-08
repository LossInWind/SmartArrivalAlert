import Foundation
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

/// 声音播放器协议
protocol AlertSoundPlayerProtocol {
    var isPlaying: Bool { get }
    func play(soundType: AlertSoundType)
    func stop()
    func setVolume(_ volume: Float)
}

/// 提醒声音播放器
/// 负责播放到站提醒铃声，支持循环播放和静音模式下播放
final class AlertSoundPlayer: NSObject, AlertSoundPlayerProtocol {
    
    // MARK: - Singleton
    
    static let shared = AlertSoundPlayer()
    
    // MARK: - Properties
    
    private var audioPlayer: AVAudioPlayer?
    private var isConfigured = false
    
    /// 是否正在播放
    private(set) var isPlaying = false
    
    /// 当前音量
    private var currentVolume: Float = 1.0
    
    /// 系统声音循环定时器
    private var systemSoundTimer: Timer?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        configureAudioSession()
    }
    
    deinit {
        stop()
    }
    
    // MARK: - Audio Session Configuration
    
    /// 配置音频会话，确保在静音模式下也能播放
    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // 使用 playback 类别，可以在静音模式下播放
            // 添加 duckOthers 选项，降低其他音频音量
            try session.setCategory(.playback, mode: .default, options: [.duckOthers])
            try session.setActive(true)
            isConfigured = true
        } catch {
            print("⚠️ AlertSoundPlayer: 配置音频会话失败 - \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public Methods
    
    /// 播放提醒声音
    /// - Parameter soundType: 声音类型
    func play(soundType: AlertSoundType) {
        // 确保音频会话已配置
        if !isConfigured {
            configureAudioSession()
        }
        
        // 停止当前播放
        stop()
        
        // 获取声音文件 URL
        guard let url = getSoundURL(for: soundType) else {
            print("⚠️ AlertSoundPlayer: 找不到声音文件 - \(soundType.fileName)")
            // 使用系统默认声音作为后备
            playSystemSound()
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.numberOfLoops = -1 // 无限循环
            audioPlayer?.volume = currentVolume
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("⚠️ AlertSoundPlayer: 播放失败 - \(error.localizedDescription)")
            // 使用系统默认声音作为后备
            playSystemSound()
        }
    }
    
    /// 停止播放
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
        systemSoundTimer?.invalidate()
        systemSoundTimer = nil
        isPlaying = false
    }
    
    /// 设置音量
    /// - Parameter volume: 音量值 (0.0 - 1.0)
    func setVolume(_ volume: Float) {
        currentVolume = max(0, min(1, volume))
        audioPlayer?.volume = currentVolume
    }
    
    // MARK: - Private Methods
    
    /// 获取声音文件 URL
    private func getSoundURL(for soundType: AlertSoundType) -> URL? {
        // 首先尝试从 bundle 中获取
        if let url = Bundle.main.url(forResource: soundType.fileName, withExtension: "wav") {
            return url
        }
        if let url = Bundle.main.url(forResource: soundType.fileName, withExtension: "mp3") {
            return url
        }
        if let url = Bundle.main.url(forResource: soundType.fileName, withExtension: "m4a") {
            return url
        }
        if let url = Bundle.main.url(forResource: soundType.fileName, withExtension: "aiff") {
            return url
        }
        return nil
    }
    
    /// 播放系统默认声音（后备方案）
    private func playSystemSound() {
        #if os(iOS)
        // 使用系统声音作为后备
        AudioServicesPlaySystemSound(1005) // 系统提示音
        isPlaying = true
        
        // 使用 Timer 实现循环播放（可正确清理）
        systemSoundTimer?.invalidate()
        systemSoundTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
            guard let self = self, self.isPlaying else {
                timer.invalidate()
                return
            }
            AudioServicesPlaySystemSound(1005)
        }
        #endif
    }
}

// MARK: - AVAudioPlayerDelegate

extension AlertSoundPlayer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        // 由于设置了无限循环，这个方法通常不会被调用
        // 除非播放被中断
        if !flag {
            isPlaying = false
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("⚠️ AlertSoundPlayer: 解码错误 - \(error?.localizedDescription ?? "未知错误")")
        isPlaying = false
    }
}
