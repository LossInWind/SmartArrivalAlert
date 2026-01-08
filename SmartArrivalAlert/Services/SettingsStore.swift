import Foundation
import Combine

/// 提醒声音类型
enum AlertSound: String, Codable, CaseIterable, Equatable {
    case `default` = "default"      // 默认声音
    case vibration = "vibration"    // 仅振动
    case silent = "silent"          // 静音
    case custom = "custom"          // 自定义
    
    var displayName: String {
        switch self {
        case .default: return "默认"
        case .vibration: return "仅振动"
        case .silent: return "静音"
        case .custom: return "自定义"
        }
    }
}

/// 设置存储
/// 管理所有用户设置，支持持久化存储
class SettingsStore: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = SettingsStore()
    
    // MARK: - Storage Keys
    
    private enum Keys {
        static let maxGeofenceRadius = "settings.maxGeofenceRadius"
        static let defaultGeofenceRadius = "settings.defaultGeofenceRadius"
        static let batteryMode = "settings.batteryMode"
        static let autoBatterySwitch = "settings.autoBatterySwitch"
        static let lowBatteryThreshold = "settings.lowBatteryThreshold"
        static let alertSound = "settings.alertSound"
        static let enableEarlyTrigger = "settings.enableEarlyTrigger"
        static let earlyTriggerMultiplier = "settings.earlyTriggerMultiplier"
        static let enableBackupAlarm = "settings.enableBackupAlarm"
        static let backupAlarmOffset = "settings.backupAlarmOffset"
        static let enableHapticFeedback = "settings.enableHapticFeedback"
        static let enableLiveActivity = "settings.enableLiveActivity"
        static let lastUsedTransportMode = "settings.lastUsedTransportMode"
        static let lastMapLatitude = "settings.lastMapLatitude"
        static let lastMapLongitude = "settings.lastMapLongitude"
    }
    
    // MARK: - Default Values
    
    private enum Defaults {
        static let maxGeofenceRadius: Double = 10000       // 10km
        static let defaultGeofenceRadius: Double = 500     // 500m
        static let batteryMode: BatteryMode = .balanced
        static let autoBatterySwitch: Bool = false
        static let lowBatteryThreshold: Int = 20           // 20%
        static let alertSound: AlertSound = .default
        static let enableEarlyTrigger: Bool = true
        static let earlyTriggerMultiplier: Double = 1.5
        static let enableBackupAlarm: Bool = true
        static let backupAlarmOffset: Int = 5              // 5 minutes
        static let enableHapticFeedback: Bool = true
        static let enableLiveActivity: Bool = true
        static let lastUsedTransportMode: TransportMode = .walking
    }
    
    // MARK: - Constraints
    
    /// 提前触发倍数范围
    static let earlyTriggerMultiplierRange: ClosedRange<Double> = 1.2...2.0
    
    /// 兜底闹钟偏移范围 (分钟)
    static let backupAlarmOffsetRange: ClosedRange<Int> = 1...30
    
    /// 低电量阈值范围 (%)
    static let lowBatteryThresholdRange: ClosedRange<Int> = 10...50
    
    // MARK: - Published Properties
    
    // 围栏设置
    @Published var maxGeofenceRadius: Double {
        didSet { save(maxGeofenceRadius, forKey: Keys.maxGeofenceRadius) }
    }
    
    @Published var defaultGeofenceRadius: Double {
        didSet { save(defaultGeofenceRadius, forKey: Keys.defaultGeofenceRadius) }
    }
    
    // 省电设置
    @Published var batteryMode: BatteryMode {
        didSet { save(batteryMode.rawValue, forKey: Keys.batteryMode) }
    }
    
    @Published var autoBatterySwitch: Bool {
        didSet { save(autoBatterySwitch, forKey: Keys.autoBatterySwitch) }
    }
    
    @Published var lowBatteryThreshold: Int {
        didSet { save(lowBatteryThreshold, forKey: Keys.lowBatteryThreshold) }
    }
    
    // 提醒设置
    @Published var alertSound: AlertSound {
        didSet { save(alertSound.rawValue, forKey: Keys.alertSound) }
    }
    
    @Published var enableEarlyTrigger: Bool {
        didSet { save(enableEarlyTrigger, forKey: Keys.enableEarlyTrigger) }
    }
    
    @Published var earlyTriggerMultiplier: Double {
        didSet {
            let clamped = clampEarlyTriggerMultiplier(earlyTriggerMultiplier)
            if clamped != earlyTriggerMultiplier {
                earlyTriggerMultiplier = clamped
            } else {
                save(clamped, forKey: Keys.earlyTriggerMultiplier)
            }
        }
    }
    
    @Published var enableBackupAlarm: Bool {
        didSet { save(enableBackupAlarm, forKey: Keys.enableBackupAlarm) }
    }
    
    @Published var backupAlarmOffset: Int {
        didSet { save(backupAlarmOffset, forKey: Keys.backupAlarmOffset) }
    }
    
    @Published var enableHapticFeedback: Bool {
        didSet { save(enableHapticFeedback, forKey: Keys.enableHapticFeedback) }
    }
    
    // 灵动岛
    @Published var enableLiveActivity: Bool {
        didSet { save(enableLiveActivity, forKey: Keys.enableLiveActivity) }
    }
    
    // 交通方式
    @Published var lastUsedTransportMode: TransportMode {
        didSet { save(lastUsedTransportMode.rawValue, forKey: Keys.lastUsedTransportMode) }
    }
    
    // 上次地图位置
    @Published var lastMapLatitude: Double? {
        didSet {
            if let lat = lastMapLatitude {
                save(lat, forKey: Keys.lastMapLatitude)
            } else {
                userDefaults.removeObject(forKey: Keys.lastMapLatitude)
            }
        }
    }
    
    @Published var lastMapLongitude: Double? {
        didSet {
            if let lon = lastMapLongitude {
                save(lon, forKey: Keys.lastMapLongitude)
            } else {
                userDefaults.removeObject(forKey: Keys.lastMapLongitude)
            }
        }
    }
    
    /// 获取上次地图位置
    var lastMapLocation: (latitude: Double, longitude: Double)? {
        guard let lat = lastMapLatitude, let lon = lastMapLongitude else { return nil }
        return (lat, lon)
    }
    
    /// 保存地图位置
    func saveMapLocation(latitude: Double, longitude: Double) {
        lastMapLatitude = latitude
        lastMapLongitude = longitude
    }
    
    // MARK: - Auto Battery Switch State
    
    /// 用户是否在当前会话中手动选择了电池模式
    @Published private(set) var userManuallySelectedBatteryMode: Bool = false
    
    /// 自动切换前的电池模式
    @Published private(set) var previousBatteryMode: BatteryMode?
    
    /// 是否处于自动省电模式
    @Published private(set) var isInAutoPowerSaving: Bool = false
    
    // MARK: - Private Properties
    
    private let userDefaults: UserDefaults
    
    // MARK: - Initialization
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // 加载保存的值或使用默认值
        self.maxGeofenceRadius = userDefaults.object(forKey: Keys.maxGeofenceRadius) as? Double ?? Defaults.maxGeofenceRadius
        self.defaultGeofenceRadius = userDefaults.object(forKey: Keys.defaultGeofenceRadius) as? Double ?? Defaults.defaultGeofenceRadius
        
        if let modeString = userDefaults.string(forKey: Keys.batteryMode),
           let mode = BatteryMode(rawValue: modeString) {
            self.batteryMode = mode
        } else {
            self.batteryMode = Defaults.batteryMode
        }
        
        self.autoBatterySwitch = userDefaults.object(forKey: Keys.autoBatterySwitch) as? Bool ?? Defaults.autoBatterySwitch
        self.lowBatteryThreshold = userDefaults.object(forKey: Keys.lowBatteryThreshold) as? Int ?? Defaults.lowBatteryThreshold
        
        if let soundString = userDefaults.string(forKey: Keys.alertSound),
           let sound = AlertSound(rawValue: soundString) {
            self.alertSound = sound
        } else {
            self.alertSound = Defaults.alertSound
        }
        
        self.enableEarlyTrigger = userDefaults.object(forKey: Keys.enableEarlyTrigger) as? Bool ?? Defaults.enableEarlyTrigger
        self.earlyTriggerMultiplier = userDefaults.object(forKey: Keys.earlyTriggerMultiplier) as? Double ?? Defaults.earlyTriggerMultiplier
        self.enableBackupAlarm = userDefaults.object(forKey: Keys.enableBackupAlarm) as? Bool ?? Defaults.enableBackupAlarm
        self.backupAlarmOffset = userDefaults.object(forKey: Keys.backupAlarmOffset) as? Int ?? Defaults.backupAlarmOffset
        self.enableHapticFeedback = userDefaults.object(forKey: Keys.enableHapticFeedback) as? Bool ?? Defaults.enableHapticFeedback
        self.enableLiveActivity = userDefaults.object(forKey: Keys.enableLiveActivity) as? Bool ?? Defaults.enableLiveActivity
        
        if let modeString = userDefaults.string(forKey: Keys.lastUsedTransportMode),
           let mode = TransportMode(rawValue: modeString) {
            self.lastUsedTransportMode = mode
        } else {
            self.lastUsedTransportMode = Defaults.lastUsedTransportMode
        }
        
        // 加载上次地图位置
        self.lastMapLatitude = userDefaults.object(forKey: Keys.lastMapLatitude) as? Double
        self.lastMapLongitude = userDefaults.object(forKey: Keys.lastMapLongitude) as? Double
    }
    
    // MARK: - Public Methods
    
    /// 重置所有设置为默认值
    func resetToDefaults() {
        maxGeofenceRadius = Defaults.maxGeofenceRadius
        defaultGeofenceRadius = Defaults.defaultGeofenceRadius
        batteryMode = Defaults.batteryMode
        autoBatterySwitch = Defaults.autoBatterySwitch
        lowBatteryThreshold = Defaults.lowBatteryThreshold
        alertSound = Defaults.alertSound
        enableEarlyTrigger = Defaults.enableEarlyTrigger
        earlyTriggerMultiplier = Defaults.earlyTriggerMultiplier
        enableBackupAlarm = Defaults.enableBackupAlarm
        backupAlarmOffset = Defaults.backupAlarmOffset
        enableHapticFeedback = Defaults.enableHapticFeedback
        enableLiveActivity = Defaults.enableLiveActivity
        lastUsedTransportMode = Defaults.lastUsedTransportMode
    }
    
    /// 获取有效的围栏半径范围
    func getEffectiveRadiusRange() -> (min: Double, max: Double) {
        return GeofenceRadiusConfig.getSliderRange(maxRadius: maxGeofenceRadius)
    }
    
    /// 限制提前触发倍数在有效范围内
    func clampEarlyTriggerMultiplier(_ value: Double) -> Double {
        return max(Self.earlyTriggerMultiplierRange.lowerBound,
                   min(value, Self.earlyTriggerMultiplierRange.upperBound))
    }
    
    // MARK: - Auto Battery Switch Methods
    
    /// 标记用户手动选择了电池模式
    func markManualBatteryModeSelection() {
        userManuallySelectedBatteryMode = true
        // 如果用户手动选择，退出自动省电状态
        if isInAutoPowerSaving {
            isInAutoPowerSaving = false
            previousBatteryMode = nil
        }
    }
    
    /// 重置手动选择标记（新会话开始时调用）
    func resetManualSelectionFlag() {
        userManuallySelectedBatteryMode = false
    }
    
    /// 执行自动切换到省电模式
    /// - Returns: 是否成功切换
    @discardableResult
    func autoSwitchToPowerSaving() -> Bool {
        // 如果用户手动选择了模式，不自动切换
        guard !userManuallySelectedBatteryMode else { return false }
        
        // 如果已经在省电模式，不需要切换
        guard batteryMode != .powerSaving else { return false }
        
        // 保存当前模式
        previousBatteryMode = batteryMode
        
        // 切换到省电模式
        batteryMode = .powerSaving
        isInAutoPowerSaving = true
        
        return true
    }
    
    /// 恢复之前的电池模式
    /// - Returns: 是否成功恢复
    @discardableResult
    func restorePreviousBatteryMode() -> Bool {
        // 如果不是自动切换的，不恢复
        guard isInAutoPowerSaving else { return false }
        
        // 恢复之前的模式
        if let previous = previousBatteryMode {
            batteryMode = previous
        } else {
            batteryMode = Defaults.batteryMode
        }
        
        previousBatteryMode = nil
        isInAutoPowerSaving = false
        
        return true
    }
    
    /// 检查并执行自动电池模式切换
    /// - Parameters:
    ///   - batteryPercentage: 当前电池电量百分比
    ///   - isCharging: 是否正在充电
    /// - Returns: 切换动作描述，nil 表示无变化
    func checkAndPerformAutoBatterySwitch(
        batteryPercentage: Int,
        isCharging: Bool
    ) -> AutoSwitchAction? {
        // 如果未启用自动切换，返回
        guard autoBatterySwitch else { return nil }
        
        // 如果用户手动选择了模式，不自动切换
        guard !userManuallySelectedBatteryMode else { return nil }
        
        // 使用 BatteryMonitor 的逻辑判断
        let result = BatteryMonitor.determineMode(
            batteryPercentage: batteryPercentage,
            threshold: lowBatteryThreshold,
            isCharging: isCharging,
            currentlyInPowerSaving: isInAutoPowerSaving
        )
        
        guard let shouldBePowerSaving = result else { return nil }
        
        if shouldBePowerSaving && !isInAutoPowerSaving {
            // 切换到省电模式
            if autoSwitchToPowerSaving() {
                return .switchedToPowerSaving
            }
        } else if !shouldBePowerSaving && isInAutoPowerSaving {
            // 恢复之前的模式
            if restorePreviousBatteryMode() {
                return .restoredPreviousMode
            }
        }
        
        return nil
    }
    
    // MARK: - Private Methods
    
    private func save(_ value: Any, forKey key: String) {
        userDefaults.set(value, forKey: key)
    }
}

// MARK: - Settings Snapshot

/// 设置快照，用于序列化和测试
struct SettingsSnapshot: Codable, Equatable {
    let maxGeofenceRadius: Double
    let defaultGeofenceRadius: Double
    let batteryMode: BatteryMode
    let autoBatterySwitch: Bool
    let lowBatteryThreshold: Int
    let alertSound: AlertSound
    let enableEarlyTrigger: Bool
    let earlyTriggerMultiplier: Double
    let enableBackupAlarm: Bool
    let backupAlarmOffset: Int
    let enableHapticFeedback: Bool
    let enableLiveActivity: Bool
    let lastUsedTransportMode: TransportMode
    
    init(from store: SettingsStore) {
        self.maxGeofenceRadius = store.maxGeofenceRadius
        self.defaultGeofenceRadius = store.defaultGeofenceRadius
        self.batteryMode = store.batteryMode
        self.autoBatterySwitch = store.autoBatterySwitch
        self.lowBatteryThreshold = store.lowBatteryThreshold
        self.alertSound = store.alertSound
        self.enableEarlyTrigger = store.enableEarlyTrigger
        self.earlyTriggerMultiplier = store.earlyTriggerMultiplier
        self.enableBackupAlarm = store.enableBackupAlarm
        self.backupAlarmOffset = store.backupAlarmOffset
        self.enableHapticFeedback = store.enableHapticFeedback
        self.enableLiveActivity = store.enableLiveActivity
        self.lastUsedTransportMode = store.lastUsedTransportMode
    }
    
    func apply(to store: SettingsStore) {
        store.maxGeofenceRadius = maxGeofenceRadius
        store.defaultGeofenceRadius = defaultGeofenceRadius
        store.batteryMode = batteryMode
        store.autoBatterySwitch = autoBatterySwitch
        store.lowBatteryThreshold = lowBatteryThreshold
        store.alertSound = alertSound
        store.enableEarlyTrigger = enableEarlyTrigger
        store.earlyTriggerMultiplier = earlyTriggerMultiplier
        store.enableBackupAlarm = enableBackupAlarm
        store.backupAlarmOffset = backupAlarmOffset
        store.enableHapticFeedback = enableHapticFeedback
        store.enableLiveActivity = enableLiveActivity
        store.lastUsedTransportMode = lastUsedTransportMode
    }
}

// MARK: - Auto Switch Action

/// 自动切换动作
enum AutoSwitchAction: Equatable {
    case switchedToPowerSaving
    case restoredPreviousMode
    
    var description: String {
        switch self {
        case .switchedToPowerSaving:
            return "已自动切换到省电模式"
        case .restoredPreviousMode:
            return "已恢复之前的电池模式"
        }
    }
}
