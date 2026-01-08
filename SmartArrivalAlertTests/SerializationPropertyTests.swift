import XCTest
import SwiftCheck
@testable import SmartArrivalAlert

// MARK: - Arbitrary Conformances

extension SignalQualityLevel: Arbitrary {
    public static var arbitrary: Gen<SignalQualityLevel> {
        Gen.fromElements(of: [.good, .fair, .poor, .unknown])
    }
}

extension SignalQuality: Arbitrary {
    public static var arbitrary: Gen<SignalQuality> {
        Gen<SignalQuality>.compose { c in
            SignalQuality(
                level: c.generate(),
                averageAccuracy: c.generate(using: Double.arbitrary.suchThat { $0 >= 0 && $0 <= 1000 }),
                sampleCount: c.generate(using: Int.arbitrary.suchThat { $0 >= 0 && $0 <= 1000 })
            )
        }
    }
}

extension SignalSample: Arbitrary {
    public static var arbitrary: Gen<SignalSample> {
        Gen<SignalSample>.compose { c in
            SignalSample(
                latitude: c.generate(using: Double.arbitrary.suchThat { $0 >= -90 && $0 <= 90 }),
                longitude: c.generate(using: Double.arbitrary.suchThat { $0 >= -180 && $0 <= 180 }),
                accuracy: c.generate(using: Double.arbitrary.suchThat { $0 >= 0 && $0 <= 1000 }),
                timestamp: Date(timeIntervalSince1970: Double(c.generate(using: UInt32.arbitrary)))
            )
        }
    }
}

extension Location: Arbitrary {
    public static var arbitrary: Gen<Location> {
        Gen<Location>.compose { c in
            let hasLastVisited: Bool = c.generate()
            let hasLastRadius: Bool = c.generate()
            
            return Location(
                id: UUID().uuidString,
                name: c.generate(using: String.arbitrary.suchThat { !$0.isEmpty && $0.count < 100 }),
                address: c.generate(using: String.arbitrary.suchThat { $0.count < 200 }),
                latitude: c.generate(using: Double.arbitrary.suchThat { $0 >= -90 && $0 <= 90 }),
                longitude: c.generate(using: Double.arbitrary.suchThat { $0 >= -180 && $0 <= 180 }),
                lastVisited: hasLastVisited ? Date(timeIntervalSince1970: Double(c.generate(using: UInt32.arbitrary))) : nil,
                isFavorite: c.generate(),
                lastGeofenceRadius: hasLastRadius ? c.generate(using: Int.arbitrary.suchThat { $0 >= 100 && $0 <= 1000 }) : nil
            )
        }
    }
}

extension AlertType: Arbitrary {
    public static var arbitrary: Gen<AlertType> {
        Gen.fromElements(of: [.arrival, .earlyArrival, .backupAlarm])
    }
}

extension UserFeedback: Arbitrary {
    public static var arbitrary: Gen<UserFeedback> {
        Gen.fromElements(of: [.success, .missed, .late])
    }
}

extension TripRecord: Arbitrary {
    public static var arbitrary: Gen<TripRecord> {
        Gen<TripRecord>.compose { c in
            let location: Location = c.generate()
            let hasEndTime: Bool = c.generate()
            let hasAlertType: Bool = c.generate()
            let hasAlertTimestamp: Bool = c.generate()
            let hasFeedback: Bool = c.generate()
            let sampleCount = c.generate(using: Int.arbitrary.suchThat { $0 >= 0 && $0 <= 5 })
            
            var samples: [SignalSample] = []
            for _ in 0..<sampleCount {
                samples.append(c.generate())
            }
            
            return TripRecord(
                id: UUID().uuidString,
                destinationId: location.id,
                destination: location,
                startTime: Date(timeIntervalSince1970: Double(c.generate(using: UInt32.arbitrary))),
                endTime: hasEndTime ? Date(timeIntervalSince1970: Double(c.generate(using: UInt32.arbitrary))) : nil,
                geofenceRadius: c.generate(using: Int.arbitrary.suchThat { $0 >= 100 && $0 <= 1000 }),
                alertTriggered: c.generate(),
                alertType: hasAlertType ? c.generate() : nil,
                alertTimestamp: hasAlertTimestamp ? Date(timeIntervalSince1970: Double(c.generate(using: UInt32.arbitrary))) : nil,
                userFeedback: hasFeedback ? c.generate() : nil,
                signalSamples: samples,
                backupAlarmSet: c.generate(),
                backupAlarmTriggered: c.generate()
            )
        }
    }
}

extension UserSettings: Arbitrary {
    public static var arbitrary: Gen<UserSettings> {
        Gen<UserSettings>.compose { c in
            UserSettings(
                defaultGeofenceRadius: c.generate(using: Int.arbitrary.suchThat { $0 >= 100 && $0 <= 1000 }),
                soundEnabled: c.generate(),
                vibrationEnabled: c.generate(),
                autoBackupAlarm: c.generate()
            )
        }
    }
}

extension RiskLevel: Arbitrary {
    public static var arbitrary: Gen<RiskLevel> {
        Gen.fromElements(of: [.low, .medium, .high])
    }
}

extension RiskAssessment: Arbitrary {
    public static var arbitrary: Gen<RiskAssessment> {
        Gen<RiskAssessment>.compose { c in
            let warningCount = c.generate(using: Int.arbitrary.suchThat { $0 >= 0 && $0 <= 3 })
            var warnings: [String] = []
            for i in 0..<warningCount {
                warnings.append("Warning_\(i)")
            }
            
            return RiskAssessment(
                overallRisk: c.generate(),
                permissionOk: c.generate(),
                destinationSignalQuality: c.generate(),
                routeSignalQuality: c.generate(),
                historicalSuccessRate: c.generate(using: Double.arbitrary.suchThat { $0 >= 0 && $0 <= 100 }),
                warnings: warnings,
                suggestEarlyTrigger: c.generate(),
                suggestBackupAlarm: c.generate()
            )
        }
    }
}

extension LocationSignalData: Arbitrary {
    public static var arbitrary: Gen<LocationSignalData> {
        Gen<LocationSignalData>.compose { c in
            let sampleCount = c.generate(using: Int.arbitrary.suchThat { $0 >= 0 && $0 <= 5 })
            var samples: [SignalSample] = []
            for _ in 0..<sampleCount {
                samples.append(c.generate())
            }
            
            let lat = c.generate(using: Double.arbitrary.suchThat { $0 >= -90 && $0 <= 90 })
            let lng = c.generate(using: Double.arbitrary.suchThat { $0 >= -180 && $0 <= 180 })
            
            return LocationSignalData(
                locationHash: "\(lat),\(lng)",
                centerLatitude: lat,
                centerLongitude: lng,
                samples: samples,
                averageAccuracy: c.generate(using: Double.arbitrary.suchThat { $0 >= 0 && $0 <= 1000 }),
                qualityLevel: c.generate(),
                lastUpdated: Date(timeIntervalSince1970: Double(c.generate(using: UInt32.arbitrary)))
            )
        }
    }
}

extension MonitoringConfig: Arbitrary {
    public static var arbitrary: Gen<MonitoringConfig> {
        Gen<MonitoringConfig>.compose { c in
            let hasEarlyTriggerDistance: Bool = c.generate()
            
            return MonitoringConfig(
                destination: c.generate(),
                geofenceRadius: c.generate(using: Int.arbitrary.suchThat { $0 >= 100 && $0 <= 1000 }),
                enableEarlyTrigger: c.generate(),
                earlyTriggerDistance: hasEarlyTriggerDistance ? c.generate(using: Int.arbitrary.suchThat { $0 >= 100 && $0 <= 500 }) : nil
            )
        }
    }
}

// MARK: - Property Tests

/// Property 13: 行程记录序列化往返一致性
/// 验证: 需求 5.2
/// 对于任意有效的行程记录对象，序列化为 JSON 后再反序列化应当得到等价的对象
final class SerializationPropertyTests: XCTestCase {
    
    /// Property 13: 行程记录序列化往返一致性
    /// Feature: smart-arrival-alert, Property 13: 行程记录序列化往返一致性
    func testTripRecordSerializationRoundTrip() {
        property("TripRecord serialization round trip preserves data") <- forAll { (tripRecord: TripRecord) in
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            guard let data = try? encoder.encode(tripRecord),
                  let decoded = try? decoder.decode(TripRecord.self, from: data) else {
                return false
            }
            
            // 比较关键字段
            return tripRecord.id == decoded.id &&
                   tripRecord.destinationId == decoded.destinationId &&
                   tripRecord.destination.id == decoded.destination.id &&
                   tripRecord.destination.name == decoded.destination.name &&
                   tripRecord.destination.latitude == decoded.destination.latitude &&
                   tripRecord.destination.longitude == decoded.destination.longitude &&
                   tripRecord.geofenceRadius == decoded.geofenceRadius &&
                   tripRecord.alertTriggered == decoded.alertTriggered &&
                   tripRecord.alertType == decoded.alertType &&
                   tripRecord.userFeedback == decoded.userFeedback &&
                   tripRecord.signalSamples.count == decoded.signalSamples.count &&
                   tripRecord.backupAlarmSet == decoded.backupAlarmSet &&
                   tripRecord.backupAlarmTriggered == decoded.backupAlarmTriggered
        }
    }
    
    /// Location 序列化往返一致性
    func testLocationSerializationRoundTrip() {
        property("Location serialization round trip preserves data") <- forAll { (location: Location) in
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            guard let data = try? encoder.encode(location),
                  let decoded = try? decoder.decode(Location.self, from: data) else {
                return false
            }
            
            return location.id == decoded.id &&
                   location.name == decoded.name &&
                   location.address == decoded.address &&
                   location.latitude == decoded.latitude &&
                   location.longitude == decoded.longitude &&
                   location.isFavorite == decoded.isFavorite &&
                   location.lastGeofenceRadius == decoded.lastGeofenceRadius
        }
    }
    
    /// SignalQuality 序列化往返一致性
    func testSignalQualitySerializationRoundTrip() {
        property("SignalQuality serialization round trip preserves data") <- forAll { (signalQuality: SignalQuality) in
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            guard let data = try? encoder.encode(signalQuality),
                  let decoded = try? decoder.decode(SignalQuality.self, from: data) else {
                return false
            }
            
            return signalQuality == decoded
        }
    }
    
    /// SignalSample 序列化往返一致性
    func testSignalSampleSerializationRoundTrip() {
        property("SignalSample serialization round trip preserves data") <- forAll { (sample: SignalSample) in
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            guard let data = try? encoder.encode(sample),
                  let decoded = try? decoder.decode(SignalSample.self, from: data) else {
                return false
            }
            
            return sample.latitude == decoded.latitude &&
                   sample.longitude == decoded.longitude &&
                   sample.accuracy == decoded.accuracy
        }
    }
    
    /// UserSettings 序列化往返一致性
    func testUserSettingsSerializationRoundTrip() {
        property("UserSettings serialization round trip preserves data") <- forAll { (settings: UserSettings) in
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            guard let data = try? encoder.encode(settings),
                  let decoded = try? decoder.decode(UserSettings.self, from: data) else {
                return false
            }
            
            return settings == decoded
        }
    }
    
    /// RiskAssessment 序列化往返一致性
    func testRiskAssessmentSerializationRoundTrip() {
        property("RiskAssessment serialization round trip preserves data") <- forAll { (assessment: RiskAssessment) in
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            guard let data = try? encoder.encode(assessment),
                  let decoded = try? decoder.decode(RiskAssessment.self, from: data) else {
                return false
            }
            
            return assessment == decoded
        }
    }
    
    /// LocationSignalData 序列化往返一致性
    func testLocationSignalDataSerializationRoundTrip() {
        property("LocationSignalData serialization round trip preserves data") <- forAll { (signalData: LocationSignalData) in
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            guard let data = try? encoder.encode(signalData),
                  let decoded = try? decoder.decode(LocationSignalData.self, from: data) else {
                return false
            }
            
            return signalData.locationHash == decoded.locationHash &&
                   signalData.centerLatitude == decoded.centerLatitude &&
                   signalData.centerLongitude == decoded.centerLongitude &&
                   signalData.samples.count == decoded.samples.count &&
                   signalData.averageAccuracy == decoded.averageAccuracy &&
                   signalData.qualityLevel == decoded.qualityLevel
        }
    }
    
    /// MonitoringConfig 序列化往返一致性
    func testMonitoringConfigSerializationRoundTrip() {
        property("MonitoringConfig serialization round trip preserves data") <- forAll { (config: MonitoringConfig) in
            let encoder = JSONEncoder()
            let decoder = JSONDecoder()
            
            guard let data = try? encoder.encode(config),
                  let decoded = try? decoder.decode(MonitoringConfig.self, from: data) else {
                return false
            }
            
            return config.destination.id == decoded.destination.id &&
                   config.geofenceRadius == decoded.geofenceRadius &&
                   config.enableEarlyTrigger == decoded.enableEarlyTrigger &&
                   config.earlyTriggerDistance == decoded.earlyTriggerDistance
        }
    }
}
