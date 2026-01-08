import Foundation

/// 行程仓库协议
protocol TripRepositoryProtocol {
    func getAllTrips() async -> [TripRecord]
    func getTrips(forDestinationId destinationId: String) async -> [TripRecord]
    func addTrip(_ trip: TripRecord) async throws
    func updateTrip(_ trip: TripRecord) async throws
    func deleteTrip(tripId: String) async throws
    func cleanupOldTrips() async throws
}

/// 行程仓库 - 管理行程记录
actor TripRepository: TripRepositoryProtocol {
    
    // MARK: - Constants
    
    /// 行程记录保留天数
    static let retentionDays = 30
    
    // MARK: - Properties
    
    private let storage: LocalStorageAdapter
    
    /// 内存缓存
    private var tripsCache: [TripRecord]?
    
    // MARK: - Initialization
    
    init(storage: LocalStorageAdapter = .shared) {
        self.storage = storage
    }
    
    // MARK: - Public Methods
    
    /// 获取所有行程记录
    /// - Returns: 所有行程记录，按开始时间倒序排列
    func getAllTrips() async -> [TripRecord] {
        // 优先使用缓存
        if let cached = tripsCache {
            return cached
        }
        
        // 从存储加载
        let trips: [TripRecord] = await storage.loadWithGracefulDegradation(forKey: StorageKeys.trips) ?? []
        tripsCache = trips
        return trips
    }
    
    /// 获取指定目的地的行程记录
    /// - Parameter destinationId: 目的地 ID
    /// - Returns: 该目的地的所有行程记录
    func getTrips(forDestinationId destinationId: String) async -> [TripRecord] {
        let allTrips = await getAllTrips()
        return allTrips.filter { $0.destinationId == destinationId }
    }
    
    /// 获取指定目的地附近的行程记录（基于经纬度）
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    ///   - radiusMeters: 搜索半径（米）
    /// - Returns: 该区域的所有行程记录
    func getTrips(nearLatitude latitude: Double, longitude: Double, radiusMeters: Double = 500) async -> [TripRecord] {
        let allTrips = await getAllTrips()
        return allTrips.filter { trip in
            let distance = GeoUtils.calculateDistance(
                lat1: latitude, lon1: longitude,
                lat2: trip.destination.latitude, lon2: trip.destination.longitude
            )
            return distance <= radiusMeters
        }
    }
    
    /// 添加行程记录
    /// - Parameter trip: 要添加的行程记录
    func addTrip(_ trip: TripRecord) async throws {
        var trips = await getAllTrips()
        trips.insert(trip, at: 0) // 新记录放在最前面
        
        try await storage.save(trips, forKey: StorageKeys.trips)
        tripsCache = trips
    }
    
    /// 更新行程记录
    /// - Parameter trip: 更新后的行程记录
    func updateTrip(_ trip: TripRecord) async throws {
        var trips = await getAllTrips()
        
        if let index = trips.firstIndex(where: { $0.id == trip.id }) {
            trips[index] = trip
            try await storage.save(trips, forKey: StorageKeys.trips)
            tripsCache = trips
        }
    }
    
    /// 删除行程记录
    /// - Parameter tripId: 要删除的行程 ID
    func deleteTrip(tripId: String) async throws {
        var trips = await getAllTrips()
        trips.removeAll { $0.id == tripId }
        
        try await storage.save(trips, forKey: StorageKeys.trips)
        tripsCache = trips
    }
    
    /// 清理超过保留期限的旧行程记录
    /// - Note: 保留最近 30 天的记录
    func cleanupOldTrips() async throws {
        var trips = await getAllTrips()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -Self.retentionDays, to: Date()) ?? Date()
        
        let originalCount = trips.count
        trips = trips.filter { $0.startTime >= cutoffDate }
        
        // 只有在有变化时才保存
        if trips.count != originalCount {
            try await storage.save(trips, forKey: StorageKeys.trips)
            tripsCache = trips
        }
    }
    
    /// 获取有用户反馈的行程记录
    /// - Returns: 有反馈的行程记录
    func getTripsWithFeedback() async -> [TripRecord] {
        let allTrips = await getAllTrips()
        return allTrips.filter { $0.userFeedback != nil }
    }
    
    /// 获取指定目的地有用户反馈的行程记录
    /// - Parameter destinationId: 目的地 ID
    /// - Returns: 该目的地有反馈的行程记录
    func getTripsWithFeedback(forDestinationId destinationId: String) async -> [TripRecord] {
        let trips = await getTrips(forDestinationId: destinationId)
        return trips.filter { $0.userFeedback != nil }
    }
    
    /// 记录用户反馈
    /// - Parameters:
    ///   - tripId: 行程 ID
    ///   - feedback: 用户反馈
    func recordFeedback(tripId: String, feedback: UserFeedback) async throws {
        var trips = await getAllTrips()
        
        if let index = trips.firstIndex(where: { $0.id == tripId }) {
            trips[index].userFeedback = feedback
            trips[index].endTime = Date()
            
            try await storage.save(trips, forKey: StorageKeys.trips)
            tripsCache = trips
        }
    }
    
    /// 获取当前活跃的行程（未结束的行程）
    /// - Returns: 当前活跃的行程，如果没有则返回 nil
    func getActiveTrip() async -> TripRecord? {
        let allTrips = await getAllTrips()
        return allTrips.first { $0.endTime == nil }
    }
    
    /// 结束当前行程
    /// - Parameter tripId: 行程 ID
    func endTrip(tripId: String) async throws {
        var trips = await getAllTrips()
        
        if let index = trips.firstIndex(where: { $0.id == tripId }) {
            trips[index].endTime = Date()
            
            try await storage.save(trips, forKey: StorageKeys.trips)
            tripsCache = trips
        }
    }
    
    // MARK: - Cache Management
    
    /// 清除缓存
    func clearCache() {
        tripsCache = nil
    }
    
    /// 刷新缓存
    func refreshCache() async {
        clearCache()
        _ = await getAllTrips()
    }
    
    // MARK: - Statistics
    
    /// 获取行程统计信息
    /// - Returns: 统计信息
    func getStatistics() async -> TripStatistics {
        let allTrips = await getAllTrips()
        let tripsWithFeedback = allTrips.filter { $0.userFeedback != nil }
        
        let successCount = tripsWithFeedback.filter { $0.userFeedback == .success }.count
        let missedCount = tripsWithFeedback.filter { $0.userFeedback == .missed }.count
        let lateCount = tripsWithFeedback.filter { $0.userFeedback == .late }.count
        
        return TripStatistics(
            totalTrips: allTrips.count,
            tripsWithFeedback: tripsWithFeedback.count,
            successCount: successCount,
            missedCount: missedCount,
            lateCount: lateCount
        )
    }
}

// MARK: - Trip Statistics

/// 行程统计信息
struct TripStatistics {
    let totalTrips: Int
    let tripsWithFeedback: Int
    let successCount: Int
    let missedCount: Int
    let lateCount: Int
    
    var successRate: Double {
        guard tripsWithFeedback > 0 else { return 100.0 }
        return Double(successCount) / Double(tripsWithFeedback) * 100.0
    }
}

// MARK: - Shared Instance

extension TripRepository {
    /// 共享实例
    static let shared = TripRepository()
}
