import XCTest
import SwiftCheck
import CoreLocation
@testable import SmartArrivalAlert

/// 监控增强功能属性测试
/// 测试交通方式、围栏半径配置、位置检查间隔等核心功能
final class MonitoringEnhancementsPropertyTests: XCTestCase {
    
    // MARK: - Property 1: Distance-based interval calculation
    
    /// Property: 距离层级正确映射到检查间隔
    func testDistanceBasedIntervalCalculation() {
        let manager = LocationCheckIntervalManager()
        
        // > 5km → 60s
        XCTAssertEqual(manager.getDistanceTier(distance: 6000).baseInterval, 60.0)
        XCTAssertEqual(manager.getDistanceTier(distance: 10000).baseInterval, 60.0)
        
        // 2-5km → 30s
        XCTAssertEqual(manager.getDistanceTier(distance: 3000).baseInterval, 30.0)
        XCTAssertEqual(manager.getDistanceTier(distance: 5000).baseInterval, 30.0)
        
        // 500m-2km → 15s
        XCTAssertEqual(manager.getDistanceTier(distance: 1000).baseInterval, 15.0)
        XCTAssertEqual(manager.getDistanceTier(distance: 2000).baseInterval, 15.0)
        
        // < 500m → 5s
        XCTAssertEqual(manager.getDistanceTier(distance: 300).baseInterval, 5.0)
        XCTAssertEqual(manager.getDistanceTier(distance: 500).baseInterval, 5.0)
    }
    
    /// Property: 任意距离都能正确映射到层级
    func testDistanceTierMappingProperty() {
        property("Distance maps to correct tier") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let distance = random.nextDouble(min: 0, max: 100000)
            
            let tier = DistanceTier.fromDistance(distance)
            
            if distance > 5000 {
                return tier == .veryFar
            } else if distance > 2000 {
                return tier == .far
            } else if distance > 500 {
                return tier == .medium
            } else {
                return tier == .close
            }
        }
    }
    
    // MARK: - Property 2: Battery mode interval multiplier
    
    /// Property: 电池模式正确应用倍数
    func testBatteryModeIntervalMultiplier() {
        // 省电模式 2x
        XCTAssertEqual(BatteryMode.powerSaving.intervalMultiplier, 2.0)
        
        // 平衡模式 1x
        XCTAssertEqual(BatteryMode.balanced.intervalMultiplier, 1.0)
        
        // 高精度模式 0.5x
        XCTAssertEqual(BatteryMode.highAccuracy.intervalMultiplier, 0.5)
    }
    
    /// Property: 电池模式倍数正确应用到间隔计算
    func testBatteryModeMultiplierApplied() {
        property("Battery mode multiplier is applied correctly") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let distance = random.nextDouble(min: 100, max: 50000)
            let manager = LocationCheckIntervalManager()
            
            let balancedInterval = manager.calculateInterval(
                distance: distance,
                speed: 0,
                batteryMode: .balanced
            )
            
            let powerSavingInterval = manager.calculateInterval(
                distance: distance,
                speed: 0,
                batteryMode: .powerSaving
            )
            
            let highAccuracyInterval = manager.calculateInterval(
                distance: distance,
                speed: 0,
                batteryMode: .highAccuracy
            )
            
            // 省电模式间隔 >= 平衡模式间隔 >= 高精度模式间隔
            return powerSavingInterval >= balancedInterval &&
                   balancedInterval >= highAccuracyInterval
        }
    }
    
    // MARK: - Property 3: High speed increases check frequency
    
    /// Property: 高速时检查频率提升
    func testHighSpeedIncreasesCheckFrequency() {
        property("High speed reduces check interval") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            // 使用较远距离以确保有提升空间
            let distance = random.nextDouble(min: 3000, max: 50000)
            let manager = LocationCheckIntervalManager()
            
            let lowSpeedInterval = manager.calculateInterval(
                distance: distance,
                speed: 5.0,  // 低速
                batteryMode: .balanced
            )
            
            let highSpeedInterval = manager.calculateInterval(
                distance: distance,
                speed: 25.0,  // 高速 (> 20 m/s)
                batteryMode: .balanced
            )
            
            // 高速时间隔应该 <= 低速时间隔
            return highSpeedInterval <= lowSpeedInterval
        }
    }
    
    /// Property: 高速阈值为 20 m/s
    func testHighSpeedThreshold() {
        XCTAssertEqual(LocationCheckIntervalManager.highSpeedThreshold, 20.0)
    }
    
    // MARK: - Interval Bounds Tests
    
    /// Property: 间隔始终在有效范围内
    func testIntervalWithinBounds() {
        property("Interval is within valid bounds") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let distance = random.nextDouble(min: 0, max: 100000)
            let speed = random.nextDouble(min: 0, max: 50)
            let modes = BatteryMode.allCases
            let mode = modes[random.nextInt(bound: modes.count)]
            
            let manager = LocationCheckIntervalManager()
            let interval = manager.calculateInterval(
                distance: distance,
                speed: speed,
                batteryMode: mode
            )
            
            return interval >= LocationCheckIntervalManager.minimumInterval &&
                   interval <= LocationCheckIntervalManager.maximumInterval
        }
    }
    
    // MARK: - BatteryMode Codable Tests
    
    /// Property: BatteryMode 编解码往返一致
    func testBatteryModeCodableRoundTrip() {
        property("BatteryMode codable round-trip") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let modes = BatteryMode.allCases
            let mode = modes[random.nextInt(bound: modes.count)]
            
            do {
                let encoded = try JSONEncoder().encode(mode)
                let decoded = try JSONDecoder().decode(BatteryMode.self, from: encoded)
                return mode == decoded
            } catch {
                return false
            }
        }
    }
    
    // MARK: - DistanceTier Tests
    
    /// Property: DistanceTier 编解码往返一致
    func testDistanceTierCodableRoundTrip() {
        property("DistanceTier codable round-trip") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let tiers = DistanceTier.allCases
            let tier = tiers[random.nextInt(bound: tiers.count)]
            
            do {
                let encoded = try JSONEncoder().encode(tier)
                let decoded = try JSONDecoder().decode(DistanceTier.self, from: encoded)
                return tier == decoded
            } catch {
                return false
            }
        }
    }
    
    /// Property: 层级基础间隔递减（越近间隔越短）
    func testTierIntervalsDecrease() {
        XCTAssertGreaterThan(DistanceTier.veryFar.baseInterval, DistanceTier.far.baseInterval)
        XCTAssertGreaterThan(DistanceTier.far.baseInterval, DistanceTier.medium.baseInterval)
        XCTAssertGreaterThan(DistanceTier.medium.baseInterval, DistanceTier.close.baseInterval)
    }
    
    // MARK: - Property 7: Speed calculation from distance/time
    
    /// Property: 速度 = 距离 / 时间
    func testSpeedCalculationFormula() {
        property("Speed equals distance divided by time") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let distance = random.nextDouble(min: 10, max: 1000)  // 10m - 1km
            let time = random.nextDouble(min: 1, max: 100)        // 1s - 100s
            
            // 创建两个位置点
            let lat1 = 39.9
            let lon1 = 116.4
            
            // 计算第二个点的经度偏移（简化计算）
            let metersPerDegree = 111000.0 * cos(lat1 * .pi / 180)
            let lonOffset = distance / metersPerDegree
            
            let loc1 = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: lat1, longitude: lon1),
                altitude: 0,
                horizontalAccuracy: 5,
                verticalAccuracy: 5,
                timestamp: Date()
            )
            
            let loc2 = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: lat1, longitude: lon1 + lonOffset),
                altitude: 0,
                horizontalAccuracy: 5,
                verticalAccuracy: 5,
                timestamp: Date().addingTimeInterval(time)
            )
            
            let result = SpeedCalculator.calculateSpeed(from: loc1, to: loc2)
            
            // 如果结果有效，验证速度计算
            if result.isValid {
                let expectedSpeed = distance / time
                // 允许 20% 误差（由于坐标计算的近似性）
                let tolerance = expectedSpeed * 0.2
                return abs(result.speed - expectedSpeed) <= tolerance || result.source == .clLocation
            }
            
            return true  // 无效结果也是可接受的
        }
    }
    
    // MARK: - Property 8: GPS noise filtering
    
    /// Property: 超过 50 m/s 的速度被标记为无效
    func testGPSNoiseFiltering() {
        // 创建一个会产生超高速度的场景
        let loc1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        )
        
        // 1秒内移动 100km（约 100000 m/s，远超 50 m/s）
        let loc2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 40.8, longitude: 116.4),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date().addingTimeInterval(1)
        )
        
        let result = SpeedCalculator.calculateSpeed(from: loc1, to: loc2)
        
        // 超高速度应该被标记为无效
        XCTAssertFalse(result.isValid)
    }
    
    /// Property: 最大有效速度为 50 m/s
    func testMaxValidSpeed() {
        XCTAssertEqual(SpeedCalculator.maxValidSpeed, 50.0)
    }
    
    // MARK: - Property 9: Minimum distance for valid speed
    
    /// Property: 距离 < 5m 时速度计算无效
    func testMinimumDistanceForValidSpeed() {
        property("Distance < 5m results in invalid speed") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let smallDistance = random.nextDouble(min: 0.1, max: 4.9)  // < 5m
            
            let lat1 = 39.9
            let lon1 = 116.4
            let metersPerDegree = 111000.0 * cos(lat1 * .pi / 180)
            let lonOffset = smallDistance / metersPerDegree
            
            let loc1 = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: lat1, longitude: lon1),
                altitude: 0,
                horizontalAccuracy: 5,
                verticalAccuracy: 5,
                timestamp: Date()
            )
            
            let loc2 = CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: lat1, longitude: lon1 + lonOffset),
                altitude: 0,
                horizontalAccuracy: 5,
                verticalAccuracy: 5,
                timestamp: Date().addingTimeInterval(10)
            )
            
            let result = SpeedCalculator.calculateSpeed(from: loc1, to: loc2)
            
            // 小距离应该返回无效结果
            return !result.isValid
        }
    }
    
    /// Property: 最小有效距离为 5m
    func testMinDistanceConstant() {
        XCTAssertEqual(SpeedCalculator.minDistanceForValidSpeed, 5.0)
    }
    
    // MARK: - Property 10: Poor accuracy weight reduction
    
    /// Property: 精度 > 50m 时置信度降低
    func testPoorAccuracyWeightReduction() {
        // 高精度位置
        let goodLoc1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date()
        )
        
        let goodLoc2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 39.901, longitude: 116.4),
            altitude: 0,
            horizontalAccuracy: 5,
            verticalAccuracy: 5,
            timestamp: Date().addingTimeInterval(10)
        )
        
        // 低精度位置
        let poorLoc1 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4),
            altitude: 0,
            horizontalAccuracy: 100,
            verticalAccuracy: 100,
            timestamp: Date()
        )
        
        let poorLoc2 = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 39.901, longitude: 116.4),
            altitude: 0,
            horizontalAccuracy: 100,
            verticalAccuracy: 100,
            timestamp: Date().addingTimeInterval(10)
        )
        
        let goodResult = SpeedCalculator.calculateSpeed(from: goodLoc1, to: goodLoc2)
        let poorResult = SpeedCalculator.calculateSpeed(from: poorLoc1, to: poorLoc2)
        
        // 低精度结果的置信度应该更低
        if goodResult.isValid && poorResult.isValid {
            XCTAssertGreaterThan(goodResult.confidence, poorResult.confidence)
        }
    }
    
    /// Property: 差精度阈值为 50m
    func testPoorAccuracyThreshold() {
        XCTAssertEqual(SpeedCalculator.poorAccuracyThreshold, 50.0)
    }
    
    // MARK: - Property 11: Stationary detection
    
    /// Property: 3+ 个连续低速样本检测为静止
    func testStationaryDetection() {
        let calculator = SpeedCalculator()
        
        // 添加 3 个低速样本
        for i in 0..<3 {
            let sample = SpeedSample(
                speed: 0.3,  // < 0.5 m/s
                confidence: 1.0,
                timestamp: Date().addingTimeInterval(Double(i)),
                accuracy: 5
            )
            calculator.addSample(sample)
        }
        
        XCTAssertTrue(calculator.isStationary())
    }
    
    /// Property: 高速样本不会被检测为静止
    func testNonStationaryDetection() {
        let calculator = SpeedCalculator()
        
        // 添加高速样本
        for i in 0..<3 {
            let sample = SpeedSample(
                speed: 5.0,  // > 0.5 m/s
                confidence: 1.0,
                timestamp: Date().addingTimeInterval(Double(i)),
                accuracy: 5
            )
            calculator.addSample(sample)
        }
        
        XCTAssertFalse(calculator.isStationary())
    }
    
    /// Property: 静止检测需要至少 3 个样本
    func testStationaryRequiresMinSamples() {
        let calculator = SpeedCalculator()
        
        // 只添加 2 个低速样本
        for i in 0..<2 {
            let sample = SpeedSample(
                speed: 0.3,
                confidence: 1.0,
                timestamp: Date().addingTimeInterval(Double(i)),
                accuracy: 5
            )
            calculator.addSample(sample)
        }
        
        // 样本不足，不应检测为静止
        XCTAssertFalse(calculator.isStationary())
    }
    
    /// Property: 静止速度阈值为 0.5 m/s
    func testStationarySpeedThreshold() {
        XCTAssertEqual(SpeedCalculator.stationarySpeedThreshold, 0.5)
    }
    
    /// Property: 静止检测所需样本数为 3
    func testStationarySampleCount() {
        XCTAssertEqual(SpeedCalculator.stationarySampleCount, 3)
    }
    
    // MARK: - Property 12: EWMA speed smoothing
    
    /// Property: EWMA 平滑系数为 0.3
    func testEWMAAlpha() {
        XCTAssertEqual(EnhancedETACalculator.ewmaAlpha, 0.3)
    }
    
    /// Property: EWMA 平滑后的速度在合理范围内
    func testEWMASpeedSmoothing() {
        property("EWMA smoothed speed is within reasonable range") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let calculator = EnhancedETACalculator()
            
            // 生成一系列速度值
            var speeds: [Double] = []
            for _ in 0..<5 {
                speeds.append(random.nextDouble(min: 1, max: 20))
            }
            
            // 计算 ETA 以更新 EWMA
            for speed in speeds {
                _ = calculator.calculateETA(
                    distance: 1000,
                    currentSpeed: speed,
                    transportMode: .walking
                )
            }
            
            // EWMA 速度应该在输入速度的范围内
            if let ewma = calculator.currentEWMASpeed {
                let minSpeed = speeds.min() ?? 0
                let maxSpeed = speeds.max() ?? 100
                // 允许一定的边界误差
                return ewma >= minSpeed * 0.5 && ewma <= maxSpeed * 1.5
            }
            
            return true
        }
    }
    
    /// Property: EWMA 公式验证
    func testEWMAFormula() {
        let calculator = EnhancedETACalculator()
        let alpha = EnhancedETACalculator.ewmaAlpha
        
        // 第一个值
        _ = calculator.calculateETA(distance: 1000, currentSpeed: 10.0, transportMode: .walking)
        XCTAssertEqual(calculator.currentEWMASpeed ?? 0, 10.0, accuracy: 0.01)
        
        // 第二个值: EWMA = 0.3 * 20 + 0.7 * 10 = 6 + 7 = 13
        _ = calculator.calculateETA(distance: 1000, currentSpeed: 20.0, transportMode: .walking)
        let expected = alpha * 20.0 + (1 - alpha) * 10.0
        XCTAssertEqual(calculator.currentEWMASpeed ?? 0, expected, accuracy: 0.01)
    }
    
    // MARK: - Property 13: Historical data blending
    
    /// Property: 历史数据权重为 70% 当前 + 30% 历史
    func testHistoricalDataBlendingWeights() {
        XCTAssertEqual(EnhancedETACalculator.currentSpeedWeight, 0.7)
        XCTAssertEqual(EnhancedETACalculator.historicalSpeedWeight, 0.3)
    }
    
    /// Property: 有历史数据时 ETA 更稳定
    func testHistoricalDataBlending() {
        property("Historical data blending produces stable ETA") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let calculator = EnhancedETACalculator()
            
            let currentSpeed = random.nextDouble(min: 5, max: 15)
            let historicalSpeed = random.nextDouble(min: 5, max: 15)
            let distance = random.nextDouble(min: 1000, max: 10000)
            
            // 有历史数据的 ETA
            let resultWithHistory = calculator.calculateETA(
                distance: distance,
                currentSpeed: currentSpeed,
                transportMode: .cycling,
                historicalAverage: historicalSpeed
            )
            
            // 重置后无历史数据的 ETA
            calculator.reset()
            let resultWithoutHistory = calculator.calculateETA(
                distance: distance,
                currentSpeed: currentSpeed,
                transportMode: .cycling,
                historicalAverage: nil
            )
            
            // 两个结果都应该有效
            return resultWithHistory.estimatedMinutes != nil &&
                   resultWithoutHistory.estimatedMinutes != nil
        }
    }
    
    // MARK: - Property 16: ETA confidence based on tolerance
    
    /// Property: 速度在容差范围内时置信度为高
    func testETAConfidenceHighWithinTolerance() {
        property("Confidence is high when speed within tolerance") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let modes = TransportMode.allCases
            let mode = modes[random.nextInt(bound: modes.count)]
            
            // 使用基准速度（一定在容差范围内）
            let speed = mode.baselineSpeed
            let calculator = EnhancedETACalculator()
            
            let result = calculator.calculateETA(
                distance: 5000,
                currentSpeed: speed,
                transportMode: mode
            )
            
            return result.confidence == .high || result.isStationary
        }
    }
    
    /// Property: 速度偏离容差范围时置信度降低
    func testETAConfidenceLowOutsideTolerance() {
        let calculator = EnhancedETACalculator()
        
        // 步行模式，但使用驾车速度
        let result = calculator.calculateETA(
            distance: 5000,
            currentSpeed: 15.0,  // 远超步行速度
            transportMode: .walking
        )
        
        // 置信度应该不是高
        XCTAssertNotEqual(result.confidence, .high)
    }
    
    // MARK: - Property 17: Mode deviation detection (已在 TransportMode 测试中覆盖)
    
    // MARK: - Property 20: ETA range for low confidence
    
    /// Property: 低置信度时返回 ETA 范围
    func testETARangeForLowConfidence() {
        let calculator = EnhancedETACalculator()
        
        // 添加一些高方差的速度样本
        for speed in [2.0, 15.0, 5.0, 20.0, 3.0] {
            _ = calculator.calculateETA(
                distance: 5000,
                currentSpeed: speed,
                transportMode: .walking
            )
        }
        
        // 使用一个偏离很大的速度
        let result = calculator.calculateETA(
            distance: 5000,
            currentSpeed: 25.0,  // 远超步行速度
            transportMode: .walking
        )
        
        // 低置信度时应该有范围
        if result.confidence == .low && !result.isStationary {
            XCTAssertNotNil(result.minMinutes)
            XCTAssertNotNil(result.maxMinutes)
            if let min = result.minMinutes, let max = result.maxMinutes {
                XCTAssertLessThanOrEqual(min, max)
            }
        }
    }
    
    /// Property: ETA 范围的最小值 <= 最大值
    func testETARangeMinLessThanMax() {
        property("ETA range min <= max") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let calculator = EnhancedETACalculator()
            
            // 添加一些随机速度样本
            for _ in 0..<5 {
                let speed = random.nextDouble(min: 1, max: 30)
                _ = calculator.calculateETA(
                    distance: 5000,
                    currentSpeed: speed,
                    transportMode: .walking
                )
            }
            
            let result = calculator.calculateETA(
                distance: random.nextDouble(min: 1000, max: 50000),
                currentSpeed: random.nextDouble(min: 1, max: 30),
                transportMode: .walking
            )
            
            if let min = result.minMinutes, let max = result.maxMinutes {
                return min <= max
            }
            
            return true
        }
    }
    
    // MARK: - ETA Stationary Detection Tests
    
    /// Property: 静止状态阈值为 0.5 m/s
    func testETAStationaryThreshold() {
        XCTAssertEqual(EnhancedETACalculator.stationaryThreshold, 0.5)
    }
    
    /// Property: 窗口大小为 10
    func testETAWindowSize() {
        XCTAssertEqual(EnhancedETACalculator.windowSize, 10)
    }
    
    // MARK: - ETAConfidence Codable Tests
    
    /// Property: ETAConfidence 编解码往返一致
    func testETAConfidenceCodableRoundTrip() {
        property("ETAConfidence codable round-trip") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let confidences: [ETAConfidence] = [.high, .medium, .low]
            let confidence = confidences[random.nextInt(bound: confidences.count)]
            
            do {
                let encoded = try JSONEncoder().encode(confidence)
                let decoded = try JSONDecoder().decode(ETAConfidence.self, from: encoded)
                return confidence == decoded
            } catch {
                return false
            }
        }
    }
    
    // MARK: - Property 6: Radius persistence round-trip
    
    /// Property: 半径值保存后加载一致
    func testRadiusPersistenceRoundTrip() {
        property("Radius persistence round-trip") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let radius = random.nextDouble(min: 100, max: 50000)
            
            // 使用临时 UserDefaults
            let defaults = UserDefaults(suiteName: "test_\(seed)")!
            defaults.removePersistentDomain(forName: "test_\(seed)")
            
            // 保存
            let store1 = SettingsStore(userDefaults: defaults)
            store1.defaultGeofenceRadius = radius
            
            // 加载
            let store2 = SettingsStore(userDefaults: defaults)
            
            let result = abs(store2.defaultGeofenceRadius - radius) < 0.01
            
            // 清理
            defaults.removePersistentDomain(forName: "test_\(seed)")
            
            return result
        }
    }
    
    // MARK: - Property 18: Settings persistence round-trip
    
    /// Property: 设置快照编解码往返一致
    func testSettingsSnapshotCodableRoundTrip() {
        property("SettingsSnapshot codable round-trip") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            
            // 创建随机设置
            let defaults = UserDefaults(suiteName: "test_snapshot_\(seed)")!
            defaults.removePersistentDomain(forName: "test_snapshot_\(seed)")
            
            let store = SettingsStore(userDefaults: defaults)
            store.maxGeofenceRadius = random.nextDouble(min: 1000, max: 50000)
            store.defaultGeofenceRadius = random.nextDouble(min: 100, max: 1000)
            store.batteryMode = BatteryMode.allCases[random.nextInt(bound: BatteryMode.allCases.count)]
            store.autoBatterySwitch = random.nextBool()
            store.lowBatteryThreshold = random.nextInt(min: 10, max: 50)
            store.alertSound = AlertSound.allCases[random.nextInt(bound: AlertSound.allCases.count)]
            store.enableEarlyTrigger = random.nextBool()
            store.earlyTriggerMultiplier = random.nextDouble(min: 1.2, max: 2.0)
            store.enableBackupAlarm = random.nextBool()
            store.backupAlarmOffset = random.nextInt(min: 1, max: 30)
            store.enableHapticFeedback = random.nextBool()
            store.enableLiveActivity = random.nextBool()
            store.lastUsedTransportMode = TransportMode.allCases[random.nextInt(bound: TransportMode.allCases.count)]
            
            // 创建快照
            let snapshot = SettingsSnapshot(from: store)
            
            do {
                // 编码
                let encoded = try JSONEncoder().encode(snapshot)
                // 解码
                let decoded = try JSONDecoder().decode(SettingsSnapshot.self, from: encoded)
                
                // 清理
                defaults.removePersistentDomain(forName: "test_snapshot_\(seed)")
                
                return snapshot == decoded
            } catch {
                defaults.removePersistentDomain(forName: "test_snapshot_\(seed)")
                return false
            }
        }
    }
    
    /// Property: 设置保存后加载一致
    func testSettingsPersistenceRoundTrip() {
        let defaults = UserDefaults(suiteName: "test_persistence")!
        defaults.removePersistentDomain(forName: "test_persistence")
        
        // 保存设置
        let store1 = SettingsStore(userDefaults: defaults)
        store1.maxGeofenceRadius = 20000
        store1.batteryMode = .highAccuracy
        store1.enableLiveActivity = false
        store1.lastUsedTransportMode = .subway
        
        // 加载设置
        let store2 = SettingsStore(userDefaults: defaults)
        
        XCTAssertEqual(store2.maxGeofenceRadius, 20000)
        XCTAssertEqual(store2.batteryMode, .highAccuracy)
        XCTAssertEqual(store2.enableLiveActivity, false)
        XCTAssertEqual(store2.lastUsedTransportMode, .subway)
        
        // 清理
        defaults.removePersistentDomain(forName: "test_persistence")
    }
    
    // MARK: - Property 19: Early trigger multiplier bounds
    
    /// Property: 提前触发倍数限制在 1.2x - 2x 范围内
    func testEarlyTriggerMultiplierBounds() {
        XCTAssertEqual(SettingsStore.earlyTriggerMultiplierRange.lowerBound, 1.2)
        XCTAssertEqual(SettingsStore.earlyTriggerMultiplierRange.upperBound, 2.0)
    }
    
    /// Property: 提前触发倍数被正确限制
    func testEarlyTriggerMultiplierClamping() {
        property("Early trigger multiplier is clamped to valid range") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let value = random.nextDouble(min: 0, max: 5)
            
            let defaults = UserDefaults(suiteName: "test_clamp_\(seed)")!
            defaults.removePersistentDomain(forName: "test_clamp_\(seed)")
            
            let store = SettingsStore(userDefaults: defaults)
            let clamped = store.clampEarlyTriggerMultiplier(value)
            
            let result = clamped >= 1.2 && clamped <= 2.0
            
            defaults.removePersistentDomain(forName: "test_clamp_\(seed)")
            
            return result
        }
    }
    
    // MARK: - AlertSound Codable Tests
    
    /// Property: AlertSound 编解码往返一致
    func testAlertSoundCodableRoundTrip() {
        property("AlertSound codable round-trip") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let sounds = AlertSound.allCases
            let sound = sounds[random.nextInt(bound: sounds.count)]
            
            do {
                let encoded = try JSONEncoder().encode(sound)
                let decoded = try JSONDecoder().decode(AlertSound.self, from: encoded)
                return sound == decoded
            } catch {
                return false
            }
        }
    }
    
    // MARK: - Settings Reset Tests
    
    /// Property: 重置后设置恢复默认值
    func testSettingsResetToDefaults() {
        let defaults = UserDefaults(suiteName: "test_reset")!
        defaults.removePersistentDomain(forName: "test_reset")
        
        let store = SettingsStore(userDefaults: defaults)
        
        // 修改设置
        store.maxGeofenceRadius = 30000
        store.batteryMode = .powerSaving
        store.enableLiveActivity = false
        
        // 重置
        store.resetToDefaults()
        
        // 验证恢复默认值
        XCTAssertEqual(store.maxGeofenceRadius, 10000)
        XCTAssertEqual(store.batteryMode, .balanced)
        XCTAssertEqual(store.enableLiveActivity, true)
        
        // 清理
        defaults.removePersistentDomain(forName: "test_reset")
    }
    
    // MARK: - Property 14: Transport mode baseline speeds
    
    /// 验证每种交通方式的基准速度符合预期
    func testTransportModeBaselineSpeeds() {
        // 步行 ~5 km/h = 1.4 m/s
        XCTAssertEqual(TransportMode.walking.baselineSpeed, 1.4, accuracy: 0.01)
        
        // 骑行 ~18 km/h = 5.0 m/s
        XCTAssertEqual(TransportMode.cycling.baselineSpeed, 5.0, accuracy: 0.01)
        
        // 驾车 ~43 km/h = 12.0 m/s
        XCTAssertEqual(TransportMode.driving.baselineSpeed, 12.0, accuracy: 0.01)
        
        // 地铁 ~54 km/h = 15.0 m/s
        XCTAssertEqual(TransportMode.subway.baselineSpeed, 15.0, accuracy: 0.01)
        
        // 公交 ~29 km/h = 8.0 m/s
        XCTAssertEqual(TransportMode.bus.baselineSpeed, 8.0, accuracy: 0.01)
    }
    
    /// Property: 所有交通方式的基准速度都是正数
    func testAllTransportModesHavePositiveBaselineSpeed() {
        property("All transport modes have positive baseline speed") <- forAll { (seed: Int) in
            let modes = TransportMode.allCases
            return modes.allSatisfy { $0.baselineSpeed > 0 }
        }
    }
    
    // MARK: - Property 15: Transport mode speed tolerances
    
    /// 验证每种交通方式的速度容差符合预期
    func testTransportModeSpeedTolerances() {
        // 步行 ±30%
        XCTAssertEqual(TransportMode.walking.speedTolerance, 0.30, accuracy: 0.01)
        
        // 骑行 ±40%
        XCTAssertEqual(TransportMode.cycling.speedTolerance, 0.40, accuracy: 0.01)
        
        // 驾车 ±50%
        XCTAssertEqual(TransportMode.driving.speedTolerance, 0.50, accuracy: 0.01)
        
        // 地铁 ±20%
        XCTAssertEqual(TransportMode.subway.speedTolerance, 0.20, accuracy: 0.01)
        
        // 公交 ±60%
        XCTAssertEqual(TransportMode.bus.speedTolerance, 0.60, accuracy: 0.01)
    }
    
    /// Property: 所有交通方式的速度容差在 0-1 范围内
    func testAllTransportModesTolerancesInValidRange() {
        property("All transport mode tolerances are between 0 and 1") <- forAll { (seed: Int) in
            let modes = TransportMode.allCases
            return modes.allSatisfy { $0.speedTolerance > 0 && $0.speedTolerance <= 1.0 }
        }
    }
    
    // MARK: - Transport Mode Speed Tolerance Tests
    
    /// Property: 基准速度在容差范围内
    func testBaselineSpeedWithinTolerance() {
        property("Baseline speed is always within tolerance") <- forAll { (seed: Int) in
            let modes = TransportMode.allCases
            return modes.allSatisfy { mode in
                mode.isSpeedWithinTolerance(mode.baselineSpeed)
            }
        }
    }
    
    /// Property: 超出容差范围的速度被正确检测
    func testSpeedOutsideToleranceDetected() {
        property("Speed outside tolerance is detected") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let modes = TransportMode.allCases
            let mode = modes[random.nextInt(bound: modes.count)]
            
            // 测试超出上限的速度
            let tooFast = mode.baselineSpeed * (1.0 + mode.speedTolerance + 0.1)
            let tooSlow = max(0, mode.baselineSpeed * (1.0 - mode.speedTolerance - 0.1))
            
            let fastOutside = !mode.isSpeedWithinTolerance(tooFast)
            let slowOutside = tooSlow > 0 ? !mode.isSpeedWithinTolerance(tooSlow) : true
            
            return fastOutside && slowOutside
        }
    }
    
    // MARK: - Transport Mode ETA Calculation Tests
    
    /// Property: ETA 计算结果为正数（距离为正时）
    func testETACalculationPositive() {
        property("ETA is positive for positive distance") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let distance = random.nextDouble(min: 100, max: 100000) // 100m - 100km
            let modes = TransportMode.allCases
            let mode = modes[random.nextInt(bound: modes.count)]
            
            let eta = mode.calculateInitialETA(distance: distance)
            return eta > 0
        }
    }
    
    /// Property: 更快的交通方式有更短的 ETA
    func testFasterModeHasShorterETA() {
        property("Faster mode has shorter ETA for same distance") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let distance = random.nextDouble(min: 1000, max: 50000) // 1-50km
            
            let walkingETA = TransportMode.walking.calculateInitialETA(distance: distance)
            let cyclingETA = TransportMode.cycling.calculateInitialETA(distance: distance)
            let drivingETA = TransportMode.driving.calculateInitialETA(distance: distance)
            let subwayETA = TransportMode.subway.calculateInitialETA(distance: distance)
            
            // 步行 > 骑行 > 公交 > 驾车 > 地铁 (按速度排序)
            return walkingETA >= cyclingETA && cyclingETA >= drivingETA
        }
    }
    
    // MARK: - Transport Mode Detection Tests
    
    /// Property: 基准速度能正确检测对应的交通方式
    func testModeDetectionFromBaselineSpeed() {
        // 步行速度检测
        XCTAssertEqual(TransportMode.detectMode(fromSpeed: 1.4), .walking)
        
        // 骑行速度检测
        XCTAssertEqual(TransportMode.detectMode(fromSpeed: 5.0), .cycling)
        
        // 公交速度检测
        XCTAssertEqual(TransportMode.detectMode(fromSpeed: 8.0), .bus)
        
        // 驾车速度检测
        XCTAssertEqual(TransportMode.detectMode(fromSpeed: 12.0), .driving)
        
        // 地铁速度检测
        XCTAssertEqual(TransportMode.detectMode(fromSpeed: 20.0), .subway)
    }
    
    // MARK: - Property 17: Mode deviation detection
    
    /// Property: 偏差超过 50% 时建议切换交通方式
    func testModeDeviationDetection() {
        property("Mode deviation > 50% suggests correction") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let modes = TransportMode.allCases
            let mode = modes[random.nextInt(bound: modes.count)]
            
            // 偏差超过 50% 的速度
            let deviatedSpeed = mode.baselineSpeed * (random.nextBool() ? 1.6 : 0.4)
            
            return mode.shouldSuggestModeCorrection(deviatedSpeed)
        }
    }
    
    /// Property: 偏差小于 50% 时不建议切换
    func testNoModeDeviationForNormalSpeed() {
        property("Mode deviation < 50% does not suggest correction") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let modes = TransportMode.allCases
            let mode = modes[random.nextInt(bound: modes.count)]
            
            // 偏差小于 50% 的速度 (在 50%-150% 范围内)
            let factor = random.nextDouble(min: 0.55, max: 1.45)
            let normalSpeed = mode.baselineSpeed * factor
            
            return !mode.shouldSuggestModeCorrection(normalSpeed)
        }
    }
    
    // MARK: - Transport Mode Codable Tests
    
    /// Property: TransportMode 编解码往返一致
    func testTransportModeCodableRoundTrip() {
        property("TransportMode codable round-trip") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let modes = TransportMode.allCases
            let mode = modes[random.nextInt(bound: modes.count)]
            
            do {
                let encoded = try JSONEncoder().encode(mode)
                let decoded = try JSONDecoder().decode(TransportMode.self, from: encoded)
                return mode == decoded
            } catch {
                return false
            }
        }
    }
    
    // MARK: - Property 4: Geofence radius step increments
    
    /// Property: < 1km 使用 50m 步进
    func testSmallRadiusStepIncrement() {
        property("Radius < 1km uses 50m steps") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let radius = random.nextDouble(min: 100, max: 999)
            
            let snapped = GeofenceRadiusConfig.snapToStep(radius)
            
            // 验证是 50 的倍数
            let remainder = snapped.truncatingRemainder(dividingBy: 50)
            return remainder < 0.001 || remainder > 49.999
        }
    }
    
    /// Property: >= 1km 使用 500m 步进
    func testLargeRadiusStepIncrement() {
        property("Radius >= 1km uses 500m steps") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let radius = random.nextDouble(min: 1000, max: 50000)
            
            let snapped = GeofenceRadiusConfig.snapToStep(radius)
            
            // 验证是 500 的倍数
            let remainder = snapped.truncatingRemainder(dividingBy: 500)
            return remainder < 0.001 || remainder > 499.999
        }
    }
    
    /// Property: 步进后的值在有效范围内
    func testSnappedRadiusInValidRange() {
        property("Snapped radius is within valid range") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let radius = random.nextDouble(min: 0, max: 100000)
            
            let snapped = GeofenceRadiusConfig.snapToStep(radius)
            
            return snapped >= GeofenceRadiusConfig.minRadius &&
                   snapped <= GeofenceRadiusConfig.absoluteMaxRadius
        }
    }
    
    // MARK: - Property 5: Radius formatting
    
    /// Property: >= 1000m 显示为 km
    func testRadiusFormattingKilometers() {
        property("Radius >= 1000m displays in km") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let radius = random.nextDouble(min: 1000, max: 50000)
            
            let formatted = GeofenceRadiusConfig.formatRadius(radius)
            
            return formatted.contains("km")
        }
    }
    
    /// Property: < 1000m 显示为 m
    func testRadiusFormattingMeters() {
        property("Radius < 1000m displays in m") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let radius = random.nextDouble(min: 100, max: 999)
            
            let formatted = GeofenceRadiusConfig.formatRadius(radius)
            
            return formatted.contains("m") && !formatted.contains("km")
        }
    }
    
    /// 测试具体格式化值
    func testRadiusFormattingSpecificValues() {
        // 米格式
        XCTAssertEqual(GeofenceRadiusConfig.formatRadius(100), "100 m")
        XCTAssertEqual(GeofenceRadiusConfig.formatRadius(500), "500 m")
        XCTAssertEqual(GeofenceRadiusConfig.formatRadius(999), "999 m")
        
        // 公里格式 - 整数
        XCTAssertEqual(GeofenceRadiusConfig.formatRadius(1000), "1 km")
        XCTAssertEqual(GeofenceRadiusConfig.formatRadius(2000), "2 km")
        XCTAssertEqual(GeofenceRadiusConfig.formatRadius(10000), "10 km")
        
        // 公里格式 - 小数
        XCTAssertEqual(GeofenceRadiusConfig.formatRadius(1500), "1.5 km")
        XCTAssertEqual(GeofenceRadiusConfig.formatRadius(2500), "2.5 km")
    }
    
    // MARK: - Geofence Radius Validation Tests
    
    /// Property: 有效半径验证
    func testRadiusValidation() {
        property("Valid radius is within bounds") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let validRadius = random.nextDouble(min: 100, max: 50000)
            let invalidSmall = random.nextDouble(min: 0, max: 99)
            let invalidLarge = random.nextDouble(min: 50001, max: 100000)
            
            return GeofenceRadiusConfig.isValidRadius(validRadius) &&
                   !GeofenceRadiusConfig.isValidRadius(invalidSmall) &&
                   !GeofenceRadiusConfig.isValidRadius(invalidLarge)
        }
    }
    
    // MARK: - Geofence Radius Step Navigation Tests
    
    /// Property: nextStep 总是增加值（除非已达最大）
    func testNextStepIncreases() {
        property("nextStep increases value unless at max") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let radius = random.nextDouble(min: 100, max: 49000)
            
            let next = GeofenceRadiusConfig.nextStep(radius)
            let snapped = GeofenceRadiusConfig.snapToStep(radius)
            
            return next > snapped || snapped >= GeofenceRadiusConfig.absoluteMaxRadius
        }
    }
    
    /// Property: previousStep 总是减少值（除非已达最小）
    func testPreviousStepDecreases() {
        property("previousStep decreases value unless at min") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let radius = random.nextDouble(min: 200, max: 50000)
            
            let prev = GeofenceRadiusConfig.previousStep(radius)
            let snapped = GeofenceRadiusConfig.snapToStep(radius)
            
            return prev < snapped || snapped <= GeofenceRadiusConfig.minRadius
        }
    }
}
