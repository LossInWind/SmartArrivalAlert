import Foundation

/// Live Activity 格式化工具
/// 提供距离格式化和进度计算功能，用于灵动岛和锁屏显示
/// Feature: live-activity-enhancement
enum LiveActivityFormatters {
    
    // MARK: - Constants
    
    /// 千米阈值（米）
    static let kilometerThreshold: Int = 1000
    
    /// 最大显示距离倍数（相对于围栏半径）
    static let maxDistanceMultiplier: Double = 10.0
    
    // MARK: - Display Mode
    
    /// 显示模式
    enum DisplayMode {
        case normal      // 正常显示 ETA
        case unreliable  // ETA 不可靠，显示距离
        case arrived     // 已到达
    }
    
    /// 根据状态确定显示模式
    /// - Parameters:
    ///   - isInsideGeofence: 是否在围栏内
    ///   - isETAReliable: ETA 是否可靠
    ///   - distance: 当前距离
    ///   - geofenceRadius: 围栏半径
    /// - Returns: 显示模式
    static func determineDisplayMode(
        isInsideGeofence: Bool,
        isETAReliable: Bool,
        distance: Int,
        geofenceRadius: Int
    ) -> DisplayMode {
        // 已到达判断：在围栏内或距离小于等于围栏半径
        if isInsideGeofence || distance <= geofenceRadius {
            return .arrived
        }
        // ETA 不可靠时显示距离
        if !isETAReliable {
            return .unreliable
        }
        return .normal
    }
    
    // MARK: - Distance Formatting
    
    /// 格式化距离（完整格式）
    /// - Parameter meters: 距离（米）
    /// - Returns: 格式化后的字符串，如 "500 m" 或 "1.5 km"
    ///
    /// 规则：
    /// - 距离 < 1000m：显示为米，如 "500 m"
    /// - 距离 >= 1000m：显示为公里，保留一位小数，如 "1.5 km"
    /// **Validates: Requirements 2.2, 3.2**
    static func formatDistance(_ meters: Int) -> String {
        guard meters >= 0 else { return "0 m" }
        
        if meters < kilometerThreshold {
            return "\(meters) m"
        } else {
            let km = Double(meters) / 1000.0
            return String(format: "%.1f km", km)
        }
    }
    
    /// 格式化距离（紧凑格式，用于灵动岛紧凑视图）
    /// - Parameter meters: 距离（米）
    /// - Returns: 格式化后的紧凑字符串，如 "500m" 或 "1.5km"
    ///
    /// 规则：
    /// - 距离 < 1000m：显示为米，无空格，如 "500m"
    /// - 距离 >= 1000m：显示为公里，保留一位小数，无空格，如 "1.5km"
    /// **Validates: Requirements 2.2, 3.2**
    static func formatCompactDistance(_ meters: Int) -> String {
        guard meters >= 0 else { return "0m" }
        
        if meters < kilometerThreshold {
            return "\(meters)m"
        } else {
            let km = Double(meters) / 1000.0
            return String(format: "%.1fkm", km)
        }
    }
    
    // MARK: - Progress Calculation
    
    /// 计算行程进度
    /// - Parameters:
    ///   - distance: 当前距离目的地的距离（米）
    ///   - geofenceRadius: 围栏半径（米）
    /// - Returns: 进度值，范围 0.0 到 1.0
    ///
    /// 规则：
    /// - 距离 <= 围栏半径：返回 1.0（已到达）
    /// - 距离 >= 最大显示距离（围栏半径 * 10）：返回 0.0（刚开始）
    /// - 其他情况：线性插值，距离越近进度越高
    ///
    /// 进度计算公式：
    /// progress = 1.0 - (distance - geofenceRadius) / (maxDistance - geofenceRadius)
    /// **Validates: Requirements 3.5**
    static func calculateProgress(distance: Int, geofenceRadius: Int) -> Double {
        // 确保参数有效
        guard geofenceRadius > 0 else { return 0.0 }
        guard distance >= 0 else { return 1.0 }
        
        let distanceDouble = Double(distance)
        let radiusDouble = Double(geofenceRadius)
        let maxDistance = radiusDouble * maxDistanceMultiplier
        
        // 已到达围栏内
        if distanceDouble <= radiusDouble {
            return 1.0
        }
        
        // 超出最大显示距离
        if distanceDouble >= maxDistance {
            return 0.0
        }
        
        // 线性插值计算进度
        let progress = 1.0 - (distanceDouble - radiusDouble) / (maxDistance - radiusDouble)
        
        // 确保结果在 0.0 到 1.0 之间
        return max(0.0, min(1.0, progress))
    }
    
    /// 计算行程进度（带初始距离）
    /// - Parameters:
    ///   - currentDistance: 当前距离目的地的距离（米）
    ///   - geofenceRadius: 围栏半径（米）
    ///   - initialDistance: 初始距离（米），用于计算相对进度
    /// - Returns: 进度值，范围 0.0 到 1.0
    /// **Validates: Requirements 3.5**
    static func calculateProgress(
        currentDistance: Int,
        geofenceRadius: Int,
        initialDistance: Int
    ) -> Double {
        // 确保参数有效
        guard geofenceRadius > 0 else { return 0.0 }
        guard currentDistance >= 0 else { return 1.0 }
        guard initialDistance > geofenceRadius else { return 1.0 }
        
        // 已到达围栏内
        if currentDistance <= geofenceRadius {
            return 1.0
        }
        
        // 超出初始距离（可能是绕路）
        if currentDistance >= initialDistance {
            return 0.0
        }
        
        // 线性插值计算进度
        let progress = 1.0 - Double(currentDistance - geofenceRadius) / Double(initialDistance - geofenceRadius)
        
        // 确保结果在 0.0 到 1.0 之间
        return max(0.0, min(1.0, progress))
    }
    
    // MARK: - ETA Formatting
    
    /// 格式化 ETA（预计到达时间）
    /// - Parameter minutes: 预计分钟数
    /// - Returns: 格式化后的字符串
    static func formatETA(_ minutes: Int?) -> String {
        guard let minutes = minutes else { return "--" }
        
        if minutes <= 0 {
            return "即将到达"
        } else if minutes < 60 {
            return "\(minutes) 分钟"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) 小时"
            } else {
                return "\(hours) 小时 \(remainingMinutes) 分钟"
            }
        }
    }
    
    /// 格式化 ETA（紧凑格式）
    /// - Parameter minutes: 预计分钟数
    /// - Returns: 格式化后的紧凑字符串
    static func formatCompactETA(_ minutes: Int?) -> String {
        guard let minutes = minutes else { return "--" }
        
        if minutes <= 0 {
            return "到达"
        } else if minutes < 60 {
            return "\(minutes)分"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h\(remainingMinutes)m"
            }
        }
    }
    
    // MARK: - Compact Trailing Display
    
    /// 获取灵动岛收起状态右侧显示内容
    /// - Parameters:
    ///   - etaMinutes: 预计分钟数
    ///   - isETAReliable: ETA 是否可靠
    ///   - distance: 当前距离
    ///   - isInsideGeofence: 是否在围栏内
    /// - Returns: 显示文本
    /// **Validates: Requirements 1.2, 1.3**
    static func compactTrailingText(
        etaMinutes: Int?,
        isETAReliable: Bool,
        distance: Int,
        isInsideGeofence: Bool
    ) -> String {
        // 已到达时不显示文本（显示图标）
        if isInsideGeofence {
            return ""
        }
        
        // ETA 可靠且有值时显示分钟数
        if isETAReliable, let eta = etaMinutes {
            return "\(eta)分"
        }
        
        // ETA 不可靠或无值时显示距离
        return formatCompactDistance(distance)
    }
    
    /// 判断是否应该显示到达图标
    /// - Parameters:
    ///   - isInsideGeofence: 是否在围栏内
    ///   - distance: 当前距离
    ///   - geofenceRadius: 围栏半径
    /// - Returns: 是否显示到达图标
    /// **Validates: Requirements 1.4, 2.6, 3.7, 5.3**
    static func shouldShowArrivalIcon(
        isInsideGeofence: Bool,
        distance: Int,
        geofenceRadius: Int
    ) -> Bool {
        return isInsideGeofence || distance <= geofenceRadius
    }
}
