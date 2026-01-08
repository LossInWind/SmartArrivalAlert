import Foundation

/// 风险等级
enum RiskLevel: String, Codable, Equatable {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

/// 权限状态
enum PermissionStatus: String, Codable, Equatable {
    case authorized = "authorized"
    case denied = "denied"
    case notDetermined = "notDetermined"
    case restricted = "restricted"
}

/// 风险评估结果
struct RiskAssessment: Codable, Equatable {
    let overallRisk: RiskLevel
    let permissionOk: Bool
    let destinationSignalQuality: SignalQuality
    let routeSignalQuality: SignalQuality
    let historicalSuccessRate: Double  // 0-100
    let warnings: [String]
    let suggestEarlyTrigger: Bool
    let suggestBackupAlarm: Bool
    
    init(
        overallRisk: RiskLevel,
        permissionOk: Bool,
        destinationSignalQuality: SignalQuality,
        routeSignalQuality: SignalQuality,
        historicalSuccessRate: Double,
        warnings: [String] = [],
        suggestEarlyTrigger: Bool = false,
        suggestBackupAlarm: Bool = false
    ) {
        self.overallRisk = overallRisk
        self.permissionOk = permissionOk
        self.destinationSignalQuality = destinationSignalQuality
        self.routeSignalQuality = routeSignalQuality
        self.historicalSuccessRate = historicalSuccessRate
        self.warnings = warnings
        self.suggestEarlyTrigger = suggestEarlyTrigger
        self.suggestBackupAlarm = suggestBackupAlarm
    }
}


/// 兜底闹钟状态
struct BackupAlarmState: Codable, Equatable {
    let alarmId: String
    let scheduledTime: Date
    let destinationId: String
    let etaMinutesWhenSet: Int
}


/// 行程速度记录
struct TripSpeedRecord: Codable, Equatable {
    let destinationId: String
    let transportMode: TransportMode
    let averageSpeed: Double      // 米/秒
    let timestamp: Date
}


// MARK: - Calculators

/// 兜底闹钟计算器
enum BackupAlarmCalculator {
    /// 计算闹钟时间
    static func calculateAlarmTime(currentTime: Date, etaMinutes: Int, offsetMinutes: Int) -> Date {
        let alarmMinutes = etaMinutes - offsetMinutes
        return currentTime.addingTimeInterval(Double(alarmMinutes) * 60)
    }
    
    /// 判断是否应该更新闹钟（ETA 变化超过 5 分钟）
    static func shouldUpdateAlarm(previousETAMinutes: Int, newETAMinutes: Int) -> Bool {
        return abs(newETAMinutes - previousETAMinutes) > 5
    }
}

/// 风险等级计算器
enum RiskLevelCalculator {
    /// 高风险阈值
    static let highRiskThreshold: Double = 70.0
    
    /// 中风险阈值
    static let mediumRiskThreshold: Double = 85.0
    
    /// 判断风险等级
    static func determineRiskLevel(reliabilityScore: Double) -> RiskLevel {
        if reliabilityScore < highRiskThreshold {
            return .high
        } else if reliabilityScore < mediumRiskThreshold {
            return .medium
        } else {
            return .low
        }
    }
    
    /// 是否应该自动启用提前触发
    static func shouldAutoEnableEarlyTrigger(reliabilityScore: Double) -> Bool {
        return reliabilityScore < highRiskThreshold
    }
    
    /// 是否应该建议启用兜底闹钟
    static func shouldSuggestBackupAlarm(reliabilityScore: Double) -> Bool {
        return reliabilityScore < mediumRiskThreshold && reliabilityScore >= highRiskThreshold
    }
}
