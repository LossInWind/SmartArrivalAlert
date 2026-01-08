import XCTest
import SwiftCheck
import CoreLocation
import MapKit
@testable import SmartArrivalAlert

/// 地图增强功能属性测试
/// **Feature: map-enhancements**
final class MapEnhancementsPropertyTests: XCTestCase {
    
    // MARK: - Property 1: POI to Location Conversion Preserves Coordinates
    
    /// **Feature: map-enhancements, Property 1: POI to Location Conversion Preserves Coordinates**
    /// *For any* POISelection with valid coordinates and name, converting it to a Location object
    /// SHALL produce a Location with identical latitude, longitude, and name values.
    /// **Validates: Requirements 1.3**
    func testPOIToLocationConversionPreservesCoordinates() {
        let expectation = XCTestExpectation(description: "Property test completed")
        
        DispatchQueue.global().async {
            property("POI to Location conversion preserves coordinates and name") <- forAll(
                POISelectionGenerator.arbitrary
            ) { (poiGen: POISelectionGenerator) in
                let poi = poiGen.poi
                let location = poi.toLocation()
                
                // 验证坐标保持不变
                let latitudePreserved = location.latitude == poi.coordinate.latitude
                let longitudePreserved = location.longitude == poi.coordinate.longitude
                
                // 验证名称保持不变
                let namePreserved = location.name == poi.name
                
                // 验证地址处理正确（nil 变为 "未知地址"）
                let addressCorrect: Bool
                if let poiAddress = poi.address {
                    addressCorrect = location.address == poiAddress
                } else {
                    addressCorrect = location.address == "未知地址"
                }
                
                return latitudePreserved && longitudePreserved && namePreserved && addressCorrect
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60.0)
    }
    
    // MARK: - Property 4: ETA Calculation Formula
    
    /// **Feature: map-enhancements, Property 4: ETA Calculation Formula**
    /// *For any* distance > 0 and speed > 0, the ETACalculator SHALL compute estimatedMinutes
    /// as approximately (distance / speed / 60).
    /// **Validates: Requirements 4.1**
    func testETACalculationFormula() {
        let expectation = XCTestExpectation(description: "Property test completed")
        
        DispatchQueue.global().async {
            property("ETA calculation follows distance/speed/60 formula") <- forAll(
                Gen.fromElements(in: 100.0...10000.0),  // distance in meters
                Gen.fromElements(in: 1.0...30.0)        // speed in m/s
            ) { (distance: Double, speed: Double) in
                let calculator = ETACalculator()
                let result = calculator.calculateETA(
                    distance: distance,
                    currentSpeed: speed,
                    signalQuality: .good
                )
                
                guard let minutes = result.estimatedMinutes else {
                    return false
                }
                
                // 计算预期分钟数
                let expectedMinutes = Int(ceil(distance / speed / 60.0))
                
                // 允许 1 分钟误差（由于平滑和取整）
                return abs(minutes - expectedMinutes) <= 1
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60.0)
    }
    
    // MARK: - Property 5: Stationary User ETA Handling
    
    /// **Feature: map-enhancements, Property 5: Stationary User ETA Handling**
    /// *For any* speed value <= 0.5 m/s (approximately stationary), the ETACalculator
    /// SHALL return nil for estimatedMinutes and displayText SHALL be "计算中...".
    /// **Validates: Requirements 4.2**
    func testStationaryUserETAHandling() {
        let expectation = XCTestExpectation(description: "Property test completed")
        
        DispatchQueue.global().async {
            property("Stationary user gets calculating status") <- forAll(
                Gen.fromElements(in: 0.0...0.5),        // stationary speed
                Gen.fromElements(in: 100.0...10000.0)   // any distance
            ) { (speed: Double, distance: Double) in
                let calculator = ETACalculator()
                let result = calculator.calculateETA(
                    distance: distance,
                    currentSpeed: speed,
                    signalQuality: .good
                )
                
                // 静止时应返回 nil 和 "计算中..."
                let minutesIsNil = result.estimatedMinutes == nil
                let displayTextCorrect = result.displayText == "计算中..."
                
                return minutesIsNil && displayTextCorrect
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60.0)
    }
    
    // MARK: - Property 6: Signal Quality Confidence Mapping
    
    /// **Feature: map-enhancements, Property 6: Signal Quality Confidence Mapping**
    /// *For any* SignalQualityLevel, the ETACalculator confidence factor SHALL be:
    /// good → 1.0, fair → 0.8, poor → 0.5, unknown → 0.3.
    /// **Validates: Requirements 4.3**
    func testSignalQualityConfidenceMapping() {
        let calculator = ETACalculator()
        
        // 测试所有信号质量等级的置信度映射
        XCTAssertEqual(calculator.confidenceFactor(for: .good), 1.0, "Good signal should have confidence 1.0")
        XCTAssertEqual(calculator.confidenceFactor(for: .fair), 0.8, "Fair signal should have confidence 0.8")
        XCTAssertEqual(calculator.confidenceFactor(for: .poor), 0.5, "Poor signal should have confidence 0.5")
        XCTAssertEqual(calculator.confidenceFactor(for: .unknown), 0.3, "Unknown signal should have confidence 0.3")
    }
    
    // MARK: - Property 7: Speed Smoothing with Moving Average
    
    /// **Feature: map-enhancements, Property 7: Speed Smoothing with Moving Average**
    /// *For any* sequence of speed samples, the smoothedSpeed SHALL be the average
    /// of the most recent N samples (where N <= maxHistorySize).
    /// **Validates: Requirements 4.4**
    func testSpeedSmoothingWithMovingAverage() {
        let expectation = XCTestExpectation(description: "Property test completed")
        
        DispatchQueue.global().async {
            property("Smoothed speed is moving average of recent samples") <- forAll(
                Gen.fromElements(of: Array(1...10)).flatMap { count in
                    Gen<[Double]>.compose { c in
                        (0..<count).map { _ in c.generate(using: Gen.fromElements(in: 0.5...20.0)) }
                    }
                }
            ) { (speeds: [Double]) in
                let calculator = ETACalculator()
                
                var lastSmoothed: Double = 0
                for speed in speeds {
                    lastSmoothed = calculator.smoothedSpeed(currentSpeed: speed)
                }
                
                // 计算预期的移动平均（最多 5 个样本）
                let recentSpeeds = Array(speeds.suffix(5))
                let expectedAverage = recentSpeeds.reduce(0, +) / Double(recentSpeeds.count)
                
                // 允许微小误差
                return abs(lastSmoothed - expectedAverage) < 0.0001
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60.0)
    }
    
    // MARK: - Property 8: Reliability Threshold
    
    /// **Feature: map-enhancements, Property 8: Reliability Threshold**
    /// *For any* ETAResult with confidence < 0.6, the isReliable property SHALL be false;
    /// for confidence >= 0.6, isReliable SHALL be true.
    /// **Validates: Requirements 4.5, 3.4**
    func testReliabilityThreshold() {
        let expectation = XCTestExpectation(description: "Property test completed")
        
        DispatchQueue.global().async {
            property("Reliability threshold is 0.6") <- forAll(
                Gen.fromElements(in: 0.0...1.0)
            ) { (confidence: Double) in
                let result = ETAResult.withMinutes(10, confidence: confidence)
                
                let expectedReliable = confidence >= 0.6
                return result.isReliable == expectedReliable
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 60.0)
    }
    
    // MARK: - Property 9: Map Style Persistence Round-Trip
    
    /// **Feature: map-enhancements, Property 9: Map Style Persistence Round-Trip**
    /// *For any* MapStyle value, saving it to UserDefaults and then loading it
    /// SHALL return the same MapStyle value.
    /// **Validates: Requirements 5.6**
    func testMapStylePersistenceRoundTrip() {
        // 测试所有地图样式的持久化往返
        for style in MapDisplayStyle.allCases {
            // 保存
            UserDefaults.standard.set(style.rawValue, forKey: "test_map_style")
            
            // 加载
            let savedValue = UserDefaults.standard.string(forKey: "test_map_style")
            let loadedStyle = MapDisplayStyle(rawValue: savedValue ?? "")
            
            XCTAssertEqual(loadedStyle, style, "Map style \(style) should round-trip correctly")
        }
        
        // 清理
        UserDefaults.standard.removeObject(forKey: "test_map_style")
    }
    
    // MARK: - Property 10: Map Style to MapKit Style Conversion
    
    /// **Feature: map-enhancements, Property 10: Map Style to MapKit Style Conversion**
    /// *For any* MapStyle enum case, the mapKitStyle computed property SHALL return
    /// a valid MapKit.MapStyle that corresponds to the intended display mode.
    /// **Validates: Requirements 5.2, 5.3, 5.4, 5.5**
    @available(iOS 17.0, *)
    func testMapStyleToMapKitStyleConversion() {
        // 验证每种样式都能正确转换
        for style in MapDisplayStyle.allCases {
            // 这个测试主要验证转换不会崩溃
            let _ = style.mapKitStyle
            
            // 验证显示名称和图标存在
            XCTAssertFalse(style.displayName.isEmpty, "Display name should not be empty for \(style)")
            XCTAssertFalse(style.icon.isEmpty, "Icon should not be empty for \(style)")
        }
        
        // 验证特定样式的属性
        XCTAssertEqual(MapDisplayStyle.explore.displayName, "探索")
        XCTAssertEqual(MapDisplayStyle.driving.displayName, "驾车")
        XCTAssertEqual(MapDisplayStyle.transit.displayName, "公交")
        XCTAssertEqual(MapDisplayStyle.satellite.displayName, "卫星")
        
        XCTAssertEqual(MapDisplayStyle.explore.icon, "map")
        XCTAssertEqual(MapDisplayStyle.driving.icon, "car")
        XCTAssertEqual(MapDisplayStyle.transit.icon, "bus")
        XCTAssertEqual(MapDisplayStyle.satellite.icon, "globe")
    }
}

// MARK: - POISelection Generator

/// POISelection 生成器
struct POISelectionGenerator: Arbitrary {
    let poi: POISelection
    
    static var arbitrary: Gen<POISelectionGenerator> {
        return Gen<POISelectionGenerator>.compose { c in
            let lat = c.generate(using: Gen.fromElements(in: -85.0...85.0))
            let lon = c.generate(using: Gen.fromElements(in: -180.0...180.0))
            let name = c.generate(using: Gen.pure("POI_\(Int.random(in: 0...1000))"))
            let hasAddress = c.generate(using: Gen.fromElements(of: [true, false]))
            let address: String? = hasAddress ? "Address_\(Int.random(in: 0...1000))" : nil
            let hasCategory = c.generate(using: Gen.fromElements(of: [true, false]))
            let category: String? = hasCategory ? "Category_\(Int.random(in: 0...100))" : nil
            
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let poi = POISelection(
                coordinate: coordinate,
                name: name,
                address: address,
                category: category
            )
            return POISelectionGenerator(poi: poi)
        }
    }
}
