import Foundation

/// 地点仓库协议
protocol LocationRepositoryProtocol {
    func getRecentLocations() async -> [Location]
    func addRecentLocation(_ location: Location) async throws
    func getFavoriteLocations() async -> [Location]
    func addFavorite(_ location: Location) async throws
    func removeFavorite(locationId: String) async throws
    func updateLocation(_ location: Location) async throws
}

/// 地点仓库 - 管理最近地点和收藏地点
actor LocationRepository: LocationRepositoryProtocol {
    
    // MARK: - Constants
    
    /// 最近地点最大数量
    static let maxRecentLocations = 10
    
    // MARK: - Properties
    
    private let storage: LocalStorageAdapter
    
    /// 内存缓存 - 最近地点
    private var recentLocationsCache: [Location]?
    
    /// 内存缓存 - 收藏地点
    private var favoriteLocationsCache: [Location]?
    
    // MARK: - Initialization
    
    init(storage: LocalStorageAdapter = .shared) {
        self.storage = storage
    }
    
    // MARK: - Recent Locations
    
    /// 获取最近地点（最多10个）
    /// - Returns: 最近访问的地点列表，按访问时间倒序排列
    func getRecentLocations() async -> [Location] {
        // 优先使用缓存
        if let cached = recentLocationsCache {
            return cached
        }
        
        // 从存储加载
        let locations: [Location] = await storage.loadWithGracefulDegradation(forKey: StorageKeys.recentLocations) ?? []
        recentLocationsCache = locations
        return locations
    }
    
    /// 添加到最近地点
    /// - Parameter location: 要添加的地点
    /// - Note: 如果地点已存在，会更新其访问时间并移到列表顶部
    /// - Note: 列表最多保留10个地点，超出时移除最旧的
    func addRecentLocation(_ location: Location) async throws {
        var locations = await getRecentLocations()
        
        // 更新地点的访问时间
        var updatedLocation = location
        updatedLocation.lastVisited = Date()
        
        // 如果地点已存在，先移除旧的
        locations.removeAll { $0.id == location.id }
        
        // 添加到列表开头
        locations.insert(updatedLocation, at: 0)
        
        // 保持列表不超过最大数量
        if locations.count > Self.maxRecentLocations {
            locations = Array(locations.prefix(Self.maxRecentLocations))
        }
        
        // 保存并更新缓存
        try await storage.save(locations, forKey: StorageKeys.recentLocations)
        recentLocationsCache = locations
    }
    
    /// 从最近地点中移除
    /// - Parameter locationId: 要移除的地点 ID
    func removeRecentLocation(locationId: String) async throws {
        var locations = await getRecentLocations()
        locations.removeAll { $0.id == locationId }
        
        try await storage.save(locations, forKey: StorageKeys.recentLocations)
        recentLocationsCache = locations
    }
    
    /// 批量删除最近地点
    /// - Parameter locationIds: 要删除的地点 ID 列表
    func removeRecentLocations(locationIds: Set<String>) async throws {
        var locations = await getRecentLocations()
        locations.removeAll { locationIds.contains($0.id) }
        
        try await storage.save(locations, forKey: StorageKeys.recentLocations)
        recentLocationsCache = locations
    }
    
    /// 重新排序最近地点
    /// - Parameter locations: 排序后的地点列表
    func reorderRecentLocations(_ locations: [Location]) async throws {
        try await storage.save(locations, forKey: StorageKeys.recentLocations)
        recentLocationsCache = locations
    }
    
    // MARK: - Favorite Locations
    
    /// 获取收藏地点
    /// - Returns: 收藏的地点列表
    func getFavoriteLocations() async -> [Location] {
        // 优先使用缓存
        if let cached = favoriteLocationsCache {
            return cached
        }
        
        // 从存储加载
        let locations: [Location] = await storage.loadWithGracefulDegradation(forKey: StorageKeys.favoriteLocations) ?? []
        favoriteLocationsCache = locations
        return locations
    }
    
    /// 添加收藏
    /// - Parameter location: 要收藏的地点
    func addFavorite(_ location: Location) async throws {
        var locations = await getFavoriteLocations()
        
        // 如果已经收藏，不重复添加
        guard !locations.contains(where: { $0.id == location.id }) else {
            return
        }
        
        // 标记为收藏
        var favoriteLocation = location
        favoriteLocation.isFavorite = true
        
        locations.append(favoriteLocation)
        
        // 保存并更新缓存
        try await storage.save(locations, forKey: StorageKeys.favoriteLocations)
        favoriteLocationsCache = locations
        
        // 同时更新最近地点中的收藏状态
        await updateFavoriteStatusInRecentLocations(locationId: location.id, isFavorite: true)
    }
    
    /// 移除收藏
    /// - Parameter locationId: 要移除收藏的地点 ID
    func removeFavorite(locationId: String) async throws {
        var locations = await getFavoriteLocations()
        locations.removeAll { $0.id == locationId }
        
        try await storage.save(locations, forKey: StorageKeys.favoriteLocations)
        favoriteLocationsCache = locations
        
        // 同时更新最近地点中的收藏状态
        await updateFavoriteStatusInRecentLocations(locationId: locationId, isFavorite: false)
    }
    
    /// 批量移除收藏
    /// - Parameter locationIds: 要移除收藏的地点 ID 列表
    func removeFavorites(locationIds: Set<String>) async throws {
        var locations = await getFavoriteLocations()
        locations.removeAll { locationIds.contains($0.id) }
        
        try await storage.save(locations, forKey: StorageKeys.favoriteLocations)
        favoriteLocationsCache = locations
        
        // 同时更新最近地点中的收藏状态
        for locationId in locationIds {
            await updateFavoriteStatusInRecentLocations(locationId: locationId, isFavorite: false)
        }
    }
    
    /// 重新排序收藏地点
    /// - Parameter locations: 排序后的地点列表
    func reorderFavoriteLocations(_ locations: [Location]) async throws {
        try await storage.save(locations, forKey: StorageKeys.favoriteLocations)
        favoriteLocationsCache = locations
    }
    
    /// 检查地点是否已收藏
    /// - Parameter locationId: 地点 ID
    /// - Returns: 是否已收藏
    func isFavorite(locationId: String) async -> Bool {
        let favorites = await getFavoriteLocations()
        return favorites.contains { $0.id == locationId }
    }
    
    // MARK: - Update Location
    
    /// 更新地点信息
    /// - Parameter location: 更新后的地点
    func updateLocation(_ location: Location) async throws {
        // 更新最近地点
        var recentLocations = await getRecentLocations()
        if let index = recentLocations.firstIndex(where: { $0.id == location.id }) {
            recentLocations[index] = location
            try await storage.save(recentLocations, forKey: StorageKeys.recentLocations)
            recentLocationsCache = recentLocations
        }
        
        // 更新收藏地点
        var favoriteLocations = await getFavoriteLocations()
        if let index = favoriteLocations.firstIndex(where: { $0.id == location.id }) {
            favoriteLocations[index] = location
            try await storage.save(favoriteLocations, forKey: StorageKeys.favoriteLocations)
            favoriteLocationsCache = favoriteLocations
        }
    }
    
    /// 根据 ID 获取地点
    /// - Parameter locationId: 地点 ID
    /// - Returns: 地点，如果不存在则返回 nil
    func getLocation(byId locationId: String) async -> Location? {
        // 先从收藏中查找
        let favorites = await getFavoriteLocations()
        if let location = favorites.first(where: { $0.id == locationId }) {
            return location
        }
        
        // 再从最近地点中查找
        let recent = await getRecentLocations()
        return recent.first { $0.id == locationId }
    }
    
    // MARK: - Cache Management
    
    /// 清除缓存
    func clearCache() {
        recentLocationsCache = nil
        favoriteLocationsCache = nil
    }
    
    /// 刷新缓存
    func refreshCache() async {
        clearCache()
        _ = await getRecentLocations()
        _ = await getFavoriteLocations()
    }
    
    // MARK: - Private Methods
    
    /// 更新最近地点中的收藏状态
    private func updateFavoriteStatusInRecentLocations(locationId: String, isFavorite: Bool) async {
        var locations = await getRecentLocations()
        if let index = locations.firstIndex(where: { $0.id == locationId }) {
            locations[index].isFavorite = isFavorite
            try? await storage.save(locations, forKey: StorageKeys.recentLocations)
            recentLocationsCache = locations
        }
    }
}

// MARK: - Shared Instance

extension LocationRepository {
    /// 共享实例
    static let shared = LocationRepository()
}
