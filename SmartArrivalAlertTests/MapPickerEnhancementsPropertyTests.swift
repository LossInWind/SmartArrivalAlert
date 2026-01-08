import XCTest
import SwiftCheck
import CoreLocation
import MapKit
@testable import SmartArrivalAlert

/// Mock AlertTrigger for testing - avoids UNUserNotificationCenter crash
final class MockAlertTrigger: AlertTriggerProtocol {
    func triggerArrivalAlert(destination: Location) async throws {}
    func triggerEarlyAlert(destination: Location, reason: String) async throws {}
    func setBackupAlarm(at time: Date, destination: Location) async throws {}
    func cancelBackupAlarm() async {}
}

/// Map Picker Enhancements 属性测试
/// Feature: map-picker-enhancements
final class MapPickerEnhancementsPropertyTests: XCTestCase {
    
    // MARK: - Property 5: Map style persistence round-trip
    // For any MapDisplayStyle, saving it via MapStyleManager and then loading SHALL return the same style.
    // **Validates: Requirements 5.1, 5.2, 5.6, 6.3**
    
    func testMapStylePersistenceRoundTrip() {
        // 使用独立的 UserDefaults 进行测试
        let suiteName = "test_map_style_\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        
        property("Map style persistence round-trip") <- forAll { (styleIndex: UInt) in
            // 清理测试环境
            testDefaults.removePersistentDomain(forName: suiteName)
            
            // 选择一个样式
            let styles = MapDisplayStyle.allCases
            let style = styles[Int(styleIndex) % styles.count]
            
            // 创建管理器并设置样式
            let manager1 = MapStyleManager(userDefaults: testDefaults)
            manager1.setStyle(style)
            
            // 创建新的管理器，验证样式被正确加载
            let manager2 = MapStyleManager(userDefaults: testDefaults)
            
            return manager2.currentStyle == style
        }
        
        // 清理
        testDefaults.removePersistentDomain(forName: suiteName)
    }
    
    func testMapStylePersistenceAllStyles() {
        // 测试所有样式的持久化
        let suiteName = "test_map_style_all_\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        
        for style in MapDisplayStyle.allCases {
            // 清理
            testDefaults.removePersistentDomain(forName: suiteName)
            
            // 设置样式
            let manager1 = MapStyleManager(userDefaults: testDefaults)
            manager1.setStyle(style)
            
            // 验证持久化
            let manager2 = MapStyleManager(userDefaults: testDefaults)
            XCTAssertEqual(manager2.currentStyle, style, "Style \(style.rawValue) should persist correctly")
        }
        
        // 清理
        testDefaults.removePersistentDomain(forName: suiteName)
    }
    
    func testMapStyleDefaultValue() {
        // 测试默认值
        let suiteName = "test_map_style_default_\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        testDefaults.removePersistentDomain(forName: suiteName)
        
        let manager = MapStyleManager(userDefaults: testDefaults)
        XCTAssertEqual(manager.currentStyle, .explore, "Default style should be .explore")
        
        // 清理
        testDefaults.removePersistentDomain(forName: suiteName)
    }
    
    func testMapStyleResetToDefault() {
        let suiteName = "test_map_style_reset_\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        
        let manager = MapStyleManager(userDefaults: testDefaults)
        manager.setStyle(.satellite)
        XCTAssertEqual(manager.currentStyle, .satellite)
        
        manager.resetToDefault()
        XCTAssertEqual(manager.currentStyle, .explore, "Reset should return to .explore")
        
        // 清理
        testDefaults.removePersistentDomain(forName: suiteName)
    }
    
    // MARK: - Property 1: Map region contains target coordinate
    // For any coordinate and map region created to center on that coordinate,
    // the region SHALL contain the target coordinate within its bounds.
    // **Validates: Requirements 1.2, 3.4, 4.3**
    
    func testMapRegionContainsTargetCoordinate() {
        property("Map region contains target coordinate") <- forAll(
            Gen<Double>.fromElements(in: 18.0...54.0),
            Gen<Double>.fromElements(in: 73.0...135.0)
        ) { lat, lon in
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            // 创建以该坐标为中心的区域
            let region = MKCoordinateRegion.centered(on: coord, span: 0.01)
            
            // 验证区域包含该坐标
            return region.contains(coord)
        }
    }
    
    func testMapRegionContainsCoordinateWithVariousSpans() {
        property("Map region contains coordinate with various spans") <- forAll(
            Gen<Double>.fromElements(in: 18.0...54.0),
            Gen<Double>.fromElements(in: 73.0...135.0),
            Gen<Double>.fromElements(in: 0.001...0.1)
        ) { lat, lon, span in
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let region = MKCoordinateRegion.centered(on: coord, span: span)
            return region.contains(coord)
        }
    }
    
    func testMapRegionContainingRadiusIncludesCenter() {
        property("Map region containing radius includes center") <- forAll(
            Gen<Double>.fromElements(in: 18.0...54.0),
            Gen<Double>.fromElements(in: 73.0...135.0),
            Gen<Double>.fromElements(in: 100...1000)
        ) { lat, lon, radius in
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let region = MKCoordinateRegion.containing(coordinate: coord, radius: radius, padding: 2.0)
            return region.contains(coord)
        }
    }
    
    // MARK: - Property 2: Clear destination resets state
    // For any HomeViewModel with a selected destination, calling clearSelectedLocation
    // SHALL result in selectedLocation being nil.
    // **Validates: Requirements 2.2, 2.3**
    
    @MainActor
    func testClearDestinationResetsState() {
        property("Clear destination resets state") <- forAll(
            Gen<Double>.fromElements(in: 18.0...54.0),
            Gen<Double>.fromElements(in: 73.0...135.0),
            Gen<String>.fromElements(of: ["测试地点", "商场", "公园", "地铁站", "餐厅"])
        ) { lat, lon, name in
            let location = Location(
                id: UUID().uuidString,
                name: name,
                address: "测试地址",
                latitude: lat,
                longitude: lon,
                isFavorite: false
            )
            
            // 创建 ViewModel 并设置选中的位置（使用 mock AlertTrigger）
            let viewModel = HomeViewModel(alertTrigger: MockAlertTrigger())
            viewModel.selectLocation(location)
            
            // 验证位置已设置
            guard viewModel.selectedLocation != nil else {
                return false
            }
            
            // 清除选中的位置
            viewModel.clearSelectedLocation()
            
            // 验证位置已清除
            return viewModel.selectedLocation == nil
        }
    }
    
    @MainActor
    func testClearDestinationFromNilState() {
        // 测试从 nil 状态清除不会崩溃（使用 mock AlertTrigger）
        let viewModel = HomeViewModel(alertTrigger: MockAlertTrigger())
        XCTAssertNil(viewModel.selectedLocation)
        
        viewModel.clearSelectedLocation()
        XCTAssertNil(viewModel.selectedLocation, "Clearing nil destination should remain nil")
    }
    
    // MARK: - Property 3: Search result selection sets POI
    // For any valid Location from search results, selecting it SHALL set the selectedPOI
    // with matching coordinates and name.
    // **Validates: Requirements 3.5, 4.1**
    
    @MainActor
    func testSearchResultSelectionSetsPOI() {
        property("Search result selection sets POI") <- forAll(
            Gen<Double>.fromElements(in: 18.0...54.0),
            Gen<Double>.fromElements(in: 73.0...135.0),
            Gen<String>.fromElements(of: ["测试地点", "商场", "公园", "地铁站", "餐厅"])
        ) { lat, lon, name in
            let viewModel = MapViewModel(mode: .picker)
            
            // 从 Location 创建 POI 并选择
            let poi = POISelection(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                name: name,
                address: "测试地址"
            )
            viewModel.selectPOI(poi)
            
            // 验证 POI 已设置且坐标匹配
            guard let selectedPOI = viewModel.selectedPOI else {
                return false
            }
            
            return selectedPOI.coordinate.latitude == lat &&
                   selectedPOI.coordinate.longitude == lon &&
                   selectedPOI.name == name
        }
    }
    
    // MARK: - Property 4: POI confirmation produces valid Location
    // For any selected POI, calling confirmPOISelection SHALL return a Location
    // with the same coordinates as the POI.
    // **Validates: Requirements 4.4**
    
    @MainActor
    func testPOIConfirmationProducesValidLocation() {
        property("POI confirmation produces valid Location") <- forAll(
            Gen<Double>.fromElements(in: 18.0...54.0),
            Gen<Double>.fromElements(in: 73.0...135.0),
            Gen<String>.fromElements(of: ["测试地点", "商场", "公园", "地铁站", "餐厅"])
        ) { lat, lon, name in
            let viewModel = MapViewModel(mode: .picker)
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            
            // 创建并选择 POI
            let poi = POISelection(
                coordinate: coord,
                name: name,
                address: "测试地址"
            )
            viewModel.selectPOI(poi)
            
            // 确认选择
            guard let location = viewModel.confirmPOISelection() else {
                return false
            }
            
            // 验证坐标匹配
            return location.latitude == lat &&
                   location.longitude == lon &&
                   location.name == name
        }
    }
    
    @MainActor
    func testPOIConfirmationWithoutSelectionReturnsNil() {
        let viewModel = MapViewModel(mode: .picker)
        XCTAssertNil(viewModel.selectedPOI)
        
        let result = viewModel.confirmPOISelection()
        XCTAssertNil(result, "Confirming without POI selection should return nil")
    }
    
    @MainActor
    func testClearPOISelection() {
        let viewModel = MapViewModel(mode: .picker)
        
        // 选择 POI
        let poi = POISelection(
            coordinate: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4),
            name: "测试",
            address: nil
        )
        viewModel.selectPOI(poi)
        XCTAssertNotNil(viewModel.selectedPOI)
        
        // 清除选择
        viewModel.clearPOISelection()
        XCTAssertNil(viewModel.selectedPOI, "Clear should set selectedPOI to nil")
    }
}
