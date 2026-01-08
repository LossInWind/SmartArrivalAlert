import Foundation
import CoreLocation

/// 速度计算来源
enum SpeedSource: String, Codable, Equatable {
    case clLocation = "clLocation"      // 来自 CLLocation.speed
    case calculated = "calculated"      // 通过距离/时间计算
}

/// 速度样本
struct SpeedSample: Codable, Equatable {
    let speed: Double           // 速度 (米/秒)
    let confidence: Double      // 置信度 (0.0-1.0)
    let timestamp: Date         // 时间戳
    let accuracy: Double        // GPS 精度 (米)
}

/// 速度计算结果
struct SpeedResult: Equatable {
    let speed: Double           // 速度 (米/秒)
    let confidence: Double      // 置信度 (0.0-1.0)
    let isValid: Bool           // 是否有效
    let source: SpeedSource     // 来源
    
    /// 无效结果
    static let invalid = SpeedResult(speed: 0, confidence: 0, isValid: false, source: .calculated)
}

/// 速度计算器
/// 负责从位置数据计算速度，包含 GPS 噪声过滤和精度权重调整
class SpeedCalculator {
    
    // MARK: - Constants
    
    /// 有效速度计算的最小距离 (米)
    static let minDistanceForValidSpeed: Double = 5.0
    
    /// 最大有效速度 (米/秒) - 约 180 km/h
    static let maxValidSpeed: Double = 50.0
    
    /// 差精度阈值 (米) - 超过此值降低置信度
    static let poorAccuracyThreshold: Double = 50.0
    
    /// 静止状态速度阈值 (米/秒)
    static let stationarySpeedThreshold: Double = 0.5
    
    /// 静止状态检测所需的连续样本数
    static let stationarySampleCount: Int = 3
    
    /// 最小时间间隔 (秒) - 避免除零
    static let minTimeInterval: TimeInterval = 0.1
    
    // MARK: - State
    
    /// 最近的速度样本
    private var recentSamples: [SpeedSample] = []
    
    /// 最大样本数量
    private let maxSampleCount: Int = 10
    
    // MARK: - Public Methods
    
    /// 从两个位置计算速度
    /// - Parameters:
    ///   - previousLocation: 前一个位置
    ///   - currentLocation: 当前位置
    /// - Returns: 速度计算结果
    func calculateSpeed(
        from previousLocation: CLLocation,
        to currentLocation: CLLocation
    ) -> SpeedResult {
        // 1. 计算时间间隔
        let timeInterval = currentLocation.timestamp.timeIntervalSince(previousLocation.timestamp)
        guard timeInterval >= Self.minTimeInterval else {
            return .invalid
        }
        
        // 2. 计算距离
        let distance = currentLocation.distance(from: previousLocation)
        
        // 3. 检查最小距离
        guard distance >= Self.minDistanceForValidSpeed else {
            return SpeedResult(
                speed: 0,
                confidence: 0.5,
                isValid: false,
                source: .calculated
            )
        }
        
        // 4. 计算速度
        let calculatedSpeed = distance / timeInterval
        
        // 5. GPS 噪声过滤
        guard calculatedSpeed <= Self.maxValidSpeed else {
            return SpeedResult(
                speed: calculatedSpeed,
                confidence: 0,
                isValid: false,
                source: .calculated
            )
        }
        
        // 6. 计算置信度（基于精度）
        let avgAccuracy = (previousLocation.horizontalAccuracy + currentLocation.horizontalAccuracy) / 2
        let confidence = calculateConfidence(accuracy: avgAccuracy)
        
        // 7. 优先使用 CLLocation 的速度（如果有效）
        if currentLocation.speed >= 0 {
            let clSpeed = currentLocation.speed
            if clSpeed <= Self.maxValidSpeed {
                return SpeedResult(
                    speed: clSpeed,
                    confidence: confidence,
                    isValid: true,
                    source: .clLocation
                )
            }
        }
        
        return SpeedResult(
            speed: calculatedSpeed,
            confidence: confidence,
            isValid: true,
            source: .calculated
        )
    }
    
    /// 添加速度样本
    /// - Parameter sample: 速度样本
    func addSample(_ sample: SpeedSample) {
        recentSamples.append(sample)
        if recentSamples.count > maxSampleCount {
            recentSamples.removeFirst()
        }
    }
    
    /// 从速度结果创建并添加样本
    /// - Parameters:
    ///   - result: 速度结果
    ///   - accuracy: GPS 精度
    func addSample(from result: SpeedResult, accuracy: Double) {
        guard result.isValid else { return }
        let sample = SpeedSample(
            speed: result.speed,
            confidence: result.confidence,
            timestamp: Date(),
            accuracy: accuracy
        )
        addSample(sample)
    }
    
    /// 检测是否处于静止状态
    /// - Returns: 是否静止
    func isStationary() -> Bool {
        guard recentSamples.count >= Self.stationarySampleCount else {
            return false
        }
        
        let recentCount = min(Self.stationarySampleCount, recentSamples.count)
        let recentSpeeds = recentSamples.suffix(recentCount)
        
        return recentSpeeds.allSatisfy { $0.speed < Self.stationarySpeedThreshold }
    }
    
    /// 获取平均速度
    /// - Returns: 平均速度 (米/秒)，如果没有有效样本则返回 nil
    func getAverageSpeed() -> Double? {
        let validSamples = recentSamples.filter { $0.confidence > 0.3 }
        guard !validSamples.isEmpty else { return nil }
        
        // 加权平均（按置信度加权）
        let totalWeight = validSamples.reduce(0.0) { $0 + $1.confidence }
        let weightedSum = validSamples.reduce(0.0) { $0 + $1.speed * $1.confidence }
        
        return weightedSum / totalWeight
    }
    
    /// 根据平均速度检测交通方式
    /// - Returns: 检测到的交通方式
    func detectTransportMode() -> TransportMode? {
        guard let avgSpeed = getAverageSpeed() else { return nil }
        return TransportMode.detectMode(fromSpeed: avgSpeed)
    }
    
    /// 清除所有样本
    func clearSamples() {
        recentSamples.removeAll()
    }
    
    /// 获取最近的样本
    var samples: [SpeedSample] {
        return recentSamples
    }
    
    // MARK: - Private Methods
    
    /// 根据 GPS 精度计算置信度
    /// - Parameter accuracy: GPS 精度 (米)
    /// - Returns: 置信度 (0.0-1.0)
    private func calculateConfidence(accuracy: Double) -> Double {
        if accuracy < 0 {
            return 0.0  // 无效精度
        } else if accuracy <= 10 {
            return 1.0  // 优秀精度
        } else if accuracy <= Self.poorAccuracyThreshold {
            // 线性降低置信度
            return 1.0 - (accuracy - 10) / (Self.poorAccuracyThreshold - 10) * 0.5
        } else {
            // 差精度，大幅降低置信度
            return max(0.1, 0.5 - (accuracy - Self.poorAccuracyThreshold) / 100)
        }
    }
}

// MARK: - Static Helpers

extension SpeedCalculator {
    
    /// 静态方法：计算两点之间的速度
    /// - Parameters:
    ///   - from: 起点
    ///   - to: 终点
    /// - Returns: 速度结果
    static func calculateSpeed(from: CLLocation, to: CLLocation) -> SpeedResult {
        let calculator = SpeedCalculator()
        return calculator.calculateSpeed(from: from, to: to)
    }
    
    /// 静态方法：检查速度是否有效（未超过最大值）
    /// - Parameter speed: 速度 (米/秒)
    /// - Returns: 是否有效
    static func isValidSpeed(_ speed: Double) -> Bool {
        return speed >= 0 && speed <= maxValidSpeed
    }
    
    /// 静态方法：检查距离是否足够计算速度
    /// - Parameter distance: 距离 (米)
    /// - Returns: 是否足够
    static func isDistanceSufficient(_ distance: Double) -> Bool {
        return distance >= minDistanceForValidSpeed
    }
}
