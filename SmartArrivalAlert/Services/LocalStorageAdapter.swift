import Foundation

/// 存储健康状态
struct StorageHealth: Codable, Equatable {
    let isHealthy: Bool
    let usedSpace: Int64
    let availableSpace: Int64
    let corruptedKeys: [String]
    
    init(isHealthy: Bool, usedSpace: Int64 = 0, availableSpace: Int64 = 0, corruptedKeys: [String] = []) {
        self.isHealthy = isHealthy
        self.usedSpace = usedSpace
        self.availableSpace = availableSpace
        self.corruptedKeys = corruptedKeys
    }
    
    static let healthy = StorageHealth(isHealthy: true)
    static let unhealthy = StorageHealth(isHealthy: false)
}

/// 存储错误类型
enum StorageError: Error, Equatable {
    case encodingFailed
    case decodingFailed
    case writeFailed(String)
    case readFailed(String)
    case deleteFailed(String)
    case directoryCreationFailed
    case corruptedData
    case insufficientSpace
}

/// 本地存储适配器协议
protocol LocalStorageAdapterProtocol {
    func save<T: Encodable>(_ data: T, forKey key: String) async throws
    func load<T: Decodable>(forKey key: String) async throws -> T?
    func delete(forKey key: String) async throws
    func exportAll() async throws -> String
    func checkHealth() async -> StorageHealth
}

/// 本地存储适配器 - 使用 FileManager 存储 JSON 数据
/// 优化：使用内存缓存减少磁盘 I/O，带有大小限制
actor LocalStorageAdapter: LocalStorageAdapterProtocol {
    
    // MARK: - Constants
    
    /// 缓存最大条目数
    private static let maxCacheEntries = 10
    
    /// 缓存最大总大小（字节）- 5MB
    private static let maxCacheSize = 5 * 1024 * 1024
    
    // MARK: - Properties
    
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let storageDirectory: URL
    
    /// 内存缓存（带 LRU 淘汰）
    private var cache: [String: Data] = [:]
    
    /// 缓存访问顺序（用于 LRU）
    private var cacheAccessOrder: [String] = []
    
    /// 当前缓存大小
    private var currentCacheSize: Int = 0
    
    /// 所有已知的存储键
    private let knownKeys: [String] = [
        StorageKeys.recentLocations,
        StorageKeys.favoriteLocations,
        StorageKeys.trips,
        StorageKeys.signalData,
        StorageKeys.settings
    ]
    
    // MARK: - Initialization
    
    init(fileManager: FileManager = .default) throws {
        self.fileManager = fileManager
        
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
        
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        
        // 获取应用文档目录
        guard let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw StorageError.directoryCreationFailed
        }
        
        self.storageDirectory = documentsDirectory.appendingPathComponent("SmartArrivalAlert", isDirectory: true)
        
        // 创建存储目录（如果不存在）
        if !fileManager.fileExists(atPath: storageDirectory.path) {
            try fileManager.createDirectory(at: storageDirectory, withIntermediateDirectories: true)
        }
    }
    
    // MARK: - Public Methods
    
    /// 保存数据到本地存储
    /// - Parameters:
    ///   - data: 要保存的数据
    ///   - key: 存储键
    func save<T: Encodable>(_ data: T, forKey key: String) async throws {
        let fileURL = fileURL(forKey: key)
        
        do {
            let jsonData = try encoder.encode(data)
            // 更新缓存（带大小限制）
            updateCache(key: key, data: jsonData)
            // 异步写入磁盘
            try jsonData.write(to: fileURL, options: [.atomic])
        } catch _ as EncodingError {
            throw StorageError.encodingFailed
        } catch {
            throw StorageError.writeFailed(error.localizedDescription)
        }
    }
    
    /// 从本地存储加载数据
    /// - Parameter key: 存储键
    /// - Returns: 解码后的数据，如果不存在则返回 nil
    func load<T: Decodable>(forKey key: String) async throws -> T? {
        // 优先从缓存读取
        if let cachedData = cache[key] {
            // 更新访问顺序
            touchCache(key: key)
            do {
                return try decoder.decode(T.self, from: cachedData)
            } catch {
                // 缓存数据损坏，清除并从磁盘读取
                removeFromCache(key: key)
            }
        }
        
        let fileURL = fileURL(forKey: key)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let jsonData = try Data(contentsOf: fileURL)
            // 更新缓存（带大小限制）
            updateCache(key: key, data: jsonData)
            let decoded = try decoder.decode(T.self, from: jsonData)
            return decoded
        } catch is DecodingError {
            throw StorageError.corruptedData
        } catch {
            throw StorageError.readFailed(error.localizedDescription)
        }
    }
    
    /// 从本地存储加载数据，如果损坏则返回 nil（优雅降级）
    /// - Parameter key: 存储键
    /// - Returns: 解码后的数据，如果不存在或损坏则返回 nil
    func loadWithGracefulDegradation<T: Decodable>(forKey key: String) async -> T? {
        do {
            return try await load(forKey: key)
        } catch {
            // 优雅降级：返回 nil 而不是抛出错误
            return nil
        }
    }
    
    /// 删除本地存储中的数据
    /// - Parameter key: 存储键
    func delete(forKey key: String) async throws {
        // 清除内存缓存
        removeFromCache(key: key)
        
        let fileURL = fileURL(forKey: key)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return // 文件不存在，无需删除
        }
        
        do {
            try fileManager.removeItem(at: fileURL)
        } catch {
            throw StorageError.deleteFailed(error.localizedDescription)
        }
    }
    
    /// 导出所有用户数据为 JSON 字符串
    /// - Returns: 包含所有数据的 JSON 字符串
    func exportAll() async throws -> String {
        var exportData: [String: Any] = [:]
        exportData["exportDate"] = ISO8601DateFormatter().string(from: Date())
        exportData["version"] = "1.0"
        
        var dataSection: [String: Any] = [:]
        
        for key in knownKeys {
            let fileURL = fileURL(forKey: key)
            if fileManager.fileExists(atPath: fileURL.path) {
                do {
                    let jsonData = try Data(contentsOf: fileURL)
                    let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
                    dataSection[key] = jsonObject
                } catch {
                    // 跳过损坏的数据
                    continue
                }
            }
        }
        
        exportData["data"] = dataSection
        
        let exportJsonData = try JSONSerialization.data(withJSONObject: exportData, options: [.prettyPrinted, .sortedKeys])
        
        guard let jsonString = String(data: exportJsonData, encoding: .utf8) else {
            throw StorageError.encodingFailed
        }
        
        return jsonString
    }
    
    /// 检查存储健康状态
    /// - Returns: 存储健康状态
    func checkHealth() async -> StorageHealth {
        var corruptedKeys: [String] = []
        
        // 检查每个已知键的数据完整性
        for key in knownKeys {
            let fileURL = fileURL(forKey: key)
            if fileManager.fileExists(atPath: fileURL.path) {
                do {
                    let jsonData = try Data(contentsOf: fileURL)
                    // 尝试解析 JSON 以验证数据完整性
                    _ = try JSONSerialization.jsonObject(with: jsonData)
                } catch {
                    corruptedKeys.append(key)
                }
            }
        }
        
        // 获取存储空间信息
        var usedSpace: Int64 = 0
        var availableSpace: Int64 = 0
        
        do {
            let resourceValues = try storageDirectory.resourceValues(forKeys: [.volumeAvailableCapacityKey])
            availableSpace = Int64(resourceValues.volumeAvailableCapacity ?? 0)
            
            // 计算已使用空间
            let contents = try fileManager.contentsOfDirectory(at: storageDirectory, includingPropertiesForKeys: [.fileSizeKey])
            for fileURL in contents {
                let fileResourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                usedSpace += Int64(fileResourceValues.fileSize ?? 0)
            }
        } catch {
            // 无法获取空间信息，但不影响健康状态判断
        }
        
        let isHealthy = corruptedKeys.isEmpty
        
        return StorageHealth(
            isHealthy: isHealthy,
            usedSpace: usedSpace,
            availableSpace: availableSpace,
            corruptedKeys: corruptedKeys
        )
    }
    
    /// 清除所有数据（用于测试或重置）
    func clearAll() async throws {
        for key in knownKeys {
            try await delete(forKey: key)
        }
    }
    
    /// 检查指定键的数据是否存在
    /// - Parameter key: 存储键
    /// - Returns: 是否存在
    func exists(forKey key: String) -> Bool {
        let fileURL = fileURL(forKey: key)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    // MARK: - Private Methods
    
    /// 获取指定键对应的文件 URL
    private func fileURL(forKey key: String) -> URL {
        return storageDirectory.appendingPathComponent("\(key).json")
    }
    
    // MARK: - Cache Management
    
    /// 更新缓存（带 LRU 淘汰和大小限制）
    private func updateCache(key: String, data: Data) {
        let dataSize = data.count
        
        // 如果单个数据超过最大缓存大小，不缓存
        guard dataSize <= Self.maxCacheSize else { return }
        
        // 移除旧数据（如果存在）
        if let oldData = cache[key] {
            currentCacheSize -= oldData.count
            cacheAccessOrder.removeAll { $0 == key }
        }
        
        // 淘汰旧数据直到有足够空间
        while (currentCacheSize + dataSize > Self.maxCacheSize || cache.count >= Self.maxCacheEntries) && !cacheAccessOrder.isEmpty {
            let oldestKey = cacheAccessOrder.removeFirst()
            if let removedData = cache.removeValue(forKey: oldestKey) {
                currentCacheSize -= removedData.count
            }
        }
        
        // 添加新数据
        cache[key] = data
        cacheAccessOrder.append(key)
        currentCacheSize += dataSize
    }
    
    /// 更新缓存访问顺序（LRU）
    private func touchCache(key: String) {
        cacheAccessOrder.removeAll { $0 == key }
        cacheAccessOrder.append(key)
    }
    
    /// 从缓存中移除
    private func removeFromCache(key: String) {
        if let data = cache.removeValue(forKey: key) {
            currentCacheSize -= data.count
        }
        cacheAccessOrder.removeAll { $0 == key }
    }
    
    /// 清除所有缓存
    func clearCache() {
        cache.removeAll()
        cacheAccessOrder.removeAll()
        currentCacheSize = 0
    }
}

// MARK: - Shared Instance

extension LocalStorageAdapter {
    /// 共享实例
    static let shared: LocalStorageAdapter = {
        do {
            return try LocalStorageAdapter()
        } catch {
            fatalError("Failed to initialize LocalStorageAdapter: \(error)")
        }
    }()
}
