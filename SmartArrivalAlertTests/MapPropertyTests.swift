import XCTest
import SwiftCheck
import CoreLocation
import MapKit
@testable import SmartArrivalAlert

/// 地图功能属性测试
final class MapPropertyTests: XCTestCase {
    
    // MARK: - Property 5: Map Region Fitting
    
    /// **Feature: map-integration, Property 5: Map Region Fitting**
    /// *For any* two coordinate points, the calculated map region should contain both points within its visible bounds.
    /// **Validates: Requirements 3.4**
    func testRegionContainsBothCoordinates() {
        let expectation = XCTestExpectation(description: "Property test completed")
        
        DispatchQueue.global().async {
            property("Region contains both coordinates") <- forAll(
                CoordinateGenerator.arbitrary,
                CoordinateGenerator.arbitrary
            ) { (coord1: CoordinateGenerator, coord2: CoordinateGenerator) in
                let c1 = CLLocationCoordinate2D(latitude: coord1.latitude, longitude: coord1.longitude)
                let c2 = CLLocationCoordinate2D(latitude: coord2.latitude, longitude: coord2.longitude)
                
                let region = MKCoordinateRegion.containing(c1, c2, padding: 1.5)
                
                // 验证两个坐标都在区域内
                let containsFirst = region.contains(c1)
                let containsSecond = region.contains(c2)
                
                return containsFirst && containsSecond
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60.0)
    }
    
    /// 测试区域中心点计算正确
    func testRegionCenterIsMiddlePoint() {
        let expectation = XCTestExpectation(description: "Property test completed")
        
        DispatchQueue.global().async {
            property("Region center is middle of two points") <- forAll(
                CoordinateGenerator.arbitrary,
                CoordinateGenerator.arbitrary
            ) { (coord1: CoordinateGenerator, coord2: CoordinateGenerator) in
                let c1 = CLLocationCoordinate2D(latitude: coord1.latitude, longitude: coord1.longitude)
                let c2 = CLLocationCoordinate2D(latitude: coord2.latitude, longitude: coord2.longitude)
                
                let region = MKCoordinateRegion.containing(c1, c2, padding: 1.5)
                
                let expectedCenterLat = (c1.latitude + c2.latitude) / 2
                let expectedCenterLon = (c1.longitude + c2.longitude) / 2
                
                let latDiff = abs(region.center.latitude - expectedCenterLat)
                let lonDiff = abs(region.center.longitude - expectedCenterLon)
                
                // 允许微小误差
                return latDiff < 0.0001 && lonDiff < 0.0001
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60.0)
    }
    
    /// 测试单点区域包含该点
    func testCenteredRegionContainsPoint() {
        let expectation = XCTestExpectation(description: "Property test completed")
        
        DispatchQueue.global().async {
            property("Centered region contains the center point") <- forAll(
                CoordinateGenerator.arbitrary
            ) { (coord: CoordinateGenerator) in
                let c = CLLocationCoordinate2D(latitude: coord.latitude, longitude: coord.longitude)
                let region = MKCoordinateRegion.centered(on: c, span: 0.01)
                
                return region.contains(c)
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60.0)
    }
    
    // MARK: - Property 6: Preview Map Configuration
    
    /// **Feature: map-integration, Property 6: Preview Map Configuration**
    /// *For any* selected destination with a geofence radius, the map preview should display a marker at the destination coordinates and a circle overlay with the specified radius.
    /// **Validates: Requirements 4.2**
    func testGeofenceCircleConfiguration() {
        let expectation = XCTestExpectation(description: "Property test completed")
        
        DispatchQueue.global().async {
            property("Geofence circle has correct center and radius") <- forAll(
                LocationGenerator.arbitrary,
                Gen.fromElements(in: 100...1000)
            ) { (locGen: LocationGenerator, radius: Int) in
                let location = locGen.location
                let circle = GeofenceCircleData.from(location: location, radius: radius)
                
                // 验证圆心坐标正确
                let centerCorrect = circle.center.latitude == location.latitude &&
                                   circle.center.longitude == location.longitude
                
                // 验证半径正确
                let radiusCorrect = circle.radius == CLLocationDistance(radius)
                
                return centerCorrect && radiusCorrect
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60.0)
    }
    
    /// 测试目的地标注创建正确
    func testDestinationAnnotationCreation() {
        let expectation = XCTestExpectation(description: "Property test completed")
        
        DispatchQueue.global().async {
            property("Destination annotation has correct coordinates") <- forAll(
                LocationGenerator.arbitrary
            ) { (locGen: LocationGenerator) in
                let location = locGen.location
                let annotation = MapAnnotationItem.destination(from: location)
                
                // 验证坐标正确
                let coordCorrect = annotation.coordinate.latitude == location.latitude &&
                                  annotation.coordinate.longitude == location.longitude
                
                // 验证类型正确
                let typeCorrect = annotation.type == .destination
                
                // 验证标题正确
                let titleCorrect = annotation.title == location.name
                
                return coordCorrect && typeCorrect && titleCorrect
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60.0)
    }
}

// MARK: - Coordinate Generator

/// 坐标生成器
struct CoordinateGenerator: Arbitrary {
    let latitude: Double
    let longitude: Double
    
    static var arbitrary: Gen<CoordinateGenerator> {
        return Gen<CoordinateGenerator>.compose { c in
            // 生成有效的经纬度范围
            let lat = c.generate(using: Gen.fromElements(in: -85.0...85.0))
            let lon = c.generate(using: Gen.fromElements(in: -180.0...180.0))
            return CoordinateGenerator(latitude: lat, longitude: lon)
        }
    }
}

// MARK: - Location Generator

/// Location 生成器
struct LocationGenerator: Arbitrary {
    let location: Location
    
    static var arbitrary: Gen<LocationGenerator> {
        return Gen<LocationGenerator>.compose { c in
            let lat = c.generate(using: Gen.fromElements(in: -85.0...85.0))
            let lon = c.generate(using: Gen.fromElements(in: -180.0...180.0))
            let id = c.generate(using: Gen.pure(UUID().uuidString))
            let name = c.generate(using: Gen.pure("Location_\(Int.random(in: 0...1000))"))
            let address = c.generate(using: Gen.pure("Address_\(Int.random(in: 0...1000))"))
            
            let location = Location(
                id: id,
                name: name,
                address: address,
                latitude: lat,
                longitude: lon,
                isFavorite: false
            )
            return LocationGenerator(location: location)
        }
    }
}


// MARK: - Property 3: Reverse Geocoding Fallback Tests

extension MapPropertyTests {
    
    /// **Feature: map-integration, Property 3: Reverse Geocoding Fallback**
    /// *For any* coordinate pair where reverse geocoding fails, the resulting location name should contain the formatted coordinates in the pattern "选定位置 (lat, lon)".
    /// **Validates: Requirements 2.3, 2.4**
    func testGeocodingFallbackFormat() {
        let expectation = XCTestExpectation(description: "Property test completed")
        
        DispatchQueue.global().async {
            property("Fallback format contains coordinates") <- forAll(
                CoordinateGenerator.arbitrary
            ) { (coord: CoordinateGenerator) in
                let geocodingService = GeocodingService()
                
                // formatCoordinateName 是 nonisolated，可以直接调用
                let result = geocodingService.formatCoordinateName(
                    latitude: coord.latitude,
                    longitude: coord.longitude
                )
                
                // 验证格式
                let hasPrefix = result.hasPrefix("选定位置")
                let containsLat = result.contains(String(format: "%.4f", coord.latitude))
                let containsLon = result.contains(String(format: "%.4f", coord.longitude))
                
                return hasPrefix && containsLat && containsLon
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60.0)
    }
    
    /// 测试格式化坐标名称的格式正确
    func testCoordinateNameFormat() {
        // 测试具体示例
        let testCases: [(Double, Double, String)] = [
            (39.9042, 116.4074, "选定位置 (39.9042, 116.4074)"),
            (31.2304, 121.4737, "选定位置 (31.2304, 121.4737)"),
            (-33.8688, 151.2093, "选定位置 (-33.8688, 151.2093)"),
            (0.0, 0.0, "选定位置 (0.0000, 0.0000)"),
        ]
        
        let geocodingService = GeocodingService()
        
        for (lat, lon, expected) in testCases {
            let result = geocodingService.formatCoordinateName(latitude: lat, longitude: lon)
            XCTAssertEqual(result, expected, "坐标 (\(lat), \(lon)) 格式化结果不正确")
        }
    }
}
