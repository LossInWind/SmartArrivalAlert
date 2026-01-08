import XCTest
import SwiftCheck
@testable import SmartArrivalAlert

/// Property 1: 最近地点列表长度不变量
/// Property 2: 收藏地点往返一致性
/// 验证: 需求 1.3, 1.4
final class LocationRepositoryPropertyTests: XCTestCase {
    
    var repository: LocationRepository!
    var storage: LocalStorageAdapter!
    
    override func setUp() async throws {
        try await super.setUp()
        storage = try LocalStorageAdapter()
        repository = LocationRepository(storage: storage)
        
        // 清理测试数据
        try await storage.delete(forKey: StorageKeys.recentLocations)
        try await storage.delete(forKey: StorageKeys.favoriteLocations)
    }
    
    override func tearDown() async throws {
        // 清理测试数据
        try? await storage.delete(forKey: StorageKeys.recentLocations)
        try? await storage.delete(forKey: StorageKeys.favoriteLocations)
        repository = nil
        storage = nil
        try await super.tearDown()
    }
    
    // MARK: - Property 1: 最近地点列表长度不变量
    
    /// Property 1: 最近地点列表长度不变量
    /// Feature: smart-arrival-alert, Property 1: 最近地点列表长度不变量
    /// 对于任意数量的地点访问操作，最近地点列表的长度应当始终不超过 10
    func testRecentLocationsListLengthInvariant() async throws {
        // 添加超过 10 个地点
        for i in 0..<15 {
            let location = Location(
                id: "location_\(i)",
                name: "Location \(i)",
                address: "Address \(i)",
                latitude: Double(i),
                longitude: Double(i),
                isFavorite: false
            )
            try await repository.addRecentLocation(location)
            
            // 每次添加后验证列表长度不超过 10
            let recentLocations = await repository.getRecentLocations()
            XCTAssertLessThanOrEqual(recentLocations.count, LocationRepository.maxRecentLocations,
                                     "最近地点列表长度应不超过 \(LocationRepository.maxRecentLocations)")
        }
        
        // 最终验证
        let finalLocations = await repository.getRecentLocations()
        XCTAssertEqual(finalLocations.count, LocationRepository.maxRecentLocations)
    }
    
    /// 属性测试：任意数量的添加操作后，列表长度不超过 10
    func testRecentLocationsLengthInvariantProperty() {
        property("Recent locations list length never exceeds 10") <- forAll { (count: UInt) in
            let addCount = Int(count % 20) + 1 // 1-20 次添加
            
            let expectation = XCTestExpectation(description: "Async operation")
            var result = false
            
            Task {
                do {
                    let storage = try LocalStorageAdapter()
                    let repo = LocationRepository(storage: storage)
                    
                    // 清理
                    try await storage.delete(forKey: StorageKeys.recentLocations)
                    
                    // 添加多个地点
                    for i in 0..<addCount {
                        let location = Location(
                            id: UUID().uuidString,
                            name: "Location \(i)",
                            address: "Address \(i)",
                            latitude: Double(i),
                            longitude: Double(i),
                            isFavorite: false
                        )
                        try await repo.addRecentLocation(location)
                    }
                    
                    // 验证长度不超过 10
                    let locations = await repo.getRecentLocations()
                    result = locations.count <= LocationRepository.maxRecentLocations
                    
                    // 清理
                    try await storage.delete(forKey: StorageKeys.recentLocations)
                } catch {
                    result = false
                }
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: 10.0)
            return result
        }
    }
    
    // MARK: - Property 2: 收藏地点往返一致性
    
    /// Property 2: 收藏地点往返一致性
    /// Feature: smart-arrival-alert, Property 2: 收藏地点往返一致性
    /// 对于任意有效的地点，添加到收藏后查询收藏列表应当包含该地点；从收藏中删除后查询应当不包含该地点
    func testFavoriteLocationsRoundTripConsistency() async throws {
        let location = Location(
            id: "test_favorite",
            name: "Test Favorite",
            address: "Test Address",
            latitude: 39.9042,
            longitude: 116.4074,
            isFavorite: false
        )
        
        // 1. 添加到收藏
        try await repository.addFavorite(location)
        
        // 2. 验证收藏列表包含该地点
        var favorites = await repository.getFavoriteLocations()
        XCTAssertTrue(favorites.contains { $0.id == location.id }, "添加后收藏列表应包含该地点")
        
        // 3. 从收藏中删除
        try await repository.removeFavorite(locationId: location.id)
        
        // 4. 验证收藏列表不包含该地点
        favorites = await repository.getFavoriteLocations()
        XCTAssertFalse(favorites.contains { $0.id == location.id }, "删除后收藏列表应不包含该地点")
    }
    
    /// 属性测试：收藏往返一致性
    func testFavoriteRoundTripProperty() {
        property("Favorite add then remove is consistent") <- forAll { (seed: Int) in
            let location = TestGenerators.generateLocation(seed: seed)
            
            let expectation = XCTestExpectation(description: "Async operation")
            var result = false
            
            Task {
                do {
                    let storage = try LocalStorageAdapter()
                    let repo = LocationRepository(storage: storage)
                    
                    // 清理
                    try await storage.delete(forKey: StorageKeys.favoriteLocations)
                    
                    // 添加到收藏
                    try await repo.addFavorite(location)
                    
                    // 验证包含
                    var favorites = await repo.getFavoriteLocations()
                    let containsAfterAdd = favorites.contains { $0.id == location.id }
                    
                    // 从收藏中删除
                    try await repo.removeFavorite(locationId: location.id)
                    
                    // 验证不包含
                    favorites = await repo.getFavoriteLocations()
                    let containsAfterRemove = favorites.contains { $0.id == location.id }
                    
                    result = containsAfterAdd && !containsAfterRemove
                    
                    // 清理
                    try await storage.delete(forKey: StorageKeys.favoriteLocations)
                } catch {
                    result = false
                }
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: 10.0)
            return result
        }
    }
    
    /// 测试：重复添加同一地点到收藏不会产生重复
    func testNoDuplicateFavorites() async throws {
        let location = Location(
            id: "duplicate_test",
            name: "Duplicate Test",
            address: "Test Address",
            latitude: 39.9042,
            longitude: 116.4074,
            isFavorite: false
        )
        
        // 添加两次
        try await repository.addFavorite(location)
        try await repository.addFavorite(location)
        
        // 验证只有一个
        let favorites = await repository.getFavoriteLocations()
        let count = favorites.filter { $0.id == location.id }.count
        XCTAssertEqual(count, 1, "收藏列表中不应有重复地点")
    }
    
    /// 测试：添加到最近地点会更新访问时间
    func testAddRecentLocationUpdatesVisitTime() async throws {
        let location = Location(
            id: "visit_time_test",
            name: "Visit Time Test",
            address: "Test Address",
            latitude: 39.9042,
            longitude: 116.4074,
            lastVisited: nil,
            isFavorite: false
        )
        
        try await repository.addRecentLocation(location)
        
        let recentLocations = await repository.getRecentLocations()
        let savedLocation = recentLocations.first { $0.id == location.id }
        
        XCTAssertNotNil(savedLocation?.lastVisited, "添加到最近地点后应设置访问时间")
    }
    
    /// 测试：最近地点按访问时间倒序排列
    func testRecentLocationsOrderedByVisitTime() async throws {
        // 添加三个地点，间隔一小段时间
        for i in 0..<3 {
            let location = Location(
                id: "order_test_\(i)",
                name: "Order Test \(i)",
                address: "Address \(i)",
                latitude: Double(i),
                longitude: Double(i),
                isFavorite: false
            )
            try await repository.addRecentLocation(location)
            
            // 短暂延迟以确保时间戳不同
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        let recentLocations = await repository.getRecentLocations()
        
        // 最后添加的应该在最前面
        XCTAssertEqual(recentLocations.first?.id, "order_test_2")
    }
    
    /// 测试：收藏状态同步到最近地点
    func testFavoriteStatusSyncToRecentLocations() async throws {
        let location = Location(
            id: "sync_test",
            name: "Sync Test",
            address: "Test Address",
            latitude: 39.9042,
            longitude: 116.4074,
            isFavorite: false
        )
        
        // 先添加到最近地点
        try await repository.addRecentLocation(location)
        
        // 添加到收藏
        try await repository.addFavorite(location)
        
        // 验证最近地点中的收藏状态已更新
        let recentLocations = await repository.getRecentLocations()
        let recentLocation = recentLocations.first { $0.id == location.id }
        XCTAssertTrue(recentLocation?.isFavorite ?? false, "最近地点中的收藏状态应同步更新")
        
        // 取消收藏
        try await repository.removeFavorite(locationId: location.id)
        
        // 验证最近地点中的收藏状态已更新
        let updatedRecentLocations = await repository.getRecentLocations()
        let updatedRecentLocation = updatedRecentLocations.first { $0.id == location.id }
        XCTAssertFalse(updatedRecentLocation?.isFavorite ?? true, "取消收藏后最近地点中的状态应同步更新")
    }
}
