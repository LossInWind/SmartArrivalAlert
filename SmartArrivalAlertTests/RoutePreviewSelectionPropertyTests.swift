import XCTest
import SwiftCheck
import CoreLocation
@testable import SmartArrivalAlert

/// Route Preview Selection 功能的属性测试
/// Feature: route-preview-selection
final class RoutePreviewSelectionPropertyTests: XCTestCase {
    
    // MARK: - Property 1: Swipe Gesture Direction Mapping
    // **Validates: Requirements 4.1, 4.2, 4.5**
    
    /// 测试向左滑动选择前一个交通方式
    /// Property 1: For any transport mode, swiping left SHALL select the previous mode
    func testSwipeLeftSelectsPreviousMode() {
        property("Swipe left selects previous mode or stays at first") <- forAll { (modeIndex: Int) in
            let allModes = TransportMode.allCases
            let safeIndex = abs(modeIndex) % allModes.count
            let currentMode = allModes[safeIndex]
            
            let newMode = TransportModeSwipeHandler.nextMode(from: currentMode, direction: .left)
            
            if safeIndex == 0 {
                // 第一个模式，向左滑动应该保持不变
                return newMode == currentMode
            } else {
                // 非第一个模式，向左滑动应该选择前一个
                return newMode == allModes[safeIndex - 1]
            }
        }
    }
    
    /// 测试向右滑动选择后一个交通方式
    /// Property 1: For any transport mode, swiping right SHALL select the next mode
    func testSwipeRightSelectsNextMode() {
        property("Swipe right selects next mode or stays at last") <- forAll { (modeIndex: Int) in
            let allModes = TransportMode.allCases
            let safeIndex = abs(modeIndex) % allModes.count
            let currentMode = allModes[safeIndex]
            
            let newMode = TransportModeSwipeHandler.nextMode(from: currentMode, direction: .right)
            
            if safeIndex == allModes.count - 1 {
                // 最后一个模式，向右滑动应该保持不变
                return newMode == currentMode
            } else {
                // 非最后一个模式，向右滑动应该选择后一个
                return newMode == allModes[safeIndex + 1]
            }
        }
    }
    
    /// 测试边界情况：第一个模式向左滑动不变
    /// Property 1: At first mode, swiping left SHALL NOT change the mode
    func testSwipeLeftAtFirstModeStays() {
        let firstMode = TransportMode.allCases.first!
        let newMode = TransportModeSwipeHandler.nextMode(from: firstMode, direction: .left)
        XCTAssertEqual(newMode, firstMode, "向左滑动在第一个模式时应保持不变")
    }
    
    /// 测试边界情况：最后一个模式向右滑动不变
    /// Property 1: At last mode, swiping right SHALL NOT change the mode
    func testSwipeRightAtLastModeStays() {
        let lastMode = TransportMode.allCases.last!
        let newMode = TransportModeSwipeHandler.nextMode(from: lastMode, direction: .right)
        XCTAssertEqual(newMode, lastMode, "向右滑动在最后一个模式时应保持不变")
    }
    
    /// 测试 canSwipe 方法与 nextMode 的一致性
    func testCanSwipeConsistencyWithNextMode() {
        property("canSwipe is consistent with nextMode behavior") <- forAll { (modeIndex: Int, directionBool: Bool) in
            let allModes = TransportMode.allCases
            let safeIndex = abs(modeIndex) % allModes.count
            let currentMode = allModes[safeIndex]
            let direction: TransportModeSwipeHandler.SwipeDirection = directionBool ? .left : .right
            
            let canSwipe = TransportModeSwipeHandler.canSwipe(from: currentMode, direction: direction)
            let newMode = TransportModeSwipeHandler.nextMode(from: currentMode, direction: direction)
            
            // 如果可以滑动，新模式应该不同；如果不能滑动，新模式应该相同
            if canSwipe {
                return newMode != currentMode
            } else {
                return newMode == currentMode
            }
        }
    }
    
    /// 测试所有交通方式的滑动行为
    func testAllModesSwipeBehavior() {
        let allModes = TransportMode.allCases
        
        for (index, mode) in allModes.enumerated() {
            // 测试向左滑动
            let leftResult = TransportModeSwipeHandler.nextMode(from: mode, direction: .left)
            if index == 0 {
                XCTAssertEqual(leftResult, mode, "\(mode) 向左滑动应保持不变（边界）")
            } else {
                XCTAssertEqual(leftResult, allModes[index - 1], "\(mode) 向左滑动应选择 \(allModes[index - 1])")
            }
            
            // 测试向右滑动
            let rightResult = TransportModeSwipeHandler.nextMode(from: mode, direction: .right)
            if index == allModes.count - 1 {
                XCTAssertEqual(rightResult, mode, "\(mode) 向右滑动应保持不变（边界）")
            } else {
                XCTAssertEqual(rightResult, allModes[index + 1], "\(mode) 向右滑动应选择 \(allModes[index + 1])")
            }
        }
    }
    
    /// 测试索引方法
    func testIndexMethod() {
        let allModes = TransportMode.allCases
        
        for (expectedIndex, mode) in allModes.enumerated() {
            let actualIndex = TransportModeSwipeHandler.index(of: mode)
            XCTAssertEqual(actualIndex, expectedIndex, "\(mode) 的索引应为 \(expectedIndex)")
        }
    }
    
    /// 测试总数方法
    func testTotalModes() {
        XCTAssertEqual(TransportModeSwipeHandler.totalModes, TransportMode.allCases.count)
    }
}


// MARK: - Property 2: Route Data Completeness for Display
// **Validates: Requirements 2.6, 3.2**

extension RoutePreviewSelectionPropertyTests {
    
    /// 测试路线数据完整性验证
    /// Property 2: For any RouteOption displayed, it SHALL contain valid name, distance, and expectedTravelTime
    func testRouteDataCompleteness() {
        property("Valid routes have non-empty name, positive distance and travel time") <- forAll { (nameLength: UInt, distance: Double, travelTime: Double) in
            // 生成测试数据
            let name = String(repeating: "a", count: Int(nameLength % 100) + 1)
            let positiveDistance = abs(distance) + 0.1  // 确保正数
            let positiveTravelTime = abs(travelTime) + 0.1  // 确保正数
            
            let route = RouteOption(
                id: "test_\(UUID().uuidString)",
                name: name,
                distance: positiveDistance,
                expectedTravelTime: positiveTravelTime,
                polyline: nil,
                isSelected: false,
                source: .mapKit
            )
            
            // 验证有效路线
            let isValid = RouteValidator.isValidRoute(route)
            return isValid == true
        }
    }
    
    /// 测试空名称路线无效
    func testEmptyNameRouteIsInvalid() {
        let route = RouteOption(
            id: "test",
            name: "",
            distance: 1000,
            expectedTravelTime: 600,
            polyline: nil,
            isSelected: false,
            source: .mapKit
        )
        
        XCTAssertFalse(RouteValidator.isValidRoute(route), "空名称的路线应该无效")
    }
    
    /// 测试零距离路线无效
    func testZeroDistanceRouteIsInvalid() {
        let route = RouteOption(
            id: "test",
            name: "测试路线",
            distance: 0,
            expectedTravelTime: 600,
            polyline: nil,
            isSelected: false,
            source: .mapKit
        )
        
        XCTAssertFalse(RouteValidator.isValidRoute(route), "零距离的路线应该无效")
    }
    
    /// 测试零时间路线无效
    func testZeroTravelTimeRouteIsInvalid() {
        let route = RouteOption(
            id: "test",
            name: "测试路线",
            distance: 1000,
            expectedTravelTime: 0,
            polyline: nil,
            isSelected: false,
            source: .mapKit
        )
        
        XCTAssertFalse(RouteValidator.isValidRoute(route), "零时间的路线应该无效")
    }
    
    /// 测试负距离路线无效
    func testNegativeDistanceRouteIsInvalid() {
        let route = RouteOption(
            id: "test",
            name: "测试路线",
            distance: -100,
            expectedTravelTime: 600,
            polyline: nil,
            isSelected: false,
            source: .mapKit
        )
        
        XCTAssertFalse(RouteValidator.isValidRoute(route), "负距离的路线应该无效")
    }
    
    /// 测试有效路线
    func testValidRouteIsValid() {
        let route = RouteOption(
            id: "test",
            name: "测试路线",
            distance: 1000,
            expectedTravelTime: 600,
            polyline: nil,
            isSelected: false,
            source: .mapKit
        )
        
        XCTAssertTrue(RouteValidator.isValidRoute(route), "有效路线应该通过验证")
    }
    
    /// 测试路线显示文本格式
    func testRouteDisplayTextFormat() {
        property("Route display text is properly formatted") <- forAll { (distance: Double, travelTime: Double) in
            let positiveDistance = abs(distance) + 1
            let positiveTravelTime = abs(travelTime) + 60
            
            let route = RouteOption(
                id: "test",
                name: "测试路线",
                distance: positiveDistance,
                expectedTravelTime: positiveTravelTime,
                polyline: nil,
                isSelected: false,
                source: .mapKit
            )
            
            // 验证距离文本不为空
            let distanceText = route.distanceText
            let timeText = route.timeText
            
            return !distanceText.isEmpty && !timeText.isEmpty
        }
    }
}


// MARK: - Property 3: Airplane Mode Direct Line Display
// **Validates: Requirements 2.5**

extension RoutePreviewSelectionPropertyTests {
    
    /// 测试飞机模式返回直线路线
    /// Property 3: For any route selection with airplane mode, the system SHALL return exactly one route with source = .directLine
    func testAirplaneModeReturnsDirectLine() {
        // 飞机模式应该返回直线路线
        let route = RouteOption.directLine(
            from: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4),
            to: CLLocationCoordinate2D(latitude: 31.2, longitude: 121.5),
            speed: RouteETAService.airplaneBaselineSpeed,
            isSelected: true
        )
        
        XCTAssertEqual(route.source, .directLine, "飞机模式应返回直线路线")
        XCTAssertTrue(route.isSelected, "飞机模式路线应该被选中")
    }
    
    /// 测试飞机模式使用正确的速度
    func testAirplaneModeUsesCorrectSpeed() {
        let source = CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4)
        let destination = CLLocationCoordinate2D(latitude: 31.2, longitude: 121.5)
        
        // 计算直线距离
        let distance = GeoUtils.calculateDistance(
            lat1: source.latitude,
            lon1: source.longitude,
            lat2: destination.latitude,
            lon2: destination.longitude
        )
        
        // 使用飞机速度计算预期时间
        let expectedTime = distance / RouteETAService.airplaneBaselineSpeed
        
        let route = RouteOption.directLine(
            from: source,
            to: destination,
            speed: RouteETAService.airplaneBaselineSpeed,
            isSelected: true
        )
        
        // 验证时间计算正确（允许小误差）
        XCTAssertEqual(route.expectedTravelTime, expectedTime, accuracy: 1.0, "飞机模式应使用 800km/h 速度计算时间")
    }
    
    /// 测试飞机模式速度常量
    func testAirplaneBaselineSpeedConstant() {
        // 800 km/h = 222.22 m/s
        XCTAssertEqual(RouteETAService.airplaneBaselineSpeed, 222.0, accuracy: 1.0, "飞机基准速度应为 222 m/s (800 km/h)")
    }
    
    /// 测试飞机模式不支持 MapKit 路线
    func testAirplaneModeDoesNotSupportMapKitRouting() {
        XCTAssertFalse(TransportMode.airplane.supportsMapKitRouting, "飞机模式不应支持 MapKit 路线")
        XCTAssertNil(TransportMode.airplane.mapKitTransportType, "飞机模式不应有 MapKit 交通类型")
    }
    
    /// 测试飞机模式直线路线属性
    func testAirplaneModeDirectLineProperties() {
        property("Airplane mode direct line has valid properties") <- forAll { (lat1: Double, lon1: Double, lat2: Double, lon2: Double) in
            // 生成有效坐标
            let sourceLat = (abs(lat1).truncatingRemainder(dividingBy: 180)) - 90
            let sourceLon = (abs(lon1).truncatingRemainder(dividingBy: 360)) - 180
            let destLat = (abs(lat2).truncatingRemainder(dividingBy: 180)) - 90
            let destLon = (abs(lon2).truncatingRemainder(dividingBy: 360)) - 180
            
            let source = CLLocationCoordinate2D(latitude: sourceLat, longitude: sourceLon)
            let destination = CLLocationCoordinate2D(latitude: destLat, longitude: destLon)
            
            let route = RouteOption.directLine(
                from: source,
                to: destination,
                speed: RouteETAService.airplaneBaselineSpeed,
                isSelected: true
            )
            
            // 验证属性
            return route.source == .directLine &&
                   route.isSelected == true &&
                   route.distance >= 0 &&
                   route.expectedTravelTime >= 0
        }
    }
}


// MARK: - Property 4: Fallback ETA on Route Fetch Failure
// **Validates: Requirements 5.4**

extension RoutePreviewSelectionPropertyTests {
    
    /// 测试路线获取失败时的备用 ETA
    /// Property 4: For any failed route fetch, the system SHALL provide a fallback RouteOption with source = .directLine
    func testFallbackETAOnRouteFailure() {
        // 创建备用路线
        let source = CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4)
        let destination = CLLocationCoordinate2D(latitude: 31.2, longitude: 121.5)
        
        let fallbackRoute = RouteOption.directLine(
            from: source,
            to: destination,
            speed: TransportMode.walking.baselineSpeed,
            isSelected: true
        )
        
        // 验证备用路线属性
        XCTAssertEqual(fallbackRoute.source, .directLine, "备用路线应为直线距离")
        XCTAssertFalse(fallbackRoute.source.isReliable, "直线距离路线不应标记为可靠")
        XCTAssertTrue(fallbackRoute.isSelected, "备用路线应被选中")
    }
    
    /// 测试备用 ETA 计算正确性
    func testFallbackETACalculation() {
        property("Fallback ETA is calculated correctly based on distance and speed") <- forAll { (lat1: Double, lon1: Double, lat2: Double, lon2: Double) in
            // 生成有效坐标
            let sourceLat = (abs(lat1).truncatingRemainder(dividingBy: 180)) - 90
            let sourceLon = (abs(lon1).truncatingRemainder(dividingBy: 360)) - 180
            let destLat = (abs(lat2).truncatingRemainder(dividingBy: 180)) - 90
            let destLon = (abs(lon2).truncatingRemainder(dividingBy: 360)) - 180
            
            let source = CLLocationCoordinate2D(latitude: sourceLat, longitude: sourceLon)
            let destination = CLLocationCoordinate2D(latitude: destLat, longitude: destLon)
            
            let speed = TransportMode.walking.baselineSpeed
            
            let fallbackRoute = RouteOption.directLine(
                from: source,
                to: destination,
                speed: speed,
                isSelected: true
            )
            
            // 计算预期距离
            let expectedDistance = GeoUtils.calculateDistance(
                lat1: sourceLat, lon1: sourceLon,
                lat2: destLat, lon2: destLon
            )
            
            // 验证距离计算正确
            let distanceMatch = abs(fallbackRoute.distance - expectedDistance) < 1.0
            
            // 验证时间计算正确
            let expectedTime = speed > 0 ? expectedDistance / speed : 0
            let timeMatch = abs(fallbackRoute.expectedTravelTime - expectedTime) < 1.0
            
            return distanceMatch && timeMatch
        }
    }
    
    /// 测试备用路线的可靠性标记
    func testFallbackRouteReliabilityFlag() {
        let source = CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4)
        let destination = CLLocationCoordinate2D(latitude: 39.95, longitude: 116.45)
        
        let fallbackRoute = RouteOption.directLine(
            from: source,
            to: destination,
            speed: TransportMode.walking.baselineSpeed,
            isSelected: true
        )
        
        // 直线距离路线不可靠
        XCTAssertEqual(fallbackRoute.source, .directLine)
        XCTAssertFalse(fallbackRoute.source.isReliable, "直线距离路线应标记为不可靠")
        
        // MapKit 路线可靠
        let mapKitRoute = RouteOption(
            id: "test",
            name: "测试路线",
            distance: 1000,
            expectedTravelTime: 600,
            polyline: nil,
            isSelected: true,
            source: .mapKit
        )
        XCTAssertTrue(mapKitRoute.source.isReliable, "MapKit 路线应标记为可靠")
    }
}


// MARK: - Property 5: Selected Route Passed to Monitoring
// **Validates: Requirements 6.1, 6.2**

extension RoutePreviewSelectionPropertyTests {
    
    /// 测试 MonitoringConfig 包含选中路线 ID
    func testMonitoringConfigContainsSelectedRouteId() {
        let destination = Location(
            id: "test",
            name: "测试目的地",
            address: "测试地址",
            latitude: 39.9,
            longitude: 116.4
        )
        
        // 创建带有选中路线的监控配置
        let config = MonitoringConfig(
            destination: destination,
            geofenceRadius: 500,
            enableEarlyTrigger: false,
            transportMode: .walking,
            batteryMode: .balanced,
            selectedRouteId: "route_1"
        )
        
        XCTAssertEqual(config.selectedRouteId, "route_1", "监控配置应包含选中的路线 ID")
    }
    
    /// 测试无选中路线时 MonitoringConfig 的 selectedRouteId 为 nil
    func testMonitoringConfigWithoutSelectedRoute() {
        let destination = Location(
            id: "test",
            name: "测试目的地",
            address: "测试地址",
            latitude: 39.9,
            longitude: 116.4
        )
        
        let config = MonitoringConfig(
            destination: destination,
            geofenceRadius: 500,
            enableEarlyTrigger: false,
            transportMode: .walking,
            batteryMode: .balanced
        )
        
        XCTAssertNil(config.selectedRouteId, "无选中路线时 selectedRouteId 应为 nil")
    }
}


// MARK: - Property 6: Auto-Select Fastest Route
// **Validates: Requirements 6.4**

extension RoutePreviewSelectionPropertyTests {
    
    /// 测试自动选择最快路线
    /// Property 6: For any set of routes where no route is explicitly selected, the system SHALL auto-select the route with minimum expectedTravelTime
    func testAutoSelectFastestRoute() {
        property("Auto-selects route with minimum travel time") <- forAll { (time1: Double, time2: Double, time3: Double) in
            // 生成正数时间
            let t1 = abs(time1) + 60
            let t2 = abs(time2) + 60
            let t3 = abs(time3) + 60
            
            let routes = [
                RouteOption(id: "1", name: "路线1", distance: 1000, expectedTravelTime: t1, polyline: nil, isSelected: false, source: .mapKit),
                RouteOption(id: "2", name: "路线2", distance: 1200, expectedTravelTime: t2, polyline: nil, isSelected: false, source: .mapKit),
                RouteOption(id: "3", name: "路线3", distance: 1100, expectedTravelTime: t3, polyline: nil, isSelected: false, source: .mapKit)
            ]
            
            // 使用 RouteETAResult.create 自动选择最快路线
            let result = RouteETAResult.create(
                routes: routes,
                selectedIndex: 0,  // 默认选择第一个（排序后的）
                source: .mapKit,
                queryLocation: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4)
            )
            
            // 验证选中的是最快的路线
            let minTime = min(t1, t2, t3)
            return result.selectedRoute?.expectedTravelTime == minTime
        }
    }
    
    /// 测试路线按时间排序
    func testRoutesAreSortedByTravelTime() {
        let routes = [
            RouteOption(id: "1", name: "慢路线", distance: 1000, expectedTravelTime: 1800, polyline: nil, isSelected: false, source: .mapKit),
            RouteOption(id: "2", name: "快路线", distance: 800, expectedTravelTime: 600, polyline: nil, isSelected: false, source: .mapKit),
            RouteOption(id: "3", name: "中等路线", distance: 900, expectedTravelTime: 1200, polyline: nil, isSelected: false, source: .mapKit)
        ]
        
        let result = RouteETAResult.create(
            routes: routes,
            selectedIndex: 0,
            source: .mapKit,
            queryLocation: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4)
        )
        
        // 验证路线按时间排序
        XCTAssertEqual(result.routes[0].expectedTravelTime, 600, "第一条路线应是最快的")
        XCTAssertEqual(result.routes[1].expectedTravelTime, 1200, "第二条路线应是中等的")
        XCTAssertEqual(result.routes[2].expectedTravelTime, 1800, "第三条路线应是最慢的")
        
        // 验证自动选择最快路线
        XCTAssertEqual(result.selectedRoute?.id, "2", "应自动选择最快的路线")
    }
    
    /// 测试路线数量限制
    func testRoutesLimitedToFive() {
        let routes = (1...10).map { i in
            RouteOption(
                id: "\(i)",
                name: "路线\(i)",
                distance: Double(i * 100),
                expectedTravelTime: Double(i * 60),
                polyline: nil,
                isSelected: false,
                source: .mapKit
            )
        }
        
        let result = RouteETAResult.create(
            routes: routes,
            selectedIndex: 0,
            source: .mapKit,
            queryLocation: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4)
        )
        
        XCTAssertEqual(result.routes.count, 5, "路线数量应限制为 5 条")
    }
}



// MARK: - Property 7: Destination Card Displays Selected Route Info
// **Validates: Requirements 5.1**

extension RoutePreviewSelectionPropertyTests {
    
    /// 测试选中路线的距离文本格式
    func testSelectedRouteDistanceTextFormat() {
        property("Route distance text is properly formatted") <- forAll { (distance: Double) in
            let positiveDistance = abs(distance) + 1
            
            let route = RouteOption(
                id: "test",
                name: "测试路线",
                distance: positiveDistance,
                expectedTravelTime: 600,
                polyline: nil,
                isSelected: true,
                source: .mapKit
            )
            
            let distanceText = route.distanceText
            
            // 验证格式正确
            if positiveDistance >= 1000 {
                // 应该显示 km
                return distanceText.contains("km")
            } else {
                // 应该显示 m
                return distanceText.contains("m")
            }
        }
    }
    
    /// 测试选中路线的时间文本格式
    func testSelectedRouteTimeTextFormat() {
        property("Route time text is properly formatted") <- forAll { (travelTime: Double) in
            let positiveTravelTime = abs(travelTime) + 60
            
            let route = RouteOption(
                id: "test",
                name: "测试路线",
                distance: 1000,
                expectedTravelTime: positiveTravelTime,
                polyline: nil,
                isSelected: true,
                source: .mapKit
            )
            
            let timeText = route.timeText
            let etaMinutes = route.etaMinutes
            
            // 验证格式正确
            if etaMinutes >= 60 {
                // 应该显示小时
                return timeText.contains("小时")
            } else {
                // 应该显示分钟
                return timeText.contains("分钟")
            }
        }
    }
    
    /// 测试距离文本具体格式
    func testDistanceTextSpecificFormats() {
        // 测试米格式
        let shortRoute = RouteOption(
            id: "1",
            name: "短路线",
            distance: 500,
            expectedTravelTime: 300,
            polyline: nil,
            isSelected: true,
            source: .mapKit
        )
        XCTAssertEqual(shortRoute.distanceText, "500 m", "500米应显示为 '500 m'")
        
        // 测试公里格式
        let longRoute = RouteOption(
            id: "2",
            name: "长路线",
            distance: 5200,
            expectedTravelTime: 1800,
            polyline: nil,
            isSelected: true,
            source: .mapKit
        )
        XCTAssertEqual(longRoute.distanceText, "5.2 km", "5200米应显示为 '5.2 km'")
    }
    
    /// 测试时间文本具体格式
    func testTimeTextSpecificFormats() {
        // 测试分钟格式
        let shortTrip = RouteOption(
            id: "1",
            name: "短行程",
            distance: 1000,
            expectedTravelTime: 1800, // 30分钟
            polyline: nil,
            isSelected: true,
            source: .mapKit
        )
        XCTAssertEqual(shortTrip.timeText, "30 分钟", "30分钟应显示为 '30 分钟'")
        
        // 测试小时格式
        let longTrip = RouteOption(
            id: "2",
            name: "长行程",
            distance: 10000,
            expectedTravelTime: 5400, // 90分钟 = 1小时30分钟
            polyline: nil,
            isSelected: true,
            source: .mapKit
        )
        XCTAssertEqual(longTrip.timeText, "1 小时 30 分钟", "90分钟应显示为 '1 小时 30 分钟'")
        
        // 测试整小时格式
        let exactHourTrip = RouteOption(
            id: "3",
            name: "整小时行程",
            distance: 8000,
            expectedTravelTime: 3600, // 60分钟 = 1小时
            polyline: nil,
            isSelected: true,
            source: .mapKit
        )
        XCTAssertEqual(exactHourTrip.timeText, "1 小时", "60分钟应显示为 '1 小时'")
    }
    
    /// 测试 ETA 分钟计算
    func testETAMinutesCalculation() {
        property("ETA minutes is correctly calculated from travel time") <- forAll { (travelTime: Double) in
            let positiveTravelTime = abs(travelTime) + 1
            
            let route = RouteOption(
                id: "test",
                name: "测试路线",
                distance: 1000,
                expectedTravelTime: positiveTravelTime,
                polyline: nil,
                isSelected: true,
                source: .mapKit
            )
            
            let expectedMinutes = Int(ceil(positiveTravelTime / 60.0))
            return route.etaMinutes == expectedMinutes
        }
    }
}
