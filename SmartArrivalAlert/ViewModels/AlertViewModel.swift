import Foundation
import Combine

/// 提醒界面 ViewModel
@MainActor
final class AlertViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 目的地名称
    @Published private(set) var destinationName: String = ""
    
    /// 当前状态
    @Published private(set) var state: AlertState = .idle
    
    /// 延迟剩余时间（秒）
    @Published private(set) var snoozeRemainingTime: TimeInterval = 0
    
    /// 是否可以延迟
    @Published private(set) var canSnooze: Bool = true
    
    /// 剩余延迟次数
    @Published private(set) var remainingSnoozeCount: Int = AlertInfo.maxSnoozeCount
    
    // MARK: - Dependencies
    
    private let alertManager: AlertManager
    private let snoozeTimer: SnoozeTimer
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        alertManager: AlertManager? = nil,
        snoozeTimer: SnoozeTimer? = nil
    ) {
        self.alertManager = alertManager ?? AlertManager.shared
        self.snoozeTimer = snoozeTimer ?? SnoozeTimer.shared
        
        setupBindings()
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func setupBindings() {
        // 监听 AlertManager 状态变化
        alertManager.$alertInfo
            .receive(on: DispatchQueue.main)
            .sink { [weak self] info in
                self?.updateFromAlertInfo(info)
            }
            .store(in: &cancellables)
        
        alertManager.$currentState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.state = state
            }
            .store(in: &cancellables)
        
        // 监听延迟计时器
        snoozeTimer.$remainingTime
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in
                self?.snoozeRemainingTime = time
            }
            .store(in: &cancellables)
    }
    
    private func updateFromAlertInfo(_ info: AlertInfo?) {
        guard let info = info else {
            destinationName = ""
            canSnooze = false
            remainingSnoozeCount = 0
            return
        }
        
        destinationName = info.destinationName
        canSnooze = info.canSnooze
        remainingSnoozeCount = info.remainingSnoozeCount
    }
    
    // MARK: - Public Methods
    
    /// 确认到达
    func confirm() {
        Task {
            await alertManager.confirmAlert()
        }
    }
    
    /// 延迟提醒
    func snooze() {
        Task {
            await alertManager.snoozeAlert()
        }
    }
    
    // MARK: - Computed Properties
    
    /// 当前时间文本
    var currentTimeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }
    
    /// 延迟剩余时间文本（分:秒）
    var snoozeRemainingText: String {
        let minutes = Int(snoozeRemainingTime) / 60
        let seconds = Int(snoozeRemainingTime) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// 是否处于延迟状态
    var isSnoozed: Bool {
        state == .snoozed
    }
    
    /// 是否处于提醒状态
    var isAlerting: Bool {
        state == .alerting
    }
    
    /// 延迟按钮文本
    var snoozeButtonText: String {
        if isSnoozed {
            return "\(snoozeRemainingText) 后再次提醒"
        } else {
            return "延迟 5 分钟"
        }
    }
    
    /// 延迟按钮是否可用
    var isSnoozeButtonEnabled: Bool {
        isAlerting && canSnooze
    }
}
