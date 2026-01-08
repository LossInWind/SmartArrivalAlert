import Foundation

/// ETA 计算服务 - 基于距离、速度和信号质量计算预计到达时间
class ETACalculator {
    
    // MARK: - Properties
    
    /// 速度历史记录（用于平滑）
    private var speedHistory: [Double] = []
    
    /// 最大历史记录数量
    private let maxHistorySize = 5
    
    /// 静止速度阈值（米/秒）
    private let stationaryThreshold = 0.5
    
    // MARK: - Singleton
    
    static let shared = ETACalculator()
    
    init() {}
    
    // MARK: - Public Methods
    
    /// 计算 ETA（预计提醒时间）
    /// - Parameters:
    ///   - distance: 到目的地中心的距离（米）
    ///   - currentSpeed: 当前速度（米/秒）
    ///   - signalQuality: 信号质量等级
    ///   - geofenceRadius: 围栏半径（米），默认为 0 表示计算到目的地的时间
    /// - Returns: ETA 计算结果
    func calculateETA(
        distance: Double,
        currentSpeed: Double,
        signalQuality: SignalQualityLevel,
        geofenceRadius: Int = 0
    ) -> ETAResult {
        // 获取平滑后的速度
        let smoothed = smoothedSpeed(currentSpeed: currentSpeed)
        
        // 如果用户静止或速度过低，返回"计算中"
        guard smoothed > stationaryThreshold else {
            return .calculating
        }
        
        // 计算到围栏边界的距离（预计提醒距离）
        // 距离 = 到目的地距离 - 围栏半径
        let distanceToGeofence = max(0, distance - Double(geofenceRadius))
        
        // 计算基础 ETA（秒）
        let etaSeconds = distanceToGeofence / smoothed
        
        // 获取置信度因子
        let confidence = confidenceFactor(for: signalQuality)
        
        // 转换为分钟
        let etaMinutes = Int(ceil(etaSeconds / 60.0))
        
        return ETAResult.withMinutes(etaMinutes, confidence: confidence)
    }
    
    /// 获取信号质量对应的置信度因子
    /// - Parameter quality: 信号质量等级
    /// - Returns: 置信度因子 (0.0 - 1.0)
    func confidenceFactor(for quality: SignalQualityLevel) -> Double {
        switch quality {
        case .good:
            return 1.0
        case .fair:
            return 0.8
        case .poor:
            return 0.5
        case .unknown:
            return 0.3
        }
    }
    
    /// 计算平滑速度（移动平均）
    /// - Parameter currentSpeed: 当前速度
    /// - Returns: 平滑后的速度
    func smoothedSpeed(currentSpeed: Double) -> Double {
        // 添加到历史记录
        speedHistory.append(currentSpeed)
        
        // 保持历史记录在最大数量内
        if speedHistory.count > maxHistorySize {
            speedHistory.removeFirst()
        }
        
        // 计算移动平均
        guard !speedHistory.isEmpty else {
            return currentSpeed
        }
        
        let sum = speedHistory.reduce(0, +)
        return sum / Double(speedHistory.count)
    }
    
    /// 重置速度历史记录
    func reset() {
        speedHistory.removeAll()
    }
    
    /// 获取当前速度历史记录数量（用于测试）
    var historyCount: Int {
        speedHistory.count
    }
}
