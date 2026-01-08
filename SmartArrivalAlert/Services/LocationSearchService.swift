import Foundation
import MapKit

/// 地点搜索服务 - 优化版本，避免 actor 开销
final class LocationSearchService: @unchecked Sendable {
    
    // MARK: - Constants
    
    /// 搜索防抖间隔（秒）
    static let debounceInterval: TimeInterval = 0.3
    
    // MARK: - Properties
    
    private var searchTask: Task<[Location], Never>?
    private let lock = NSLock()
    
    // MARK: - Public Methods
    
    /// 搜索地点（带防抖）
    /// - Parameter query: 搜索关键词
    /// - Returns: 搜索结果
    @MainActor
    func search(query: String) async -> [Location] {
        // 取消之前的搜索任务
        searchTask?.cancel()
        
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }
        
        // 创建新的搜索任务
        let task = Task<[Location], Never> {
            // 防抖延迟
            do {
                try await Task.sleep(for: .milliseconds(300))
            } catch {
                return []
            }
            
            // 检查是否被取消
            if Task.isCancelled { return [] }
            
            return await performSearch(query: query)
        }
        
        searchTask = task
        return await task.value
    }
    
    /// 执行实际搜索
    private func performSearch(query: String) async -> [Location] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = [.address, .pointOfInterest]
        
        let search = MKLocalSearch(request: request)
        
        do {
            let response = try await search.start()
            return response.mapItems.prefix(10).compactMap { item -> Location? in
                guard let name = item.name else { return nil }
                
                let address = [
                    item.placemark.thoroughfare,
                    item.placemark.subThoroughfare,
                    item.placemark.locality
                ].compactMap { $0 }.joined(separator: " ")
                
                return Location(
                    id: UUID().uuidString,
                    name: name,
                    address: address.isEmpty ? "未知地址" : address,
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude,
                    isFavorite: false
                )
            }
        } catch {
            return []
        }
    }
}

// MARK: - Shared Instance

extension LocationSearchService {
    static let shared = LocationSearchService()
}
