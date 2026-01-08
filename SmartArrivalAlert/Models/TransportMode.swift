import Foundation
import MapKit

/// 交通方式枚举
/// 定义用户可选择的出行方式，每种方式有对应的基准速度和容差范围
enum TransportMode: String, Codable, CaseIterable, Equatable {
    case walking = "walking"      // 步行
    case cycling = "cycling"      // 骑行
    case driving = "driving"      // 驾车
    case subway = "subway"        // 地铁
    case bus = "bus"              // 公交
    case airplane = "airplane"    // 飞机
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .walking: return "步行"
        case .cycling: return "骑行"
        case .driving: return "驾车"
        case .subway: return "地铁"
        case .bus: return "公交"
        case .airplane: return "飞机"
        }
    }
    
    /// SF Symbol 图标名称
    var icon: String {
        switch self {
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        case .driving: return "car.fill"
        case .subway: return "tram.fill"
        case .bus: return "bus.fill"
        case .airplane: return "airplane"
        }
    }
    
    /// 基准速度 (米/秒)
    /// 步行 ~5 km/h, 骑行 ~18 km/h, 驾车 ~43 km/h, 地铁 ~54 km/h, 公交 ~29 km/h, 飞机 ~800 km/h
    var baselineSpeed: Double {
        switch self {
        case .walking: return 1.4    // ~5 km/h
        case .cycling: return 5.0    // ~18 km/h
        case .driving: return 12.0   // ~43 km/h
        case .subway: return 15.0    // ~54 km/h
        case .bus: return 8.0        // ~29 km/h
        case .airplane: return 222.0 // ~800 km/h
        }
    }
    
    /// 速度容差范围 (0.0-1.0)
    /// 表示实际速度与基准速度的允许偏差百分比
    var speedTolerance: Double {
        switch self {
        case .walking: return 0.30   // ±30%
        case .cycling: return 0.40   // ±40%
        case .driving: return 0.50   // ±50%
        case .subway: return 0.20    // ±20% (地铁速度相对稳定)
        case .bus: return 0.60       // ±60% (公交受交通影响大)
        case .airplane: return 0.30  // ±30% (飞机巡航速度相对稳定)
        }
    }
    
    /// 是否支持 MapKit 路线查询
    /// 步行、驾车支持；骑行在部分地区支持；公交在中国大陆支持有限；地铁、飞机不支持
    var supportsMapKitRouting: Bool {
        switch self {
        case .walking, .driving:
            return true
        case .cycling:
            return true  // iOS 14+ 支持骑行路线
        case .subway, .bus:
            return true  // 公交路线（包含地铁）
        case .airplane:
            return false // 飞机不支持路线查询，使用直线距离
        }
    }
    
    /// 对应的 MKDirectionsTransportType
    var mapKitTransportType: MKDirectionsTransportType? {
        switch self {
        case .walking:
            return .walking
        case .cycling:
            return .walking  // iOS 没有专门的骑行类型，用步行近似
        case .driving:
            return .automobile
        case .subway, .bus:
            return .transit
        case .airplane:
            return nil  // 飞机不支持
        }
    }
    
    /// 计算初始 ETA - 预计提醒时间 (分钟)
    /// - Parameters:
    ///   - distance: 到目的地中心的距离 (米)
    ///   - geofenceRadius: 围栏半径 (米)，默认为 0
    /// - Returns: 预计提醒时间 (分钟)
    func calculateInitialETA(distance: Double, geofenceRadius: Int = 0) -> Int {
        guard baselineSpeed > 0 else { return 0 }
        // 计算到围栏边界的距离
        let distanceToGeofence = max(0, distance - Double(geofenceRadius))
        let seconds = distanceToGeofence / baselineSpeed
        return Int(ceil(seconds / 60.0))
    }
    
    /// 检查速度是否在容差范围内
    /// - Parameter speed: 实际速度 (米/秒)
    /// - Returns: 是否在容差范围内
    func isSpeedWithinTolerance(_ speed: Double) -> Bool {
        let minSpeed = baselineSpeed * (1.0 - speedTolerance)
        let maxSpeed = baselineSpeed * (1.0 + speedTolerance)
        return speed >= minSpeed && speed <= maxSpeed
    }
    
    /// 计算速度偏差百分比
    /// - Parameter speed: 实际速度 (米/秒)
    /// - Returns: 偏差百分比 (0.0 表示完全匹配)
    func speedDeviation(_ speed: Double) -> Double {
        guard baselineSpeed > 0 else { return 1.0 }
        return abs(speed - baselineSpeed) / baselineSpeed
    }
    
    /// 检查是否需要建议切换交通方式
    /// - Parameter speed: 实际速度 (米/秒)
    /// - Returns: 是否偏差超过 50%
    func shouldSuggestModeCorrection(_ speed: Double) -> Bool {
        return speedDeviation(speed) > 0.5
    }
    
    /// 根据速度检测可能的交通方式
    /// - Parameter averageSpeed: 平均速度 (米/秒)
    /// - Returns: 最可能的交通方式
    static func detectMode(fromSpeed averageSpeed: Double) -> TransportMode {
        // 速度范围判断
        if averageSpeed < 2.5 {
            return .walking
        } else if averageSpeed < 8.0 {
            return .cycling
        } else if averageSpeed < 12.0 {
            return .bus
        } else if averageSpeed < 18.0 {
            return .driving
        } else {
            return .subway
        }
    }
}
