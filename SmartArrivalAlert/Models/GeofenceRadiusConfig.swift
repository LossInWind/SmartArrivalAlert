import Foundation

/// 围栏半径配置
/// 定义围栏半径的范围、步进和格式化规则
struct GeofenceRadiusConfig {
    /// 最小半径 (米)
    static let minRadius: Double = 100
    
    /// 主界面默认最大半径 (米) - 10km
    static let defaultMaxRadius: Double = 10000
    
    /// 设置页面可配置的绝对最大半径 (米) - 50km
    static let absoluteMaxRadius: Double = 50000
    
    /// 小步进增量 (米) - 用于 < 1km
    static let smallStepIncrement: Double = 50
    
    /// 大步进增量 (米) - 用于 >= 1km
    static let largeStepIncrement: Double = 500
    
    /// 步进切换阈值 (米)
    static let stepThreshold: Double = 1000
    
    /// 将半径值对齐到最近的步进值
    /// - Parameter value: 原始半径值 (米)
    /// - Returns: 对齐后的半径值 (米)
    static func snapToStep(_ value: Double) -> Double {
        // 确保在有效范围内
        let clampedValue = max(minRadius, min(value, absoluteMaxRadius))
        
        if clampedValue < stepThreshold {
            // < 1km: 使用 50m 步进
            let steps = round(clampedValue / smallStepIncrement)
            let snapped = steps * smallStepIncrement
            return max(minRadius, snapped)
        } else {
            // >= 1km: 使用 500m 步进
            let steps = round(clampedValue / largeStepIncrement)
            let snapped = steps * largeStepIncrement
            return max(stepThreshold, snapped)
        }
    }
    
    /// 格式化半径显示
    /// - Parameter meters: 半径值 (米)
    /// - Returns: 格式化后的字符串
    static func formatRadius(_ meters: Double) -> String {
        if meters >= 1000 {
            let km = meters / 1000.0
            // 如果是整数公里，不显示小数点
            if km.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(km)) km"
            } else {
                return String(format: "%.1f km", km)
            }
        } else {
            return "\(Int(meters)) m"
        }
    }
    
    /// 验证半径值是否有效
    /// - Parameter meters: 半径值 (米)
    /// - Returns: 是否有效
    static func isValidRadius(_ meters: Double) -> Bool {
        return meters >= minRadius && meters <= absoluteMaxRadius
    }
    
    /// 获取主界面滑杆的有效范围
    /// - Parameter maxRadius: 用户设置的最大半径限制
    /// - Returns: (最小值, 最大值)
    static func getSliderRange(maxRadius: Double = defaultMaxRadius) -> (min: Double, max: Double) {
        let effectiveMax = min(maxRadius, absoluteMaxRadius)
        return (minRadius, effectiveMax)
    }
    
    /// 计算给定范围内的步进数量
    /// - Parameters:
    ///   - from: 起始值
    ///   - to: 结束值
    /// - Returns: 步进数量
    static func stepCount(from: Double, to: Double) -> Int {
        var count = 0
        var current = snapToStep(from)
        let target = snapToStep(to)
        
        while current < target {
            if current < stepThreshold {
                current += smallStepIncrement
            } else {
                current += largeStepIncrement
            }
            count += 1
        }
        
        return count
    }
    
    /// 获取下一个步进值
    /// - Parameter current: 当前值
    /// - Returns: 下一个步进值
    static func nextStep(_ current: Double) -> Double {
        let snapped = snapToStep(current)
        if snapped < stepThreshold {
            return min(snapped + smallStepIncrement, absoluteMaxRadius)
        } else {
            return min(snapped + largeStepIncrement, absoluteMaxRadius)
        }
    }
    
    /// 获取上一个步进值
    /// - Parameter current: 当前值
    /// - Returns: 上一个步进值
    static func previousStep(_ current: Double) -> Double {
        let snapped = snapToStep(current)
        if snapped <= stepThreshold {
            return max(snapped - smallStepIncrement, minRadius)
        } else {
            return max(snapped - largeStepIncrement, stepThreshold)
        }
    }
}
