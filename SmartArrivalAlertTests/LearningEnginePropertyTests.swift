import XCTest
import SwiftCheck
@testable import SmartArrivalAlert

/// Property 10: 可靠性评分计算正确性
/// Property 11: 高风险路线判定正确性
/// 验证: 需求 4.3, 4.4
final class LearningEnginePropertyTests: XCTestCase {
    
    var learningEngine: LearningEngine!
    var tripRepository: TripRepository!
    var storage: LocalStorageAdapter!
    
    override func setUp() async throws {
        try await super.setUp()
        storage = try LocalStorageAdapter()
        tripRepository = TripRepository(storage: storage)
        learningEngine = LearningEngine(tripRepository: tripRepository, storage: storage)
        
        // 清理测试数据
        try await storage.delete(forKey: StorageKeys.trips)
        try await storage.delete(forKey: StorageKeys.signalData)
    }
    
    override func tearDown() async throws {
        try? await storage.delete(forKey: StorageKeys.trips)
        try? await storage.delete(forKey: StorageKeys.signalData)
        learningEngine = nil
        tripRepository = nil
        storage = nil
        try await super.tearDown()
    }
    
    // MARK: - Property 10: 可靠性评分计算正确性
    
    /// Property 10: 可靠性评分计算正确性
    /// Feature: smart-arrival-alert, Property 10: 可靠性评分计算正确性
    /// 对于任意行程记录集合，可靠性评分应当等于成功次数除以总反馈次数的百分比（最近10次）
    func testReliabilityScoreCalculation() {
        // 测试空数据
        let emptyScore = LearningEngine.calculateReliabilityScore(from: [])
        XCTAssertEqual(emptyScore, 100.0, "空数据应返回100%")
        
        // 测试全部成功
        let allSuccessTrips = createTripsWithFeedback(successCount: 5, missedCount: 0, lateCount: 0)
        let allSuccessScore = LearningEngine.calculateReliabilityScore(from: allSuccessTrips)
        XCTAssertEqual(allSuccessScore, 100.0, "全部成功应返回100%")
        
        // 测试全部失败
        let allFailedTrips = createTripsWithFeedback(successCount: 0, missedCount: 3, lateCount: 2)
        let allFailedScore = LearningEngine.calculateReliabilityScore(from: allFailedTrips)
        XCTAssertEqual(allFailedScore, 0.0, "全部失败应返回0%")
        
        // 测试混合情况
        let mixedTrips = createTripsWithFeedback(successCount: 7, missedCount: 2, lateCount: 1)
        let mixedScore = LearningEngine.calculateReliabilityScore(from: mixedTrips)
        XCTAssertEqual(mixedScore, 70.0, "7成功/10总数应返回70%")
    }
    
    /// 属性测试：可靠性评分等于成功次数/总次数*100
    func testReliabilityScoreProperty() {
        property("Reliability score equals success count / total count * 100") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            
            // 生成随机的成功/失败数量（总数1-15）
            let totalCount = random.nextInt(min: 1, max: 15)
            let successCount = random.nextInt(bound: totalCount + 1)
            let missedCount = random.nextInt(bound: totalCount - successCount + 1)
            let lateCount = totalCount - successCount - missedCount
            
            let trips = self.createTripsWithFeedback(
                successCount: successCount,
                missedCount: missedCount,
                lateCount: lateCount
            )
            
            let score = LearningEngine.calculateReliabilityScore(from: trips)
            
            // 只考虑最近10次
            let effectiveTotal = min(totalCount, LearningEngine.recentTripsCount)
            let effectiveSuccess = min(successCount, effectiveTotal)
            
            // 计算期望值
            let expectedScore: Double
            if totalCount <= LearningEngine.recentTripsCount {
                expectedScore = Double(successCount) / Double(totalCount) * 100.0
            } else {
                // 当超过10个时，只看前10个（按添加顺序）
                let recentTrips = Array(trips.prefix(LearningEngine.recentTripsCount))
                let recentSuccessCount = recentTrips.filter { $0.userFeedback == .success }.count
                expectedScore = Double(recentSuccessCount) / Double(LearningEngine.recentTripsCount) * 100.0
            }
            
            // 允许浮点数误差
            return abs(score - expectedScore) < 0.01
        }
    }
    
    // MARK: - Property 11: 高风险路线判定正确性
    
    /// Property 11: 高风险路线判定正确性
    /// Feature: smart-arrival-alert, Property 11: 高风险路线判定正确性
    /// 对于任意可靠性评分低于 70% 的路线，应当被判定为高风险路线
    func testHighRiskRouteJudgment() async throws {
        let destinationId = "test_destination"
        let location = Location(
            id: destinationId,
            name: "Test",
            address: "Test",
            latitude: 39.9042,
            longitude: 116.4074,
            isFavorite: false
        )
        
        // 测试低于70%的情况（高风险）
        // 添加10个行程，6个失败，4个成功 = 40%成功率
        for i in 0..<10 {
            var trip = TripRecord(
                id: "trip_\(i)",
                destinationId: destinationId,
                destination: location,
                geofenceRadius: 200
            )
            trip.userFeedback = i < 4 ? .success : .missed
            try await tripRepository.addTrip(trip)
        }
        
        let isHighRisk = await learningEngine.isHighRiskRoute(destinationId: destinationId)
        XCTAssertTrue(isHighRisk, "40%成功率应该是高风险")
        
        // 清理并测试正好70%的情况（不是高风险）
        try await storage.delete(forKey: StorageKeys.trips)
        await learningEngine.clearCache()
        
        for i in 0..<10 {
            var trip = TripRecord(
                id: "trip2_\(i)",
                destinationId: destinationId,
                destination: location,
                geofenceRadius: 200
            )
            trip.userFeedback = i < 7 ? .success : .missed
            try await tripRepository.addTrip(trip)
        }
        
        let isHighRisk70 = await learningEngine.isHighRiskRoute(destinationId: destinationId)
        XCTAssertFalse(isHighRisk70, "70%成功率不应该是高风险")
    }
    
    /// 属性测试：低于70%的评分应判定为高风险
    func testHighRiskThresholdProperty() {
        property("Score below 70% is high risk") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            
            // 生成随机评分 (0-100)
            let score = random.nextDouble(min: 0, max: 100)
            
            // 创建对应的行程数据
            let totalCount = 10
            let successCount = Int((score / 100.0) * Double(totalCount))
            
            let trips = self.createTripsWithFeedback(
                successCount: successCount,
                missedCount: totalCount - successCount,
                lateCount: 0
            )
            
            let calculatedScore = LearningEngine.calculateReliabilityScore(from: trips)
            let isHighRisk = calculatedScore < LearningEngine.highRiskThreshold
            
            // 验证：评分低于70%时应该是高风险
            let expectedHighRisk = calculatedScore < 70.0
            return isHighRisk == expectedHighRisk
        }
    }
    
    // MARK: - Signal Quality Tests
    
    /// 测试信号质量等级判定
    func testSignalQualityLevelDetermination() {
        // 好信号：精度 <= 20米
        XCTAssertEqual(LearningEngine.determineQualityLevel(accuracy: 10), .good)
        XCTAssertEqual(LearningEngine.determineQualityLevel(accuracy: 20), .good)
        
        // 一般信号：精度 20-50米
        XCTAssertEqual(LearningEngine.determineQualityLevel(accuracy: 21), .fair)
        XCTAssertEqual(LearningEngine.determineQualityLevel(accuracy: 50), .fair)
        
        // 差信号：精度 > 50米
        XCTAssertEqual(LearningEngine.determineQualityLevel(accuracy: 51), .poor)
        XCTAssertEqual(LearningEngine.determineQualityLevel(accuracy: 100), .poor)
    }
    
    /// 测试位置哈希计算
    func testLocationHashCalculation() {
        // 相同位置应该有相同的哈希
        let hash1 = LearningEngine.calculateLocationHash(latitude: 39.9042, longitude: 116.4074)
        let hash1Again = LearningEngine.calculateLocationHash(latitude: 39.9042, longitude: 116.4074)
        XCTAssertEqual(hash1, hash1Again, "相同位置应该有相同的哈希")
        
        // 非常接近的位置（在同一个网格内）应该有相同的哈希
        let hash2 = LearningEngine.calculateLocationHash(latitude: 39.9042, longitude: 116.4074)
        let hash3 = LearningEngine.calculateLocationHash(latitude: 39.9041, longitude: 116.4074)
        XCTAssertEqual(hash2, hash3, "非常接近的位置应该有相同的哈希")
        
        // 较远的位置应该有不同的哈希
        let hash4 = LearningEngine.calculateLocationHash(latitude: 39.9142, longitude: 116.4174)
        XCTAssertNotEqual(hash1, hash4, "较远位置应该有不同的哈希")
    }
    
    // MARK: - Helper Methods
    
    private func createTripsWithFeedback(successCount: Int, missedCount: Int, lateCount: Int) -> [TripRecord] {
        var trips: [TripRecord] = []
        let location = Location(
            id: "test_loc",
            name: "Test",
            address: "Test",
            latitude: 39.9042,
            longitude: 116.4074,
            isFavorite: false
        )
        
        var index = 0
        
        // 添加成功的行程
        for _ in 0..<successCount {
            var trip = TripRecord(
                id: "trip_\(index)",
                destinationId: location.id,
                destination: location,
                geofenceRadius: 200
            )
            trip.userFeedback = .success
            trips.append(trip)
            index += 1
        }
        
        // 添加漏响的行程
        for _ in 0..<missedCount {
            var trip = TripRecord(
                id: "trip_\(index)",
                destinationId: location.id,
                destination: location,
                geofenceRadius: 200
            )
            trip.userFeedback = .missed
            trips.append(trip)
            index += 1
        }
        
        // 添加晚响的行程
        for _ in 0..<lateCount {
            var trip = TripRecord(
                id: "trip_\(index)",
                destinationId: location.id,
                destination: location,
                geofenceRadius: 200
            )
            trip.userFeedback = .late
            trips.append(trip)
            index += 1
        }
        
        return trips
    }
}
