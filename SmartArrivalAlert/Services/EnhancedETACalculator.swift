import Foundation

/// ETA 置信度等级
enum ETAConfidence: String, Codable, Equatable {
    case high = "high"          // 高置信度 - 速度在交通方式容差范围内
    case medium = "medium"      // 中置信度 - 速度略微偏离容差范围
    case low = "low"            // 低置信度 - 高方差或未知状态
}

/// 增强 ETA 计算结果
struct EnhancedETAResult: Equatable {
    let estimatedMinutes: Int?      // 预计分钟数
    let minMinutes: Int?            // 最小分钟数（低置信度时显示范围）
    let maxMinutes: Int?            // 最大分钟数（低置信度时显示范围）
    let confidence: ETAConfidence   // 置信度
    let isStationary: Bool          // 是否静止
    let smoothedSpeed: Double       // 平滑后的速度
    
    /// 格式化显示
    var displayText: String {
        if isStationary {
            return "已停止"
        }
        
        guard let minutes = estimatedMinutes else {
            return "计算中..."
        }
        
        switch confidence {
        case .high:
            return formatMinutes(minutes)
        case .medium:
            return "约 \(formatMinutes(minutes))"
        case .low:
            if let min = minMinutes, let max = maxMinutes {
                return "\(formatMinutes(min)) - \(formatMinutes(max))"
            }
            return "约 \(formatMinutes(minutes))"
        }
    }
    
    private func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) 分钟"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 {
                return "\(hours) 小时"
            }
            return "\(hours) 小时 \(mins) 分钟"
        }
    }
    
    /// 无效结果
    static let invalid = EnhancedETAResult(
        estimatedMinutes: nil,
        minMinutes: nil,
        maxMinutes: nil,
        confidence: .low,
        isStationary: false,
        smoothedSpeed: 0
    )
    
    /// 静止状态结果
    static let stationary = EnhancedETAResult(
        estimatedMinutes: nil,
        minMinutes: nil,
        maxMinutes: nil,
        confidence: .low,
        isStationary: true,
        smoothedSpeed: 0
    )
}

/// 增强 ETA 计算器
/// 使用 EWMA 速度平滑、历史数据融合和交通方式基准速度计算 ETA
class EnhancedETACalculator {
    
    // MARK: - Configuration
    
    /// EWMA 平滑系数 (0-1, 越大越重视新数据)
    static let ewmaAlpha: Double = 0.3
    
    /// 速度历史窗口大小
    static let windowSize: Int = 10
    
    /// 静止状态速度阈值 (米/秒)
    static let stationaryThreshold: Double = 0.5
    
    /// 静止状态持续时间阈值 (秒)
    static let stationaryDuration: TimeInterval = 30
    
    /// 历史数据权重 (当前速度 70%, 历史 30%)
    static let currentSpeedWeight: Double = 0.7
    static let historicalSpeedWeight: Double = 0.3
    
    // MARK: - State
    
    /// 速度历史记录
    private var speedHistory: [Double] = []
    
    /// EWMA 平滑速度
    private var ewmaSpeed: Double?
    
    /// 是否处于静止状态
    private var isStationary: Bool = false
    
    /// 静止状态开始时间
    private var stationaryStartTime: Date?
    
    // MARK: - Public Methods
    
    /// 计算 ETA
    /// - Parameters:
    ///   - distance: 距离 (米)
    ///   - currentSpeed: 当前速度 (米/秒)
    ///   - transportMode: 交通方式
    ///   - historicalAverage: 历史平均速度 (可选)
    /// - Returns: ETA 计算结果
    func calculateETA(
        distance: Double,
        currentSpeed: Double,
        transportMode: TransportMode,
        historicalAverage: Double? = nil
    ) -> EnhancedETAResult {
        // 1. 更新速度历史
        updateSpeedHistory(currentSpeed)
        
        // 2. 计算 EWMA 平滑速度
        let smoothedSpeed = calculateEWMASpeed(currentSpeed)
        
        // 3. 检测静止状态
        updateStationaryState(smoothedSpeed)
        
        if isStationary {
            return EnhancedETAResult(
                estimatedMinutes: nil,
                minMinutes: nil,
                maxMinutes: nil,
                confidence: .low,
                isStationary: true,
                smoothedSpeed: smoothedSpeed
            )
        }
        
        // 4. 融合历史数据
        let blendedSpeed = blendWithHistorical(
            currentSpeed: smoothedSpeed,
            historicalAverage: historicalAverage,
            transportMode: transportMode
        )
        
        // 5. 计算置信度
        let confidence = calculateConfidence(
            speed: blendedSpeed,
            transportMode: transportMode
        )
        
        // 6. 计算 ETA
        guard blendedSpeed > 0 else {
            return .invalid
        }
        
        let etaSeconds = distance / blendedSpeed
        let etaMinutes = Int(ceil(etaSeconds / 60.0))
        
        // 7. 低置信度时计算范围
        var minMinutes: Int? = nil
        var maxMinutes: Int? = nil
        
        if confidence == .low {
            let variance = calculateSpeedVariance()
            let minSpeed = max(0.5, blendedSpeed - variance)
            let maxSpeed = blendedSpeed + variance
            
            minMinutes = Int(ceil(distance / maxSpeed / 60.0))
            maxMinutes = Int(ceil(distance / minSpeed / 60.0))
        }
        
        return EnhancedETAResult(
            estimatedMinutes: etaMinutes,
            minMinutes: minMinutes,
            maxMinutes: maxMinutes,
            confidence: confidence,
            isStationary: false,
            smoothedSpeed: smoothedSpeed
        )
    }
    
    /// 重置计算器状态
    func reset() {
        speedHistory.removeAll()
        ewmaSpeed = nil
        isStationary = false
        stationaryStartTime = nil
    }
    
    /// 获取当前 EWMA 速度
    var currentEWMASpeed: Double? {
        return ewmaSpeed
    }
    
    // MARK: - Private Methods
    
    /// 更新速度历史
    private func updateSpeedHistory(_ speed: Double) {
        speedHistory.append(speed)
        if speedHistory.count > Self.windowSize {
            speedHistory.removeFirst()
        }
    }
    
    /// 计算 EWMA 平滑速度
    /// EWMA = α * current + (1-α) * previous
    private func calculateEWMASpeed(_ currentSpeed: Double) -> Double {
        if let previous = ewmaSpeed {
            let smoothed = Self.ewmaAlpha * currentSpeed + (1 - Self.ewmaAlpha) * previous
            ewmaSpeed = smoothed
            return smoothed
        } else {
            ewmaSpeed = currentSpeed
            return currentSpeed
        }
    }
    
    /// 更新静止状态
    private func updateStationaryState(_ speed: Double) {
        if speed < Self.stationaryThreshold {
            if stationaryStartTime == nil {
                stationaryStartTime = Date()
            } else if let startTime = stationaryStartTime,
                      Date().timeIntervalSince(startTime) >= Self.stationaryDuration {
                isStationary = true
            }
        } else {
            stationaryStartTime = nil
            isStationary = false
        }
    }
    
    /// 融合历史数据
    /// 70% 当前速度 + 30% 历史速度
    private func blendWithHistorical(
        currentSpeed: Double,
        historicalAverage: Double?,
        transportMode: TransportMode
    ) -> Double {
        // 如果有历史数据，使用加权融合
        if let historical = historicalAverage, historical > 0 {
            return Self.currentSpeedWeight * currentSpeed + Self.historicalSpeedWeight * historical
        }
        
        // 如果当前速度太低，使用交通方式基准速度作为参考
        if currentSpeed < 0.5 {
            return transportMode.baselineSpeed
        }
        
        return currentSpeed
    }
    
    /// 计算置信度
    private func calculateConfidence(
        speed: Double,
        transportMode: TransportMode
    ) -> ETAConfidence {
        // 检查速度是否在交通方式容差范围内
        if transportMode.isSpeedWithinTolerance(speed) {
            return .high
        }
        
        // 检查偏差程度
        let deviation = transportMode.speedDeviation(speed)
        if deviation <= 0.7 {  // 偏差 <= 70%
            return .medium
        }
        
        return .low
    }
    
    /// 计算速度方差
    private func calculateSpeedVariance() -> Double {
        guard speedHistory.count >= 2 else { return 1.0 }
        
        let mean = speedHistory.reduce(0, +) / Double(speedHistory.count)
        let squaredDiffs = speedHistory.map { pow($0 - mean, 2) }
        let variance = squaredDiffs.reduce(0, +) / Double(speedHistory.count)
        
        return sqrt(variance)
    }
}

// MARK: - Static Helpers

extension EnhancedETACalculator {
    
    /// 静态方法：简单 ETA 计算
    static func simpleETA(distance: Double, speed: Double) -> Int? {
        guard speed > 0 else { return nil }
        return Int(ceil(distance / speed / 60.0))
    }
    
    /// 静态方法：使用交通方式基准速度计算 ETA
    static func baselineETA(distance: Double, mode: TransportMode) -> Int {
        return mode.calculateInitialETA(distance: distance)
    }
}
