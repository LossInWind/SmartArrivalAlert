import Foundation

// MARK: - Alert State

/// 提醒状态枚举
enum AlertState: String, Codable, Equatable {
    case idle           // 空闲状态
    case alerting       // 正在提醒
    case snoozed        // 已延迟
    case confirmed      // 已确认
    
    /// 是否可以延迟
    var canSnooze: Bool {
        self == .alerting
    }
    
    /// 是否可以确认
    var canConfirm: Bool {
        self == .alerting || self == .snoozed
    }
    
    /// 是否处于活跃状态（需要用户响应）
    var isActive: Bool {
        self == .alerting || self == .snoozed
    }
}

// MARK: - Alert Info

/// 提醒信息数据模型
struct AlertInfo: Codable, Equatable {
    /// 目的地名称
    let destinationName: String
    
    /// 目的地地址
    let destinationAddress: String
    
    /// 目的地 ID
    let destinationId: String
    
    /// 触发时间
    let triggeredAt: Date
    
    /// 延迟次数
    var snoozeCount: Int
    
    /// 延迟结束时间
    var snoozeEndTime: Date?
    
    /// 当前状态
    var state: AlertState
    
    /// 最大延迟次数
    static let maxSnoozeCount = 3
    
    /// 默认延迟时长（秒）
    static let defaultSnoozeDuration: TimeInterval = 300 // 5 分钟
    
    /// 震动间隔（秒）
    static let hapticInterval: TimeInterval = 2.0
    
    /// 后续通知延迟（秒）
    static let followUpNotificationDelay: TimeInterval = 30.0
    
    // MARK: - Initialization
    
    init(
        destinationName: String,
        destinationAddress: String,
        destinationId: String,
        triggeredAt: Date = Date(),
        snoozeCount: Int = 0,
        snoozeEndTime: Date? = nil,
        state: AlertState = .alerting
    ) {
        self.destinationName = destinationName
        self.destinationAddress = destinationAddress
        self.destinationId = destinationId
        self.triggeredAt = triggeredAt
        self.snoozeCount = snoozeCount
        self.snoozeEndTime = snoozeEndTime
        self.state = state
    }
    
    /// 从 Location 创建
    init(from location: Location, triggeredAt: Date = Date()) {
        self.destinationName = location.name
        self.destinationAddress = location.address
        self.destinationId = location.id
        self.triggeredAt = triggeredAt
        self.snoozeCount = 0
        self.snoozeEndTime = nil
        self.state = .alerting
    }
    
    // MARK: - Computed Properties
    
    /// 是否可以继续延迟
    var canSnooze: Bool {
        state.canSnooze && snoozeCount < Self.maxSnoozeCount
    }
    
    /// 剩余延迟次数
    var remainingSnoozeCount: Int {
        max(0, Self.maxSnoozeCount - snoozeCount)
    }
    
    /// 延迟剩余时间（秒）
    var snoozeRemainingTime: TimeInterval? {
        guard let endTime = snoozeEndTime, state == .snoozed else { return nil }
        let remaining = endTime.timeIntervalSinceNow
        return remaining > 0 ? remaining : nil
    }
    
    /// 延迟剩余时间格式化文本
    var snoozeRemainingText: String? {
        guard let remaining = snoozeRemainingTime else { return nil }
        let minutes = Int(remaining) / 60
        let seconds = Int(remaining) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Mutations
    
    /// 执行延迟
    /// - Parameter duration: 延迟时长（秒）
    /// - Returns: 更新后的 AlertInfo，如果无法延迟则返回 nil
    func snoozed(duration: TimeInterval = AlertInfo.defaultSnoozeDuration) -> AlertInfo? {
        guard canSnooze else { return nil }
        
        var updated = self
        updated.snoozeCount += 1
        updated.snoozeEndTime = Date().addingTimeInterval(duration)
        updated.state = .snoozed
        return updated
    }
    
    /// 确认到达
    /// - Returns: 更新后的 AlertInfo
    func confirmed() -> AlertInfo {
        var updated = self
        updated.state = .confirmed
        updated.snoozeEndTime = nil
        return updated
    }
    
    /// 重新触发（延迟到期后）
    /// - Returns: 更新后的 AlertInfo
    func retriggered() -> AlertInfo {
        var updated = self
        updated.state = .alerting
        updated.snoozeEndTime = nil
        return updated
    }
    
    /// 取消/重置
    /// - Returns: 更新后的 AlertInfo
    func cancelled() -> AlertInfo {
        var updated = self
        updated.state = .idle
        updated.snoozeEndTime = nil
        return updated
    }
}

// MARK: - Alert Sound Type

/// 提醒声音类型
enum AlertSoundType: String, Codable, CaseIterable, Equatable {
    case radar = "radar"
    case beacon = "beacon"
    case chime = "chime"
    case signal = "signal"
    
    var displayName: String {
        switch self {
        case .radar: return "雷达"
        case .beacon: return "信标"
        case .chime: return "铃声"
        case .signal: return "信号"
        }
    }
    
    /// 声音文件名
    var fileName: String {
        rawValue
    }
}

// MARK: - Alert Configuration

/// 提醒配置常量
enum AlertConfiguration {
    /// 默认延迟时长（秒）
    static let defaultSnoozeDuration: TimeInterval = 300 // 5 分钟
    
    /// 最大延迟次数
    static let maxSnoozeCount: Int = 3
    
    /// 震动间隔（秒）
    static let hapticInterval: TimeInterval = 2.0
    
    /// 后续通知延迟（秒）
    static let followUpNotificationDelay: TimeInterval = 30.0
    
    /// 声音循环间隔（秒）
    static let soundLoopInterval: TimeInterval = 0.5
}
