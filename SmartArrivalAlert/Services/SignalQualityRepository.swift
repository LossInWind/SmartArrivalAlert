import Foundation

/// 信号质量仓库协议
protocol SignalQualityRepositoryProtocol {
    func getSignalQuality(latitude: Double, longitude: Double) async -> SignalQuality
    func recordSignalSample(_ sample: SignalSample) async throws
    func getSignalDataNearLocation(latitude: Double, longitude: Double, radiusMeters: Double) async -> [LocationSignalData]
}

/// 信号质量仓库 - 管理位置信号质量数据
actor SignalQualityRepository: SignalQualityRepositoryProtocol {
    
    // MARK: - Constants
    
    /// 位置哈希精度（小数位数，3位约等于100米）
    static let hashPrecision = 3
    
    /// 每个位置最多保留的样本数
    static let maxSamplesPerLocation = 100
    
    /// 信号数据过期天数
    static let dataExpirationDays = 90
    
    // MARK: - Properties
    
    private let storage: LocalStorageAdapter
    
    /// 内存缓存
    private var signalDataCache: [LocationSignalData]?
    
    /// 空间索引缓存 (locationHash -> index in array)
    private var spatialIndex: [String: Int] = [:]
    
    // MARK: - Initialization
    
    init(storage: LocalStorageAdapter = .shared) {
        self.storage = storage
    }
    
    // MARK: - Public Methods
    
    /// 获取指定位置的信号质量
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    /// - Returns: 信号质量，如果没有数据则返回 unknown
    func getSignalQuality(latitude: Double, longitude: Double) async -> SignalQuality {
        let signalDataList = await getAllSignalData()
        let locationHash = Self.calculateLocationHash(latitude: latitude, longitude: longitude)
        
        // 使用空间索引快速查找
        if let index = spatialIndex[locationHash], index < signalDataList.count {
            let signalData = signalDataList[index]
            return SignalQuality(
                level: signalData.qualityLevel,
                averageAccuracy: signalData.averageAccuracy,
                sampleCount: signalData.samples.count
            )
        }
        
        // 线性查找（备用）
        if let signalData = signalDataList.first(where: { $0.locationHash == locationHash }) {
            return SignalQuality(
                level: signalData.qualityLevel,
                averageAccuracy: signalData.averageAccuracy,
                sampleCount: signalData.samples.count
            )
        }
        
        return .unknown
    }
    
    /// 记录信号样本
    /// - Parameter sample: 信号样本
    func recordSignalSample(_ sample: SignalSample) async throws {
        var signalDataList = await getAllSignalData()
        let locationHash = Self.calculateLocationHash(latitude: sample.latitude, longitude: sample.longitude)
        
        if let index = signalDataList.firstIndex(where: { $0.locationHash == locationHash }) {
            // 更新现有数据
            signalDataList[index].samples.append(sample)
            
            // 限制样本数量
            if signalDataList[index].samples.count > Self.maxSamplesPerLocation {
                signalDataList[index].samples = Array(signalDataList[index].samples.suffix(Self.maxSamplesPerLocation))
            }
            
            // 重新计算统计数据
            signalDataList[index] = recalculateStatistics(for: signalDataList[index])
        } else {
            // 创建新的位置信号数据
            let newSignalData = LocationSignalData(
                locationHash: locationHash,
                centerLatitude: sample.latitude,
                centerLongitude: sample.longitude,
                samples: [sample],
                averageAccuracy: sample.accuracy,
                qualityLevel: Self.determineQualityLevel(accuracy: sample.accuracy),
                lastUpdated: Date()
            )
            signalDataList.append(newSignalData)
        }
        
        // 保存并更新缓存
        try await storage.save(signalDataList, forKey: StorageKeys.signalData)
        signalDataCache = signalDataList
        rebuildSpatialIndex(from: signalDataList)
    }
    
    /// 批量记录信号样本
    /// - Parameter samples: 信号样本数组
    func recordSignalSamples(_ samples: [SignalSample]) async throws {
        guard !samples.isEmpty else { return }
        
        var signalDataList = await getAllSignalData()
        
        for sample in samples {
            let locationHash = Self.calculateLocationHash(latitude: sample.latitude, longitude: sample.longitude)
            
            if let index = signalDataList.firstIndex(where: { $0.locationHash == locationHash }) {
                signalDataList[index].samples.append(sample)
                
                if signalDataList[index].samples.count > Self.maxSamplesPerLocation {
                    signalDataList[index].samples = Array(signalDataList[index].samples.suffix(Self.maxSamplesPerLocation))
                }
                
                signalDataList[index] = recalculateStatistics(for: signalDataList[index])
            } else {
                let newSignalData = LocationSignalData(
                    locationHash: locationHash,
                    centerLatitude: sample.latitude,
                    centerLongitude: sample.longitude,
                    samples: [sample],
                    averageAccuracy: sample.accuracy,
                    qualityLevel: Self.determineQualityLevel(accuracy: sample.accuracy),
                    lastUpdated: Date()
                )
                signalDataList.append(newSignalData)
            }
        }
        
        try await storage.save(signalDataList, forKey: StorageKeys.signalData)
        signalDataCache = signalDataList
        rebuildSpatialIndex(from: signalDataList)
    }
    
    /// 获取指定位置附近的信号数据
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    ///   - radiusMeters: 搜索半径（米）
    /// - Returns: 附近的信号数据
    func getSignalDataNearLocation(latitude: Double, longitude: Double, radiusMeters: Double = 500) async -> [LocationSignalData] {
        let signalDataList = await getAllSignalData()
        
        return signalDataList.filter { signalData in
            let distance = GeoUtils.calculateDistance(
                lat1: latitude, lon1: longitude,
                lat2: signalData.centerLatitude, lon2: signalData.centerLongitude
            )
            return distance <= radiusMeters
        }
    }
    
    /// 获取路线沿途的信号质量
    /// - Parameter waypoints: 路线途经点
    /// - Returns: 沿途的信号质量
    func getRouteSignalQuality(waypoints: [(latitude: Double, longitude: Double)]) async -> SignalQuality {
        guard !waypoints.isEmpty else { return .unknown }
        
        var allSamples: [SignalSample] = []
        
        for waypoint in waypoints {
            let nearbyData = await getSignalDataNearLocation(
                latitude: waypoint.latitude,
                longitude: waypoint.longitude,
                radiusMeters: 200
            )
            
            for data in nearbyData {
                allSamples.append(contentsOf: data.samples)
            }
        }
        
        return Self.evaluateSignalQuality(from: allSamples)
    }
    
    /// 清理过期的信号数据
    func cleanupExpiredData() async throws {
        var signalDataList = await getAllSignalData()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -Self.dataExpirationDays, to: Date()) ?? Date()
        
        let originalCount = signalDataList.count
        signalDataList = signalDataList.filter { $0.lastUpdated >= cutoffDate }
        
        if signalDataList.count != originalCount {
            try await storage.save(signalDataList, forKey: StorageKeys.signalData)
            signalDataCache = signalDataList
            rebuildSpatialIndex(from: signalDataList)
        }
    }
    
    // MARK: - Cache Management
    
    /// 清除缓存
    func clearCache() {
        signalDataCache = nil
        spatialIndex.removeAll()
    }
    
    /// 刷新缓存
    func refreshCache() async {
        clearCache()
        _ = await getAllSignalData()
    }
    
    /// 获取缓存统计信息
    func getCacheStats() -> (entryCount: Int, estimatedSize: Int) {
        let count = signalDataCache?.count ?? 0
        // 粗略估算：每个 LocationSignalData 约 1KB
        let estimatedSize = count * 1024
        return (count, estimatedSize)
    }
    
    // MARK: - Private Methods
    
    /// 获取所有信号数据
    private func getAllSignalData() async -> [LocationSignalData] {
        if let cached = signalDataCache {
            return cached
        }
        
        let signalDataList: [LocationSignalData] = await storage.loadWithGracefulDegradation(forKey: StorageKeys.signalData) ?? []
        signalDataCache = signalDataList
        rebuildSpatialIndex(from: signalDataList)
        return signalDataList
    }
    
    /// 重建空间索引
    private func rebuildSpatialIndex(from signalDataList: [LocationSignalData]) {
        spatialIndex.removeAll()
        for (index, data) in signalDataList.enumerated() {
            spatialIndex[data.locationHash] = index
        }
    }
    
    /// 重新计算统计数据
    private func recalculateStatistics(for signalData: LocationSignalData) -> LocationSignalData {
        var updated = signalData
        
        if signalData.samples.isEmpty {
            updated.averageAccuracy = 0
            updated.qualityLevel = .unknown
        } else {
            let avgAccuracy = signalData.samples.reduce(0.0) { $0 + $1.accuracy } / Double(signalData.samples.count)
            updated.averageAccuracy = avgAccuracy
            updated.qualityLevel = Self.determineQualityLevel(accuracy: avgAccuracy)
        }
        
        updated.lastUpdated = Date()
        return updated
    }
    
    // MARK: - Static Methods
    
    /// 计算位置哈希
    static func calculateLocationHash(latitude: Double, longitude: Double) -> String {
        let multiplier = pow(10.0, Double(hashPrecision))
        let roundedLat = (latitude * multiplier).rounded() / multiplier
        let roundedLng = (longitude * multiplier).rounded() / multiplier
        return "\(roundedLat),\(roundedLng)"
    }
    
    /// 根据精度确定信号质量等级
    static func determineQualityLevel(accuracy: Double) -> SignalQualityLevel {
        if accuracy <= 20 {
            return .good
        } else if accuracy <= 50 {
            return .fair
        } else {
            return .poor
        }
    }
    
    /// 从样本评估信号质量
    static func evaluateSignalQuality(from samples: [SignalSample]) -> SignalQuality {
        guard !samples.isEmpty else {
            return .unknown
        }
        
        let avgAccuracy = samples.reduce(0.0) { $0 + $1.accuracy } / Double(samples.count)
        let level = determineQualityLevel(accuracy: avgAccuracy)
        
        return SignalQuality(
            level: level,
            averageAccuracy: avgAccuracy,
            sampleCount: samples.count
        )
    }
}

// MARK: - Shared Instance

extension SignalQualityRepository {
    /// 共享实例
    static let shared = SignalQualityRepository()
}
