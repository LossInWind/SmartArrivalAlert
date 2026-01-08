import Foundation

/// 信号质量评估器 - 提供信号质量评估相关的算法
enum SignalQualityEvaluator {
    
    // MARK: - Constants
    
    /// 好信号的精度阈值（米）
    static let goodAccuracyThreshold: Double = 20.0
    
    /// 一般信号的精度阈值（米）
    static let fairAccuracyThreshold: Double = 50.0
    
    // MARK: - Public Methods
    
    /// 从样本评估信号质量
    /// - Parameter samples: 信号样本数组
    /// - Returns: 评估后的信号质量
    static func evaluateSignalQuality(from samples: [SignalSample]) -> SignalQuality {
        guard !samples.isEmpty else {
            return SignalQuality(level: .unknown, averageAccuracy: 0, sampleCount: 0)
        }
        
        let avgAccuracy = samples.reduce(0.0) { $0 + $1.accuracy } / Double(samples.count)
        let level = determineQualityLevel(accuracy: avgAccuracy)
        
        return SignalQuality(
            level: level,
            averageAccuracy: avgAccuracy,
            sampleCount: samples.count
        )
    }
    
    /// 根据精度确定信号质量等级
    /// - Parameter accuracy: 精度（米）
    /// - Returns: 信号质量等级
    static func determineQualityLevel(accuracy: Double) -> SignalQualityLevel {
        if accuracy <= goodAccuracyThreshold {
            return .good
        } else if accuracy <= fairAccuracyThreshold {
            return .fair
        } else {
            return .poor
        }
    }
    
    /// 合并多个信号质量评估
    /// - Parameter qualities: 信号质量数组
    /// - Returns: 合并后的信号质量（取最差的）
    static func mergeSignalQualities(_ qualities: [SignalQuality]) -> SignalQuality {
        guard !qualities.isEmpty else {
            return .unknown
        }
        
        // 过滤掉 unknown 的质量
        let knownQualities = qualities.filter { $0.level != .unknown }
        
        guard !knownQualities.isEmpty else {
            return .unknown
        }
        
        // 计算加权平均精度
        let totalSamples = knownQualities.reduce(0) { $0 + $1.sampleCount }
        guard totalSamples > 0 else {
            return .unknown
        }
        
        let weightedAccuracy = knownQualities.reduce(0.0) { sum, quality in
            sum + quality.averageAccuracy * Double(quality.sampleCount)
        } / Double(totalSamples)
        
        let level = determineQualityLevel(accuracy: weightedAccuracy)
        
        return SignalQuality(
            level: level,
            averageAccuracy: weightedAccuracy,
            sampleCount: totalSamples
        )
    }
    
    /// 判断信号质量是否足够好（可以可靠触发提醒）
    /// - Parameter quality: 信号质量
    /// - Returns: 是否足够好
    static func isQualitySufficient(_ quality: SignalQuality) -> Bool {
        return quality.level == .good || quality.level == .fair
    }
    
    /// 判断是否需要提前触发（因为信号质量差）
    /// - Parameter quality: 目的地信号质量
    /// - Returns: 是否需要提前触发
    static func shouldTriggerEarly(destinationQuality: SignalQuality) -> Bool {
        return destinationQuality.level == .poor
    }
    
    /// 计算信号质量置信度
    /// - Parameter quality: 信号质量
    /// - Returns: 置信度 (0-1)，样本越多置信度越高
    static func calculateConfidence(_ quality: SignalQuality) -> Double {
        // 基于样本数量计算置信度
        // 10个样本以上视为高置信度
        let sampleFactor = min(Double(quality.sampleCount) / 10.0, 1.0)
        return sampleFactor
    }
    
    /// 获取信号质量的描述文本
    /// - Parameter quality: 信号质量
    /// - Returns: 描述文本
    static func getQualityDescription(_ quality: SignalQuality) -> String {
        switch quality.level {
        case .good:
            return "信号良好"
        case .fair:
            return "信号一般"
        case .poor:
            return "信号较差"
        case .unknown:
            return "信号未知"
        }
    }
    
    /// 获取信号质量的详细描述
    /// - Parameter quality: 信号质量
    /// - Returns: 详细描述
    static func getDetailedDescription(_ quality: SignalQuality) -> String {
        let levelDesc = getQualityDescription(quality)
        let accuracyDesc = String(format: "平均精度: %.1f米", quality.averageAccuracy)
        let sampleDesc = "样本数: \(quality.sampleCount)"
        
        return "\(levelDesc) (\(accuracyDesc), \(sampleDesc))"
    }
}
