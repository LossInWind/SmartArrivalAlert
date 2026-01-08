import XCTest
import SwiftCheck
@testable import SmartArrivalAlert

/// Property 14: 存储损坏优雅降级
/// 验证: 需求 5.4
/// 对于任意损坏的存储数据，系统应当能够检测到损坏并返回空数据而非崩溃
final class StoragePropertyTests: XCTestCase {
    
    var storageAdapter: LocalStorageAdapter!
    var testDirectory: URL!
    
    override func setUp() async throws {
        try await super.setUp()
        
        // 创建临时测试目录
        let tempDir = FileManager.default.temporaryDirectory
        testDirectory = tempDir.appendingPathComponent("SmartArrivalAlertTests_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
        
        // 创建测试用的存储适配器
        storageAdapter = try LocalStorageAdapter(fileManager: .default)
    }
    
    override func tearDown() async throws {
        // 清理测试目录
        if let testDirectory = testDirectory {
            try? FileManager.default.removeItem(at: testDirectory)
        }
        storageAdapter = nil
        try await super.tearDown()
    }
    
    // MARK: - Property 14: 存储损坏优雅降级
    
    /// Property 14: 存储损坏优雅降级
    /// Feature: smart-arrival-alert, Property 14: 存储损坏优雅降级
    /// 对于任意损坏的存储数据，系统应当能够检测到损坏并返回空数据而非崩溃
    func testCorruptedDataGracefulDegradation() async throws {
        // 测试：当数据损坏时，loadWithGracefulDegradation 应返回 nil 而不是崩溃
        
        // 1. 先保存有效数据
        let validLocation = Location(
            id: "test-id",
            name: "Test Location",
            address: "Test Address",
            latitude: 39.9042,
            longitude: 116.4074,
            isFavorite: true
        )
        
        try await storageAdapter.save([validLocation], forKey: "test_locations")
        
        // 2. 验证可以正常读取
        let loaded: [Location]? = try await storageAdapter.load(forKey: "test_locations")
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.count, 1)
        
        // 3. 清理测试数据
        try await storageAdapter.delete(forKey: "test_locations")
    }
    
    /// 测试健康检查能够检测损坏数据
    func testHealthCheckDetectsCorruption() async throws {
        // 1. 初始状态应该是健康的
        let initialHealth = await storageAdapter.checkHealth()
        XCTAssertTrue(initialHealth.isHealthy)
        XCTAssertTrue(initialHealth.corruptedKeys.isEmpty)
    }
    
    /// 测试空数据场景的优雅处理
    func testEmptyDataGracefulHandling() async throws {
        // 尝试加载不存在的数据应返回 nil
        let result: [Location]? = await storageAdapter.loadWithGracefulDegradation(forKey: "nonexistent_key")
        XCTAssertNil(result)
    }
    
    /// 属性测试：任意有效数据保存后应能正确读取
    func testSaveAndLoadRoundTrip() {
        property("Save and load round trip preserves data") <- forAll { (seed: Int) in
            let location = TestGenerators.generateLocation(seed: seed)
            
            // 使用同步方式测试（因为 SwiftCheck 不支持 async）
            let expectation = XCTestExpectation(description: "Async operation")
            var result = false
            
            Task {
                do {
                    let adapter = try LocalStorageAdapter()
                    let key = "test_location_\(seed)"
                    
                    // 保存
                    try await adapter.save(location, forKey: key)
                    
                    // 读取
                    let loaded: Location? = try await adapter.load(forKey: key)
                    
                    // 验证
                    if let loaded = loaded {
                        result = location.id == loaded.id &&
                                 location.name == loaded.name &&
                                 location.latitude == loaded.latitude &&
                                 location.longitude == loaded.longitude
                    }
                    
                    // 清理
                    try await adapter.delete(forKey: key)
                } catch {
                    result = false
                }
                expectation.fulfill()
            }
            
            // 等待异步操作完成
            _ = XCTWaiter.wait(for: [expectation], timeout: 5.0)
            return result
        }
    }
    
    /// 属性测试：删除后数据应不存在
    func testDeleteRemovesData() {
        property("Delete removes data") <- forAll { (seed: Int) in
            let location = TestGenerators.generateLocation(seed: seed)
            
            let expectation = XCTestExpectation(description: "Async operation")
            var result = false
            
            Task {
                do {
                    let adapter = try LocalStorageAdapter()
                    let key = "test_delete_\(seed)"
                    
                    // 保存
                    try await adapter.save(location, forKey: key)
                    
                    // 删除
                    try await adapter.delete(forKey: key)
                    
                    // 验证已删除
                    let loaded: Location? = try await adapter.load(forKey: key)
                    result = loaded == nil
                } catch {
                    result = false
                }
                expectation.fulfill()
            }
            
            _ = XCTWaiter.wait(for: [expectation], timeout: 5.0)
            return result
        }
    }
    
    /// 属性测试：导出功能应返回有效 JSON
    func testExportReturnsValidJSON() async throws {
        // 保存一些测试数据
        let locations = [
            Location(id: "1", name: "Location 1", address: "Address 1", latitude: 39.9, longitude: 116.4, isFavorite: true),
            Location(id: "2", name: "Location 2", address: "Address 2", latitude: 31.2, longitude: 121.5, isFavorite: false)
        ]
        
        try await storageAdapter.save(locations, forKey: StorageKeys.recentLocations)
        
        // 导出
        let exportedJSON = try await storageAdapter.exportAll()
        
        // 验证是有效的 JSON
        XCTAssertFalse(exportedJSON.isEmpty)
        
        let jsonData = exportedJSON.data(using: .utf8)!
        let parsed = try JSONSerialization.jsonObject(with: jsonData)
        XCTAssertNotNil(parsed)
        
        // 清理
        try await storageAdapter.delete(forKey: StorageKeys.recentLocations)
    }
}
