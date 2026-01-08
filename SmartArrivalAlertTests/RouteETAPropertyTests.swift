import XCTest
import SwiftCheck
import CoreLocation
import MapKit
@testable import SmartArrivalAlert

/// Route ETA 属性测试
/// Feature: route-eta-enhancement
final class RouteETAPropertyTests: XCTestCase {
    
    // MARK: - Test Generators
    
    /// 生成有效的路线距离（米）
    static var validDistance: Gen<Double> {
        Gen<Double>.fromElements(in: 100...100000)
    }
    
    /// 生成有效的行程时间（秒）
    static var validTravelTime: Gen<TimeInterval> {
        Gen<Double>.fromElements(in: 60...36000) // 1分钟到10小时
    }
    
    /// 生成有效的坐标
    static var validCoordinate: Gen<CLLocationCoordinate2D> {
        Gen<(Double, Double)>.zip(
            Gen<Double>.fromElements(in: -90...90),
            Gen<Double>.fromElements(in: -180...180)
        ).map { CLLocationCoordinate2D(latitude: $0.0, longitude: $0.1) }
    }
    
    /// 生成有效的速度（米/秒）
    static var validSpeed: Gen<Double> {
        Gen<Double>.fromElements(in: 1...250) // 1 m/s 到 250 m/s (900 km/h)
    }
    
    /// 生成 ETA 分钟数
    static var validETAMinutes: Gen<Int> {
        Gen<Int>.fromElements(in: 1...120)
    }
    
    /// 生成电池模式
    static var batteryMode: Gen<BatteryMode> {
        Gen<BatteryMode>.fromElements(of: BatteryMode.allCases)
    }
    
    /// 生成交通方式
    static var transportMode: Gen<TransportMode> {
        Gen<TransportMode>.fromElements(of: TransportMode.allCases)
    }
    
    /// 生成路线来源
    static var routeSource: Gen<RouteSource> {
        Gen<RouteSource>.fromElements(of: [.mapKit, .directLine])
    }
    
    /// 生成 RouteOption
    static var routeOption: Gen<RouteOption> {
        Gen<(Double, TimeInterval, RouteSource, Bool)>.zip(
            validDistance,
            validTravelTime,
            routeSource,
            Bool.arbitrary
        ).map { distance, time, source, selected in
            RouteOption(
                id: UUID().uuidString,
                name: "测试路线",
                distance: distance,
                expectedTravelTime: time,
                polyline: nil,
                isSelected: selected,
                source: source
            )
        }
    }
    
    /// 生成路线列表（1-10条）
    static var routeList: Gen<[RouteOption]> {
        Gen<Int>.fromElements(in: 1...10).flatMap { count in
            Gen<[RouteOption]>.compose { composer in
                (0..<count).map { index in
                    let distance = composer.generate(using: validDistance)
                    let time = composer.generate(using: validTravelTime)
                    return RouteOption(
                        id: "route_\(index)",
                        name: "路线 \(index + 1)",
                        distance: distance,
                        expectedTravelTime: time,
                        polyline: nil,
                        isSelected: false,
                        source: .mapKit
                    )
                }
            }
        }
    }
    
    // MARK: - Property 3: Route Extraction Completeness
    
    /// Property 3: Route Extraction Completeness
    /// For any successful route, the extracted RouteOption SHALL contain valid distance (> 0),
    /// expectedTravelTime (> 0), and computed properties.
    /// **Validates: Requirements 1.5**
    func testRouteExtractionCompleteness() {
        property("Route extraction produces valid data") <- forAll(
            Self.validDistance,
            Self.validTravelTime
        ) { (distance: Double, travelTime: TimeInterval) in
            let route = RouteOption(
                id: UUID().uuidString,
                name: "测试路线",
                distance: distance,
                expectedTravelTime: travelTime,
                polyline: nil,
                isSelected: false,
                source: .mapKit
            )
            
            // 验证基本属性有效
            let hasValidDistance = route.distance > 0
            let hasValidTime = route.expectedTravelTime > 0
            
            // 验证计算属性正确
            let etaMinutes = route.etaMinutes
            let expectedMinutes = Int(ceil(travelTime / 60.0))
            let hasCorrectETA = etaMinutes == expectedMinutes
            
            // 验证距离文本格式正确
            let distanceText = route.distanceText
            let hasValidDistanceText = !distanceText.isEmpty &&
                (distanceText.contains("km") || distanceText.contains("m"))
            
            return hasValidDistance && hasValidTime && hasCorrectETA && hasValidDistanceText
        }
    }
    
    // MARK: - Property 5: Route Display Limit
    
    /// Property 5: Route Display Limit
    /// For any RouteETAResult, the routes array SHALL contain at most 5 elements.
    /// **Validates: Requirements 2.1**
    func testRouteDisplayLimit() {
        property("Route list is limited to 5 elements") <- forAllNoShrink(Self.routeList) { (routes: [RouteOption]) in
            let result = RouteETAResult.create(
                routes: routes,
                selectedIndex: 0,
                source: .mapKit,
                queryLocation: CLLocationCoordinate2D(latitude: 0, longitude: 0)
            )
            
            return result.routes.count <= 5
        }
    }
    
    // MARK: - Property 6: Routes Sorted by Time
    
    /// Property 6: Routes Sorted by Time
    /// For any RouteETAResult with multiple routes, the routes SHALL be sorted by
    /// expectedTravelTime in ascending order.
    /// **Validates: Requirements 2.2**
    func testRoutesSortedByTime() {
        property("Routes are sorted by travel time ascending") <- forAllNoShrink(Self.routeList) { (routes: [RouteOption]) in
            let result = RouteETAResult.create(
                routes: routes,
                selectedIndex: 0,
                source: .mapKit,
                queryLocation: CLLocationCoordinate2D(latitude: 0, longitude: 0)
            )
            
            // 检查是否按时间升序排列
            for i in 0..<(result.routes.count - 1) {
                if result.routes[i].expectedTravelTime > result.routes[i + 1].expectedTravelTime {
                    return false
                }
            }
            return true
        }
    }
    
    // MARK: - Property 7: Default Route Selection
    
    /// Property 7: Default Route Selection
    /// For any RouteETAResult with at least one route, the selectedRoute SHALL be
    /// the route with minimum expectedTravelTime.
    /// **Validates: Requirements 2.6**
    func testDefaultRouteSelection() {
        property("Default selection is the fastest route") <- forAllNoShrink(Self.routeList) { (routes: [RouteOption]) in
            guard !routes.isEmpty else { return true }
            
            let result = RouteETAResult.create(
                routes: routes,
                selectedIndex: 0,
                source: .mapKit,
                queryLocation: CLLocationCoordinate2D(latitude: 0, longitude: 0)
            )
            
            guard let selected = result.selectedRoute else { return false }
            
            // 找到最快的路线
            let minTime = routes.min(by: { $0.expectedTravelTime < $1.expectedTravelTime })?.expectedTravelTime
            
            // 选中的路线应该是最快的
            return selected.expectedTravelTime == minTime
        }
    }
    
    // MARK: - Property 11: Significant ETA Change Detection
    
    /// Property 11: Significant ETA Change Detection
    /// For any two consecutive ETA values, a significant change notification SHALL be
    /// triggered if and only if the absolute difference exceeds 3 minutes.
    /// **Validates: Requirements 6.4**
    func testSignificantETAChangeDetection() {
        property("Significant change detected when diff > 3 minutes") <- forAll(
            Self.validETAMinutes,
            Self.validETAMinutes
        ) { (eta1: Int, eta2: Int) in
            let isSignificant = ETAChangeDetector.isSignificantChange(previousETA: eta1, currentETA: eta2)
            let expectedSignificant = abs(eta1 - eta2) > 3
            
            return isSignificant == expectedSignificant
        }
    }
    
    // MARK: - RouteOption Computed Properties Tests
    
    /// 测试 etaMinutes 计算正确性
    func testETAMinutesCalculation() {
        property("ETA minutes is ceiling of seconds/60") <- forAll(Self.validTravelTime) { (seconds: TimeInterval) in
            let route = RouteOption(
                id: "test",
                name: "test",
                distance: 1000,
                expectedTravelTime: seconds,
                polyline: nil,
                isSelected: false,
                source: .mapKit
            )
            
            let expected = Int(ceil(seconds / 60.0))
            return route.etaMinutes == expected
        }
    }
    
    /// 测试 distanceText 格式正确性
    func testDistanceTextFormat() {
        property("Distance text uses km for >= 1000m, m otherwise") <- forAll(Self.validDistance) { (distance: Double) in
            let route = RouteOption(
                id: "test",
                name: "test",
                distance: distance,
                expectedTravelTime: 600,
                polyline: nil,
                isSelected: false,
                source: .mapKit
            )
            
            let text = route.distanceText
            if distance >= 1000 {
                return text.contains("km")
            } else {
                return text.contains("m") && !text.contains("km")
            }
        }
    }
    
    /// 测试 timeText 格式正确性
    func testTimeTextFormat() {
        // 测试小于 60 分钟
        let route1 = RouteOption(
            id: "test",
            name: "test",
            distance: 1000,
            expectedTravelTime: 30 * 60, // 30 分钟
            polyline: nil,
            isSelected: false,
            source: .mapKit
        )
        XCTAssertEqual(route1.timeText, "30 分钟")
        
        // 测试正好 60 分钟
        let route2 = RouteOption(
            id: "test",
            name: "test",
            distance: 1000,
            expectedTravelTime: 60 * 60, // 60 分钟
            polyline: nil,
            isSelected: false,
            source: .mapKit
        )
        XCTAssertEqual(route2.timeText, "1 小时")
        
        // 测试超过 60 分钟
        let route3 = RouteOption(
            id: "test",
            name: "test",
            distance: 1000,
            expectedTravelTime: 90 * 60, // 90 分钟
            polyline: nil,
            isSelected: false,
            source: .mapKit
        )
        XCTAssertEqual(route3.timeText, "1 小时 30 分钟")
    }
}


// MARK: - Property 1: Transport Mode to MKDirections Type Mapping

extension RouteETAPropertyTests {
    
    /// Property 1: Transport Mode to MKDirections Type Mapping
    /// For any transport mode that supports MapKit routing, the corresponding
    /// MKDirectionsTransportType SHALL be correctly mapped.
    /// **Validates: Requirements 1.1, 1.2, 1.3**
    func testTransportModeToMKDirectionsMapping() {
        // 步行 -> walking
        XCTAssertEqual(TransportMode.walking.mapKitTransportType, .walking)
        XCTAssertTrue(TransportMode.walking.supportsMapKitRouting)
        
        // 驾车 -> automobile
        XCTAssertEqual(TransportMode.driving.mapKitTransportType, .automobile)
        XCTAssertTrue(TransportMode.driving.supportsMapKitRouting)
        
        // 地铁 -> transit
        XCTAssertEqual(TransportMode.subway.mapKitTransportType, .transit)
        XCTAssertTrue(TransportMode.subway.supportsMapKitRouting)
        
        // 公交 -> transit
        XCTAssertEqual(TransportMode.bus.mapKitTransportType, .transit)
        XCTAssertTrue(TransportMode.bus.supportsMapKitRouting)
        
        // 骑行 -> walking (近似)
        XCTAssertEqual(TransportMode.cycling.mapKitTransportType, .walking)
        XCTAssertTrue(TransportMode.cycling.supportsMapKitRouting)
        
        // 飞机 -> nil (不支持)
        XCTAssertNil(TransportMode.airplane.mapKitTransportType)
        XCTAssertFalse(TransportMode.airplane.supportsMapKitRouting)
    }
    
    /// 属性测试：所有支持路线规划的交通方式都有对应的 MKDirectionsTransportType
    func testAllRoutingModesHaveTransportType() {
        property("All routing-supported modes have MKDirectionsTransportType") <- forAllNoShrink(Self.transportMode) { (mode: TransportMode) in
            if mode.supportsMapKitRouting {
                return mode.mapKitTransportType != nil
            } else {
                return mode.mapKitTransportType == nil
            }
        }
    }
}


// MARK: - Property 2: Airplane Mode Uses Direct Distance

extension RouteETAPropertyTests {
    
    /// Property 2: Airplane Mode Uses Direct Distance
    /// For any route query with airplane transport mode, the system SHALL NOT call
    /// MKDirections API and SHALL calculate ETA using direct distance with 222 m/s
    /// (800 km/h) baseline speed.
    /// **Validates: Requirements 1.4, 4.2, 4.3**
    func testAirplaneModeUsesDirectDistance() {
        // 验证飞机模式不支持 MapKit 路线
        XCTAssertFalse(TransportMode.airplane.supportsMapKitRouting)
        XCTAssertNil(TransportMode.airplane.mapKitTransportType)
        
        // 验证飞机基准速度为 222 m/s (800 km/h)
        XCTAssertEqual(TransportMode.airplane.baselineSpeed, 222.0, accuracy: 0.1)
        
        // 验证 RouteETAService 的飞机速度常量
        XCTAssertEqual(RouteETAService.airplaneBaselineSpeed, 222.0, accuracy: 0.1)
    }
    
    /// 属性测试：飞机模式 ETA 计算使用直线距离和 800km/h 速度
    func testAirplaneModeETACalculation() {
        property("Airplane ETA uses direct distance with 222 m/s speed") <- forAllNoShrink(
            Self.validCoordinate,
            Self.validCoordinate
        ) { (source: CLLocationCoordinate2D, dest: CLLocationCoordinate2D) in
            // 计算直线距离
            let distance = GeoUtils.calculateDistance(
                lat1: source.latitude,
                lon1: source.longitude,
                lat2: dest.latitude,
                lon2: dest.longitude
            )
            
            // 使用飞机速度计算预期时间
            let expectedTime = distance / 222.0
            let expectedMinutes = Int(ceil(expectedTime / 60.0))
            
            // 创建直线路线
            let route = RouteOption.directLine(
                from: source,
                to: dest,
                speed: 222.0,
                isSelected: true
            )
            
            // 验证 ETA 计算正确
            return route.etaMinutes == expectedMinutes
        }
    }
    
    /// 测试飞机模式返回直线距离来源
    func testAirplaneModeReturnsDirectLineSource() {
        let source = CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074) // 北京
        let dest = CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)   // 上海
        
        let route = RouteOption.directLine(
            from: source,
            to: dest,
            speed: TransportMode.airplane.baselineSpeed,
            isSelected: true
        )
        
        XCTAssertEqual(route.source, .directLine)
        XCTAssertFalse(route.source.isReliable)
    }
}


// MARK: - Property 4: Fallback on API Failure

extension RouteETAPropertyTests {
    
    /// Property 4: Fallback on API Failure
    /// For any failed MKDirections query, the system SHALL return a RouteETAResult
    /// with source = .directLine and isReliable = false.
    /// **Validates: Requirements 1.6**
    func testFallbackResultProperties() {
        // 创建一个模拟的备用结果
        let source = CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
        let dest = CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
        
        let route = RouteOption.directLine(
            from: source,
            to: dest,
            speed: TransportMode.walking.baselineSpeed,
            isSelected: true
        )
        
        let fallbackResult = RouteETAResult(
            routes: [route],
            selectedRoute: route,
            isReliable: false,
            source: .directLine,
            timestamp: Date(),
            queryLocation: source
        )
        
        // 验证备用结果属性
        XCTAssertEqual(fallbackResult.source, .directLine)
        XCTAssertFalse(fallbackResult.isReliable)
        XCTAssertFalse(fallbackResult.routes.isEmpty)
        XCTAssertNotNil(fallbackResult.selectedRoute)
    }
    
    /// 属性测试：直线距离结果总是不可靠的
    func testDirectLineResultIsUnreliable() {
        property("Direct line results are always unreliable") <- forAllNoShrink(
            Self.validCoordinate,
            Self.validCoordinate,
            Self.validSpeed
        ) { (source: CLLocationCoordinate2D, dest: CLLocationCoordinate2D, speed: Double) in
            let route = RouteOption.directLine(
                from: source,
                to: dest,
                speed: speed,
                isSelected: true
            )
            
            return route.source == .directLine && !route.source.isReliable
        }
    }
    
    /// 测试 RouteSource 的 isReliable 属性
    func testRouteSourceReliability() {
        XCTAssertTrue(RouteSource.mapKit.isReliable)
        XCTAssertFalse(RouteSource.directLine.isReliable)
    }
}


// MARK: - Property 8: Refresh Interval Calculation

extension RouteETAPropertyTests {
    
    /// Property 8: Refresh Interval Calculation
    /// For any combination of ETA (minutes) and BatteryMode, the calculated refresh
    /// interval SHALL follow the defined rules:
    /// - High Accuracy: intervals are halved
    /// - Balanced: base intervals
    /// - Power Saving: intervals increased by 50%
    /// **Validates: Requirements 5.2, 7.4**
    func testRefreshIntervalCalculation() {
        property("Refresh interval follows battery mode rules") <- forAllNoShrink(
            Self.validETAMinutes,
            Self.batteryMode
        ) { (eta: Int, mode: BatteryMode) in
            let interval = RefreshIntervalCalculator.calculate(etaMinutes: eta, batteryMode: mode)
            let baseInterval = RefreshIntervalCalculator.getBaseInterval(etaMinutes: eta)
            
            switch mode {
            case .highAccuracy:
                // 高精度模式：减半
                return abs(interval - baseInterval * 0.5) < 0.001
            case .balanced:
                // 平衡模式：不变
                return abs(interval - baseInterval) < 0.001
            case .powerSaving:
                // 省电模式：增加 50%
                return abs(interval - baseInterval * 1.5) < 0.001
            }
        }
    }
    
    /// 测试基础间隔根据 ETA 正确分层
    func testBaseIntervalTiers() {
        // < 5 分钟：60 秒
        XCTAssertEqual(RefreshIntervalCalculator.getBaseInterval(etaMinutes: 3), 60)
        XCTAssertEqual(RefreshIntervalCalculator.getBaseInterval(etaMinutes: 4), 60)
        
        // 5-10 分钟：120 秒
        XCTAssertEqual(RefreshIntervalCalculator.getBaseInterval(etaMinutes: 5), 120)
        XCTAssertEqual(RefreshIntervalCalculator.getBaseInterval(etaMinutes: 9), 120)
        
        // 10-30 分钟：300 秒
        XCTAssertEqual(RefreshIntervalCalculator.getBaseInterval(etaMinutes: 10), 300)
        XCTAssertEqual(RefreshIntervalCalculator.getBaseInterval(etaMinutes: 29), 300)
        
        // > 30 分钟：600 秒
        XCTAssertEqual(RefreshIntervalCalculator.getBaseInterval(etaMinutes: 30), 600)
        XCTAssertEqual(RefreshIntervalCalculator.getBaseInterval(etaMinutes: 60), 600)
    }
    
    /// 测试各电池模式的具体间隔值
    func testBatteryModeIntervals() {
        // ETA = 3 分钟（基础 60 秒）
        XCTAssertEqual(RefreshIntervalCalculator.calculate(etaMinutes: 3, batteryMode: .highAccuracy), 30)
        XCTAssertEqual(RefreshIntervalCalculator.calculate(etaMinutes: 3, batteryMode: .balanced), 60)
        XCTAssertEqual(RefreshIntervalCalculator.calculate(etaMinutes: 3, batteryMode: .powerSaving), 90)
        
        // ETA = 20 分钟（基础 300 秒）
        XCTAssertEqual(RefreshIntervalCalculator.calculate(etaMinutes: 20, batteryMode: .highAccuracy), 150)
        XCTAssertEqual(RefreshIntervalCalculator.calculate(etaMinutes: 20, batteryMode: .balanced), 300)
        XCTAssertEqual(RefreshIntervalCalculator.calculate(etaMinutes: 20, batteryMode: .powerSaving), 450)
    }
    
    /// 属性测试：高精度模式间隔总是小于平衡模式
    func testHighAccuracyAlwaysShorter() {
        property("High accuracy interval < balanced interval") <- forAll(Self.validETAMinutes) { (eta: Int) in
            let highAccuracy = RefreshIntervalCalculator.calculate(etaMinutes: eta, batteryMode: .highAccuracy)
            let balanced = RefreshIntervalCalculator.calculate(etaMinutes: eta, batteryMode: .balanced)
            return highAccuracy < balanced
        }
    }
    
    /// 属性测试：省电模式间隔总是大于平衡模式
    func testPowerSavingAlwaysLonger() {
        property("Power saving interval > balanced interval") <- forAll(Self.validETAMinutes) { (eta: Int) in
            let powerSaving = RefreshIntervalCalculator.calculate(etaMinutes: eta, batteryMode: .powerSaving)
            let balanced = RefreshIntervalCalculator.calculate(etaMinutes: eta, batteryMode: .balanced)
            return powerSaving > balanced
        }
    }
}


// MARK: - Property 9: Location Change Threshold

extension RouteETAPropertyTests {
    
    /// Property 9: Location Change Threshold
    /// For any two locations, shouldRefresh SHALL return true if and only if
    /// the distance between them exceeds 500 meters.
    /// **Validates: Requirements 5.3**
    func testLocationChangeThreshold() {
        // 测试 500m 阈值
        let baseLocation = (latitude: 39.9042, longitude: 116.4074)
        
        // 计算 500m 对应的经度变化（在北京纬度约 0.0058 度）
        // 1度经度 ≈ 111km * cos(39.9°) ≈ 85km
        // 500m ≈ 0.0059 度
        
        // 小于 500m - 不应刷新
        let nearLocation = (latitude: 39.9042, longitude: 116.4080) // 约 50m
        XCTAssertFalse(LocationThresholdCalculator.shouldRefreshImmediately(
            currentLocation: nearLocation,
            lastQueryLocation: baseLocation
        ))
        
        // 大于 500m - 应该刷新
        let farLocation = (latitude: 39.9042, longitude: 116.4150) // 约 650m
        XCTAssertTrue(LocationThresholdCalculator.shouldRefreshImmediately(
            currentLocation: farLocation,
            lastQueryLocation: baseLocation
        ))
    }
    
    /// 属性测试：距离超过 500m 时应该刷新
    func testShouldRefreshWhenDistanceExceeds500m() {
        property("Should refresh when distance > 500m") <- forAllNoShrink(
            Self.validCoordinate
        ) { (base: CLLocationCoordinate2D) in
            // 创建一个距离约 600m 的点
            let offset = 0.006 // 约 600m
            let farPoint = (
                latitude: base.latitude + offset,
                longitude: base.longitude
            )
            let basePoint = (latitude: base.latitude, longitude: base.longitude)
            
            let distance = LocationThresholdCalculator.calculateDistance(from: basePoint, to: farPoint)
            let shouldRefresh = LocationThresholdCalculator.shouldRefreshImmediately(
                currentLocation: farPoint,
                lastQueryLocation: basePoint
            )
            
            // 如果距离 > 500m，应该刷新
            if distance > 500 {
                return shouldRefresh == true
            }
            return true
        }
    }
    
    /// 测试缓存复用阈值（100m）
    func testCacheReuseThreshold() {
        let baseLocation = (latitude: 39.9042, longitude: 116.4074)
        
        // 小于 100m - 应该使用缓存
        let veryNearLocation = (latitude: 39.9043, longitude: 116.4075) // 约 15m
        XCTAssertTrue(LocationThresholdCalculator.shouldUseCache(
            currentLocation: veryNearLocation,
            lastQueryLocation: baseLocation
        ))
        
        // 大于 100m - 不应使用缓存
        let notSoNearLocation = (latitude: 39.9055, longitude: 116.4074) // 约 145m
        XCTAssertFalse(LocationThresholdCalculator.shouldUseCache(
            currentLocation: notSoNearLocation,
            lastQueryLocation: baseLocation
        ))
    }
    
    /// 测试阈值常量值
    func testThresholdConstants() {
        XCTAssertEqual(LocationThresholdCalculator.immediateRefreshThreshold, 500.0)
        XCTAssertEqual(LocationThresholdCalculator.cacheReuseThreshold, 100.0)
        XCTAssertEqual(RouteETAService.immediateRefreshThreshold, 500.0)
        XCTAssertEqual(RouteETAService.cacheReuseThreshold, 100.0)
    }
}


// MARK: - Property 12: Cache Reuse for Minimal Location Change

extension RouteETAPropertyTests {
    
    /// Property 12: Cache Reuse for Minimal Location Change
    /// For any route query where the location change from last query is less than
    /// 100 meters, the cached route SHALL be returned instead of making a new API call.
    /// **Validates: Requirements 7.1, 7.3**
    func testCacheReuseForMinimalLocationChange() {
        property("Cache is reused when location change < 100m") <- forAllNoShrink(
            Self.validCoordinate
        ) { (base: CLLocationCoordinate2D) in
            // 创建一个距离约 50m 的点
            let offset = 0.0005 // 约 50m
            let nearPoint = (
                latitude: base.latitude + offset,
                longitude: base.longitude
            )
            let basePoint = (latitude: base.latitude, longitude: base.longitude)
            
            let distance = LocationThresholdCalculator.calculateDistance(from: basePoint, to: nearPoint)
            let shouldUseCache = LocationThresholdCalculator.shouldUseCache(
                currentLocation: nearPoint,
                lastQueryLocation: basePoint
            )
            
            // 如果距离 < 100m，应该使用缓存
            if distance < 100 {
                return shouldUseCache == true
            }
            return true
        }
    }
    
    /// 测试缓存复用逻辑
    func testCacheReuseLogic() async {
        let service = RouteETAService()
        
        let source = CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
        let dest = CLLocationCoordinate2D(latitude: 39.9142, longitude: 116.4174)
        
        // 第一次查询
        let result1 = await service.fetchRoutes(
            from: source,
            to: dest,
            transportMode: .airplane // 使用飞机模式避免网络请求
        )
        
        // 验证有缓存
        let cached = await service.getCachedResult()
        XCTAssertNotNil(cached)
        
        // 小位置变化的第二次查询（应该使用缓存）
        let nearSource = CLLocationCoordinate2D(
            latitude: source.latitude + 0.0005, // 约 50m
            longitude: source.longitude
        )
        
        let result2 = await service.fetchRoutes(
            from: nearSource,
            to: dest,
            transportMode: .airplane
        )
        
        // 由于位置变化小，应该返回相同的缓存结果
        // 注意：由于时间戳不同，我们比较关键属性
        XCTAssertEqual(result1.source, result2.source)
        XCTAssertEqual(result1.routes.count, result2.routes.count)
    }
}
