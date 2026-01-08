import Foundation
import SwiftUI
import CoreLocation
import MapKit
import Combine

/// 路线选择视图模型
/// 管理路线选择地图视图的状态和逻辑
@MainActor
class RouteSelectionViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// 可用路线列表
    @Published var routes: [RouteOption] = []
    
    /// 选中的路线 ID
    @Published var selectedRouteId: String?
    
    /// 是否正在加载
    @Published var isLoading: Bool = false
    
    /// 是否为飞机模式（显示直线）
    @Published var isAirplaneMode: Bool = false
    
    /// 错误信息
    @Published var errorMessage: String?
    
    /// 地图区域
    @Published var mapRegion: MKCoordinateRegion
    
    /// 地图相机位置
    @Published var cameraPosition: MapCameraPosition = .automatic
    
    // MARK: - Properties
    
    /// 目的地
    let destination: Location
    
    /// 用户当前位置
    let userLocation: CLLocationCoordinate2D
    
    /// 交通方式
    var transportMode: TransportMode {
        didSet {
            if oldValue != transportMode {
                isAirplaneMode = transportMode == .airplane
                Task {
                    await fetchRoutes()
                }
            }
        }
    }
    
    /// 路线 ETA 服务
    private let routeETAService = RouteETAService.shared
    
    /// 取消令牌
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// 获取选中的路线
    var selectedRoute: RouteOption? {
        routes.first { $0.id == selectedRouteId }
    }
    
    /// 目的地坐标
    var destinationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
    }
    
    /// 是否有可用路线
    var hasRoutes: Bool {
        !routes.isEmpty
    }
    
    // MARK: - Initialization
    
    init(
        destination: Location,
        userLocation: CLLocationCoordinate2D,
        transportMode: TransportMode
    ) {
        self.destination = destination
        self.userLocation = userLocation
        self.transportMode = transportMode
        self.isAirplaneMode = transportMode == .airplane
        
        // 初始化地图区域，包含用户位置和目的地
        self.mapRegion = MKCoordinateRegion.containing(
            userLocation,
            CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude),
            padding: 1.5
        )
        self.cameraPosition = .region(mapRegion)
    }
    
    // MARK: - Public Methods
    
    /// 获取路线
    func fetchRoutes() async {
        isLoading = true
        errorMessage = nil
        
        let result = await routeETAService.fetchRoutes(
            from: userLocation,
            to: destinationCoordinate,
            transportMode: transportMode
        )
        
        // 更新状态
        routes = result.routes
        selectedRouteId = result.selectedRoute?.id
        isAirplaneMode = transportMode == .airplane
        
        // 检查是否获取失败（使用了备用方案）
        if !result.isReliable && result.source == .directLine && transportMode != .airplane {
            errorMessage = "无法获取路线，显示直线距离估算"
        }
        
        // 更新地图区域以显示路线
        updateMapRegionForRoutes()
        
        isLoading = false
    }
    
    /// 选择路线
    /// - Parameter routeId: 路线 ID
    func selectRoute(_ routeId: String) {
        guard routes.contains(where: { $0.id == routeId }) else { return }
        
        // 更新选中状态
        selectedRouteId = routeId
        
        // 更新路线的 isSelected 属性
        routes = routes.map { route in
            var updated = route
            updated.isSelected = route.id == routeId
            return updated
        }
        
        // 触发触觉反馈
        HapticManager.shared.trigger(.selection)
    }
    
    /// 确认选择并返回选中的路线
    /// - Returns: 选中的路线，如果没有选中则返回 nil
    func confirmSelection() -> RouteOption? {
        return selectedRoute
    }
    
    /// 取消请求
    func cancelRequests() async {
        await routeETAService.cancelPendingRequests()
    }
    
    // MARK: - Private Methods
    
    /// 更新地图区域以显示所有路线
    private func updateMapRegionForRoutes() {
        guard let selectedRoute = selectedRoute,
              let polyline = selectedRoute.polyline else {
            // 如果没有路线，显示用户位置和目的地
            let newRegion = MKCoordinateRegion.containing(
                userLocation,
                destinationCoordinate,
                padding: 1.5
            )
            mapRegion = newRegion
            cameraPosition = .region(newRegion)
            return
        }
        
        // 计算包含路线的区域
        let rect = polyline.boundingMapRect
        let newRegion = MKCoordinateRegion(rect)
        
        // 添加一些边距
        let paddedRegion = MKCoordinateRegion(
            center: newRegion.center,
            span: MKCoordinateSpan(
                latitudeDelta: newRegion.span.latitudeDelta * 1.3,
                longitudeDelta: newRegion.span.longitudeDelta * 1.3
            )
        )
        
        withAnimation(.easeInOut(duration: 0.3)) {
            mapRegion = paddedRegion
            cameraPosition = .region(paddedRegion)
        }
    }
}

// MARK: - Route Data Validation

extension RouteSelectionViewModel {
    
    /// 获取有效的路线列表
    var validRoutes: [RouteOption] {
        RouteValidator.filterValidRoutes(routes)
    }
}
