import Foundation

/// 信号质量等级
enum SignalQualityLevel: String, Codable, Equatable {
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case unknown = "unknown"
}

/// 信号质量
struct SignalQuality: Codable, Equatable {
    let level: SignalQualityLevel
    let averageAccuracy: Double  // 米
    let sampleCount: Int
    
    init(level: SignalQualityLevel, averageAccuracy: Double, sampleCount: Int) {
        self.level = level
        self.averageAccuracy = averageAccuracy
        self.sampleCount = sampleCount
    }
    
    /// 未知信号质量
    static let unknown = SignalQuality(level: .unknown, averageAccuracy: 0, sampleCount: 0)
}

/// 信号质量样本
struct SignalSample: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let timestamp: Date
    
    init(latitude: Double, longitude: Double, accuracy: Double, timestamp: Date = Date()) {
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.timestamp = timestamp
    }
}

/// 位置信号质量聚合数据
struct LocationSignalData: Codable, Equatable, Identifiable {
    var id: String { locationHash }
    
    let locationHash: String
    let centerLatitude: Double
    let centerLongitude: Double
    var samples: [SignalSample]
    var averageAccuracy: Double
    var qualityLevel: SignalQualityLevel
    var lastUpdated: Date
    
    init(
        locationHash: String,
        centerLatitude: Double,
        centerLongitude: Double,
        samples: [SignalSample] = [],
        averageAccuracy: Double = 0,
        qualityLevel: SignalQualityLevel = .unknown,
        lastUpdated: Date = Date()
    ) {
        self.locationHash = locationHash
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.samples = samples
        self.averageAccuracy = averageAccuracy
        self.qualityLevel = qualityLevel
        self.lastUpdated = lastUpdated
    }
}
