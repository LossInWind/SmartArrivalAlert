import Foundation
import CoreLocation

/// 地理计算工具
enum GeoUtils {
    
    // MARK: - Constants
    
    /// 地球半径（米）
    static let earthRadius: Double = 6371000.0
    
    /// 默认围栏半径（米）
    static let defaultGeofenceRadius: Double = 200.0
    
    /// 最小围栏半径（米）
    static let minGeofenceRadius: Double = 100.0
    
    /// 最大围栏半径（米）
    static let maxGeofenceRadius: Double = 1000.0
    
    // MARK: - Distance Calculation
    
    /// 计算两点之间的距离（米）
    /// 使用 Haversine 公式
    /// - Parameters:
    ///   - lat1: 第一个点的纬度
    ///   - lon1: 第一个点的经度
    ///   - lat2: 第二个点的纬度
    ///   - lon2: 第二个点的经度
    /// - Returns: 两点之间的距离（米）
    static func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let lat1Rad = lat1 * .pi / 180
        let lat2Rad = lat2 * .pi / 180
        let deltaLat = (lat2 - lat1) * .pi / 180
        let deltaLon = (lon2 - lon1) * .pi / 180
        
        let a = sin(deltaLat / 2) * sin(deltaLat / 2) +
                cos(lat1Rad) * cos(lat2Rad) *
                sin(deltaLon / 2) * sin(deltaLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))
        
        return earthRadius * c
    }
    
    /// 计算两个位置之间的距离（米）
    /// - Parameters:
    ///   - from: 起点位置
    ///   - to: 终点位置
    /// - Returns: 两点之间的距离（米）
    static func calculateDistance(from: Location, to: Location) -> Double {
        return calculateDistance(
            lat1: from.latitude, lon1: from.longitude,
            lat2: to.latitude, lon2: to.longitude
        )
    }
    
    /// 计算 CLLocationCoordinate2D 之间的距离（米）
    /// - Parameters:
    ///   - from: 起点坐标
    ///   - to: 终点坐标
    /// - Returns: 两点之间的距离（米）
    static func calculateDistance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        return calculateDistance(
            lat1: from.latitude, lon1: from.longitude,
            lat2: to.latitude, lon2: to.longitude
        )
    }
    
    // MARK: - Geofence Detection
    
    /// 判断是否进入围栏
    /// - Parameters:
    ///   - currentLat: 当前纬度
    ///   - currentLon: 当前经度
    ///   - centerLat: 围栏中心纬度
    ///   - centerLon: 围栏中心经度
    ///   - radius: 围栏半径（米）
    /// - Returns: 是否在围栏内
    static func isInsideGeofence(
        currentLat: Double, currentLon: Double,
        centerLat: Double, centerLon: Double,
        radius: Double
    ) -> Bool {
        let distance = calculateDistance(
            lat1: currentLat, lon1: currentLon,
            lat2: centerLat, lon2: centerLon
        )
        return distance <= radius
    }
    
    /// 判断是否进入围栏
    /// - Parameters:
    ///   - currentLocation: 当前位置
    ///   - center: 围栏中心
    ///   - radius: 围栏半径（米）
    /// - Returns: 是否在围栏内
    static func isInsideGeofence(
        currentLocation: CLLocationCoordinate2D,
        center: CLLocationCoordinate2D,
        radius: Double
    ) -> Bool {
        return isInsideGeofence(
            currentLat: currentLocation.latitude, currentLon: currentLocation.longitude,
            centerLat: center.latitude, centerLon: center.longitude,
            radius: radius
        )
    }
    
    /// 判断是否进入围栏
    /// - Parameters:
    ///   - currentLocation: 当前位置
    ///   - destination: 目的地
    ///   - radius: 围栏半径（米）
    /// - Returns: 是否在围栏内
    static func isInsideGeofence(
        currentLocation: CLLocationCoordinate2D,
        destination: Location,
        radius: Double
    ) -> Bool {
        return isInsideGeofence(
            currentLat: currentLocation.latitude, currentLon: currentLocation.longitude,
            centerLat: destination.latitude, centerLon: destination.longitude,
            radius: radius
        )
    }
    
    // MARK: - Geofence Radius Validation
    
    /// 验证围栏半径是否在有效范围内
    /// - Parameter radius: 围栏半径（米）
    /// - Returns: 是否有效
    static func isValidGeofenceRadius(_ radius: Double) -> Bool {
        return radius >= minGeofenceRadius && radius <= maxGeofenceRadius
    }
    
    /// 将围栏半径限制在有效范围内
    /// - Parameter radius: 原始半径
    /// - Returns: 限制后的半径
    static func clampGeofenceRadius(_ radius: Double) -> Double {
        return min(max(radius, minGeofenceRadius), maxGeofenceRadius)
    }
    
    // MARK: - Geofence Entry Detection
    
    /// 检测围栏进入事件
    /// - Parameters:
    ///   - previousLocation: 上一个位置
    ///   - currentLocation: 当前位置
    ///   - center: 围栏中心
    ///   - radius: 围栏半径
    /// - Returns: 是否刚刚进入围栏
    static func didEnterGeofence(
        previousLocation: CLLocationCoordinate2D,
        currentLocation: CLLocationCoordinate2D,
        center: CLLocationCoordinate2D,
        radius: Double
    ) -> Bool {
        let wasInside = isInsideGeofence(currentLocation: previousLocation, center: center, radius: radius)
        let isInside = isInsideGeofence(currentLocation: currentLocation, center: center, radius: radius)
        
        return !wasInside && isInside
    }
    
    /// 检测围栏退出事件
    /// - Parameters:
    ///   - previousLocation: 上一个位置
    ///   - currentLocation: 当前位置
    ///   - center: 围栏中心
    ///   - radius: 围栏半径
    /// - Returns: 是否刚刚退出围栏
    static func didExitGeofence(
        previousLocation: CLLocationCoordinate2D,
        currentLocation: CLLocationCoordinate2D,
        center: CLLocationCoordinate2D,
        radius: Double
    ) -> Bool {
        let wasInside = isInsideGeofence(currentLocation: previousLocation, center: center, radius: radius)
        let isInside = isInsideGeofence(currentLocation: currentLocation, center: center, radius: radius)
        
        return wasInside && !isInside
    }
    
    // MARK: - Bearing Calculation
    
    /// 计算从一点到另一点的方位角（度）
    /// - Parameters:
    ///   - from: 起点坐标
    ///   - to: 终点坐标
    /// - Returns: 方位角（0-360度，北为0）
    static func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let deltaLon = (to.longitude - from.longitude) * .pi / 180
        
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        
        var bearing = atan2(y, x) * 180 / .pi
        bearing = (bearing + 360).truncatingRemainder(dividingBy: 360)
        
        return bearing
    }
    
    // MARK: - Location Hash
    
    /// 计算位置哈希（用于空间索引）
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    ///   - precision: 精度（小数位数）
    /// - Returns: 位置哈希字符串
    static func calculateLocationHash(latitude: Double, longitude: Double, precision: Int = 3) -> String {
        let factor = pow(10.0, Double(precision))
        let latHash = Int(latitude * factor)
        let lonHash = Int(longitude * factor)
        return "\(latHash)_\(lonHash)"
    }
    
    // MARK: - Coordinate Validation
    
    /// 验证坐标是否有效
    /// - Parameters:
    ///   - latitude: 纬度
    ///   - longitude: 经度
    /// - Returns: 是否有效
    static func isValidCoordinate(latitude: Double, longitude: Double) -> Bool {
        return latitude >= -90 && latitude <= 90 &&
               longitude >= -180 && longitude <= 180
    }
    
    /// 验证坐标是否有效
    /// - Parameter coordinate: 坐标
    /// - Returns: 是否有效
    static func isValidCoordinate(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return isValidCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}
