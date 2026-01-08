import Foundation
import SwiftCheck
@testable import SmartArrivalAlert

// MARK: - Shared Test Generators

/// 共享的测试数据生成器
enum TestGenerators {
    
    static func generateLocation(seed: Int) -> Location {
        let random = SeededRandom(seed: seed)
        return Location(
            id: UUID().uuidString,
            name: "Location_\(random.nextInt(bound: 1000))",
            address: "Address_\(random.nextInt(bound: 1000))",
            latitude: random.nextDouble(min: -90, max: 90),
            longitude: random.nextDouble(min: -180, max: 180),
            lastVisited: random.nextBool() ? Date() : nil,
            isFavorite: random.nextBool(),
            lastGeofenceRadius: random.nextBool() ? random.nextInt(min: 100, max: 1000) : nil
        )
    }
    
    static func generateSignalSample(seed: Int) -> SignalSample {
        let random = SeededRandom(seed: seed)
        return SignalSample(
            latitude: random.nextDouble(min: -90, max: 90),
            longitude: random.nextDouble(min: -180, max: 180),
            accuracy: random.nextDouble(min: 0, max: 1000),
            timestamp: Date()
        )
    }
    
    static func generateSignalQuality(seed: Int) -> SignalQuality {
        let random = SeededRandom(seed: seed)
        let levels: [SignalQualityLevel] = [.good, .fair, .poor, .unknown]
        return SignalQuality(
            level: levels[random.nextInt(bound: levels.count)],
            averageAccuracy: random.nextDouble(min: 0, max: 1000),
            sampleCount: random.nextInt(bound: 1000)
        )
    }
    
    static func generateTripRecord(seed: Int) -> TripRecord {
        let random = SeededRandom(seed: seed)
        let location = generateLocation(seed: seed + 1)
        
        let alertTypes: [AlertType?] = [nil, .arrival, .earlyArrival, .backupAlarm]
        let feedbacks: [UserFeedback?] = [nil, .success, .missed, .late]
        
        let sampleCount = random.nextInt(bound: 5)
        var samples: [SignalSample] = []
        for i in 0..<sampleCount {
            samples.append(generateSignalSample(seed: seed + i + 10))
        }
        
        return TripRecord(
            id: UUID().uuidString,
            destinationId: location.id,
            destination: location,
            startTime: Date(),
            endTime: random.nextBool() ? Date() : nil,
            geofenceRadius: random.nextInt(min: 100, max: 1000),
            alertTriggered: random.nextBool(),
            alertType: alertTypes[random.nextInt(bound: alertTypes.count)],
            alertTimestamp: random.nextBool() ? Date() : nil,
            userFeedback: feedbacks[random.nextInt(bound: feedbacks.count)],
            signalSamples: samples,
            backupAlarmSet: random.nextBool(),
            backupAlarmTriggered: random.nextBool()
        )
    }
    
    static func generateUserSettings(seed: Int) -> UserSettings {
        let random = SeededRandom(seed: seed)
        return UserSettings(
            defaultGeofenceRadius: random.nextInt(min: 100, max: 1000),
            soundEnabled: random.nextBool(),
            vibrationEnabled: random.nextBool(),
            autoBackupAlarm: random.nextBool()
        )
    }
    
    static func generateRiskAssessment(seed: Int) -> RiskAssessment {
        let random = SeededRandom(seed: seed)
        let riskLevels: [RiskLevel] = [.low, .medium, .high]
        
        var warnings: [String] = []
        let warningCount = random.nextInt(bound: 3)
        for i in 0..<warningCount {
            warnings.append("Warning_\(i)")
        }
        
        return RiskAssessment(
            overallRisk: riskLevels[random.nextInt(bound: riskLevels.count)],
            permissionOk: random.nextBool(),
            destinationSignalQuality: generateSignalQuality(seed: seed + 1),
            routeSignalQuality: generateSignalQuality(seed: seed + 2),
            historicalSuccessRate: random.nextDouble(min: 0, max: 100),
            warnings: warnings,
            suggestEarlyTrigger: random.nextBool(),
            suggestBackupAlarm: random.nextBool()
        )
    }
}

// MARK: - Seeded Random Generator

/// 可重复的随机数生成器
class SeededRandom {
    private var state: UInt64
    
    init(seed: Int) {
        self.state = UInt64(bitPattern: Int64(seed))
        if self.state == 0 { self.state = 1 }
    }
    
    func nextUInt64() -> UInt64 {
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 0x2545F4914F6CDD1D
    }
    
    func nextInt(bound: Int) -> Int {
        guard bound > 0 else { return 0 }
        return Int(nextUInt64() % UInt64(bound))
    }
    
    func nextInt(min: Int, max: Int) -> Int {
        guard max > min else { return min }
        return min + nextInt(bound: max - min + 1)
    }
    
    func nextDouble(min: Double, max: Double) -> Double {
        let fraction = Double(nextUInt64()) / Double(UInt64.max)
        return min + fraction * (max - min)
    }
    
    func nextBool() -> Bool {
        return nextInt(bound: 2) == 1
    }
}
