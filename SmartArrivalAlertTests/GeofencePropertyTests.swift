import XCTest
import SwiftCheck
import CoreLocation
@testable import SmartArrivalAlert

/// Property 5: 地理围栏触发正确性
/// Property 6: 围栏半径有效范围
/// 验证: 需求 3.2, 3.3
final class GeofencePropertyTests: XCTestCase {
    
    // MARK: - Property 5: 地理围栏触发正确性
    
    /// Property 5: 地理围栏触发正确性
    /// Feature: smart-arrival-alert, Property 5: 地理围栏触发正确性
    /// 对于任意位置和围栏配置，当用户位置进入围栏半径内时应触发提醒
    func testGeofenceTriggerCorrectness() {
        // 测试在围栏内的情况
        let center = CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
        let radius = 200.0
        
        // 在围栏中心
        XCTAssertTrue(GeoUtils.isInsideGeofence(
            currentLocation: center,
            center: center,
            radius: radius
        ), "围栏中心应该在围栏内")
        
        // 在围栏边界内（150米）
        let insideLocation = offsetCoordinate(center, distanceMeters: 150, bearing: 0)
        XCTAssertTrue(GeoUtils.isInsideGeofence(
            currentLocation: insideLocation,
            center: center,
            radius: radius
        ), "150米处应该在200米围栏内")
        
        // 在围栏边界外（250米）
        let outsideLocation = offsetCoordinate(center, distanceMeters: 250, bearing: 0)
        XCTAssertFalse(GeoUtils.isInsideGeofence(
            currentLocation: outsideLocation,
            center: center,
            radius: radius
        ), "250米处应该在200米围栏外")
    }
    
    /// 属性测试：围栏触发的正确性
    func testGeofenceTriggerProperty() {
        property("Geofence trigger is correct based on distance") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            
            // 生成随机围栏中心
            let centerLat = random.nextDouble(min: -85, max: 85)
            let centerLon = random.nextDouble(min: -180, max: 180)
            
            // 生成有效的围栏半径
            let radius = random.nextDouble(min: GeoUtils.minGeofenceRadius, max: GeoUtils.maxGeofenceRadius)
            
            // 生成测试点距离（0到2倍半径）
            let testDistance = random.nextDouble(min: 0, max: radius * 2)
            let bearing = random.nextDouble(min: 0, max: 360)
            
            // 计算测试点坐标
            let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
            let testPoint = self.offsetCoordinate(center, distanceMeters: testDistance, bearing: bearing)
            
            // 验证围栏判断
            let isInside = GeoUtils.isInsideGeofence(
                currentLocation: testPoint,
                center: center,
                radius: radius
            )
            
            // 计算实际距离
            let actualDistance = GeoUtils.calculateDistance(from: center, to: testPoint)
            
            // 允许一定的误差（由于坐标偏移计算的近似性）
            let tolerance = 10.0 // 10米误差容忍
            
            if testDistance <= radius - tolerance {
                return isInside == true
            } else if testDistance >= radius + tolerance {
                return isInside == false
            } else {
                // 边界情况，两种结果都可接受
                return true
            }
        }
    }
    
    /// 测试围栏进入检测
    func testGeofenceEntryDetection() {
        let center = CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
        let radius = 200.0
        
        // 从外部进入
        let outsideLocation = offsetCoordinate(center, distanceMeters: 300, bearing: 0)
        let insideLocation = offsetCoordinate(center, distanceMeters: 100, bearing: 0)
        
        XCTAssertTrue(GeoUtils.didEnterGeofence(
            previousLocation: outsideLocation,
            currentLocation: insideLocation,
            center: center,
            radius: radius
        ), "从外部移动到内部应该触发进入事件")
        
        // 从内部移动到内部
        let anotherInsideLocation = offsetCoordinate(center, distanceMeters: 150, bearing: 90)
        XCTAssertFalse(GeoUtils.didEnterGeofence(
            previousLocation: insideLocation,
            currentLocation: anotherInsideLocation,
            center: center,
            radius: radius
        ), "在内部移动不应该触发进入事件")
        
        // 从外部移动到外部
        let anotherOutsideLocation = offsetCoordinate(center, distanceMeters: 350, bearing: 90)
        XCTAssertFalse(GeoUtils.didEnterGeofence(
            previousLocation: outsideLocation,
            currentLocation: anotherOutsideLocation,
            center: center,
            radius: radius
        ), "在外部移动不应该触发进入事件")
    }
    
    /// 属性测试：围栏进入检测的正确性
    func testGeofenceEntryProperty() {
        property("Geofence entry is detected correctly") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            
            let centerLat = random.nextDouble(min: -85, max: 85)
            let centerLon = random.nextDouble(min: -180, max: 180)
            let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
            let radius = random.nextDouble(min: GeoUtils.minGeofenceRadius, max: GeoUtils.maxGeofenceRadius)
            
            // 生成明确在外部的点
            let outsideDistance = radius * 1.5
            let outsidePoint = self.offsetCoordinate(center, distanceMeters: outsideDistance, bearing: 0)
            
            // 生成明确在内部的点
            let insideDistance = radius * 0.5
            let insidePoint = self.offsetCoordinate(center, distanceMeters: insideDistance, bearing: 0)
            
            // 从外部进入内部应该触发
            let didEnter = GeoUtils.didEnterGeofence(
                previousLocation: outsidePoint,
                currentLocation: insidePoint,
                center: center,
                radius: radius
            )
            
            // 从内部到内部不应该触发
            let anotherInsidePoint = self.offsetCoordinate(center, distanceMeters: insideDistance, bearing: 90)
            let didNotEnter = !GeoUtils.didEnterGeofence(
                previousLocation: insidePoint,
                currentLocation: anotherInsidePoint,
                center: center,
                radius: radius
            )
            
            return didEnter && didNotEnter
        }
    }
    
    // MARK: - Property 6: 围栏半径有效范围
    
    /// Property 6: 围栏半径有效范围
    /// Feature: smart-arrival-alert, Property 6: 围栏半径有效范围
    /// 围栏半径必须在 100-1000 米范围内
    func testGeofenceRadiusValidRange() {
        // 有效范围内
        XCTAssertTrue(GeoUtils.isValidGeofenceRadius(100), "100米应该有效")
        XCTAssertTrue(GeoUtils.isValidGeofenceRadius(500), "500米应该有效")
        XCTAssertTrue(GeoUtils.isValidGeofenceRadius(1000), "1000米应该有效")
        
        // 无效范围
        XCTAssertFalse(GeoUtils.isValidGeofenceRadius(50), "50米应该无效")
        XCTAssertFalse(GeoUtils.isValidGeofenceRadius(99), "99米应该无效")
        XCTAssertFalse(GeoUtils.isValidGeofenceRadius(1001), "1001米应该无效")
        XCTAssertFalse(GeoUtils.isValidGeofenceRadius(2000), "2000米应该无效")
    }
    
    /// 属性测试：围栏半径验证
    func testGeofenceRadiusValidationProperty() {
        property("Geofence radius validation is correct") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let radius = random.nextDouble(min: 0, max: 2000)
            
            let isValid = GeoUtils.isValidGeofenceRadius(radius)
            let expectedValid = radius >= GeoUtils.minGeofenceRadius && radius <= GeoUtils.maxGeofenceRadius
            
            return isValid == expectedValid
        }
    }
    
    /// 测试围栏半径限制
    func testGeofenceRadiusClamping() {
        // 小于最小值
        XCTAssertEqual(GeoUtils.clampGeofenceRadius(50), GeoUtils.minGeofenceRadius)
        
        // 大于最大值
        XCTAssertEqual(GeoUtils.clampGeofenceRadius(1500), GeoUtils.maxGeofenceRadius)
        
        // 在有效范围内
        XCTAssertEqual(GeoUtils.clampGeofenceRadius(500), 500)
    }
    
    /// 属性测试：围栏半径限制
    func testGeofenceRadiusClampingProperty() {
        property("Clamped radius is always valid") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            let radius = random.nextDouble(min: -1000, max: 5000)
            
            let clamped = GeoUtils.clampGeofenceRadius(radius)
            
            return GeoUtils.isValidGeofenceRadius(clamped)
        }
    }
    
    // MARK: - Distance Calculation Tests
    
    /// 测试距离计算的正确性
    func testDistanceCalculation() {
        // 北京到上海的大致距离（约1000公里）
        let beijing = CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
        let shanghai = CLLocationCoordinate2D(latitude: 31.2304, longitude: 121.4737)
        
        let distance = GeoUtils.calculateDistance(from: beijing, to: shanghai)
        
        // 允许5%的误差
        XCTAssertGreaterThan(distance, 1000000, "北京到上海应该超过1000公里")
        XCTAssertLessThan(distance, 1200000, "北京到上海应该小于1200公里")
    }
    
    /// 测试同一点的距离为0
    func testSamePointDistance() {
        let point = CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
        let distance = GeoUtils.calculateDistance(from: point, to: point)
        
        XCTAssertEqual(distance, 0, accuracy: 0.001, "同一点的距离应该为0")
    }
    
    /// 属性测试：距离计算的对称性
    func testDistanceSymmetryProperty() {
        property("Distance calculation is symmetric") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            
            let lat1 = random.nextDouble(min: -85, max: 85)
            let lon1 = random.nextDouble(min: -180, max: 180)
            let lat2 = random.nextDouble(min: -85, max: 85)
            let lon2 = random.nextDouble(min: -180, max: 180)
            
            let point1 = CLLocationCoordinate2D(latitude: lat1, longitude: lon1)
            let point2 = CLLocationCoordinate2D(latitude: lat2, longitude: lon2)
            
            let distance1 = GeoUtils.calculateDistance(from: point1, to: point2)
            let distance2 = GeoUtils.calculateDistance(from: point2, to: point1)
            
            // 允许微小的浮点误差
            return abs(distance1 - distance2) < 0.001
        }
    }
    
    /// 属性测试：距离总是非负的
    func testDistanceNonNegativeProperty() {
        property("Distance is always non-negative") <- forAll { (seed: Int) in
            let random = SeededRandom(seed: seed)
            
            let lat1 = random.nextDouble(min: -85, max: 85)
            let lon1 = random.nextDouble(min: -180, max: 180)
            let lat2 = random.nextDouble(min: -85, max: 85)
            let lon2 = random.nextDouble(min: -180, max: 180)
            
            let distance = GeoUtils.calculateDistance(
                lat1: lat1, lon1: lon1,
                lat2: lat2, lon2: lon2
            )
            
            return distance >= 0
        }
    }
    
    // MARK: - Coordinate Validation Tests
    
    /// 测试坐标验证
    func testCoordinateValidation() {
        // 有效坐标
        XCTAssertTrue(GeoUtils.isValidCoordinate(latitude: 0, longitude: 0))
        XCTAssertTrue(GeoUtils.isValidCoordinate(latitude: 90, longitude: 180))
        XCTAssertTrue(GeoUtils.isValidCoordinate(latitude: -90, longitude: -180))
        
        // 无效坐标
        XCTAssertFalse(GeoUtils.isValidCoordinate(latitude: 91, longitude: 0))
        XCTAssertFalse(GeoUtils.isValidCoordinate(latitude: -91, longitude: 0))
        XCTAssertFalse(GeoUtils.isValidCoordinate(latitude: 0, longitude: 181))
        XCTAssertFalse(GeoUtils.isValidCoordinate(latitude: 0, longitude: -181))
    }
    
    // MARK: - Helper Methods
    
    /// 根据距离和方位角偏移坐标
    /// - Parameters:
    ///   - coordinate: 原始坐标
    ///   - distanceMeters: 偏移距离（米）
    ///   - bearing: 方位角（度，北为0）
    /// - Returns: 偏移后的坐标
    private func offsetCoordinate(_ coordinate: CLLocationCoordinate2D, distanceMeters: Double, bearing: Double) -> CLLocationCoordinate2D {
        let earthRadius = GeoUtils.earthRadius
        let angularDistance = distanceMeters / earthRadius
        
        let bearingRad = bearing * .pi / 180
        let lat1 = coordinate.latitude * .pi / 180
        let lon1 = coordinate.longitude * .pi / 180
        
        let lat2 = asin(sin(lat1) * cos(angularDistance) + cos(lat1) * sin(angularDistance) * cos(bearingRad))
        let lon2 = lon1 + atan2(sin(bearingRad) * sin(angularDistance) * cos(lat1),
                                cos(angularDistance) - sin(lat1) * sin(lat2))
        
        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }
}
