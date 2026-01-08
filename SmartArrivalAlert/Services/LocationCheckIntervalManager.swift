import Foundation

/// 位置检查间隔管理器
/// 根据距离、速度和电池模式动态计算位置检查间隔
class LocationCheckIntervalManager {
    
    // MARK: - Constants
    
    /// 高速阈值 (米/秒) - 超过此速度时提升检查频率
    static let highSpeedThreshold: Double = 20.0
    
    /// 最小检查间隔 (秒)
    static let minimumInterval: TimeInterval = 5.0
    
    /// 最大检查间隔 (秒)
    static let maximumInterval: TimeInterval = 120.0
    
    // MARK: - Public Methods
    
    /// 计算位置检查间隔
    /// - Parameters:
    ///   - distance: 距离目的地的距离 (米)
    ///   - speed: 当前速度 (米/秒)
    ///   - batteryMode: 电池模式
    /// - Returns: 检查间隔 (秒)
    func calculateInterval(
        distance: Double,
        speed: Double,
        batteryMode: BatteryMode
    ) -> TimeInterval {
        // 1. 获取基于距离的基础间隔
        let tier = getDistanceTier(distance: distance)
        var interval = tier.baseInterval
        
        // 2. 应用电池模式倍数
        interval *= batteryMode.intervalMultiplier
        
        // 3. 高速时提升检查频率（降低间隔）
        if speed > Self.highSpeedThreshold {
            // 使用下一个更近层级的间隔
            if let closerTier = tier.nextCloserTier {
                interval = min(interval, closerTier.baseInterval * batteryMode.intervalMultiplier)
            }
        }
        
        // 4. 确保在有效范围内
        return clampInterval(interval)
    }
    
    /// 获取距离层级
    /// - Parameter distance: 距离 (米)
    /// - Returns: 距离层级
    func getDistanceTier(distance: Double) -> DistanceTier {
        return DistanceTier.fromDistance(distance)
    }
    
    /// 计算基于到达时间的动态间隔
    /// - Parameters:
    ///   - distance: 距离 (米)
    ///   - speed: 速度 (米/秒)
    ///   - batteryMode: 电池模式
    /// - Returns: 检查间隔 (秒)
    func calculateDynamicInterval(
        distance: Double,
        speed: Double,
        batteryMode: BatteryMode
    ) -> TimeInterval {
        // 如果速度有效，基于预计到达时间计算
        if speed > 0.5 {
            let etaSeconds = distance / speed
            
            // 根据 ETA 调整间隔
            // ETA < 1分钟: 5秒
            // ETA < 5分钟: 10秒
            // ETA < 15分钟: 20秒
            // ETA < 30分钟: 30秒
            // ETA >= 30分钟: 60秒
            var interval: TimeInterval
            if etaSeconds < 60 {
                interval = 5.0
            } else if etaSeconds < 300 {
                interval = 10.0
            } else if etaSeconds < 900 {
                interval = 20.0
            } else if etaSeconds < 1800 {
                interval = 30.0
            } else {
                interval = 60.0
            }
            
            // 应用电池模式
            interval *= batteryMode.intervalMultiplier
            
            return clampInterval(interval)
        }
        
        // 速度无效时使用基于距离的计算
        return calculateInterval(distance: distance, speed: speed, batteryMode: batteryMode)
    }
    
    // MARK: - Private Methods
    
    /// 将间隔限制在有效范围内
    private func clampInterval(_ interval: TimeInterval) -> TimeInterval {
        return max(Self.minimumInterval, min(interval, Self.maximumInterval))
    }
}
