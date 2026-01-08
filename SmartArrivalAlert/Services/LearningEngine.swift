import Foundation

/// 学习引擎协议
protocol LearningEngineProtocol {
    func recordTripResult(_ trip: TripRecord) async throws
    func calculateReliabilityScore(forDestinationId destinationId: String) async -> Double
    func isHighRiskRoute(destinationId: String) async -> Bool
    func recordSignalQuality(location: Location, quality: SignalQuality) async throws
    func getHistoricalAverageSpeed(forDestinationId destinationId: String, transportMode: TransportMode) async -> Double?
    func recordTripSpeed(destinationId: String, averageSpeed: Double, transportMode: TransportMode) async throws
}

/// 学习引擎 - 从历史数据中学习和计算可靠性
actor LearningEngine: LearningEngineProtocol {
    
    // MARK: - Constants
    
    /// 高风险阈值（低于此值视为高风险）
    static let highRiskThreshold: Double = 70.0
    
    /// 中风险阈值
    static let mediumRiskThreshold: Double = 85.0
    
    /// 计算可靠性时考虑的最近行程数量
    static let recentTripsCount = 10
    
    // MARK: - Properties
    
    private let tripRepository: TripRepository
    private let storage: LocalStorageAdapter
    
    /// 可靠性评分缓存 (destinationId -> score)
    private var reliabilityCache: [String: Double] = [:]
    
    /// 缓存过期时间（秒）
    private let cacheExpirationSeconds: TimeInterval = 300 // 5分钟
    
    /// 缓存时间戳
    private var cacheTimestamp: Date = .distantPast
    
    // MARK: - Initialization
    
    init(tripRepository: TripRepository = .shared, storage: LocalStorageAdapter = .shared) {
        self.tripRepository = tripRepository
        self.storage = storage
    }
    
    // MARK: - Public Methods
    
    /// 记录行程结果
    /// - Parameter trip: 行程记录
    func recordTripResult(_ trip: TripRecord) async throws {
        try await tripRepository.addTrip(trip)
        
        // 清除该目的地的缓存
        reliabilityCache.removeValue(forKey: trip.destinationId)
    }
    
    /// 记录用户反馈
    /// - Parameters:
    ///   - tripId: 行程 ID
    ///   - feedback: 用户反馈
    func recordUserFeedback(tripId: String, feedback: UserFeedback) async throws {
        try await tripRepository.recordFeedback(tripId: tripId, feedback: feedback)
        
        // 获取行程以清除对应目的地的缓存
        let trips = await tripRepository.getAllTrips()
        if let trip = trips.first(where: { $0.id == tripId }) {
            reliabilityCache.removeValue(forKey: trip.destinationId)
        }
    }
    
    /// 计算指定目的地的可靠性评分
    /// - Parameter destinationId: 目的地 ID
    /// - Returns: 可靠性评分 (0-100)
    func calculateReliabilityScore(forDestinationId destinationId: String) async -> Double {
        // 检查缓存
        if isCacheValid(), let cachedScore = reliabilityCache[destinationId] {
            return cachedScore
        }
        
        // 获取该目的地有反馈的行程
        let tripsWithFeedback = await tripRepository.getTripsWithFeedback(forDestinationId: destinationId)
        
        // 计算评分
        let score = Self.calculateReliabilityScore(from: tripsWithFeedback)
        
        // 更新缓存
        reliabilityCache[destinationId] = score
        cacheTimestamp = Date()
        
        return score
    }
    
    /// 计算指定位置附近的可靠性评分
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    /// - Returns: 可靠性评分 (0-100)
    func calculateReliabilityScore(nearLatitude latitude: Double, longitude: Double) async -> Double {
        let nearbyTrips = await tripRepository.getTrips(nearLatitude: latitude, longitude: longitude)
        let tripsWithFeedback = nearbyTrips.filter { $0.userFeedback != nil }
        return Self.calculateReliabilityScore(from: tripsWithFeedback)
    }
    
    /// 判断是否为高风险路线
    /// - Parameter destinationId: 目的地 ID
    /// - Returns: 是否为高风险
    func isHighRiskRoute(destinationId: String) async -> Bool {
        let score = await calculateReliabilityScore(forDestinationId: destinationId)
        return score < Self.highRiskThreshold
    }
    
    /// 判断是否为中风险路线
    /// - Parameter destinationId: 目的地 ID
    /// - Returns: 是否为中风险
    func isMediumRiskRoute(destinationId: String) async -> Bool {
        let score = await calculateReliabilityScore(forDestinationId: destinationId)
        return score >= Self.highRiskThreshold && score < Self.mediumRiskThreshold
    }
    
    /// 记录信号质量数据
    /// - Parameters:
    ///   - location: 位置
    ///   - quality: 信号质量
    func recordSignalQuality(location: Location, quality: SignalQuality) async throws {
        // 加载现有信号数据
        var signalDataList: [LocationSignalData] = await storage.loadWithGracefulDegradation(forKey: StorageKeys.signalData) ?? []
        
        // 计算位置哈希
        let locationHash = Self.calculateLocationHash(latitude: location.latitude, longitude: location.longitude)
        
        // 创建信号样本
        let sample = SignalSample(
            latitude: location.latitude,
            longitude: location.longitude,
            accuracy: quality.averageAccuracy,
            timestamp: Date()
        )
        
        // 查找或创建位置信号数据
        if let index = signalDataList.firstIndex(where: { $0.locationHash == locationHash }) {
            // 更新现有数据
            signalDataList[index].samples.append(sample)
            
            // 只保留最近的样本（最多100个）
            if signalDataList[index].samples.count > 100 {
                signalDataList[index].samples = Array(signalDataList[index].samples.suffix(100))
            }
            
            // 重新计算平均精度和质量等级
            let avgAccuracy = signalDataList[index].samples.reduce(0.0) { $0 + $1.accuracy } / Double(signalDataList[index].samples.count)
            signalDataList[index].averageAccuracy = avgAccuracy
            signalDataList[index].qualityLevel = Self.determineQualityLevel(accuracy: avgAccuracy)
            signalDataList[index].lastUpdated = Date()
        } else {
            // 创建新的位置信号数据
            let newSignalData = LocationSignalData(
                locationHash: locationHash,
                centerLatitude: location.latitude,
                centerLongitude: location.longitude,
                samples: [sample],
                averageAccuracy: quality.averageAccuracy,
                qualityLevel: Self.determineQualityLevel(accuracy: quality.averageAccuracy),
                lastUpdated: Date()
            )
            signalDataList.append(newSignalData)
        }
        
        // 保存
        try await storage.save(signalDataList, forKey: StorageKeys.signalData)
    }
    
    /// 获取指定位置的信号质量
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    /// - Returns: 信号质量，如果没有数据则返回 unknown
    func getSignalQuality(latitude: Double, longitude: Double) async -> SignalQuality {
        let signalDataList: [LocationSignalData] = await storage.loadWithGracefulDegradation(forKey: StorageKeys.signalData) ?? []
        
        let locationHash = Self.calculateLocationHash(latitude: latitude, longitude: longitude)
        
        if let signalData = signalDataList.first(where: { $0.locationHash == locationHash }) {
            return SignalQuality(
                level: signalData.qualityLevel,
                averageAccuracy: signalData.averageAccuracy,
                sampleCount: signalData.samples.count
            )
        }
        
        return .unknown
    }
    
    // MARK: - Historical Speed Methods
    
    /// 获取目的地的历史平均速度
    /// - Parameters:
    ///   - destinationId: 目的地 ID
    ///   - transportMode: 交通方式
    /// - Returns: 历史平均速度（米/秒），如果没有数据则返回 nil
    func getHistoricalAverageSpeed(forDestinationId destinationId: String, transportMode: TransportMode) async -> Double? {
        let speedRecords: [TripSpeedRecord] = await storage.loadWithGracefulDegradation(forKey: StorageKeys.tripSpeedRecords) ?? []
        
        // 筛选匹配的记录
        let matchingRecords = speedRecords.filter {
            $0.destinationId == destinationId && $0.transportMode == transportMode
        }
        
        guard !matchingRecords.isEmpty else { return nil }
        
        // 只取最近 10 条记录
        let recentRecords = Array(matchingRecords.suffix(Self.recentTripsCount))
        
        // 计算平均速度
        let totalSpeed = recentRecords.reduce(0.0) { $0 + $1.averageSpeed }
        return totalSpeed / Double(recentRecords.count)
    }
    
    /// 记录行程速度数据
    /// - Parameters:
    ///   - destinationId: 目的地 ID
    ///   - averageSpeed: 平均速度（米/秒）
    ///   - transportMode: 交通方式
    func recordTripSpeed(destinationId: String, averageSpeed: Double, transportMode: TransportMode) async throws {
        // 忽略无效速度
        guard averageSpeed > 0 else { return }
        
        var speedRecords: [TripSpeedRecord] = await storage.loadWithGracefulDegradation(forKey: StorageKeys.tripSpeedRecords) ?? []
        
        let newRecord = TripSpeedRecord(
            destinationId: destinationId,
            transportMode: transportMode,
            averageSpeed: averageSpeed,
            timestamp: Date()
        )
        
        speedRecords.append(newRecord)
        
        // 只保留最近 100 条记录（防止数据膨胀）
        if speedRecords.count > 100 {
            speedRecords = Array(speedRecords.suffix(100))
        }
        
        try await storage.save(speedRecords, forKey: StorageKeys.tripSpeedRecords)
    }
    
    // MARK: - Cache Management
    
    /// 清除缓存
    func clearCache() {
        reliabilityCache.removeAll()
        cacheTimestamp = .distantPast
    }
    
    // MARK: - Static Methods
    
    /// 计算可靠性评分
    /// - Parameter trips: 有反馈的行程记录
    /// - Returns: 可靠性评分 (0-100)
    static func calculateReliabilityScore(from trips: [TripRecord]) -> Double {
        // 无历史数据，默认可靠
        guard !trips.isEmpty else { return 100.0 }
        
        // 只看最近的行程
        let recentTrips = Array(trips.prefix(recentTripsCount))
        
        // 计算成功次数
        let successCount = recentTrips.filter { $0.userFeedback == .success }.count
        
        // 计算评分
        return Double(successCount) / Double(recentTrips.count) * 100.0
    }
    
    /// 计算位置哈希（用于信号数据聚合）
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    ///   - precision: 精度（小数位数，默认3位约等于100米）
    /// - Returns: 位置哈希字符串
    static func calculateLocationHash(latitude: Double, longitude: Double, precision: Int = 3) -> String {
        let multiplier = pow(10.0, Double(precision))
        let roundedLat = (latitude * multiplier).rounded() / multiplier
        let roundedLng = (longitude * multiplier).rounded() / multiplier
        return "\(roundedLat),\(roundedLng)"
    }
    
    /// 根据精度确定信号质量等级
    /// - Parameter accuracy: 精度（米）
    /// - Returns: 信号质量等级
    static func determineQualityLevel(accuracy: Double) -> SignalQualityLevel {
        if accuracy <= 20 {
            return .good
        } else if accuracy <= 50 {
            return .fair
        } else {
            return .poor
        }
    }
    
    // MARK: - Private Methods
    
    /// 检查缓存是否有效
    private func isCacheValid() -> Bool {
        return Date().timeIntervalSince(cacheTimestamp) < cacheExpirationSeconds
    }
}

// MARK: - Shared Instance

extension LearningEngine {
    /// 共享实例
    static let shared = LearningEngine()
}
