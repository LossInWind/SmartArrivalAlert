import Foundation
import Combine

/// 提醒管理器协议
@MainActor
protocol AlertManagerProtocol {
    var currentState: AlertState { get }
    var alertInfo: AlertInfo? { get }
    var statePublisher: AnyPublisher<AlertState, Never> { get }
    
    func triggerAlert(destination: Location) async
    func confirmAlert() async
    func snoozeAlert(duration: TimeInterval) async
    func cancelAlert() async
}

/// 提醒管理器
/// 协调声音、震动、计时器，管理提醒状态
@MainActor
final class AlertManager: ObservableObject, AlertManagerProtocol {
    
    // MARK: - Singleton
    
    static let shared = AlertManager()
    
    // MARK: - Published Properties
    
    /// 当前提醒状态
    @Published private(set) var currentState: AlertState = .idle
    
    /// 当前提醒信息
    @Published private(set) var alertInfo: AlertInfo?
    
    /// 是否显示提醒界面
    @Published var showAlertView = false
    
    // MARK: - Publishers
    
    /// 状态变化发布者
    var statePublisher: AnyPublisher<AlertState, Never> {
        $currentState.eraseToAnyPublisher()
    }
    
    // MARK: - Dependencies
    
    private let soundPlayer: AlertSoundPlayerProtocol
    private let hapticEngine: AlertHapticEngineProtocol
    private let snoozeTimer: SnoozeTimerProtocol
    private let settingsStore: SettingsStore
    
    // MARK: - Storage
    
    private let alertInfoKey = "alertManager.alertInfo"
    private let userDefaults: UserDefaults
    
    /// 设置变化订阅
    private var settingsCancellables = Set<AnyCancellable>()
    
    /// 当前是否启用触觉反馈
    private var currentEnableHapticFeedback: Bool = true
    
    // MARK: - Initialization
    
    init(
        soundPlayer: AlertSoundPlayerProtocol = AlertSoundPlayer.shared,
        hapticEngine: AlertHapticEngineProtocol = AlertHapticEngine.shared,
        snoozeTimer: SnoozeTimerProtocol = SnoozeTimer.shared,
        settingsStore: SettingsStore = .shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.soundPlayer = soundPlayer
        self.hapticEngine = hapticEngine
        self.snoozeTimer = snoozeTimer
        self.settingsStore = settingsStore
        self.userDefaults = userDefaults
        
        // 初始化设置值
        self.currentEnableHapticFeedback = settingsStore.enableHapticFeedback
        
        // 恢复持久化的提醒状态
        restoreAlertState()
        
        // 订阅设置变化
        subscribeToSettingsChanges()
    }
    
    // MARK: - Settings Subscription
    
    /// 订阅设置变化
    private func subscribeToSettingsChanges() {
        // 订阅触觉反馈开关变化
        settingsStore.$enableHapticFeedback
            .dropFirst()
            .sink { [weak self] newValue in
                self?.handleHapticFeedbackSettingChange(newValue)
            }
            .store(in: &settingsCancellables)
        
        // 订阅提醒声音变化
        settingsStore.$alertSound
            .dropFirst()
            .sink { [weak self] newValue in
                self?.handleAlertSoundSettingChange(newValue)
            }
            .store(in: &settingsCancellables)
    }
    
    /// 处理触觉反馈设置变化
    private func handleHapticFeedbackSettingChange(_ enabled: Bool) {
        currentEnableHapticFeedback = enabled
        
        // 如果正在提醒中，立即应用变化
        if currentState == .alerting {
            if enabled {
                hapticEngine.startRepeatingHaptic(interval: AlertConfiguration.hapticInterval)
            } else {
                hapticEngine.stopHaptic()
            }
        }
    }
    
    /// 处理提醒声音设置变化
    private func handleAlertSoundSettingChange(_ sound: AlertSound) {
        // 如果正在提醒中，根据新设置调整
        if currentState == .alerting {
            if sound == .silent {
                soundPlayer.stop()
                hapticEngine.stopHaptic()
            } else if sound == .vibration {
                soundPlayer.stop()
                if currentEnableHapticFeedback {
                    hapticEngine.startRepeatingHaptic(interval: AlertConfiguration.hapticInterval)
                }
            } else {
                soundPlayer.play(soundType: .radar)
                if currentEnableHapticFeedback {
                    hapticEngine.startRepeatingHaptic(interval: AlertConfiguration.hapticInterval)
                }
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// 触发到站提醒
    /// - Parameter destination: 目的地
    func triggerAlert(destination: Location) async {
        // 创建提醒信息
        let info = AlertInfo(from: destination)
        alertInfo = info
        currentState = .alerting
        
        // 持久化状态
        saveAlertState()
        
        // 启动声音和震动
        startFeedback()
        
        // 显示提醒界面
        showAlertView = true
    }
    
    /// 确认到达
    func confirmAlert() async {
        guard let info = alertInfo, info.state.canConfirm else { return }
        
        // 停止所有反馈
        stopFeedback()
        
        // 取消延迟计时器
        snoozeTimer.cancel()
        
        // 更新状态
        alertInfo = info.confirmed()
        currentState = .confirmed
        
        // 持久化状态
        saveAlertState()
        
        // 隐藏提醒界面
        showAlertView = false
        
        // 延迟后重置状态
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.resetState()
        }
    }
    
    /// 延迟提醒
    /// - Parameter duration: 延迟时长（秒），默认 5 分钟
    func snoozeAlert(duration: TimeInterval = AlertConfiguration.defaultSnoozeDuration) async {
        guard let info = alertInfo, info.canSnooze else { return }
        
        // 停止所有反馈
        stopFeedback()
        
        // 更新状态
        guard let snoozedInfo = info.snoozed(duration: duration) else { return }
        alertInfo = snoozedInfo
        currentState = .snoozed
        
        // 持久化状态
        saveAlertState()
        
        // 启动延迟计时器
        snoozeTimer.start(duration: duration) { [weak self] in
            Task { @MainActor [weak self] in
                await self?.handleSnoozeExpired()
            }
        }
    }
    
    /// 取消提醒
    func cancelAlert() async {
        // 停止所有反馈
        stopFeedback()
        
        // 取消延迟计时器
        snoozeTimer.cancel()
        
        // 重置状态
        resetState()
        
        // 隐藏提醒界面
        showAlertView = false
    }
    
    /// 重置状态（停止监控时调用）
    func resetState() {
        alertInfo = nil
        currentState = .idle
        showAlertView = false
        
        // 清除持久化数据
        userDefaults.removeObject(forKey: alertInfoKey)
    }
    
    // MARK: - Private Methods
    
    /// 启动声音和震动反馈
    private func startFeedback() {
        // 根据设置决定是否播放声音
        if settingsStore.alertSound != .silent && settingsStore.alertSound != .vibration {
            // 使用默认声音类型（后续可以从设置中读取）
            soundPlayer.play(soundType: .radar)
        }
        
        // 根据设置决定是否震动
        if currentEnableHapticFeedback && settingsStore.alertSound != .silent {
            hapticEngine.startRepeatingHaptic(interval: AlertConfiguration.hapticInterval)
        }
    }
    
    /// 停止声音和震动反馈
    private func stopFeedback() {
        soundPlayer.stop()
        hapticEngine.stopHaptic()
    }
    
    /// 处理延迟到期
    private func handleSnoozeExpired() async {
        guard let info = alertInfo, info.state == .snoozed else { return }
        
        // 重新触发提醒
        alertInfo = info.retriggered()
        currentState = .alerting
        
        // 持久化状态
        saveAlertState()
        
        // 重新启动反馈
        startFeedback()
        
        // 显示提醒界面
        showAlertView = true
    }
    
    /// 保存提醒状态
    private func saveAlertState() {
        guard let info = alertInfo else {
            userDefaults.removeObject(forKey: alertInfoKey)
            return
        }
        
        do {
            let data = try JSONEncoder().encode(info)
            userDefaults.set(data, forKey: alertInfoKey)
        } catch {
            print("⚠️ AlertManager: 保存状态失败 - \(error.localizedDescription)")
        }
    }
    
    /// 恢复提醒状态
    private func restoreAlertState() {
        guard let data = userDefaults.data(forKey: alertInfoKey) else { return }
        
        do {
            let info = try JSONDecoder().decode(AlertInfo.self, from: data)
            
            // 检查状态是否仍然有效
            if info.state.isActive {
                alertInfo = info
                currentState = info.state
                
                // 如果是延迟状态，检查是否已过期
                if info.state == .snoozed, let endTime = info.snoozeEndTime {
                    let remaining = endTime.timeIntervalSinceNow
                    if remaining > 0 {
                        // 继续延迟计时
                        snoozeTimer.start(duration: remaining) { [weak self] in
                            Task { @MainActor [weak self] in
                                await self?.handleSnoozeExpired()
                            }
                        }
                    } else {
                        // 延迟已过期，重新触发
                        Task {
                            await handleSnoozeExpired()
                        }
                    }
                } else if info.state == .alerting {
                    // 恢复提醒状态
                    startFeedback()
                    showAlertView = true
                }
            } else {
                // 状态无效，清除
                resetState()
            }
        } catch {
            print("⚠️ AlertManager: 恢复状态失败 - \(error.localizedDescription)")
            userDefaults.removeObject(forKey: alertInfoKey)
        }
    }
    
    // MARK: - Computed Properties
    
    /// 是否可以延迟
    var canSnooze: Bool {
        alertInfo?.canSnooze ?? false
    }
    
    /// 剩余延迟次数
    var remainingSnoozeCount: Int {
        alertInfo?.remainingSnoozeCount ?? AlertInfo.maxSnoozeCount
    }
}
