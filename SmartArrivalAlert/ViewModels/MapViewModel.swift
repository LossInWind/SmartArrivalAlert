import Foundation
import SwiftUI
import MapKit
import CoreLocation
import Combine

/// 地图视图模型 - 管理地图状态
@MainActor
class MapViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 地图区域
    @Published var region: MKCoordinateRegion
    
    /// 用户当前位置
    @Published var userLocation: CLLocationCoordinate2D?
    
    /// 目的地
    @Published var destination: Location?
    
    /// 围栏半径（米）
    @Published var geofenceRadius: Int = 200
    
    /// 是否在围栏内
    @Published var isInsideGeofence: Bool = false
    
    /// 地图模式
    @Published var mode: MapMode = .preview
    
    /// 标注列表
    @Published var annotations: [MapAnnotationItem] = []
    
    /// 围栏圆圈
    @Published var geofenceCircle: GeofenceCircleData?
    
    /// 相机位置（iOS 17+）
    @Published var cameraPosition: MapCameraPosition = .automatic
    
    // MARK: - Map Enhancement Properties
    
    /// 地图显示样式
    @Published var mapStyle: MapDisplayStyle = .explore
    
    /// 选中的 POI
    @Published var selectedPOI: POISelection?
    
    /// 是否显示用户位置
    @Published var showUserLocation: Bool = true
    
    // MARK: - Route Display Properties
    
    /// 可用路线列表
    @Published var routes: [RouteOption] = []
    
    /// 选中的路线 ID
    @Published var selectedRouteId: String?
    
    /// 是否为飞机模式（显示直线）
    @Published var isAirplaneMode: Bool = false
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        destination: Location? = nil,
        userLocation: CLLocationCoordinate2D? = nil,
        geofenceRadius: Int = 200,
        mode: MapMode = .preview
    ) {
        self.destination = destination
        self.userLocation = userLocation
        self.geofenceRadius = geofenceRadius
        self.mode = mode
        
        // 初始化区域
        if let dest = destination {
            self.region = MKCoordinateRegion.centered(on: dest, span: 0.01)
        } else if let user = userLocation {
            self.region = MKCoordinateRegion.centered(on: user, span: 0.01)
        } else {
            self.region = MKCoordinateRegion.centered(on: .defaultLocation, span: 0.05)
        }
        
        // 更新标注和围栏
        updateAnnotations()
        updateGeofenceCircle()
        updateCameraPosition()
        
        // 加载保存的地图样式
        loadSavedMapStyle()
        
        // 监听变化
        setupBindings()
    }
    
    // MARK: - Public Methods
    
    /// 设置目的地
    func setDestination(_ location: Location) {
        destination = location
        updateAnnotations()
        updateGeofenceCircle()
        centerOnLocation(location)
    }
    
    /// 居中到指定位置
    func centerOnLocation(_ location: Location) {
        let coordinate = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            region = MKCoordinateRegion.containing(
                coordinate: coordinate,
                radius: Double(geofenceRadius),
                padding: 2.5
            )
            cameraPosition = .region(region)
        }
    }
    
    /// 居中到坐标
    func centerOnCoordinate(_ coordinate: CLLocationCoordinate2D, span: Double = 0.01) {
        withAnimation(.easeInOut(duration: 0.3)) {
            region = MKCoordinateRegion.centered(on: coordinate, span: span)
            cameraPosition = .region(region)
        }
    }
    
    /// 更新用户位置
    func updateUserLocation(_ coordinate: CLLocationCoordinate2D) {
        userLocation = coordinate
        updateAnnotations()
        checkGeofenceStatus()
        
        // 在监控模式下自动调整视野
        if mode == .monitoring {
            fitToShowBothLocations()
        }
    }
    
    /// 调整视野以显示用户位置和目的地
    func fitToShowBothLocations() {
        guard let user = userLocation,
              let dest = destination else {
            return
        }
        
        let destCoord = CLLocationCoordinate2D(latitude: dest.latitude, longitude: dest.longitude)
        
        withAnimation(.easeInOut(duration: 0.3)) {
            region = MKCoordinateRegion.containing(user, destCoord, padding: 1.8)
            cameraPosition = .region(region)
        }
    }
    
    /// 设置围栏半径
    func setGeofenceRadius(_ radius: Int) {
        geofenceRadius = radius
        updateGeofenceCircle()
        checkGeofenceStatus()
        
        // 调整视野以显示完整围栏
        if let dest = destination {
            let coordinate = CLLocationCoordinate2D(latitude: dest.latitude, longitude: dest.longitude)
            withAnimation(.easeInOut(duration: 0.3)) {
                region = MKCoordinateRegion.containing(
                    coordinate: coordinate,
                    radius: Double(radius),
                    padding: 2.5
                )
                cameraPosition = .region(region)
            }
        }
    }
    
    /// 设置地图模式
    func setMode(_ newMode: MapMode) {
        mode = newMode
        updateAnnotations()
        updateCameraPosition()
    }
    
    /// 更新围栏状态（外部调用）
    func updateGeofenceStatus(isInside: Bool) {
        guard isInsideGeofence != isInside else { return }
        isInsideGeofence = isInside
        updateGeofenceCircle()
    }
    
    /// 获取地图中心坐标
    func getCenterCoordinate() -> CLLocationCoordinate2D {
        return region.center
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // 监听目的地变化
        $destination
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateAnnotations()
                self?.updateGeofenceCircle()
            }
            .store(in: &cancellables)
        
        // 监听用户位置变化
        $userLocation
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateAnnotations()
                self?.checkGeofenceStatus()
            }
            .store(in: &cancellables)
        
        // 监听围栏半径变化
        $geofenceRadius
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateGeofenceCircle()
                self?.checkGeofenceStatus()
            }
            .store(in: &cancellables)
        
        // 监听模式变化
        $mode
            .dropFirst()
            .sink { [weak self] _ in
                self?.updateAnnotations()
            }
            .store(in: &cancellables)
    }
    
    /// 更新标注列表
    private func updateAnnotations() {
        var newAnnotations: [MapAnnotationItem] = []
        
        // 添加目的地标注
        if let dest = destination {
            newAnnotations.append(MapAnnotationItem.destination(from: dest))
        }
        
        // 在监控模式下添加用户位置标注
        if mode == .monitoring, let user = userLocation {
            newAnnotations.append(MapAnnotationItem.userLocation(coordinate: user))
        }
        
        annotations = newAnnotations
    }
    
    /// 更新围栏圆圈
    private func updateGeofenceCircle() {
        guard let dest = destination else {
            geofenceCircle = nil
            return
        }
        
        geofenceCircle = GeofenceCircleData.from(
            location: dest,
            radius: geofenceRadius,
            isInside: isInsideGeofence
        )
    }
    
    /// 检查是否在围栏内
    private func checkGeofenceStatus() {
        guard let user = userLocation,
              let dest = destination else {
            isInsideGeofence = false
            return
        }
        
        let distance = GeoUtils.calculateDistance(
            lat1: user.latitude, lon1: user.longitude,
            lat2: dest.latitude, lon2: dest.longitude
        )
        
        let wasInside = isInsideGeofence
        isInsideGeofence = distance <= Double(geofenceRadius)
        
        // 如果状态变化，更新围栏圆圈
        if wasInside != isInsideGeofence {
            updateGeofenceCircle()
        }
    }
    
    /// 更新相机位置
    private func updateCameraPosition() {
        switch mode {
        case .preview:
            if let dest = destination {
                let coordinate = CLLocationCoordinate2D(latitude: dest.latitude, longitude: dest.longitude)
                let newRegion = MKCoordinateRegion.containing(
                    coordinate: coordinate,
                    radius: Double(geofenceRadius),
                    padding: 2.5
                )
                cameraPosition = .region(newRegion)
            }
        case .monitoring:
            if let user = userLocation, let dest = destination {
                let destCoord = CLLocationCoordinate2D(latitude: dest.latitude, longitude: dest.longitude)
                let newRegion = MKCoordinateRegion.containing(user, destCoord, padding: 1.8)
                cameraPosition = .region(newRegion)
            }
        case .picker:
            cameraPosition = .region(region)
        }
    }
    
    // MARK: - POI Selection Methods
    
    /// 选择 POI（使用 POISelection 对象）
    /// - Parameter poi: POI 选择对象
    func selectPOI(_ poi: POISelection) {
        selectedPOI = poi
    }
    
    /// 选择 POI
    /// - Parameters:
    ///   - coordinate: POI 坐标
    ///   - name: POI 名称
    ///   - address: POI 地址（可选）
    ///   - category: POI 类别（可选）
    func selectPOI(at coordinate: CLLocationCoordinate2D, name: String, address: String? = nil, category: String? = nil) {
        let poiName = name.isEmpty ? "未命名地点" : name
        selectedPOI = POISelection(
            coordinate: coordinate,
            name: poiName,
            address: address,
            category: category
        )
    }
    
    /// 清除 POI 选择
    func clearPOISelection() {
        selectedPOI = nil
    }
    
    /// 确认 POI 选择并转换为 Location
    /// - Returns: 转换后的 Location，如果没有选中 POI 则返回 nil
    func confirmPOISelection() -> Location? {
        guard let poi = selectedPOI else { return nil }
        let location = poi.toLocation()
        clearPOISelection()
        return location
    }
    
    // MARK: - Map Style Methods
    
    /// 设置地图样式
    /// - Parameter style: 新的地图样式
    func setMapStyle(_ style: MapDisplayStyle) {
        mapStyle = style
        saveMapStyle()
    }
    
    /// 从 UserDefaults 加载保存的地图样式
    func loadSavedMapStyle() {
        if let savedValue = UserDefaults.standard.string(forKey: MapDisplayStyle.storageKey),
           let style = MapDisplayStyle(rawValue: savedValue) {
            mapStyle = style
        }
    }
    
    /// 保存地图样式到 UserDefaults
    func saveMapStyle() {
        UserDefaults.standard.set(mapStyle.rawValue, forKey: MapDisplayStyle.storageKey)
    }
    
    /// 居中到用户位置
    func centerOnUserLocation() {
        guard let user = userLocation else { return }
        centerOnCoordinate(user, span: 0.01)
    }
    
    // MARK: - Route Display Methods
    
    /// 更新路线列表
    /// - Parameters:
    ///   - newRoutes: 新的路线列表
    ///   - selectedId: 选中的路线 ID
    ///   - isAirplane: 是否为飞机模式
    func updateRoutes(_ newRoutes: [RouteOption], selectedId: String?, isAirplane: Bool = false) {
        routes = newRoutes
        selectedRouteId = selectedId
        isAirplaneMode = isAirplane
    }
    
    /// 选择路线
    /// - Parameter routeId: 路线 ID
    func selectRoute(withId routeId: String) {
        selectedRouteId = routeId
        
        // 更新路线选中状态
        routes = routes.map { route in
            var updated = route
            updated.isSelected = route.id == routeId
            return updated
        }
    }
    
    /// 路线选择回调（用于外部通知）
    var onRouteSelected: ((String) -> Void)?
    
    /// 选择路线并触发回调
    /// - Parameter routeId: 路线 ID
    func selectRouteAndNotify(withId routeId: String) {
        selectRoute(withId: routeId)
        onRouteSelected?(routeId)
    }
    
    /// 清除路线
    func clearRoutes() {
        routes = []
        selectedRouteId = nil
        isAirplaneMode = false
    }
    
    /// 获取选中的路线
    var selectedRoute: RouteOption? {
        routes.first { $0.id == selectedRouteId }
    }
}
