import XCTest
import SwiftCheck
@testable import SmartArrivalAlert

/// Live Activity 格式化工具属性测试
/// Feature: live-activity-enhancement
final class LiveActivityPropertyTests: XCTestCase {
    
    // MARK: - Property 1: Distance Formatting
    // *For any* distance value in meters, the formatted string SHALL:
    // - Display as "Xm" when distance < 1000
    // - Display as "X.Xkm" (one decimal place) when distance >= 1000
    // **Validates: Requirements 2.2, 3.2**
    
    func testDistanceFormattingMeters() {
        // Feature: live-activity-enhancement, Property 1: Distance Formatting
        // Validates: Requirements 2.2, 3.2
        property("Distance < 1000m should be formatted in meters") <- forAll(Gen.choose((0, 999))) { (distance: Int) in
            let formatted = LiveActivityFormatters.formatDistance(distance)
            
            // 应该以 " m" 结尾
            guard formatted.hasSuffix(" m") else { return false }
            
            // 提取数字部分
            let numberPart = formatted.dropLast(2) // 移除 " m"
            guard let parsedDistance = Int(numberPart) else { return false }
            
            // 数字应该与输入一致
            return parsedDistance == distance
        }
    }
    
    func testDistanceFormattingKilometers() {
        // Feature: live-activity-enhancement, Property 1: Distance Formatting
        // Validates: Requirements 2.2, 3.2
        property("Distance >= 1000m should be formatted in kilometers") <- forAll(Gen.choose((1000, 100000))) { (distance: Int) in
            let formatted = LiveActivityFormatters.formatDistance(distance)
            
            // 应该以 " km" 结尾
            guard formatted.hasSuffix(" km") else { return false }
            
            // 提取数字部分
            let numberPart = formatted.dropLast(3) // 移除 " km"
            guard let parsedKm = Double(numberPart) else { return false }
            
            // 转换回米并验证（允许四舍五入误差）
            let expectedKm = Double(distance) / 1000.0
            let roundedExpected = (expectedKm * 10).rounded() / 10 // 保留一位小数
            
            return abs(parsedKm - roundedExpected) < 0.01
        }
    }
    
    func testCompactDistanceFormattingMeters() {
        // Feature: live-activity-enhancement, Property 1: Distance Formatting
        // Validates: Requirements 2.2, 3.2
        property("Compact distance < 1000m should be formatted without space") <- forAll(Gen.choose((0, 999))) { (distance: Int) in
            let formatted = LiveActivityFormatters.formatCompactDistance(distance)
            
            // 应该以 "m" 结尾（无空格）
            guard formatted.hasSuffix("m") && !formatted.hasSuffix(" m") else { return false }
            
            // 提取数字部分
            let numberPart = formatted.dropLast(1) // 移除 "m"
            guard let parsedDistance = Int(numberPart) else { return false }
            
            return parsedDistance == distance
        }
    }
    
    func testCompactDistanceFormattingKilometers() {
        // Feature: live-activity-enhancement, Property 1: Distance Formatting
        // Validates: Requirements 2.2, 3.2
        property("Compact distance >= 1000m should be formatted in km without space") <- forAll(Gen.choose((1000, 100000))) { (distance: Int) in
            let formatted = LiveActivityFormatters.formatCompactDistance(distance)
            
            // 应该以 "km" 结尾（无空格）
            guard formatted.hasSuffix("km") && !formatted.hasSuffix(" km") else { return false }
            
            // 提取数字部分
            let numberPart = formatted.dropLast(2) // 移除 "km"
            guard let parsedKm = Double(numberPart) else { return false }
            
            // 转换回米并验证
            let expectedKm = Double(distance) / 1000.0
            let roundedExpected = (expectedKm * 10).rounded() / 10
            
            return abs(parsedKm - roundedExpected) < 0.01
        }
    }
    
    func testDistanceFormattingBoundary() {
        // Feature: live-activity-enhancement, Property 1: Distance Formatting
        // Validates: Requirements 2.2, 3.2
        // 测试边界值 999m 和 1000m
        XCTAssertEqual(LiveActivityFormatters.formatDistance(999), "999 m")
        XCTAssertEqual(LiveActivityFormatters.formatDistance(1000), "1.0 km")
        XCTAssertEqual(LiveActivityFormatters.formatDistance(1001), "1.0 km")
        XCTAssertEqual(LiveActivityFormatters.formatDistance(1050), "1.1 km")
        XCTAssertEqual(LiveActivityFormatters.formatDistance(1500), "1.5 km")
    }
    
    func testCompactDistanceFormattingBoundary() {
        // Feature: live-activity-enhancement, Property 1: Distance Formatting
        // Validates: Requirements 2.2, 3.2
        // 测试紧凑格式边界值
        XCTAssertEqual(LiveActivityFormatters.formatCompactDistance(999), "999m")
        XCTAssertEqual(LiveActivityFormatters.formatCompactDistance(1000), "1.0km")
        XCTAssertEqual(LiveActivityFormatters.formatCompactDistance(1500), "1.5km")
    }
    
    func testNegativeDistanceHandling() {
        // Feature: live-activity-enhancement, Property 1: Distance Formatting
        // Validates: Requirements 2.2, 3.2
        // 测试负数距离处理
        XCTAssertEqual(LiveActivityFormatters.formatDistance(-100), "0 m")
        XCTAssertEqual(LiveActivityFormatters.formatCompactDistance(-100), "0m")
    }
    
    // MARK: - Property 4: Progress Calculation Bounds
    // *For any* current distance and geofence radius, the calculated progress value
    // SHALL be bounded within [0.0, 1.0], where progress approaches 1.0 as distance
    // approaches geofenceRadius.
    // **Validates: Requirements 3.5**
    
    func testProgressValueBounds() {
        // Feature: live-activity-enhancement, Property 4: Progress Calculation Bounds
        // Validates: Requirements 3.5
        property("Progress value should always be between 0.0 and 1.0") <- forAll(
            Gen.choose((0, 100000)),  // distance
            Gen.choose((100, 50000))  // geofenceRadius
        ) { (distance: Int, geofenceRadius: Int) in
            let progress = LiveActivityFormatters.calculateProgress(
                distance: distance,
                geofenceRadius: geofenceRadius
            )
            
            return progress >= 0.0 && progress <= 1.0
        }
    }
    
    func testProgressValueBoundsWithEdgeCases() {
        // Feature: live-activity-enhancement, Property 4: Progress Calculation Bounds
        // Validates: Requirements 3.5
        property("Progress bounds with edge cases") <- forAll(
            Gen.one(of: [
                Gen.pure(0),           // 零距离
                Gen.pure(1),           // 最小距离
                Gen.pure(Int.max / 2), // 大距离
                Gen.choose((0, 100000))
            ]),
            Gen.one(of: [
                Gen.pure(100),         // 最小围栏
                Gen.pure(50000),       // 最大围栏
                Gen.choose((100, 50000))
            ])
        ) { (distance: Int, geofenceRadius: Int) in
            let progress = LiveActivityFormatters.calculateProgress(
                distance: distance,
                geofenceRadius: geofenceRadius
            )
            
            return progress >= 0.0 && progress <= 1.0
        }
    }
    
    func testProgressMonotonicity() {
        // Feature: live-activity-enhancement, Property 4: Progress Calculation Bounds
        // Validates: Requirements 3.5
        property("Progress should increase as distance decreases") <- forAll(
            Gen.choose((100, 50000)),  // geofenceRadius
            Gen.choose((0, 100000)),   // distance1
            Gen.choose((0, 100000))    // distance2
        ) { (geofenceRadius: Int, distance1: Int, distance2: Int) in
            let progress1 = LiveActivityFormatters.calculateProgress(
                distance: distance1,
                geofenceRadius: geofenceRadius
            )
            let progress2 = LiveActivityFormatters.calculateProgress(
                distance: distance2,
                geofenceRadius: geofenceRadius
            )
            
            // 如果 distance1 < distance2，则 progress1 >= progress2
            if distance1 < distance2 {
                return progress1 >= progress2
            } else if distance1 > distance2 {
                return progress1 <= progress2
            } else {
                return progress1 == progress2
            }
        }
    }
    
    func testProgressCalculationExamples() {
        // Feature: live-activity-enhancement, Property 4: Progress Calculation Bounds
        // Validates: Requirements 3.5
        let geofenceRadius = 500
        
        // 在围栏内
        XCTAssertEqual(LiveActivityFormatters.calculateProgress(distance: 0, geofenceRadius: geofenceRadius), 1.0)
        XCTAssertEqual(LiveActivityFormatters.calculateProgress(distance: 250, geofenceRadius: geofenceRadius), 1.0)
        XCTAssertEqual(LiveActivityFormatters.calculateProgress(distance: 500, geofenceRadius: geofenceRadius), 1.0)
        
        // 在围栏外但在最大距离内
        let progressAt1000 = LiveActivityFormatters.calculateProgress(distance: 1000, geofenceRadius: geofenceRadius)
        XCTAssertGreaterThan(progressAt1000, 0.0)
        XCTAssertLessThan(progressAt1000, 1.0)
        
        // 超出最大距离
        let maxDistance = geofenceRadius * 10 // 5000m
        XCTAssertEqual(LiveActivityFormatters.calculateProgress(distance: maxDistance, geofenceRadius: geofenceRadius), 0.0)
        XCTAssertEqual(LiveActivityFormatters.calculateProgress(distance: maxDistance + 1000, geofenceRadius: geofenceRadius), 0.0)
    }
    
    func testZeroGeofenceRadiusHandling() {
        // Feature: live-activity-enhancement, Property 4: Progress Calculation Bounds
        // Validates: Requirements 3.5
        // 测试零围栏半径处理
        XCTAssertEqual(LiveActivityFormatters.calculateProgress(distance: 100, geofenceRadius: 0), 0.0)
    }
    
    func testNegativeDistanceProgressHandling() {
        // Feature: live-activity-enhancement, Property 4: Progress Calculation Bounds
        // Validates: Requirements 3.5
        // 测试负数距离处理
        XCTAssertEqual(LiveActivityFormatters.calculateProgress(distance: -100, geofenceRadius: 500), 1.0)
    }
    
    // MARK: - ETA Formatting Tests
    
    func testETAFormatting() {
        // 测试 ETA 格式化
        XCTAssertEqual(LiveActivityFormatters.formatETA(nil), "--")
        XCTAssertEqual(LiveActivityFormatters.formatETA(0), "即将到达")
        XCTAssertEqual(LiveActivityFormatters.formatETA(5), "5 分钟")
        XCTAssertEqual(LiveActivityFormatters.formatETA(59), "59 分钟")
        XCTAssertEqual(LiveActivityFormatters.formatETA(60), "1 小时")
        XCTAssertEqual(LiveActivityFormatters.formatETA(90), "1 小时 30 分钟")
        XCTAssertEqual(LiveActivityFormatters.formatETA(120), "2 小时")
    }
    
    func testCompactETAFormatting() {
        // 测试紧凑 ETA 格式化
        XCTAssertEqual(LiveActivityFormatters.formatCompactETA(nil), "--")
        XCTAssertEqual(LiveActivityFormatters.formatCompactETA(0), "到达")
        XCTAssertEqual(LiveActivityFormatters.formatCompactETA(5), "5分")
        XCTAssertEqual(LiveActivityFormatters.formatCompactETA(60), "1h")
        XCTAssertEqual(LiveActivityFormatters.formatCompactETA(90), "1h30m")
    }
    
    // MARK: - Property 2: ETA Reliability Display Mode
    // *For any* ContentState where `isETAReliable` is false, the compact trailing view
    // SHALL display distance instead of ETA minutes.
    // **Validates: Requirements 1.3, 2.5**
    
    func testETAReliabilityDisplayMode() {
        // Feature: live-activity-enhancement, Property 2: ETA Reliability Display Mode
        // Validates: Requirements 1.3, 2.5
        property("When ETA is unreliable, compact trailing should show distance") <- forAll(
            Gen.choose((100, 100000)),  // distance
            Gen.choose((1, 120))        // etaMinutes
        ) { (distance: Int, etaMinutes: Int) in
            // 当 ETA 不可靠时
            let text = LiveActivityFormatters.compactTrailingText(
                etaMinutes: etaMinutes,
                isETAReliable: false,
                distance: distance,
                isInsideGeofence: false
            )
            
            // 应该显示距离格式
            let expectedDistance = LiveActivityFormatters.formatCompactDistance(distance)
            return text == expectedDistance
        }
    }
    
    func testETAReliableDisplayMode() {
        // Feature: live-activity-enhancement, Property 2: ETA Reliability Display Mode
        // Validates: Requirements 1.2
        property("When ETA is reliable, compact trailing should show ETA minutes") <- forAll(
            Gen.choose((100, 100000)),  // distance
            Gen.choose((1, 120))        // etaMinutes
        ) { (distance: Int, etaMinutes: Int) in
            // 当 ETA 可靠时
            let text = LiveActivityFormatters.compactTrailingText(
                etaMinutes: etaMinutes,
                isETAReliable: true,
                distance: distance,
                isInsideGeofence: false
            )
            
            // 应该显示分钟数
            return text == "\(etaMinutes)分"
        }
    }
    
    func testETANilDisplayMode() {
        // Feature: live-activity-enhancement, Property 2: ETA Reliability Display Mode
        // Validates: Requirements 1.3
        property("When ETA is nil, compact trailing should show distance") <- forAll(
            Gen.choose((100, 100000))  // distance
        ) { (distance: Int) in
            // 当 ETA 为 nil 时（即使标记为可靠）
            let text = LiveActivityFormatters.compactTrailingText(
                etaMinutes: nil,
                isETAReliable: true,
                distance: distance,
                isInsideGeofence: false
            )
            
            // 应该显示距离格式
            let expectedDistance = LiveActivityFormatters.formatCompactDistance(distance)
            return text == expectedDistance
        }
    }
    
    func testInsideGeofenceDisplayMode() {
        // Feature: live-activity-enhancement, Property 2: ETA Reliability Display Mode
        // Validates: Requirements 1.4
        property("When inside geofence, compact trailing should be empty (icon shown instead)") <- forAll(
            Gen.choose((100, 100000)),  // distance
            Gen.choose((1, 120))        // etaMinutes
        ) { (distance: Int, etaMinutes: Int) in
            // 当在围栏内时
            let text = LiveActivityFormatters.compactTrailingText(
                etaMinutes: etaMinutes,
                isETAReliable: true,
                distance: distance,
                isInsideGeofence: true
            )
            
            // 应该返回空字符串（显示图标）
            return text.isEmpty
        }
    }
    
    func testDisplayModeExamples() {
        // Feature: live-activity-enhancement, Property 2: ETA Reliability Display Mode
        // Validates: Requirements 1.2, 1.3, 1.4
        
        // ETA 可靠时显示分钟
        XCTAssertEqual(
            LiveActivityFormatters.compactTrailingText(
                etaMinutes: 5,
                isETAReliable: true,
                distance: 1000,
                isInsideGeofence: false
            ),
            "5分"
        )
        
        // ETA 不可靠时显示距离
        XCTAssertEqual(
            LiveActivityFormatters.compactTrailingText(
                etaMinutes: 5,
                isETAReliable: false,
                distance: 1000,
                isInsideGeofence: false
            ),
            "1.0km"
        )
        
        // 在围栏内时返回空（显示图标）
        XCTAssertEqual(
            LiveActivityFormatters.compactTrailingText(
                etaMinutes: 5,
                isETAReliable: true,
                distance: 100,
                isInsideGeofence: true
            ),
            ""
        )
    }
    
    // MARK: - Property 3: Arrival State Detection
    // *For any* ContentState, `isInsideGeofence` SHALL be true if and only if
    // `distance <= geofenceRadius`.
    // **Validates: Requirements 1.4, 2.6, 3.7, 5.3**
    
    func testArrivalStateDetectionInsideGeofence() {
        // Feature: live-activity-enhancement, Property 3: Arrival State Detection
        // Validates: Requirements 1.4, 2.6, 3.7, 5.3
        property("Should show arrival when distance <= geofenceRadius") <- forAll(
            Gen.choose((100, 10000))  // geofenceRadius
        ) { (geofenceRadius: Int) in
            // 测试距离等于围栏半径
            let shouldShowAtBoundary = LiveActivityFormatters.shouldShowArrivalIcon(
                isInsideGeofence: false,
                distance: geofenceRadius,
                geofenceRadius: geofenceRadius
            )
            
            // 测试距离小于围栏半径
            let distanceInside = max(0, geofenceRadius - 100)
            let shouldShowInside = LiveActivityFormatters.shouldShowArrivalIcon(
                isInsideGeofence: false,
                distance: distanceInside,
                geofenceRadius: geofenceRadius
            )
            
            return shouldShowAtBoundary && shouldShowInside
        }
    }
    
    func testArrivalStateDetectionOutsideGeofence() {
        // Feature: live-activity-enhancement, Property 3: Arrival State Detection
        // Validates: Requirements 1.4, 2.6, 3.7, 5.3
        property("Should not show arrival when distance > geofenceRadius and not inside") <- forAll(
            Gen.choose((100, 10000)),  // geofenceRadius
            Gen.choose((1, 10000))     // extraDistance
        ) { (geofenceRadius: Int, extraDistance: Int) in
            let distance = geofenceRadius + extraDistance
            
            let shouldShow = LiveActivityFormatters.shouldShowArrivalIcon(
                isInsideGeofence: false,
                distance: distance,
                geofenceRadius: geofenceRadius
            )
            
            return !shouldShow
        }
    }
    
    func testArrivalStateDetectionWithIsInsideGeofenceFlag() {
        // Feature: live-activity-enhancement, Property 3: Arrival State Detection
        // Validates: Requirements 1.4, 2.6, 3.7, 5.3
        property("Should show arrival when isInsideGeofence is true regardless of distance") <- forAll(
            Gen.choose((100, 100000)),  // distance
            Gen.choose((100, 10000))    // geofenceRadius
        ) { (distance: Int, geofenceRadius: Int) in
            // 当 isInsideGeofence 为 true 时，无论距离多远都应该显示到达
            let shouldShow = LiveActivityFormatters.shouldShowArrivalIcon(
                isInsideGeofence: true,
                distance: distance,
                geofenceRadius: geofenceRadius
            )
            
            return shouldShow
        }
    }
    
    func testArrivalStateDetectionExamples() {
        // Feature: live-activity-enhancement, Property 3: Arrival State Detection
        // Validates: Requirements 1.4, 2.6, 3.7, 5.3
        
        // 在围栏内（isInsideGeofence = true）
        XCTAssertTrue(LiveActivityFormatters.shouldShowArrivalIcon(
            isInsideGeofence: true,
            distance: 1000,
            geofenceRadius: 500
        ))
        
        // 距离小于围栏半径
        XCTAssertTrue(LiveActivityFormatters.shouldShowArrivalIcon(
            isInsideGeofence: false,
            distance: 400,
            geofenceRadius: 500
        ))
        
        // 距离等于围栏半径
        XCTAssertTrue(LiveActivityFormatters.shouldShowArrivalIcon(
            isInsideGeofence: false,
            distance: 500,
            geofenceRadius: 500
        ))
        
        // 距离大于围栏半径
        XCTAssertFalse(LiveActivityFormatters.shouldShowArrivalIcon(
            isInsideGeofence: false,
            distance: 600,
            geofenceRadius: 500
        ))
        
        // 零距离
        XCTAssertTrue(LiveActivityFormatters.shouldShowArrivalIcon(
            isInsideGeofence: false,
            distance: 0,
            geofenceRadius: 500
        ))
    }
    
    // MARK: - Display Mode Tests
    
    func testDisplayModeDetermination() {
        // Feature: live-activity-enhancement
        // Validates: Requirements 1.3, 1.4, 2.5, 2.6
        
        // 已到达状态
        XCTAssertEqual(
            LiveActivityFormatters.determineDisplayMode(
                isInsideGeofence: true,
                isETAReliable: true,
                distance: 1000,
                geofenceRadius: 500
            ),
            .arrived
        )
        
        // 距离小于围栏半径也是到达状态
        XCTAssertEqual(
            LiveActivityFormatters.determineDisplayMode(
                isInsideGeofence: false,
                isETAReliable: true,
                distance: 400,
                geofenceRadius: 500
            ),
            .arrived
        )
        
        // ETA 不可靠状态
        XCTAssertEqual(
            LiveActivityFormatters.determineDisplayMode(
                isInsideGeofence: false,
                isETAReliable: false,
                distance: 1000,
                geofenceRadius: 500
            ),
            .unreliable
        )
        
        // 正常状态
        XCTAssertEqual(
            LiveActivityFormatters.determineDisplayMode(
                isInsideGeofence: false,
                isETAReliable: true,
                distance: 1000,
                geofenceRadius: 500
            ),
            .normal
        )
    }
}
