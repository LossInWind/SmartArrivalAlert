import Foundation

/// 刷新间隔计算器
/// 根据 ETA 和电池模式动态计算路线刷新间隔
struct RefreshIntervalCalculator {
    
    // MARK: - Constants
    
    /// ETA 阈值（分钟）
    private enum ETAThreshold {
        static let veryClose = 5      // < 5 分钟
        static let close = 10         // 5-10 分钟
        static let medium = 30        // 10-30 分钟
        // > 30 分钟为远距离
    }
    
    /// 基础刷新间隔（秒）- 平衡模式
    private enum BaseInterval {
        static let veryClose: TimeInterval = 60      // 1 分钟
        static let close: TimeInterval = 120         // 2 分钟
        static let medium: TimeInterval = 300        // 5 分钟
        static let far: TimeInterval = 600           // 10 分钟
    }
    
    // MARK: - Public Methods
    
    /// 根据 ETA 和电池模式计算刷新间隔
    /// - Parameters:
    ///   - etaMinutes: 预计到达时间（分钟）
    ///   - batteryMode: 电池模式
    /// - Returns: 刷新间隔（秒）
    static func calculate(etaMinutes: Int, batteryMode: BatteryMode) -> TimeInterval {
        let baseInterval = getBaseInterval(etaMinutes: etaMinutes)
        return applyBatteryModeMultiplier(baseInterval: baseInterval, batteryMode: batteryMode)
    }
    
    /// 获取基础刷新间隔（平衡模式）
    /// - Parameter etaMinutes: 预计到达时间（分钟）
    /// - Returns: 基础刷新间隔（秒）
    static func getBaseInterval(etaMinutes: Int) -> TimeInterval {
        switch etaMinutes {
        case 0..<ETAThreshold.veryClose:
            return BaseInterval.veryClose      // < 5 分钟：每 1 分钟刷新
        case ETAThreshold.veryClose..<ETAThreshold.close:
            return BaseInterval.close          // 5-10 分钟：每 2 分钟刷新
        case ETAThreshold.close..<ETAThreshold.medium:
            return BaseInterval.medium         // 10-30 分钟：每 5 分钟刷新
        default:
            return BaseInterval.far            // > 30 分钟：每 10 分钟刷新
        }
    }
    
    /// 应用电池模式倍数
    /// - Parameters:
    ///   - baseInterval: 基础间隔
    ///   - batteryMode: 电池模式
    /// - Returns: 调整后的间隔
    static func applyBatteryModeMultiplier(baseInterval: TimeInterval, batteryMode: BatteryMode) -> TimeInterval {
        switch batteryMode {
        case .highAccuracy:
            return baseInterval * 0.5    // 高精度：减半
        case .balanced:
            return baseInterval          // 平衡：不变
        case .powerSaving:
            return baseInterval * 1.5    // 省电：增加 50%
        }
    }
    
    /// 获取所有 ETA 范围的刷新间隔配置
    /// - Parameter batteryMode: 电池模式
    /// - Returns: 各 ETA 范围对应的刷新间隔
    static func getAllIntervals(for batteryMode: BatteryMode) -> [(etaRange: String, interval: TimeInterval)] {
        return [
            ("< 5 分钟", calculate(etaMinutes: 3, batteryMode: batteryMode)),
            ("5-10 分钟", calculate(etaMinutes: 7, batteryMode: batteryMode)),
            ("10-30 分钟", calculate(etaMinutes: 20, batteryMode: batteryMode)),
            ("> 30 分钟", calculate(etaMinutes: 60, batteryMode: batteryMode))
        ]
    }
    
    /// 格式化间隔为可读文本
    /// - Parameter interval: 间隔（秒）
    /// - Returns: 格式化文本
    static func formatInterval(_ interval: TimeInterval) -> String {
        let seconds = Int(interval)
        if seconds >= 60 {
            let minutes = seconds / 60
            let remainingSeconds = seconds % 60
            if remainingSeconds == 0 {
                return "\(minutes) 分钟"
            } else {
                return "\(minutes) 分 \(remainingSeconds) 秒"
            }
        } else {
            return "\(seconds) 秒"
        }
    }
}

// MARK: - Location Threshold Calculator

/// 位置变化阈值计算器
/// 用于判断是否需要刷新路线
struct LocationThresholdCalculator {
    
    // MARK: - Constants
    
    /// 立即刷新阈值（米）- 位置变化超过此值立即刷新
    static let immediateRefreshThreshold: Double = 500.0
    
    /// 缓存复用阈值（米）- 位置变化小于此值使用缓存
    static let cacheReuseThreshold: Double = 100.0
    
    // MARK: - Public Methods
    
    /// 检查是否需要立即刷新
    /// - Parameters:
    ///   - currentLocation: 当前位置
    ///   - lastQueryLocation: 上次查询位置
    /// - Returns: 是否需要立即刷新
    static func shouldRefreshImmediately(
        currentLocation: (latitude: Double, longitude: Double),
        lastQueryLocation: (latitude: Double, longitude: Double)
    ) -> Bool {
        let distance = GeoUtils.calculateDistance(
            lat1: currentLocation.latitude,
            lon1: currentLocation.longitude,
            lat2: lastQueryLocation.latitude,
            lon2: lastQueryLocation.longitude
        )
        return distance > immediateRefreshThreshold
    }
    
    /// 检查是否应该使用缓存
    /// - Parameters:
    ///   - currentLocation: 当前位置
    ///   - lastQueryLocation: 上次查询位置
    /// - Returns: 是否应该使用缓存
    static func shouldUseCache(
        currentLocation: (latitude: Double, longitude: Double),
        lastQueryLocation: (latitude: Double, longitude: Double)
    ) -> Bool {
        let distance = GeoUtils.calculateDistance(
            lat1: currentLocation.latitude,
            lon1: currentLocation.longitude,
            lat2: lastQueryLocation.latitude,
            lon2: lastQueryLocation.longitude
        )
        return distance < cacheReuseThreshold
    }
    
    /// 计算两点之间的距离
    /// - Parameters:
    ///   - location1: 位置 1
    ///   - location2: 位置 2
    /// - Returns: 距离（米）
    static func calculateDistance(
        from location1: (latitude: Double, longitude: Double),
        to location2: (latitude: Double, longitude: Double)
    ) -> Double {
        return GeoUtils.calculateDistance(
            lat1: location1.latitude,
            lon1: location1.longitude,
            lat2: location2.latitude,
            lon2: location2.longitude
        )
    }
}
