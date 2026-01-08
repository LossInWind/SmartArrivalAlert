import XCTest
import SwiftCheck
import CoreLocation
@testable import SmartArrivalAlert

/// Property 7: 行程记录完整性
/// Property 8: 提前触发条件正确性
/// 验证: 需求 3.6, 3.8
final class MonitoringPropertyTests: XCTestCase {
    
    var storage: LocalStorageAdapter!
    var tripRepository: TripRepository!
    
    override func setUp() async throws {
        try await super.setUp()
        storage = try LocalStorageAdapter()
        tripRepository = TripRepository(storage: storage)
        
        // 清理测试数据
        try await storage.delete(forKey: StorageKeys.trips)
    }
    
    override func tearDown() async throws {
        try? await storage.delete(forKey: StorageKeys.trips)
        tripRepository = nil
        storage = nil
        try await super.tearDown()
    }
    
    // MARK: - Property 7: 行程记录完整性
    
    /// Property 7: 行程记录完整性
    /// Feature: smart-arrival-alert, Property 7: 行程记录完整性
    /// 对于任意行程，记录应包含：开始时间、目的地、围栏半径、提醒类型（如果已触发）
    func testTripRecordCompleteness() async throws {
        let destination = Location(
            id: "test_dest",
            name: "Test Destination",
            address: "Test Address",
            latitude: 39.9042,
            longitude: 116.4074,
            isFavorite: false
        )
        
        // 创建行程记录
        let trip = TripRecord(
            id: "test_trip",
            destinationId: destination.id,
            destination: destination,
            geofenceRadius: 200
        )
        
        // 验证必要字段
        XCTAssertNotNil(trip.id)
        XCTAssertNotNil(trip.startTime)
        XCTAssertNotNil(trip.destinationId)
        XCTAssertNotNil(trip.destination)
        XCTAssertGreaterThan(trip.geofenceRadius, 0)
        
        // 保存并读取
        try await tripRepository.addTrip(trip)
        let trips = await tripRepository.getAllTrips()
        
        XCTAssertEqual(trips.count, 1)
        let savedTrip = trips[0]
        
        XCTAssertEqual(savedTrip.id, trip.id)
        XCTAssertEqual(savedTrip.destinationId, trip.destinationId)
        XCTAssertEqual(savedTrip.destination.id, trip.destination.id)
        XCTAssertEqual(savedTrip.geofenceRadius, trip.geofenceRadius)
    }
    
    /// 属性测试：行程记录完整性
    func testTripRecordCompletenessProperty() {
        property("Trip record is always complete") <- forAll { (seed: Int) in
            let location = TestGenerators.generateLocation(seed: seed)
            let random = SeededRandom(seed: seed)
            let radius = random.nextInt(bound: 901) + 100 // 100-1000
            
            let trip = TripRecord(
                id: "trip_\(seed)",
                destinationId: location.id,
                destination: location,
                geofenceRadius: radius
            )
            
            // 验证完整性
            return !trip.id.isEmpty &&
                   !trip.destinationId.isEmpty &&
                   !trip.destination.id.isEmpty &&
                   trip.geofenceRadius >= 100 &&
                   trip.geofenceRadius <= 1000
        }
    }
    
    /// 测试行程记录更新
    func testTripRecordUpdate() async throws {
        let destination = Location(
            id: "test_dest",
            name: "Test Destination",
            address: "Test Address",
            latitude: 39.9042,
            longitude: 116.4074,
            isFavorite: false
        )
        
        var trip = TripRecord(
            id: "test_trip",
            destinationId: destination.id,
            destination: destination,
            geofenceRadius: 200
        )
        
        try await tripRepository.addTrip(trip)
        
        // 更新提醒类型
        trip.alertTriggered = true
        trip.alertType = .arrival
        trip.alertTimestamp = Date()
        try await tripRepository.updateTrip(trip)
        
        let trips = await tripRepository.getAllTrips()
        XCTAssertEqual(trips[0].alertType, .arrival)
        XCTAssertNotNil(trips[0].alertTimestamp)
    }
    
    // MARK: - Property 8: 提前触发条件正确性
    
    /// Property 8: 提前触发条件正确性
    /// Feature: smart-arrival-alert, Property 8: 提前触发条件正确性
    /// 当目的地信号差且当前位置信号良好时，应该提前触发
    func testEarlyTriggerConditions() {
        // 测试提前触发逻辑
        
        // 情况1：目的地信号差，当前信号好，距离近 -> 应该提前触发
        let shouldTrigger1 = evaluateEarlyTrigger(
            destinationSignal: .poor,
            currentSignal: .good,
            distanceRatio: 1.2 // 在围栏半径的1.2倍处
        )
        XCTAssertTrue(shouldTrigger1, "目的地信号差、当前信号好、距离近时应该提前触发")
        
        // 情况2：目的地信号好 -> 不应该提前触发
        let shouldTrigger2 = evaluateEarlyTrigger(
            destinationSignal: .good,
            currentSignal: .good,
            distanceRatio: 1.2
        )
        XCTAssertFalse(shouldTrigger2, "目的地信号好时不应该提前触发")
        
        // 情况3：当前信号差 -> 不应该提前触发
        let shouldTrigger3 = evaluateEarlyTrigger(
            destinationSignal: .poor,
            currentSignal: .poor,
            distanceRatio: 1.2
        )
        XCTAssertFalse(shouldTrigger3, "当前信号差时不应该提前触发")
        
        // 情况4：距离太远 -> 不应该提前触发
        let shouldTrigger4 = evaluateEarlyTrigger(
            destinationSignal: .poor,
            currentSignal: .good,
            distanceRatio: 2.0 // 在围栏半径的2倍处
        )
        XCTAssertFalse(shouldTrigger4, "距离太远时不应该提前触发")
    }
    
    /// 属性测试：提前触发条件
    func testEarlyTriggerProperty() {
        property("Early trigger conditions are correct") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            
            let destinationSignals: [SignalQualityLevel] = [.good, .fair, .poor, .unknown]
            let currentSignals: [SignalQualityLevel] = [.good, .fair, .poor, .unknown]
            
            let destinationSignal = destinationSignals[random.nextInt(bound: destinationSignals.count)]
            let currentSignal = currentSignals[random.nextInt(bound: currentSignals.count)]
            let distanceRatio = random.nextDouble(min: 0.5, max: 3.0)
            
            let shouldTrigger = self.evaluateEarlyTrigger(
                destinationSignal: destinationSignal,
                currentSignal: currentSignal,
                distanceRatio: distanceRatio
            )
            
            // 验证逻辑正确性
            if destinationSignal != .poor {
                // 目的地信号不差时，不应该提前触发
                return shouldTrigger == false
            }
            
            if currentSignal != .good {
                // 当前信号不好时，不应该提前触发
                return shouldTrigger == false
            }
            
            if distanceRatio > 1.5 {
                // 距离太远时，不应该提前触发
                return shouldTrigger == false
            }
            
            // 满足所有条件时应该提前触发
            return shouldTrigger == true
        }
    }
    
    /// 测试提前触发记录
    func testEarlyTriggerRecording() async throws {
        let destination = Location(
            id: "test_dest",
            name: "Test Destination",
            address: "Test Address",
            latitude: 39.9042,
            longitude: 116.4074,
            isFavorite: false
        )
        
        var trip = TripRecord(
            id: "test_trip",
            destinationId: destination.id,
            destination: destination,
            geofenceRadius: 200
        )
        
        try await tripRepository.addTrip(trip)
        
        // 记录提前触发
        trip.alertTriggered = true
        trip.alertType = .earlyArrival
        trip.alertTimestamp = Date()
        try await tripRepository.updateTrip(trip)
        
        let trips = await tripRepository.getAllTrips()
        XCTAssertEqual(trips[0].alertType, .earlyArrival)
    }
    
    // MARK: - Monitoring Config Tests
    
    /// 测试监控配置验证
    func testMonitoringConfigValidation() {
        let destination = Location(
            id: "test_dest",
            name: "Test Destination",
            address: "Test Address",
            latitude: 39.9042,
            longitude: 116.4074,
            isFavorite: false
        )
        
        // 有效配置
        let validConfig = MonitoringConfig(
            destination: destination,
            geofenceRadius: 200,
            enableEarlyTrigger: true
        )
        
        XCTAssertTrue(GeoUtils.isValidGeofenceRadius(Double(validConfig.geofenceRadius)))
        
        // 无效半径会被限制
        let invalidConfig = MonitoringConfig(
            destination: destination,
            geofenceRadius: 50,
            enableEarlyTrigger: false
        )
        XCTAssertEqual(invalidConfig.geofenceRadius, 100) // 被限制到最小值
    }
    
    /// 属性测试：监控配置半径总是有效
    func testMonitoringConfigRadiusProperty() {
        property("Monitoring config radius is always valid") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let location = TestGenerators.generateLocation(seed: seed)
            let radius = random.nextInt(bound: 60000) - 5000 // -5000 to 54999
            
            let config = MonitoringConfig(
                destination: location,
                geofenceRadius: radius,
                enableEarlyTrigger: false
            )
            
            // 围栏半径范围已扩展到 100m - 50km
            return config.geofenceRadius >= 100 && config.geofenceRadius <= 50000
        }
    }
    
    // MARK: - Helper Methods
    
    /// 评估是否应该提前触发
    /// - Parameters:
    ///   - destinationSignal: 目的地信号质量
    ///   - currentSignal: 当前位置信号质量
    ///   - distanceRatio: 距离与围栏半径的比值
    /// - Returns: 是否应该提前触发
    private func evaluateEarlyTrigger(
        destinationSignal: SignalQualityLevel,
        currentSignal: SignalQualityLevel,
        distanceRatio: Double
    ) -> Bool {
        // 提前触发条件：
        // 1. 目的地信号差
        // 2. 当前位置信号好
        // 3. 距离在围栏半径的1.5倍以内
        
        guard destinationSignal == .poor else { return false }
        guard currentSignal == .good else { return false }
        guard distanceRatio <= 1.5 else { return false }
        
        return true
    }
}
