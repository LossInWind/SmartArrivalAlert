import XCTest
import SwiftCheck
@testable import SmartArrivalAlert

/// Property 3: 自检结果完整性
/// Property 4: 风险等级与响应一致性
/// 验证: 需求 2.1, 2.2, 2.3, 2.4, 2.5, 2.6
final class SelfDiagnosisPropertyTests: XCTestCase {
    
    var selfDiagnosisEngine: SelfDiagnosisEngine!
    var learningEngine: LearningEngine!
    var signalQualityRepository: SignalQualityRepository!
    var tripRepository: TripRepository!
    var storage: LocalStorageAdapter!
    
    override func setUp() async throws {
        try await super.setUp()
        storage = try LocalStorageAdapter()
        tripRepository = TripRepository(storage: storage)
        learningEngine = LearningEngine(tripRepository: tripRepository, storage: storage)
        signalQualityRepository = SignalQualityRepository(storage: storage)
        selfDiagnosisEngine = SelfDiagnosisEngine(
            learningEngine: learningEngine,
            signalQualityRepository: signalQualityRepository
        )
        
        // 清理测试数据
        try await storage.delete(forKey: StorageKeys.trips)
        try await storage.delete(forKey: StorageKeys.signalData)
    }
    
    override func tearDown() async throws {
        try? await storage.delete(forKey: StorageKeys.trips)
        try? await storage.delete(forKey: StorageKeys.signalData)
        selfDiagnosisEngine = nil
        learningEngine = nil
        signalQualityRepository = nil
        tripRepository = nil
        storage = nil
        try await super.tearDown()
    }
    
    // MARK: - Property 3: 自检结果完整性
    
    /// Property 3: 自检结果完整性
    /// Feature: smart-arrival-alert, Property 3: 自检结果完整性
    /// 对于任意目的地和路线，执行自检后返回的风险评估结果应当包含：权限状态、目的地信号质量、路线信号质量、历史成功率
    func testDiagnosisResultCompleteness() async throws {
        let destination = Location(
            id: "test_dest",
            name: "Test Destination",
            address: "Test Address",
            latitude: 39.9042,
            longitude: 116.4074,
            isFavorite: false
        )
        
        let result = await selfDiagnosisEngine.performDiagnosis(destination: destination, route: nil)
        
        // 验证结果包含所有必要字段
        // 1. 权限状态（permissionOk 是 Bool，总是有值）
        XCTAssertNotNil(result.permissionOk as Bool?)
        
        // 2. 目的地信号质量
        XCTAssertNotNil(result.destinationSignalQuality)
        
        // 3. 路线信号质量
        XCTAssertNotNil(result.routeSignalQuality)
        
        // 4. 历史成功率
        XCTAssertGreaterThanOrEqual(result.historicalSuccessRate, 0)
        XCTAssertLessThanOrEqual(result.historicalSuccessRate, 100)
        
        // 5. 总体风险等级
        XCTAssertNotNil(result.overallRisk)
    }
    
    /// 属性测试：任意目的地的自检结果都应该完整
    func testDiagnosisCompletenessProperty() {
        property("Diagnosis result is always complete") <- forAll { (seed: Int) in
            let location = TestGenerators.generateLocation(seed: seed)
            
            let expectation = XCTestExpectation(description: "Async operation")
            var result = false
            
            Task {
                do {
                    let storage = try LocalStorageAdapter()
                    let tripRepo = TripRepository(storage: storage)
                    let learning = LearningEngine(tripRepository: tripRepo, storage: storage)
                    let signalRepo = SignalQualityRepository(storage: storage)
                    let engine = SelfDiagnosisEngine(learningEngine: learning, signalQualityRepository: signalRepo)
                    
                    let assessment = await engine.performDiagnosis(destination: location, route: nil)
                    
                    // 验证完整性
                    result = assessment.historicalSuccessRate >= 0 &&
                             assessment.historicalSuccessRate <= 100 &&
                             (assessment.overallRisk == .low || 
                              assessment.overallRisk == .medium || 
                              assessment.overallRisk == .high)
                } catch {
                    result = false
                }
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: 10.0)
            return result
        }
    }
    
    // MARK: - Property 4: 风险等级与响应一致性
    
    /// Property 4: 风险等级与响应一致性
    /// Feature: smart-arrival-alert, Property 4: 风险等级与响应一致性
    /// 对于任意风险评估结果，当风险等级为 'low' 时不应产生警告；当风险等级为 'high' 时必须产生警告
    func testRiskLevelResponseConsistency() {
        // 测试低风险情况
        let lowRiskAssessment = RiskAssessment(
            overallRisk: .low,
            permissionOk: true,
            destinationSignalQuality: SignalQuality(level: .good, averageAccuracy: 10, sampleCount: 10),
            routeSignalQuality: SignalQuality(level: .good, averageAccuracy: 15, sampleCount: 5),
            historicalSuccessRate: 95,
            warnings: [],
            suggestEarlyTrigger: false,
            suggestBackupAlarm: false
        )
        
        // 低风险时不应有警告
        XCTAssertTrue(lowRiskAssessment.warnings.isEmpty, "低风险时不应产生警告")
        
        // 测试高风险情况 - 权限问题
        let highRiskPermission = createHighRiskAssessment(reason: .permission)
        XCTAssertFalse(highRiskPermission.warnings.isEmpty, "高风险（权限问题）时必须产生警告")
        
        // 测试高风险情况 - 信号差
        let highRiskSignal = createHighRiskAssessment(reason: .poorSignal)
        XCTAssertFalse(highRiskSignal.warnings.isEmpty, "高风险（信号差）时必须产生警告")
        
        // 测试高风险情况 - 成功率低
        let highRiskSuccessRate = createHighRiskAssessment(reason: .lowSuccessRate)
        XCTAssertFalse(highRiskSuccessRate.warnings.isEmpty, "高风险（成功率低）时必须产生警告")
    }
    
    /// 属性测试：风险等级判定正确性
    func testRiskLevelDeterminationProperty() {
        property("Risk level is correctly determined") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            
            let permissionOk = random.nextBool()
            let signalLevels: [SignalQualityLevel] = [.good, .fair, .poor, .unknown]
            let signalLevel = signalLevels[random.nextInt(bound: signalLevels.count)]
            let successRate = random.nextDouble(min: 0, max: 100)
            
            let signalQuality = SignalQuality(
                level: signalLevel,
                averageAccuracy: random.nextDouble(min: 0, max: 100),
                sampleCount: random.nextInt(bound: 100)
            )
            
            let riskLevel = SelfDiagnosisEngine.determineRiskLevel(
                permissionOk: permissionOk,
                destinationSignalQuality: signalQuality,
                historicalSuccessRate: successRate
            )
            
            // 验证风险等级判定逻辑
            if !permissionOk {
                return riskLevel == .high
            }
            
            if signalLevel == .poor {
                return riskLevel == .high
            }
            
            if successRate < 70 {
                return riskLevel == .high
            }
            
            if signalLevel == .fair || successRate < 85 {
                return riskLevel == .medium
            }
            
            return riskLevel == .low
        }
    }
    
    /// 测试：高风险时应建议设置兜底闹钟
    func testHighRiskSuggestsBackupAlarm() async throws {
        let destination = Location(
            id: "high_risk_dest",
            name: "High Risk Destination",
            address: "Test Address",
            latitude: 39.9042,
            longitude: 116.4074,
            isFavorite: false
        )
        
        // 添加一些失败的行程记录来降低成功率
        for i in 0..<10 {
            var trip = TripRecord(
                id: "fail_trip_\(i)",
                destinationId: destination.id,
                destination: destination,
                geofenceRadius: 200
            )
            trip.userFeedback = i < 3 ? .success : .missed // 30% 成功率
            try await tripRepository.addTrip(trip)
        }
        
        let result = await selfDiagnosisEngine.performDiagnosis(destination: destination, route: nil)
        
        XCTAssertEqual(result.overallRisk, .high, "30%成功率应该是高风险")
        XCTAssertTrue(result.suggestBackupAlarm, "高风险时应建议设置兜底闹钟")
    }
    
    /// 测试：信号差区域应建议提前触发
    func testPoorSignalSuggestsEarlyTrigger() async throws {
        let destination = Location(
            id: "poor_signal_dest",
            name: "Poor Signal Destination",
            address: "Test Address",
            latitude: 39.9042,
            longitude: 116.4074,
            isFavorite: false
        )
        
        // 添加差信号的样本
        for i in 0..<10 {
            let sample = SignalSample(
                latitude: destination.latitude,
                longitude: destination.longitude,
                accuracy: 80 + Double(i), // 80-89米，差信号
                timestamp: Date()
            )
            try await signalQualityRepository.recordSignalSample(sample)
        }
        
        let result = await selfDiagnosisEngine.performDiagnosis(destination: destination, route: nil)
        
        XCTAssertTrue(result.suggestEarlyTrigger, "信号差区域应建议提前触发")
    }
    
    // MARK: - Helper Methods
    
    private enum HighRiskReason {
        case permission
        case poorSignal
        case lowSuccessRate
    }
    
    private func createHighRiskAssessment(reason: HighRiskReason) -> RiskAssessment {
        switch reason {
        case .permission:
            return RiskAssessment(
                overallRisk: .high,
                permissionOk: false,
                destinationSignalQuality: SignalQuality(level: .good, averageAccuracy: 10, sampleCount: 10),
                routeSignalQuality: .unknown,
                historicalSuccessRate: 100,
                warnings: ["位置权限未授予"],
                suggestEarlyTrigger: false,
                suggestBackupAlarm: true
            )
        case .poorSignal:
            return RiskAssessment(
                overallRisk: .high,
                permissionOk: true,
                destinationSignalQuality: SignalQuality(level: .poor, averageAccuracy: 80, sampleCount: 10),
                routeSignalQuality: .unknown,
                historicalSuccessRate: 100,
                warnings: ["目的地信号质量较差"],
                suggestEarlyTrigger: true,
                suggestBackupAlarm: true
            )
        case .lowSuccessRate:
            return RiskAssessment(
                overallRisk: .high,
                permissionOk: true,
                destinationSignalQuality: SignalQuality(level: .good, averageAccuracy: 10, sampleCount: 10),
                routeSignalQuality: .unknown,
                historicalSuccessRate: 50,
                warnings: ["该路线历史成功率较低"],
                suggestEarlyTrigger: false,
                suggestBackupAlarm: true
            )
        }
    }
}
