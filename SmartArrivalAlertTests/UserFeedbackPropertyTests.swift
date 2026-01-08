import XCTest
import SwiftCheck
@testable import SmartArrivalAlert

/// Property 9: 用户反馈记录正确性
/// 验证: 需求 4.2
/// 对于任意用户反馈（漏响或晚响），系统应当将对应行程记录的 userFeedback 字段设置为 'missed' 或 'late'
final class UserFeedbackPropertyTests: XCTestCase {
    
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
    }
    
    override func tearDown() async throws {
        try? await storage.delete(forKey: StorageKeys.trips)
        learningEngine = nil
        tripRepository = nil
        storage = nil
        try await super.tearDown()
    }
    
    // MARK: - Property 9: 用户反馈记录正确性
    
    /// Property 9: 用户反馈记录正确性
    /// Feature: smart-arrival-alert, Property 9: 用户反馈记录正确性
    /// 对于任意用户反馈（漏响或晚响），系统应当将对应行程记录的 userFeedback 字段设置为 'missed' 或 'late'
    func testUserFeedbackRecording() async throws {
        let location = Location(
            id: "test_loc",
            name: "Test Location",
            address: "Test Address",
            latitude: 39.9042,
            longitude: 116.4074,
            isFavorite: false
        )
        
        // 创建行程
        let trip = TripRecord(
            id: "test_trip",
            destinationId: location.id,
            destination: location,
            geofenceRadius: 200
        )
        
        try await tripRepository.addTrip(trip)
        
        // 记录漏响反馈
        try await learningEngine.recordUserFeedback(tripId: trip.id, feedback: .missed)
        
        // 验证反馈已记录
        let trips = await tripRepository.getAllTrips()
        let updatedTrip = trips.first { $0.id == trip.id }
        
        XCTAssertNotNil(updatedTrip)
        XCTAssertEqual(updatedTrip?.userFeedback, .missed, "漏响反馈应该被正确记录")
    }
    
    /// 测试晚响反馈记录
    func testLateFeedbackRecording() async throws {
        let location = Location(
            id: "test_loc_late",
            name: "Test Location",
            address: "Test Address",
            latitude: 39.9042,
            longitude: 116.4074,
            isFavorite: false
        )
        
        let trip = TripRecord(
            id: "test_trip_late",
            destinationId: location.id,
            destination: location,
            geofenceRadius: 200
        )
        
        try await tripRepository.addTrip(trip)
        
        // 记录晚响反馈
        try await learningEngine.recordUserFeedback(tripId: trip.id, feedback: .late)
        
        // 验证反馈已记录
        let trips = await tripRepository.getAllTrips()
        let updatedTrip = trips.first { $0.id == trip.id }
        
        XCTAssertNotNil(updatedTrip)
        XCTAssertEqual(updatedTrip?.userFeedback, .late, "晚响反馈应该被正确记录")
    }
    
    /// 测试成功反馈记录
    func testSuccessFeedbackRecording() async throws {
        let location = Location(
            id: "test_loc_success",
            name: "Test Location",
            address: "Test Address",
            latitude: 39.9042,
            longitude: 116.4074,
            isFavorite: false
        )
        
        let trip = TripRecord(
            id: "test_trip_success",
            destinationId: location.id,
            destination: location,
            geofenceRadius: 200
        )
        
        try await tripRepository.addTrip(trip)
        
        // 记录成功反馈
        try await learningEngine.recordUserFeedback(tripId: trip.id, feedback: .success)
        
        // 验证反馈已记录
        let trips = await tripRepository.getAllTrips()
        let updatedTrip = trips.first { $0.id == trip.id }
        
        XCTAssertNotNil(updatedTrip)
        XCTAssertEqual(updatedTrip?.userFeedback, .success, "成功反馈应该被正确记录")
    }
    
    /// 属性测试：任意反馈类型都应该被正确记录
    func testFeedbackRecordingProperty() {
        property("Any feedback type is correctly recorded") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let feedbackTypes: [UserFeedback] = [.success, .missed, .late]
            let feedback = feedbackTypes[random.nextInt(bound: feedbackTypes.count)]
            
            let expectation = XCTestExpectation(description: "Async operation")
            var result = false
            
            Task {
                do {
                    let storage = try LocalStorageAdapter()
                    let tripRepo = TripRepository(storage: storage)
                    let engine = LearningEngine(tripRepository: tripRepo, storage: storage)
                    
                    // 清理
                    try await storage.delete(forKey: StorageKeys.trips)
                    
                    let location = Location(
                        id: "prop_test_loc_\(seed)",
                        name: "Test",
                        address: "Test",
                        latitude: 39.9042,
                        longitude: 116.4074,
                        isFavorite: false
                    )
                    
                    let trip = TripRecord(
                        id: "prop_test_trip_\(seed)",
                        destinationId: location.id,
                        destination: location,
                        geofenceRadius: 200
                    )
                    
                    try await tripRepo.addTrip(trip)
                    try await engine.recordUserFeedback(tripId: trip.id, feedback: feedback)
                    
                    let trips = await tripRepo.getAllTrips()
                    let updatedTrip = trips.first { $0.id == trip.id }
                    
                    result = updatedTrip?.userFeedback == feedback
                    
                    // 清理
                    try await storage.delete(forKey: StorageKeys.trips)
                } catch {
                    result = false
                }
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: 10.0)
            return result
        }
    }
    
    /// 测试反馈记录同时设置结束时间
    func testFeedbackSetsEndTime() async throws {
        let location = Location(
            id: "test_loc_endtime",
            name: "Test Location",
            address: "Test Address",
            latitude: 39.9042,
            longitude: 116.4074,
            isFavorite: false
        )
        
        let trip = TripRecord(
            id: "test_trip_endtime",
            destinationId: location.id,
            destination: location,
            geofenceRadius: 200
        )
        
        // 确保初始没有结束时间
        XCTAssertNil(trip.endTime)
        
        try await tripRepository.addTrip(trip)
        try await learningEngine.recordUserFeedback(tripId: trip.id, feedback: .success)
        
        // 验证结束时间已设置
        let trips = await tripRepository.getAllTrips()
        let updatedTrip = trips.first { $0.id == trip.id }
        
        XCTAssertNotNil(updatedTrip?.endTime, "记录反馈时应该设置结束时间")
    }
    
    /// 测试反馈记录后清除可靠性缓存
    func testFeedbackClearsReliabilityCache() async throws {
        let destinationId = "cache_test_dest"
        let location = Location(
            id: destinationId,
            name: "Test Location",
            address: "Test Address",
            latitude: 39.9042,
            longitude: 116.4074,
            isFavorite: false
        )
        
        // 添加一些行程并计算可靠性（触发缓存）
        for i in 0..<5 {
            var trip = TripRecord(
                id: "cache_trip_\(i)",
                destinationId: destinationId,
                destination: location,
                geofenceRadius: 200
            )
            trip.userFeedback = .success
            try await tripRepository.addTrip(trip)
        }
        
        // 计算可靠性（这会缓存结果）
        let initialScore = await learningEngine.calculateReliabilityScore(forDestinationId: destinationId)
        XCTAssertEqual(initialScore, 100.0)
        
        // 添加新行程并记录失败反馈
        let newTrip = TripRecord(
            id: "cache_trip_new",
            destinationId: destinationId,
            destination: location,
            geofenceRadius: 200
        )
        try await tripRepository.addTrip(newTrip)
        try await learningEngine.recordUserFeedback(tripId: newTrip.id, feedback: .missed)
        
        // 重新计算可靠性（缓存应该已清除，所以会重新计算）
        let newScore = await learningEngine.calculateReliabilityScore(forDestinationId: destinationId)
        
        // 6个行程中5个成功，1个失败 = 83.33%
        XCTAssertLessThan(newScore, 100.0, "新的失败反馈应该降低可靠性评分")
    }
}
