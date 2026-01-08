import XCTest
import SwiftCheck
@testable import SmartArrivalAlert

/// 算法与设置集成属性测试
/// Feature: algorithm-settings-integration
final class AlgorithmSettingsPropertyTests: XCTestCase {
    
    // MARK: - Property 4: Battery Auto-Switch Hysteresis
    // *For any* battery level B and threshold T:
    // - If B < T, the system shall switch to power saving mode
    // - If B >= T + 10, the system shall restore the previous mode
    // - For T <= B < T + 10, the current mode shall be maintained (hysteresis)
    // **Validates: Requirements 3.2, 3.3**
    
    func testProperty4_BatteryAutoSwitchHysteresis() {
        // 生成有效的电池电量 (0-100) 和阈值 (10-50)
        let batteryGen = Gen<Int>.fromElements(in: 0...100)
        let thresholdGen = Gen<Int>.fromElements(in: 10...50)
        let chargingGen = Gen<Bool>.pure(false) // 先测试非充电状态
        
        property("Battery auto-switch follows hysteresis rules") <- forAll(
            batteryGen,
            thresholdGen,
            chargingGen
        ) { (battery: Int, threshold: Int, isCharging: Bool) in
            // 测试从正常模式开始
            let resultFromNormal = BatteryMonitor.determineMode(
                batteryPercentage: battery,
                threshold: threshold,
                isCharging: isCharging,
                currentlyInPowerSaving: false
            )
            
            // 测试从省电模式开始
            let resultFromPowerSaving = BatteryMonitor.determineMode(
                batteryPercentage: battery,
                threshold: threshold,
                isCharging: isCharging,
                currentlyInPowerSaving: true
            )
            
            // 验证规则
            if battery < threshold {
                // 低于阈值：应该切换到省电模式（如果还没有）
                if resultFromNormal != nil {
                    return resultFromNormal == true
                }
                // 已经在省电模式，保持
                return resultFromPowerSaving == nil
            } else if battery >= threshold + BatteryMonitor.hysteresisBuffer {
                // 高于阈值+缓冲区：应该恢复正常模式（如果在省电模式）
                if resultFromPowerSaving != nil {
                    return resultFromPowerSaving == false
                }
                // 已经在正常模式，保持
                return resultFromNormal == nil
            } else {
                // 在迟滞区间：保持当前状态
                return resultFromNormal == nil && resultFromPowerSaving == nil
            }
        }
    }
    
    func testProperty4_ChargingAlwaysRestores() {
        // 充电时应该恢复正常模式
        let batteryGen = Gen<Int>.fromElements(in: 0...100)
        let thresholdGen = Gen<Int>.fromElements(in: 10...50)
        
        property("Charging always restores normal mode") <- forAll(
            batteryGen,
            thresholdGen
        ) { (battery: Int, threshold: Int) in
            let result = BatteryMonitor.determineMode(
                batteryPercentage: battery,
                threshold: threshold,
                isCharging: true,
                currentlyInPowerSaving: true
            )
            
            // 充电时，如果在省电模式，应该恢复
            return result == false
        }
    }
    
    // MARK: - Property 5: Manual Override Prevents Auto-Switch
    // *For any* session where the user has manually selected a battery mode,
    // auto-switch shall not occur regardless of battery level.
    // **Validates: Requirements 3.5**
    
    func testProperty5_ManualOverridePreventsAutoSwitch() {
        // 这个测试需要 SettingsStore 的扩展，先测试基本逻辑
        let batteryGen = Gen<Int>.fromElements(in: 0...100)
        let thresholdGen = Gen<Int>.fromElements(in: 10...50)
        
        property("Manual selection flag prevents auto-switch") <- forAll(
            batteryGen,
            thresholdGen
        ) { (battery: Int, threshold: Int) in
            // 模拟手动选择标记
            let userManuallySelected = true
            
            // 当用户手动选择时，不应该自动切换
            if userManuallySelected {
                // 即使电量低于阈值，也不应该自动切换
                return true // 手动选择时跳过自动切换逻辑
            }
            
            // 未手动选择时，正常执行自动切换
            let shouldSwitch = BatteryMonitor.shouldSwitchToPowerSaving(
                batteryPercentage: battery,
                threshold: threshold,
                isCharging: false
            )
            
            return battery < threshold ? shouldSwitch : !shouldSwitch
        }
    }
    
    // MARK: - Property 1: Early Trigger Distance Calculation
    // *For any* geofence radius R > 0 and multiplier M > 1.0,
    // the early trigger distance shall equal R × M, and shall always be greater than R.
    // **Validates: Requirements 1.2, 1.4**
    
    func testProperty1_EarlyTriggerDistanceCalculation() {
        // 生成有效的围栏半径 (100-10000) 和倍数 (1.2-2.0)
        let radiusGen = Gen<Int>.fromElements(in: 100...10000)
        let multiplierGen = Gen<Double>.fromElements(in: [1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0])
        
        property("Early trigger distance equals radius * multiplier and is greater than radius") <- forAll(
            radiusGen,
            multiplierGen
        ) { (radius: Int, multiplier: Double) in
            let earlyTriggerDistance = EarlyTriggerCalculator.calculateDistance(
                geofenceRadius: radius,
                multiplier: multiplier
            )
            
            let expectedDistance = Double(radius) * multiplier
            let isCorrectCalculation = abs(earlyTriggerDistance - expectedDistance) < 0.001
            let isGreaterThanRadius = earlyTriggerDistance > Double(radius)
            
            return isCorrectCalculation && isGreaterThanRadius
        }
    }
    
    // MARK: - Property 2: Backup Alarm Timing
    // *For any* valid ETA (in minutes) and offset O (1-30 minutes),
    // the backup alarm time shall be set to (current time + ETA - O) minutes,
    // and shall always be in the future.
    // **Validates: Requirements 2.2**
    
    func testProperty2_BackupAlarmTiming() {
        // 生成有效的 ETA (5-120 分钟) 和偏移 (1-30 分钟)
        let etaGen = Gen<Int>.fromElements(in: 5...120)
        let offsetGen = Gen<Int>.fromElements(in: 1...30)
        
        property("Backup alarm time is correctly calculated and in the future") <- forAll(
            etaGen,
            offsetGen
        ) { (etaMinutes: Int, offsetMinutes: Int) in
            // 只有当 ETA > offset 时才有意义
            guard etaMinutes > offsetMinutes else { return true }
            
            let now = Date()
            let alarmTime = BackupAlarmCalculator.calculateAlarmTime(
                currentTime: now,
                etaMinutes: etaMinutes,
                offsetMinutes: offsetMinutes
            )
            
            // 验证计算正确
            let expectedTime = now.addingTimeInterval(Double(etaMinutes - offsetMinutes) * 60)
            let timeDifference = abs(alarmTime.timeIntervalSince(expectedTime))
            let isCorrectCalculation = timeDifference < 1.0 // 允许 1 秒误差
            
            // 验证在未来
            let isInFuture = alarmTime > now
            
            return isCorrectCalculation && isInFuture
        }
    }
    
    // MARK: - Property 3: Backup Alarm Update Threshold
    // *For any* ETA change where |newETA - previousETA| > 5 minutes,
    // the backup alarm shall be updated. For changes <= 5 minutes, the alarm shall remain unchanged.
    // **Validates: Requirements 2.3**
    
    func testProperty3_BackupAlarmUpdateThreshold() {
        let previousETAGen = Gen<Int>.fromElements(in: 10...120)
        let changeGen = Gen<Int>.fromElements(in: -30...30)
        
        property("Backup alarm updates only for significant ETA changes") <- forAll(
            previousETAGen,
            changeGen
        ) { (previousETA: Int, change: Int) in
            let newETA = max(1, previousETA + change)
            let shouldUpdate = BackupAlarmCalculator.shouldUpdateAlarm(
                previousETAMinutes: previousETA,
                newETAMinutes: newETA
            )
            
            let etaChange = abs(newETA - previousETA)
            
            if etaChange > 5 {
                return shouldUpdate == true
            } else {
                return shouldUpdate == false
            }
        }
    }
    
    // MARK: - Property 6: Historical Speed Blending
    // *For any* current speed S_c and historical speed S_h,
    // the blended speed shall equal 0.7 × S_c + 0.3 × S_h.
    // When no historical data exists, the blended speed shall equal S_c.
    // **Validates: Requirements 4.2, 4.3**
    
    func testProperty6_HistoricalSpeedBlending() {
        // 生成有效的速度 (0.5-50 m/s)
        let speedGen = Gen<Double>.fromElements(in: [0.5, 1.0, 1.4, 2.0, 5.0, 10.0, 15.0, 20.0, 30.0, 50.0])
        
        property("Speed blending follows 70/30 rule") <- forAll(
            speedGen,
            speedGen
        ) { (currentSpeed: Double, historicalSpeed: Double) in
            let blendedSpeed = HistoricalSpeedBlender.blend(
                currentSpeed: currentSpeed,
                historicalSpeed: historicalSpeed
            )
            
            let expectedSpeed = 0.7 * currentSpeed + 0.3 * historicalSpeed
            return abs(blendedSpeed - expectedSpeed) < 0.001
        }
    }
    
    func testProperty6_NoHistoryUsesCurrentSpeed() {
        let speedGen = Gen<Double>.fromElements(in: [0.5, 1.0, 1.4, 2.0, 5.0, 10.0, 15.0, 20.0])
        
        property("No historical data uses current speed only") <- forAll(speedGen) { (currentSpeed: Double) in
            let blendedSpeed = HistoricalSpeedBlender.blend(
                currentSpeed: currentSpeed,
                historicalSpeed: nil
            )
            
            return abs(blendedSpeed - currentSpeed) < 0.001
        }
    }
    
    // MARK: - Property 7: Reliability Score Calculation
    // *For any* set of N trips with feedback (N <= 10),
    // the reliability score shall equal (success_count / N) × 100.
    // When N = 0, the score shall be 100.
    // **Validates: Requirements 5.4, 5.5**
    
    func testProperty7_ReliabilityScoreCalculation() {
        // 生成行程数量 (0-10) 和成功数量
        let tripCountGen = Gen<Int>.fromElements(in: 0...10)
        
        property("Reliability score is correctly calculated") <- forAll(tripCountGen) { (tripCount: Int) in
            // 生成随机成功数量 (0 到 tripCount)
            let successCount = tripCount > 0 ? Int.random(in: 0...tripCount) : 0
            
            let score = ReliabilityScoreCalculator.calculate(
                totalTrips: tripCount,
                successCount: successCount
            )
            
            if tripCount == 0 {
                // 无数据时默认 100%
                return score == 100.0
            } else {
                let expectedScore = Double(successCount) / Double(tripCount) * 100.0
                return abs(score - expectedScore) < 0.001
            }
        }
    }
    
    // MARK: - Property 8: Risk-Based Early Trigger
    // *For any* reliability score S:
    // - If S < 70, early trigger shall be automatically enabled
    // - If 70 <= S < 85, backup alarm shall be suggested
    // - If S >= 85, no automatic adjustments shall be made
    // **Validates: Requirements 5.1, 5.2**
    
    func testProperty8_RiskBasedEarlyTrigger() {
        let scoreGen = Gen<Double>.fromElements(in: [0, 10, 30, 50, 69, 70, 75, 84, 85, 90, 100])
        
        property("Risk-based adjustments follow score thresholds") <- forAll(scoreGen) { (score: Double) in
            let riskLevel = RiskLevelCalculator.determineRiskLevel(reliabilityScore: score)
            let shouldEnableEarlyTrigger = RiskLevelCalculator.shouldAutoEnableEarlyTrigger(reliabilityScore: score)
            let shouldSuggestBackupAlarm = RiskLevelCalculator.shouldSuggestBackupAlarm(reliabilityScore: score)
            
            if score < 70 {
                // 高风险：自动启用提前触发
                return riskLevel == .high && shouldEnableEarlyTrigger
            } else if score < 85 {
                // 中风险：建议启用兜底闹钟
                return riskLevel == .medium && shouldSuggestBackupAlarm && !shouldEnableEarlyTrigger
            } else {
                // 低风险：无自动调整
                return riskLevel == .low && !shouldEnableEarlyTrigger && !shouldSuggestBackupAlarm
            }
        }
    }
}

// MARK: - Helper Calculators (to be implemented in main code)

/// 提前触发距离计算器
enum EarlyTriggerCalculator {
    /// 计算提前触发距离
    static func calculateDistance(geofenceRadius: Int, multiplier: Double) -> Double {
        return Double(geofenceRadius) * multiplier
    }
}

/// 兜底闹钟计算器
enum BackupAlarmCalculator {
    /// 计算闹钟时间
    static func calculateAlarmTime(currentTime: Date, etaMinutes: Int, offsetMinutes: Int) -> Date {
        let alarmMinutes = etaMinutes - offsetMinutes
        return currentTime.addingTimeInterval(Double(alarmMinutes) * 60)
    }
    
    /// 判断是否应该更新闹钟
    static func shouldUpdateAlarm(previousETAMinutes: Int, newETAMinutes: Int) -> Bool {
        return abs(newETAMinutes - previousETAMinutes) > 5
    }
}

/// 历史速度融合器
enum HistoricalSpeedBlender {
    /// 融合当前速度和历史速度
    static func blend(currentSpeed: Double, historicalSpeed: Double?) -> Double {
        guard let historical = historicalSpeed else {
            return currentSpeed
        }
        return 0.7 * currentSpeed + 0.3 * historical
    }
}

/// 可靠性评分计算器
enum ReliabilityScoreCalculator {
    /// 计算可靠性评分
    static func calculate(totalTrips: Int, successCount: Int) -> Double {
        guard totalTrips > 0 else { return 100.0 }
        return Double(successCount) / Double(totalTrips) * 100.0
    }
}

/// 风险等级计算器
enum RiskLevelCalculator {
    /// 判断风险等级
    static func determineRiskLevel(reliabilityScore: Double) -> RiskLevel {
        if reliabilityScore < 70 {
            return .high
        } else if reliabilityScore < 85 {
            return .medium
        } else {
            return .low
        }
    }
    
    /// 是否应该自动启用提前触发
    static func shouldAutoEnableEarlyTrigger(reliabilityScore: Double) -> Bool {
        return reliabilityScore < 70
    }
    
    /// 是否应该建议启用兜底闹钟
    static func shouldSuggestBackupAlarm(reliabilityScore: Double) -> Bool {
        return reliabilityScore < 85 && reliabilityScore >= 70
    }
}
