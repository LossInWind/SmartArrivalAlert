import Foundation
import MapKit
import CoreLocation

// MARK: - Route Source

/// 路线来源枚举
/// 标识 ETA 数据是来自 MapKit 路线规划还是直线距离计算
enum RouteSource: String, Codable, Equatable {
    case mapKit = "mapkit"      // MapKit 路线规划
    case directLine = "direct"  // 直线距离（飞机模式或备用）
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .mapKit: return "路线规划"
        case .directLine: return "直线距离"
        }
    }
    
    /// 是否可靠
    var isReliable: Bool {
        switch self {
        case .mapKit: return true
        case .directLine: return false
        }
    }
}

// MARK: - Route Option

/// 路线选项数据模型
/// 表示一条可选的路线，包含距离、时间、折线等信息
struct RouteOption: Identifiable, Equatable {
    /// 唯一标识符
    let id: String
    
    /// 路线名称（如"经由XX路"）
    let name: String
    
    /// 路线距离（米）
    let distance: Double
    
    /// 预计行程时间（秒）
    let expectedTravelTime: TimeInterval
    
    /// 路线折线（用于地图显示）
    /// 注意：MKPolyline 不支持 Equatable，所以在比较时忽略
    let polyline: MKPolyline?
    
    /// 是否选中
    var isSelected: Bool
    
    /// 路线来源
    let source: RouteSource
    
    /// 围栏半径（米）- 用于计算到达提醒范围的时间
    var geofenceRadius: Int = 500
    
    // MARK: - Computed Properties
    
    /// 预计到达目的地时间（分钟）- 原始 ETA
    var etaToDestinationMinutes: Int {
        Int(ceil(expectedTravelTime / 60.0))
    }
    
    /// 预计到达提醒范围时间（分钟）- 考虑围栏半径
    /// 这是用户真正关心的时间：多久后会收到提醒
    var etaMinutes: Int {
        // 计算平均速度（米/秒）
        let avgSpeed = distance > 0 ? distance / expectedTravelTime : 1.0
        
        // 计算到达围栏边缘需要减少的时间（秒）
        let geofenceTimeReduction = Double(geofenceRadius) / avgSpeed
        
        // 调整后的时间
        let adjustedTime = max(0, expectedTravelTime - geofenceTimeReduction)
        
        return Int(ceil(adjustedTime / 60.0))
    }
    
    /// 距离文本显示
    var distanceText: String {
        if distance >= 1000 {
            return String(format: "%.1f km", distance / 1000)
        } else {
            return String(format: "%.0f m", distance)
        }
    }
    
    /// 时间文本显示（到达提醒范围的时间）
    var timeText: String {
        let minutes = etaMinutes
        if minutes >= 60 {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours) 小时"
            } else {
                return "\(hours) 小时 \(remainingMinutes) 分钟"
            }
        } else {
            return "\(minutes) 分钟"
        }
    }
    
    // MARK: - Equatable
    
    static func == (lhs: RouteOption, rhs: RouteOption) -> Bool {
        // 忽略 polyline 的比较，因为 MKPolyline 不支持 Equatable
        return lhs.id == rhs.id &&
               lhs.name == rhs.name &&
               lhs.distance == rhs.distance &&
               lhs.expectedTravelTime == rhs.expectedTravelTime &&
               lhs.isSelected == rhs.isSelected &&
               lhs.source == rhs.source &&
               lhs.geofenceRadius == rhs.geofenceRadius
    }
    
    // MARK: - Methods
    
    /// 创建带有新围栏半径的副本
    func withGeofenceRadius(_ radius: Int) -> RouteOption {
        var copy = self
        copy.geofenceRadius = radius
        return copy
    }
    
    // MARK: - Factory Methods
    
    /// 从 MKRoute 创建 RouteOption
    /// - Parameters:
    ///   - route: MapKit 路线
    ///   - index: 路线索引（用于生成 ID）
    ///   - isSelected: 是否选中
    ///   - geofenceRadius: 围栏半径（米）
    /// - Returns: RouteOption 实例
    static func from(mkRoute route: MKRoute, index: Int, isSelected: Bool = false, geofenceRadius: Int = 500) -> RouteOption {
        return RouteOption(
            id: "route_\(index)_\(route.expectedTravelTime)",
            name: route.name.isEmpty ? "路线 \(index + 1)" : route.name,
            distance: route.distance,
            expectedTravelTime: route.expectedTravelTime,
            polyline: route.polyline,
            isSelected: isSelected,
            source: .mapKit,
            geofenceRadius: geofenceRadius
        )
    }
    
    /// 创建直线距离路线（用于飞机模式或备用）
    /// - Parameters:
    ///   - from: 起点坐标
    ///   - to: 终点坐标
    ///   - speed: 速度（米/秒）
    ///   - isSelected: 是否选中
    ///   - geofenceRadius: 围栏半径（米）
    /// - Returns: RouteOption 实例
    static func directLine(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        speed: Double,
        isSelected: Bool = true,
        geofenceRadius: Int = 500
    ) -> RouteOption {
        // 计算直线距离
        let distance = GeoUtils.calculateDistance(
            lat1: source.latitude,
            lon1: source.longitude,
            lat2: destination.latitude,
            lon2: destination.longitude
        )
        
        // 计算预计时间
        let travelTime = speed > 0 ? distance / speed : 0
        
        // 创建直线折线
        var coordinates = [source, destination]
        let polyline = MKPolyline(coordinates: &coordinates, count: 2)
        
        return RouteOption(
            id: "direct_\(Date().timeIntervalSince1970)",
            name: "直线距离",
            distance: distance,
            expectedTravelTime: travelTime,
            polyline: polyline,
            isSelected: isSelected,
            source: .directLine,
            geofenceRadius: geofenceRadius
        )
    }
}

// MARK: - Route ETA Result

/// 路线 ETA 结果
/// 包含所有可用路线、选中路线、可靠性等信息
struct RouteETAResult: Equatable {
    /// 可用路线列表（最多 5 条，按时间排序）
    let routes: [RouteOption]
    
    /// 选中的路线
    let selectedRoute: RouteOption?
    
    /// 是否可靠（路线规划 vs 直线距离）
    let isReliable: Bool
    
    /// 数据来源
    let source: RouteSource
    
    /// 查询时间
    let timestamp: Date
    
    /// 查询时的位置
    let queryLocation: CLLocationCoordinate2D
    
    /// 围栏半径（米）
    var geofenceRadius: Int = 500
    
    // MARK: - Computed Properties
    
    /// 是否有可用路线
    var hasRoutes: Bool {
        !routes.isEmpty
    }
    
    /// 选中路线的 ETA（分钟）- 到达提醒范围的时间
    var selectedETAMinutes: Int? {
        selectedRoute?.etaMinutes
    }
    
    /// 选中路线的距离文本
    var selectedDistanceText: String? {
        selectedRoute?.distanceText
    }
    
    // MARK: - Equatable
    
    static func == (lhs: RouteETAResult, rhs: RouteETAResult) -> Bool {
        return lhs.routes == rhs.routes &&
               lhs.selectedRoute == rhs.selectedRoute &&
               lhs.isReliable == rhs.isReliable &&
               lhs.source == rhs.source &&
               lhs.timestamp == rhs.timestamp &&
               lhs.queryLocation.latitude == rhs.queryLocation.latitude &&
               lhs.queryLocation.longitude == rhs.queryLocation.longitude &&
               lhs.geofenceRadius == rhs.geofenceRadius
    }
    
    // MARK: - Methods
    
    /// 创建带有新围栏半径的副本
    func withGeofenceRadius(_ radius: Int) -> RouteETAResult {
        let updatedRoutes = routes.map { $0.withGeofenceRadius(radius) }
        let updatedSelected = selectedRoute?.withGeofenceRadius(radius)
        
        return RouteETAResult(
            routes: updatedRoutes,
            selectedRoute: updatedSelected,
            isReliable: isReliable,
            source: source,
            timestamp: timestamp,
            queryLocation: queryLocation,
            geofenceRadius: radius
        )
    }
    
    // MARK: - Static Properties
    
    /// 空结果
    static let empty = RouteETAResult(
        routes: [],
        selectedRoute: nil,
        isReliable: false,
        source: .directLine,
        timestamp: Date(),
        queryLocation: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        geofenceRadius: 500
    )
    
    // MARK: - Factory Methods
    
    /// 创建带有选中路线的结果
    /// - Parameters:
    ///   - routes: 路线列表
    ///   - selectedIndex: 选中的路线索引
    ///   - source: 数据来源
    ///   - queryLocation: 查询位置
    ///   - geofenceRadius: 围栏半径（米）
    /// - Returns: RouteETAResult 实例
    static func create(
        routes: [RouteOption],
        selectedIndex: Int = 0,
        source: RouteSource,
        queryLocation: CLLocationCoordinate2D,
        geofenceRadius: Int = 500
    ) -> RouteETAResult {
        // 确保路线按时间排序
        let sortedRoutes = routes.sorted { $0.expectedTravelTime < $1.expectedTravelTime }
        
        // 限制最多 5 条路线
        let limitedRoutes = Array(sortedRoutes.prefix(5))
        
        // 更新选中状态和围栏半径
        var updatedRoutes = limitedRoutes.map { route -> RouteOption in
            var mutableRoute = route
            mutableRoute.isSelected = false
            mutableRoute.geofenceRadius = geofenceRadius
            return mutableRoute
        }
        
        // 设置选中路线
        let safeIndex = min(max(0, selectedIndex), updatedRoutes.count - 1)
        var selectedRoute: RouteOption? = nil
        
        if !updatedRoutes.isEmpty {
            updatedRoutes[safeIndex].isSelected = true
            selectedRoute = updatedRoutes[safeIndex]
        }
        
        return RouteETAResult(
            routes: updatedRoutes,
            selectedRoute: selectedRoute,
            isReliable: source == .mapKit,
            source: source,
            timestamp: Date(),
            queryLocation: queryLocation,
            geofenceRadius: geofenceRadius
        )
    }
    
    /// 选择指定路线
    /// - Parameter routeId: 路线 ID
    /// - Returns: 更新后的 RouteETAResult
    func selectRoute(withId routeId: String) -> RouteETAResult {
        guard let index = routes.firstIndex(where: { $0.id == routeId }) else {
            return self
        }
        
        return RouteETAResult.create(
            routes: routes,
            selectedIndex: index,
            source: source,
            queryLocation: queryLocation,
            geofenceRadius: geofenceRadius
        )
    }
}

// MARK: - ETA Change Detection

/// ETA 变化检测器
/// 用于检测 ETA 是否发生显著变化
struct ETAChangeDetector {
    /// 显著变化阈值（分钟）
    static let significantChangeThreshold: Int = 3
    
    /// 检测是否发生显著变化
    /// - Parameters:
    ///   - previousETA: 之前的 ETA（分钟）
    ///   - currentETA: 当前的 ETA（分钟）
    /// - Returns: 是否发生显著变化
    static func isSignificantChange(previousETA: Int, currentETA: Int) -> Bool {
        return abs(previousETA - currentETA) > significantChangeThreshold
    }
    
    /// 获取变化描述
    /// - Parameters:
    ///   - previousETA: 之前的 ETA（分钟）
    ///   - currentETA: 当前的 ETA（分钟）
    /// - Returns: 变化描述文本
    static func changeDescription(previousETA: Int, currentETA: Int) -> String? {
        let diff = currentETA - previousETA
        guard abs(diff) > significantChangeThreshold else { return nil }
        
        if diff > 0 {
            return "预计时间增加了 \(diff) 分钟"
        } else {
            return "预计时间减少了 \(abs(diff)) 分钟"
        }
    }
}
