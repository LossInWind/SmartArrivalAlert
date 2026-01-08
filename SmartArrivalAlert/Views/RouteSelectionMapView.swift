import SwiftUI
import MapKit
import CoreLocation

// MARK: - Route Selection Map View

/// 全屏路线选择地图视图
/// 显示所有可用路线，支持点击选择，底部显示路线列表面板
struct RouteSelectionMapView: View {
    @ObservedObject var viewModel: RouteSelectionViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var cameraPosition: MapCameraPosition = .automatic
    @ObservedObject private var styleManager = MapStyleManager.shared
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 地图
                mapContent
                
                // 底部路线列表面板
                VStack {
                    Spacer()
                    RouteListPanel(
                        routes: viewModel.routes,
                        selectedRouteId: viewModel.selectedRouteId,
                        isLoading: viewModel.isLoading,
                        onSelectRoute: { routeId in
                            viewModel.selectRoute(routeId)
                            updateCameraForSelectedRoute()
                        }
                    )
                }
            }
            .navigationTitle("选择路线")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .task {
                await viewModel.fetchRoutes()
                fitMapToRoutes()
            }
        }
    }
    
    // MARK: - Map Content
    
    private var mapContent: some View {
        Map(position: $cameraPosition) {
            // 显示所有路线折线
            ForEach(viewModel.routes) { route in
                if let polyline = route.polyline {
                    MapPolyline(polyline)
                        .stroke(
                            routeColor(for: route),
                            lineWidth: route.id == viewModel.selectedRouteId ? 6 : 3
                        )
                }
            }
            
            // 用户位置标记
            Annotation("我的位置", coordinate: viewModel.userLocation) {
                UserLocationMarker()
            }
            
            // 目的地标记
            let destCoord = CLLocationCoordinate2D(
                latitude: viewModel.destination.latitude,
                longitude: viewModel.destination.longitude
            )
            Annotation(viewModel.destination.name, coordinate: destCoord) {
                DestinationMarker()
            }
        }
        .mapStyle(styleManager.currentStyle.mapKitStyle)
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }
    
    // MARK: - Helper Methods
    
    /// 获取路线颜色
    private func routeColor(for route: RouteOption) -> Color {
        if route.id == viewModel.selectedRouteId {
            return .blue
        } else if route.source == .directLine {
            return .orange.opacity(0.6)
        } else {
            return .gray.opacity(0.5)
        }
    }
    
    /// 调整地图以显示所有路线
    private func fitMapToRoutes() {
        guard !viewModel.routes.isEmpty else {
            // 没有路线时，显示用户位置和目的地
            fitMapToUserAndDestination()
            return
        }
        
        // 收集所有坐标点
        var allCoordinates: [CLLocationCoordinate2D] = [viewModel.userLocation]
        let destCoord = CLLocationCoordinate2D(
            latitude: viewModel.destination.latitude,
            longitude: viewModel.destination.longitude
        )
        allCoordinates.append(destCoord)
        
        // 添加路线折线的坐标
        for route in viewModel.routes {
            if let polyline = route.polyline {
                let points = polyline.points()
                for i in 0..<polyline.pointCount {
                    allCoordinates.append(points[i].coordinate)
                }
            }
        }
        
        // 计算包含所有点的区域
        let region = MKCoordinateRegion.containing(coordinates: allCoordinates, padding: 1.5)
        
        withAnimation(AnimationConstants.Curve.slow) {
            cameraPosition = .region(region)
        }
    }
    
    /// 调整地图以显示用户位置和目的地
    private func fitMapToUserAndDestination() {
        let destCoord = CLLocationCoordinate2D(
            latitude: viewModel.destination.latitude,
            longitude: viewModel.destination.longitude
        )
        
        let region = MKCoordinateRegion.containing(
            coordinates: [viewModel.userLocation, destCoord],
            padding: 1.5
        )
        
        withAnimation(AnimationConstants.Curve.slow) {
            cameraPosition = .region(region)
        }
    }
    
    /// 更新相机以显示选中的路线
    private func updateCameraForSelectedRoute() {
        guard let selectedRoute = viewModel.selectedRoute,
              let polyline = selectedRoute.polyline else {
            return
        }
        
        // 收集选中路线的坐标
        var coordinates: [CLLocationCoordinate2D] = [viewModel.userLocation]
        let destCoord = CLLocationCoordinate2D(
            latitude: viewModel.destination.latitude,
            longitude: viewModel.destination.longitude
        )
        coordinates.append(destCoord)
        
        let points = polyline.points()
        for i in 0..<polyline.pointCount {
            coordinates.append(points[i].coordinate)
        }
        
        let region = MKCoordinateRegion.containing(coordinates: coordinates, padding: 1.3)
        
        withAnimation(AnimationConstants.Curve.map) {
            cameraPosition = .region(region)
        }
    }
}

// MARK: - MKCoordinateRegion Extension

extension MKCoordinateRegion {
    /// 创建包含多个坐标的区域
    static func containing(coordinates: [CLLocationCoordinate2D], padding: Double = 1.2) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.9, longitude: 116.4),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude
        
        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let latDelta = (maxLat - minLat) * padding
        let lonDelta = (maxLon - minLon) * padding
        
        // 确保最小跨度
        let span = MKCoordinateSpan(
            latitudeDelta: max(latDelta, 0.01),
            longitudeDelta: max(lonDelta, 0.01)
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Preview

#Preview {
    RouteSelectionMapView(
        viewModel: RouteSelectionViewModel(
            destination: Location(
                id: "test",
                name: "测试目的地",
                address: "测试地址",
                latitude: 39.9,
                longitude: 116.4
            ),
            userLocation: CLLocationCoordinate2D(latitude: 39.95, longitude: 116.45),
            transportMode: .walking
        )
    )
}
