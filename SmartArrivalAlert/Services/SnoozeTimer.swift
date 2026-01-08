import Foundation
import Combine

/// 延迟计时器协议
protocol SnoozeTimerProtocol {
    var isActive: Bool { get }
    var remainingTime: TimeInterval { get }
    var remainingTimePublisher: AnyPublisher<TimeInterval, Never> { get }
    func start(duration: TimeInterval, onExpire: @escaping () -> Void)
    func cancel()
}

/// 延迟提醒计时器
/// 管理延迟提醒的倒计时，到期时触发回调
final class SnoozeTimer: SnoozeTimerProtocol, ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SnoozeTimer()
    
    // MARK: - Published Properties
    
    /// 剩余时间（秒）
    @Published private(set) var remainingTime: TimeInterval = 0
    
    /// 是否正在计时
    @Published private(set) var isActive = false
    
    // MARK: - Properties
    
    /// 剩余时间发布者
    var remainingTimePublisher: AnyPublisher<TimeInterval, Never> {
        $remainingTime.eraseToAnyPublisher()
    }
    
    /// 结束时间
    private var endTime: Date?
    
    /// 更新定时器
    private var updateTimer: Timer?
    
    /// 到期回调
    private var onExpireCallback: (() -> Void)?
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// 开始计时
    /// - Parameters:
    ///   - duration: 延迟时长（秒）
    ///   - onExpire: 到期回调
    func start(duration: TimeInterval, onExpire: @escaping () -> Void) {
        // 取消之前的计时
        cancel()
        
        endTime = Date().addingTimeInterval(duration)
        remainingTime = duration
        isActive = true
        onExpireCallback = onExpire
        
        // 启动更新定时器（每秒更新一次）
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateRemainingTime()
        }
        
        // 确保定时器在 RunLoop 中运行
        if let timer = updateTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    /// 取消计时
    func cancel() {
        updateTimer?.invalidate()
        updateTimer = nil
        endTime = nil
        remainingTime = 0
        isActive = false
        onExpireCallback = nil
    }
    
    // MARK: - Private Methods
    
    /// 更新剩余时间
    private func updateRemainingTime() {
        guard let endTime = endTime else {
            cancel()
            return
        }
        
        let remaining = endTime.timeIntervalSinceNow
        
        if remaining <= 0 {
            // 计时结束
            let callback = onExpireCallback
            cancel()
            callback?()
        } else {
            remainingTime = remaining
        }
    }
    
    // MARK: - Computed Properties
    
    /// 剩余时间格式化文本（分:秒）
    var remainingTimeText: String {
        let minutes = Int(remainingTime) / 60
        let seconds = Int(remainingTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// 剩余分钟数（向上取整）
    var remainingMinutes: Int {
        Int(ceil(remainingTime / 60))
    }
    
    // MARK: - Deinitialization
    
    deinit {
        cancel()
    }
}
