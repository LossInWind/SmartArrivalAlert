import Foundation
import CoreLocation
import MapKit
import SwiftUI

// MARK: - Map Annotation Item

/// 地图标注数据模型
struct MapAnnotationItem: Identifiable, Equatable {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let type: AnnotationType
    let title: String
    
    /// 标注类型
    enum AnnotationType: String, Codable, Equatable {
        case userLocation = "user"
        case destination = "destination"
    }
    
    init(id: String = UUID().uuidString, coordinate: CLLocationCoordinate2D, type: AnnotationType, title: String) {
        self.id = id
        self.coordinate = coordinate
        self.type = type
        self.title = title
    }
    
    /// 从 Location 创建目的地标注
    static func destination(from location: Location) -> MapAnnotationItem {
        MapAnnotationItem(
            id: "destination_\(location.id)",
            coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
            type: .destination,
            title: location.name
        )
    }
    
    /// 创建用户位置标注
    static func userLocation(coordinate: CLLocationCoordinate2D) -> MapAnnotationItem {
        MapAnnotationItem(
            id: "user_location",
            coordinate: coordinate,
            type: .userLocation,
            title: "我的位置"
        )
    }
    
    static func == (lhs: MapAnnotationItem, rhs: MapAnnotationItem) -> Bool {
        lhs.id == rhs.id &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.type == rhs.type &&
        lhs.title == rhs.title
    }
}

// MARK: - Map Mode

/// 地图显示模式
enum MapMode: Equatable {
    case preview      // 预览模式，只显示目的地
    case monitoring   // 监控模式，显示用户位置和目的地
    case picker       // 选点模式，中心固定标记
}

// MARK: - Geofence Circle

/// 围栏圆圈数据模型
struct GeofenceCircleData: Identifiable, Equatable {
    let id: String
    let center: CLLocationCoordinate2D
    let radius: CLLocationDistance
    let isInside: Bool
    
    init(id: String = UUID().uuidString, center: CLLocationCoordinate2D, radius: CLLocationDistance, isInside: Bool = false) {
        self.id = id
        self.center = center
        self.radius = radius
        self.isInside = isInside
    }
    
    /// 从 Location 和半径创建围栏圆圈
    static func from(location: Location, radius: Int, isInside: Bool = false) -> GeofenceCircleData {
        GeofenceCircleData(
            id: "geofence_\(location.id)",
            center: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude),
            radius: CLLocationDistance(radius),
            isInside: isInside
        )
    }
    
    static func == (lhs: GeofenceCircleData, rhs: GeofenceCircleData) -> Bool {
        lhs.id == rhs.id &&
        lhs.center.latitude == rhs.center.latitude &&
        lhs.center.longitude == rhs.center.longitude &&
        lhs.radius == rhs.radius &&
        lhs.isInside == rhs.isInside
    }
}

// MARK: - MKCoordinateRegion Extension

extension MKCoordinateRegion {
    
    /// 创建以指定坐标为中心的区域
    /// - Parameters:
    ///   - coordinate: 中心坐标
    ///   - span: 跨度，默认 0.01 度（约 1km）
    /// - Returns: 地图区域
    static func centered(on coordinate: CLLocationCoordinate2D, span: Double = 0.01) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
    }
    
    /// 创建以 Location 为中心的区域
    /// - Parameters:
    ///   - location: 位置
    ///   - span: 跨度
    /// - Returns: 地图区域
    static func centered(on location: Location, span: Double = 0.01) -> MKCoordinateRegion {
        centered(on: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude), span: span)
    }
    
    /// 创建包含两个坐标点的区域
    /// - Parameters:
    ///   - coord1: 第一个坐标
    ///   - coord2: 第二个坐标
    ///   - padding: 边距倍数，默认 1.5
    /// - Returns: 包含两点的地图区域
    static func containing(
        _ coord1: CLLocationCoordinate2D,
        _ coord2: CLLocationCoordinate2D,
        padding: Double = 1.5
    ) -> MKCoordinateRegion {
        // 计算中心点
        let centerLat = (coord1.latitude + coord2.latitude) / 2
        let centerLon = (coord1.longitude + coord2.longitude) / 2
        let center = CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon)
        
        // 计算跨度
        let latDelta = abs(coord1.latitude - coord2.latitude) * padding
        let lonDelta = abs(coord1.longitude - coord2.longitude) * padding
        
        // 确保最小跨度
        let minSpan = 0.005
        let finalLatDelta = max(latDelta, minSpan)
        let finalLonDelta = max(lonDelta, minSpan)
        
        return MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: finalLatDelta, longitudeDelta: finalLonDelta)
        )
    }
    
    /// 创建包含坐标和围栏半径的区域
    /// - Parameters:
    ///   - coordinate: 中心坐标
    ///   - radius: 围栏半径（米）
    ///   - padding: 边距倍数
    /// - Returns: 地图区域
    static func containing(coordinate: CLLocationCoordinate2D, radius: Double, padding: Double = 2.0) -> MKCoordinateRegion {
        // 将米转换为度（粗略估算：1度约111km）
        let radiusInDegrees = (radius / 111000.0) * padding
        
        return MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: radiusInDegrees * 2, longitudeDelta: radiusInDegrees * 2)
        )
    }
    
    /// 检查坐标是否在区域内
    /// - Parameter coordinate: 要检查的坐标
    /// - Returns: 是否在区域内
    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        let latMin = center.latitude - span.latitudeDelta / 2
        let latMax = center.latitude + span.latitudeDelta / 2
        let lonMin = center.longitude - span.longitudeDelta / 2
        let lonMax = center.longitude + span.longitudeDelta / 2
        
        return coordinate.latitude >= latMin &&
               coordinate.latitude <= latMax &&
               coordinate.longitude >= lonMin &&
               coordinate.longitude <= lonMax
    }
}

// MARK: - Default Locations

extension CLLocationCoordinate2D {
    /// 默认位置（北京天安门）
    static let defaultLocation = CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074)
}

// MARK: - Map Style

/// 地图显示样式
enum MapDisplayStyle: String, CaseIterable, Codable, Equatable {
    case explore = "explore"      // 探索模式
    case driving = "driving"      // 驾车模式
    case transit = "transit"      // 公交模式
    case satellite = "satellite"  // 卫星模式
    
    /// 显示名称
    var displayName: String {
        switch self {
        case .explore: return "探索"
        case .driving: return "驾车"
        case .transit: return "公交"
        case .satellite: return "卫星"
        }
    }
    
    /// 图标名称
    var icon: String {
        switch self {
        case .explore: return "map"
        case .driving: return "car"
        case .transit: return "bus"
        case .satellite: return "globe"
        }
    }
    
    /// 转换为 MapKit 样式
    @available(iOS 17.0, *)
    var mapKitStyle: _MapKit_SwiftUI.MapStyle {
        switch self {
        case .explore:
            return .standard(elevation: .realistic, pointsOfInterest: .all)
        case .driving:
            return .standard(elevation: .flat, pointsOfInterest: .excludingAll)
        case .transit:
            return .standard(elevation: .flat, pointsOfInterest: .including([.publicTransport]))
        case .satellite:
            return .imagery(elevation: .realistic)
        }
    }
    
    /// 存储键
    static let storageKey = "map_display_style"
}

// MARK: - POI Selection

/// POI 选择数据模型
struct POISelection: Equatable {
    let coordinate: CLLocationCoordinate2D
    let name: String
    let address: String?
    let category: String?
    
    init(coordinate: CLLocationCoordinate2D, name: String, address: String? = nil, category: String? = nil) {
        self.coordinate = coordinate
        self.name = name
        self.address = address
        self.category = category
    }
    
    /// 转换为 Location 对象
    func toLocation() -> Location {
        Location(
            id: UUID().uuidString,
            name: name,
            address: address ?? "未知地址",
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            isFavorite: false
        )
    }
    
    static func == (lhs: POISelection, rhs: POISelection) -> Bool {
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude &&
        lhs.name == rhs.name &&
        lhs.address == rhs.address &&
        lhs.category == rhs.category
    }
}

// MARK: - ETA Result

/// ETA 计算结果
struct ETAResult: Equatable {
    /// 预计分钟数，nil 表示无法计算
    let estimatedMinutes: Int?
    /// 置信度 0.0-1.0
    let confidence: Double
    /// 是否可靠（confidence >= 0.6）
    let isReliable: Bool
    /// 格式化显示文本
    let displayText: String
    
    init(estimatedMinutes: Int?, confidence: Double, isReliable: Bool, displayText: String) {
        self.estimatedMinutes = estimatedMinutes
        self.confidence = confidence
        self.isReliable = isReliable
        self.displayText = displayText
    }
    
    /// 创建"计算中"状态的结果
    static let calculating = ETAResult(
        estimatedMinutes: nil,
        confidence: 0.0,
        isReliable: false,
        displayText: "计算中..."
    )
    
    /// 创建带分钟数的结果
    static func withMinutes(_ minutes: Int, confidence: Double) -> ETAResult {
        let isReliable = confidence >= 0.6
        let displayText: String
        if minutes < 1 {
            displayText = "即将到达"
        } else if minutes == 1 {
            displayText = "约 1 分钟"
        } else {
            displayText = "约 \(minutes) 分钟"
        }
        return ETAResult(
            estimatedMinutes: minutes,
            confidence: confidence,
            isReliable: isReliable,
            displayText: displayText
        )
    }
}
