import Foundation

/// 电池模式枚举
/// 定义不同的省电策略，影响位置检查频率
enum BatteryMode: String, Codable, CaseIterable, Equatable {
    case powerSaving = "powerSaving"    // 省电模式
    case balanced = "balanced"          // 平衡模式
    case highAccuracy = "highAccuracy"  // 高精度模式
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .powerSaving: return "省电模式"
        case .balanced: return "平衡模式"
        case .highAccuracy: return "高精度模式"
        }
    }
    
    /// 描述
    var description: String {
        switch self {
        case .powerSaving: return "降低检查频率，延长电池续航"
        case .balanced: return "平衡精度与电量消耗"
        case .highAccuracy: return "提高检查频率，更精确的到站提醒"
        }
    }
    
    /// SF Symbol 图标名称
    var icon: String {
        switch self {
        case .powerSaving: return "battery.100"
        case .balanced: return "battery.75"
        case .highAccuracy: return "location.fill"
        }
    }
    
    /// 间隔倍数
    /// 省电模式 2x, 平衡模式 1x, 高精度模式 0.5x
    var intervalMultiplier: Double {
        switch self {
        case .powerSaving: return 2.0
        case .balanced: return 1.0
        case .highAccuracy: return 0.5
        }
    }
}

/// 距离层级枚举
/// 根据距离目的地的远近划分不同的检查频率层级
enum DistanceTier: String, Codable, CaseIterable, Equatable {
    case veryFar = "veryFar"    // > 5km
    case far = "far"            // 2-5km
    case medium = "medium"      // 500m-2km
    case close = "close"        // < 500m
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .veryFar: return "很远"
        case .far: return "较远"
        case .medium: return "中等"
        case .close: return "接近"
        }
    }
    
    /// 基础检查间隔 (秒)
    var baseInterval: TimeInterval {
        switch self {
        case .veryFar: return 60.0   // 60秒
        case .far: return 30.0       // 30秒
        case .medium: return 15.0    // 15秒
        case .close: return 5.0      // 5秒
        }
    }
    
    /// 距离阈值 (米)
    /// 返回进入该层级的最小距离
    var minDistance: Double {
        switch self {
        case .veryFar: return 5000.0   // > 5km
        case .far: return 2000.0       // > 2km
        case .medium: return 500.0     // > 500m
        case .close: return 0.0        // >= 0m
        }
    }
    
    /// 根据距离获取对应的层级
    /// - Parameter distance: 距离 (米)
    /// - Returns: 对应的距离层级
    static func fromDistance(_ distance: Double) -> DistanceTier {
        if distance > 5000 {
            return .veryFar
        } else if distance > 2000 {
            return .far
        } else if distance > 500 {
            return .medium
        } else {
            return .close
        }
    }
    
    /// 获取下一个更近的层级
    var nextCloserTier: DistanceTier? {
        switch self {
        case .veryFar: return .far
        case .far: return .medium
        case .medium: return .close
        case .close: return nil
        }
    }
}
