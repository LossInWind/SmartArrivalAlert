import Foundation
import MapKit
import CoreLocation

/// 路线 ETA 服务
/// 负责调用 MapKit Directions API 获取路线和预计时间
actor RouteETAService {
    
    // MARK: - Constants
    
    /// 最大路线数量
    static let maxRouteCount = 5
    
    /// 缓存复用的最小位置变化阈值（米）
    static let cacheReuseThreshold: Double = 100.0
    
    /// 立即刷新的位置变化阈值（米）
    static let immediateRefreshThreshold: Double = 500.0
    
    /// 飞机基准速度（米/秒）= 800 km/h
    static let airplaneBaselineSpeed: Double = 222.0
    
    // MARK: - Properties
    
    /// 缓存的路线结果
    private var cachedResult: RouteETAResult?
    
    /// 当前待处理的请求
    private var pendingTask: Task<RouteETAResult, Never>?
    
    /// 上次查询的位置
    private var lastQueryLocation: CLLocationCoordinate2D?
    
    /// 上次查询的目的地
    private var lastDestination: CLLocationCoordinate2D?
    
    /// 上次查询的交通方式
    private var lastTransportMode: TransportMode?
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// 获取路线
    /// - Parameters:
    ///   - source: 起点坐标
    ///   - destination: 终点坐标
    ///   - transportMode: 交通方式
    ///   - geofenceRadius: 围栏半径（米）
    /// - Returns: 路线 ETA 结果
    func fetchRoutes(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportMode: TransportMode,
        geofenceRadius: Int = 500
    ) async -> RouteETAResult {
        // 检查是否可以使用缓存
        if let cached = cachedResult,
           shouldUseCachedResult(
               currentLocation: source,
               destination: destination,
               transportMode: transportMode
           ) {
            // 更新缓存结果的围栏半径
            return cached.withGeofenceRadius(geofenceRadius)
        }
        
        // 取消之前的请求
        pendingTask?.cancel()
        
        // 创建新的请求任务
        let task = Task<RouteETAResult, Never> {
            let result: RouteETAResult
            
            // 飞机模式使用直线距离
            if transportMode == .airplane {
                result = calculateDirectLineResult(
                    from: source,
                    to: destination,
                    speed: Self.airplaneBaselineSpeed,
                    geofenceRadius: geofenceRadius
                )
            } else if transportMode.supportsMapKitRouting,
                      let mkTransportType = transportMode.mapKitTransportType {
                // 使用 MapKit 路线规划
                result = await fetchMapKitRoutes(
                    from: source,
                    to: destination,
                    transportType: mkTransportType,
                    geofenceRadius: geofenceRadius
                )
            } else {
                // 不支持路线规划，使用直线距离
                result = calculateDirectLineResult(
                    from: source,
                    to: destination,
                    speed: transportMode.baselineSpeed,
                    geofenceRadius: geofenceRadius
                )
            }
            
            return result
        }
        
        pendingTask = task
        let result = await task.value
        
        // 更新缓存
        cachedResult = result
        lastQueryLocation = source
        lastDestination = destination
        lastTransportMode = transportMode
        
        return result
    }
    
    /// 取消待处理的请求
    func cancelPendingRequests() {
        pendingTask?.cancel()
        pendingTask = nil
    }
    
    /// 清除缓存
    func clearCache() {
        cachedResult = nil
        lastQueryLocation = nil
        lastDestination = nil
        lastTransportMode = nil
    }
    
    /// 检查是否需要刷新路线
    /// - Parameters:
    ///   - currentLocation: 当前位置
    ///   - lastQueryLocation: 上次查询位置
    /// - Returns: 是否需要刷新
    func shouldRefresh(
        currentLocation: CLLocationCoordinate2D,
        lastQueryLocation: CLLocationCoordinate2D
    ) -> Bool {
        let distance = GeoUtils.calculateDistance(
            lat1: currentLocation.latitude,
            lon1: currentLocation.longitude,
            lat2: lastQueryLocation.latitude,
            lon2: lastQueryLocation.longitude
        )
        return distance > Self.immediateRefreshThreshold
    }
    
    /// 检查是否应该使用缓存
    /// - Parameters:
    ///   - currentLocation: 当前位置
    ///   - lastQueryLocation: 上次查询位置
    /// - Returns: 是否应该使用缓存
    func shouldUseCache(
        currentLocation: CLLocationCoordinate2D,
        lastQueryLocation: CLLocationCoordinate2D
    ) -> Bool {
        let distance = GeoUtils.calculateDistance(
            lat1: currentLocation.latitude,
            lon1: currentLocation.longitude,
            lat2: lastQueryLocation.latitude,
            lon2: lastQueryLocation.longitude
        )
        return distance < Self.cacheReuseThreshold
    }
    
    /// 选择路线
    /// - Parameter routeId: 路线 ID
    /// - Returns: 更新后的结果
    func selectRoute(withId routeId: String) -> RouteETAResult? {
        guard let cached = cachedResult else { return nil }
        let updated = cached.selectRoute(withId: routeId)
        cachedResult = updated
        return updated
    }
    
    /// 获取缓存的结果
    func getCachedResult() -> RouteETAResult? {
        return cachedResult
    }
    
    // MARK: - Private Methods
    
    /// 检查是否可以使用缓存结果
    private func shouldUseCachedResult(
        currentLocation: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        transportMode: TransportMode
    ) -> Bool {
        guard let lastLocation = lastQueryLocation,
              let lastDest = lastDestination,
              let lastMode = lastTransportMode,
              cachedResult != nil else {
            return false
        }
        
        // 交通方式必须相同
        guard lastMode == transportMode else { return false }
        
        // 目的地必须相同（允许小误差）
        let destDistance = GeoUtils.calculateDistance(
            lat1: destination.latitude,
            lon1: destination.longitude,
            lat2: lastDest.latitude,
            lon2: lastDest.longitude
        )
        guard destDistance < 10 else { return false } // 10米误差
        
        // 位置变化必须小于阈值
        return shouldUseCache(currentLocation: currentLocation, lastQueryLocation: lastLocation)
    }
    
    /// 使用 MapKit 获取路线
    private func fetchMapKitRoutes(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType,
        geofenceRadius: Int
    ) async -> RouteETAResult {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: source))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = transportType
        request.requestsAlternateRoutes = true
        
        let directions = MKDirections(request: request)
        
        do {
            let response = try await directions.calculate()
            
            // 转换路线
            var routes: [RouteOption] = []
            for (index, mkRoute) in response.routes.enumerated() {
                let route = RouteOption.from(
                    mkRoute: mkRoute,
                    index: index,
                    isSelected: index == 0,
                    geofenceRadius: geofenceRadius
                )
                routes.append(route)
            }
            
            // 如果没有路线，使用备用方案
            guard !routes.isEmpty else {
                return calculateFallbackResult(
                    from: source,
                    to: destination,
                    transportType: transportType,
                    geofenceRadius: geofenceRadius
                )
            }
            
            return RouteETAResult.create(
                routes: routes,
                selectedIndex: 0,
                source: .mapKit,
                queryLocation: source,
                geofenceRadius: geofenceRadius
            )
            
        } catch {
            // API 失败，使用备用方案
            return calculateFallbackResult(
                from: source,
                to: destination,
                transportType: transportType,
                geofenceRadius: geofenceRadius
            )
        }
    }
    
    /// 计算直线距离结果
    private func calculateDirectLineResult(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        speed: Double,
        geofenceRadius: Int
    ) -> RouteETAResult {
        let route = RouteOption.directLine(
            from: source,
            to: destination,
            speed: speed,
            isSelected: true,
            geofenceRadius: geofenceRadius
        )
        
        return RouteETAResult(
            routes: [route],
            selectedRoute: route,
            isReliable: false,
            source: .directLine,
            timestamp: Date(),
            queryLocation: source,
            geofenceRadius: geofenceRadius
        )
    }
    
    /// 计算备用结果（API 失败时）
    private func calculateFallbackResult(
        from source: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType,
        geofenceRadius: Int
    ) -> RouteETAResult {
        // 根据交通类型选择速度
        let speed: Double
        switch transportType {
        case .walking:
            speed = TransportMode.walking.baselineSpeed
        case .automobile:
            speed = TransportMode.driving.baselineSpeed
        case .transit:
            speed = TransportMode.bus.baselineSpeed
        default:
            speed = TransportMode.walking.baselineSpeed
        }
        
        return calculateDirectLineResult(from: source, to: destination, speed: speed, geofenceRadius: geofenceRadius)
    }
}

// MARK: - Shared Instance

extension RouteETAService {
    /// 共享实例
    static let shared = RouteETAService()
}
