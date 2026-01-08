import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// 震动引擎协议
protocol AlertHapticEngineProtocol {
    var isActive: Bool { get }
    func startRepeatingHaptic(interval: TimeInterval)
    func stopHaptic()
    func triggerOnce()
}

/// 提醒震动引擎
/// 负责触发设备震动反馈，支持重复震动模式
final class AlertHapticEngine: AlertHapticEngineProtocol {
    
    // MARK: - Singleton
    
    static let shared = AlertHapticEngine()
    
    // MARK: - Properties
    
    /// 是否正在震动
    private(set) var isActive = false
    
    /// 重复震动定时器
    private var repeatTimer: Timer?
    
    /// 震动间隔
    private var currentInterval: TimeInterval = AlertConfiguration.hapticInterval
    
    #if os(iOS)
    /// 触觉反馈生成器
    private var feedbackGenerator: UINotificationFeedbackGenerator?
    #endif
    
    // MARK: - Initialization
    
    init() {
        prepareGenerator()
    }
    
    // MARK: - Private Methods
    
    /// 准备触觉反馈生成器
    private func prepareGenerator() {
        #if os(iOS)
        feedbackGenerator = UINotificationFeedbackGenerator()
        feedbackGenerator?.prepare()
        #endif
    }
    
    // MARK: - Public Methods
    
    /// 开始重复震动
    /// - Parameter interval: 震动间隔（秒）
    func startRepeatingHaptic(interval: TimeInterval = AlertConfiguration.hapticInterval) {
        // 停止之前的震动
        stopHaptic()
        
        currentInterval = interval
        isActive = true
        
        // 立即触发一次
        triggerOnce()
        
        // 设置重复定时器
        repeatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.triggerOnce()
        }
        
        // 确保定时器在 RunLoop 中运行
        if let timer = repeatTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    /// 停止震动
    func stopHaptic() {
        repeatTimer?.invalidate()
        repeatTimer = nil
        isActive = false
    }
    
    /// 触发一次震动
    func triggerOnce() {
        #if os(iOS)
        // 使用通知类型的触觉反馈（较强）
        feedbackGenerator?.notificationOccurred(.warning)
        
        // 重新准备生成器以便下次使用
        feedbackGenerator?.prepare()
        #endif
    }
    
    // MARK: - Deinitialization
    
    deinit {
        stopHaptic()
    }
}
