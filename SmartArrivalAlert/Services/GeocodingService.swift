import Foundation
import CoreLocation

/// 地址解析服务协议
protocol GeocodingServiceProtocol {
    func reverseGeocode(latitude: Double, longitude: Double) async -> String?
    func formatCoordinateName(latitude: Double, longitude: Double) -> String
}

/// 地址解析服务 - 负责坐标与地址的转换
actor GeocodingService: GeocodingServiceProtocol {
    
    // MARK: - Properties
    
    private let geocoder: CLGeocoder
    
    /// 缓存已解析的地址
    private var cache: [String: String] = [:]
    
    // MARK: - Initialization
    
    init() {
        self.geocoder = CLGeocoder()
    }
    
    // MARK: - Public Methods
    
    /// 反向地理编码 - 将坐标转换为地址
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    /// - Returns: 地址字符串，如果失败返回 nil
    func reverseGeocode(latitude: Double, longitude: Double) async -> String? {
        let cacheKey = "\(latitude),\(longitude)"
        
        // 检查缓存
        if let cached = cache[cacheKey] {
            return cached
        }
        
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            
            guard let placemark = placemarks.first else {
                return nil
            }
            
            // 构建地址字符串
            let address = buildAddressString(from: placemark)
            
            // 缓存结果
            cache[cacheKey] = address
            
            return address
        } catch {
            print("反向地理编码失败: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// 格式化坐标名称 - 当地理编码失败时使用
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    /// - Returns: 格式化的坐标字符串
    nonisolated func formatCoordinateName(latitude: Double, longitude: Double) -> String {
        return "选定位置 (\(String(format: "%.4f", latitude)), \(String(format: "%.4f", longitude)))"
    }
    
    /// 获取地址或回退到坐标名称
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    /// - Returns: 地址或坐标名称
    func getAddressOrFallback(latitude: Double, longitude: Double) async -> String {
        if let address = await reverseGeocode(latitude: latitude, longitude: longitude) {
            return address
        }
        return formatCoordinateName(latitude: latitude, longitude: longitude)
    }
    
    /// 从坐标创建 Location 对象
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    /// - Returns: Location 对象
    func createLocation(latitude: Double, longitude: Double) async -> Location {
        let address = await getAddressOrFallback(latitude: latitude, longitude: longitude)
        
        // 尝试获取更友好的名称
        let name: String
        if let geocodedName = await getPlaceName(latitude: latitude, longitude: longitude) {
            name = geocodedName
        } else {
            name = "选定位置"
        }
        
        return Location(
            id: UUID().uuidString,
            name: name,
            address: address,
            latitude: latitude,
            longitude: longitude,
            isFavorite: false
        )
    }
    
    /// 清除缓存
    func clearCache() {
        cache.removeAll()
    }
    
    // MARK: - Private Methods
    
    /// 从 placemark 构建地址字符串
    private func buildAddressString(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        // 街道地址
        if let thoroughfare = placemark.thoroughfare {
            if let subThoroughfare = placemark.subThoroughfare {
                components.append("\(thoroughfare)\(subThoroughfare)号")
            } else {
                components.append(thoroughfare)
            }
        }
        
        // 区/县
        if let subLocality = placemark.subLocality {
            components.append(subLocality)
        }
        
        // 城市
        if let locality = placemark.locality {
            components.append(locality)
        }
        
        // 省/州
        if let administrativeArea = placemark.administrativeArea {
            // 避免重复（有些城市名和省名相同）
            if administrativeArea != placemark.locality {
                components.append(administrativeArea)
            }
        }
        
        // 如果没有任何组件，使用名称
        if components.isEmpty {
            if let name = placemark.name {
                return name
            }
            return "未知地址"
        }
        
        // 反转顺序（从大到小）
        return components.reversed().joined(separator: " ")
    }
    
    /// 获取地点名称
    private func getPlaceName(latitude: Double, longitude: Double) async -> String? {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            
            guard let placemark = placemarks.first else {
                return nil
            }
            
            // 优先使用 POI 名称
            if let name = placemark.name, !name.isEmpty {
                // 过滤掉纯数字地址
                if !name.allSatisfy({ $0.isNumber || $0 == "-" || $0 == "." }) {
                    return name
                }
            }
            
            // 使用街道名
            if let thoroughfare = placemark.thoroughfare {
                return thoroughfare
            }
            
            // 使用区域名
            if let subLocality = placemark.subLocality {
                return subLocality
            }
            
            return nil
        } catch {
            return nil
        }
    }
}

// MARK: - Shared Instance

extension GeocodingService {
    /// 共享实例
    static let shared = GeocodingService()
}
