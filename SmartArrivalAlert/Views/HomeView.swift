import SwiftUI
import CoreLocation
import MapKit

/// 主页面视图
struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @StateObject private var alertManager = AlertManager.shared
    @EnvironmentObject var permissionManager: PermissionManager
    @State private var showMapDetail = false
    @State private var showMapPicker = false
    @State private var showSettings = false
    @State private var showRouteSelection = false
    @State private var showAbout = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if permissionManager.isLocationDenied || permissionManager.isNotificationDenied {
                    permissionDeniedView
                } else if viewModel.monitoringStatus.state == .monitoring {
                    MonitoringView(viewModel: viewModel)
                } else {
                    mainContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    NavTitleBrandView()
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAbout = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.body)
                    }
                }
            }
        }
        .task {
            await viewModel.loadLocations()
        }
        .sheet(isPresented: $showMapPicker) {
            MapPickerView { location in
                viewModel.selectLocation(location)
                Task { await viewModel.addRecentLocation(location) }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .sheet(isPresented: $showRouteSelection) {
            if let selected = viewModel.selectedLocation,
               let userLocation = CLLocationManager().location?.coordinate {
                RouteSelectionMapView(
                    viewModel: RouteSelectionViewModel(
                        destination: selected,
                        userLocation: userLocation,
                        transportMode: viewModel.selectedTransportMode
                    )
                )
            }
        }
        .sheet(isPresented: $viewModel.showRiskWarning) {
            RiskWarningSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $viewModel.showFeedbackDialog) {
            FeedbackSheet(viewModel: viewModel)
                .presentationDetents([.height(200)])
        }
        .fullScreenCover(isPresented: $alertManager.showAlertView) {
            ArrivalAlertView(alertManager: alertManager)
        }
    }
    
    /// 权限被拒绝时的视图
    private var permissionDeniedView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "location.slash.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)
            
            VStack(spacing: 8) {
                Text("需要权限")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("到站提醒需要位置和通知权限才能正常工作")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                if permissionManager.isLocationDenied {
                    PermissionRow(
                        icon: "location.fill",
                        title: "位置权限",
                        status: "未授权",
                        statusColor: .red
                    )
                }
                
                if permissionManager.isNotificationDenied {
                    PermissionRow(
                        icon: "bell.fill",
                        title: "通知权限",
                        status: "未授权",
                        statusColor: .red
                    )
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)
            
            Button {
                permissionManager.openSettings()
            } label: {
                HStack {
                    Image(systemName: "gear")
                    Text("前往设置")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            
            Spacer()
        }
    }
    
    private var mainContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 编辑模式
                if viewModel.isEditMode {
                    editModeContent
                } else {
                    // 地图入口卡片（没有选中目的地时显示）
                    if viewModel.selectedLocation == nil {
                        HomeMapCard {
                            showMapPicker = true
                        }
                    }
                    
                    // 选中的目的地
                    if let selected = viewModel.selectedLocation {
                        selectedDestinationCard(selected)
                    }
                    
                    // 收藏地点
                    if !viewModel.favoriteLocations.isEmpty {
                        locationSection(
                            title: "收藏",
                            locations: viewModel.favoriteLocations,
                            section: .favorite
                        )
                    }
                    
                    // 最近地点
                    if !viewModel.recentLocations.isEmpty {
                        locationSection(
                            title: "最近",
                            locations: viewModel.recentLocations,
                            section: .recent
                        )
                    }
                    
                    // 空状态（只有在没有任何地点且没有选中时显示）
                    if viewModel.recentLocations.isEmpty && viewModel.favoriteLocations.isEmpty && viewModel.selectedLocation == nil {
                        emptyStateHint
                    }
                }
            }
            .padding()
        }
    }
    
    /// 编辑模式内容（统一编辑收藏和历史地点）
    private var editModeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题栏
            HStack {
                Text("编辑地点")
                    .font(.headline)
                
                Spacer()
                
                Button("完成") {
                    viewModel.exitEditMode()
                }
                .font(.subheadline)
                .foregroundStyle(.blue)
            }
            
            // 统一工具栏
            UnifiedEditModeToolbar(viewModel: viewModel)
            
            // 收藏地点
            if !viewModel.favoriteLocations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("收藏")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    EditableLocationList(
                        viewModel: viewModel,
                        locations: $viewModel.favoriteLocations,
                        section: .favorite
                    )
                }
            }
            
            // 最近地点
            if !viewModel.recentLocations.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    EditableLocationList(
                        viewModel: viewModel,
                        locations: $viewModel.recentLocations,
                        section: .recent
                    )
                }
            }
            
            // 空状态
            if viewModel.favoriteLocations.isEmpty && viewModel.recentLocations.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "tray")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("没有地点")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            }
        }
    }
    
    private func selectedDestinationCard(_ location: Location) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(location.name)
                        .font(.headline)
                    Text(location.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                
                // 收藏按钮 - 使用 viewModel.selectedLocation 确保实时更新
                Button {
                    Task { await viewModel.toggleFavorite(location) }
                } label: {
                    Image(systemName: viewModel.selectedLocation?.isFavorite == true ? "star.fill" : "star")
                        .foregroundStyle(viewModel.selectedLocation?.isFavorite == true ? .yellow : .gray)
                }
                
                // 取消选择按钮
                Button {
                    viewModel.clearSelectedLocation()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
            
            // 地图预览（点击打开路线选择）
            MapPreviewView(
                destination: location,
                geofenceRadius: viewModel.geofenceRadius
            ) {
                showRouteSelection = true
            }
            .id(location.id) // 强制在地点变化时重新创建地图
            .overlay(alignment: .bottomTrailing) {
                // 路线选择提示
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.caption2)
                    Text("选择路线")
                        .font(.caption2)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(8)
            }
            
            // 交通方式选择器（支持滑动）
            SwipeableTransportModeSelector(selectedMode: $viewModel.selectedTransportMode)
            
            // 选中路线信息显示
            if let route = viewModel.selectedRoute {
                CompactRouteInfo(route: route, isLoading: viewModel.isLoadingRoutes)
            } else if viewModel.isLoadingRoutes {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("加载路线中...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // 围栏半径滑杆（范围从设置中读取）
            VStack(alignment: .leading, spacing: 8) {
                Text("提醒距离：\(GeofenceRadiusConfig.formatRadius(Double(viewModel.geofenceRadius)))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HapticIntSlider(
                    value: Binding(
                        get: { viewModel.geofenceRadius },
                        set: { viewModel.geofenceRadius = Int(GeofenceRadiusConfig.snapToStep(Double($0))) }
                    ),
                    in: 100...viewModel.maxGeofenceRadius,
                    step: 50,
                    tint: .blue
                )
            }
            
            // 预计提醒时间显示（优先使用路线 ETA）
            if let route = viewModel.selectedRoute {
                HStack {
                    Image(systemName: viewModel.selectedTransportMode.icon)
                        .foregroundStyle(.blue)
                    Text("预计 \(route.etaMinutes) 分钟后提醒")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if route.source == .directLine {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            } else if let eta = viewModel.initialETA {
                HStack {
                    Image(systemName: viewModel.selectedTransportMode.icon)
                        .foregroundStyle(.blue)
                    Text("预计 \(eta) 分钟后提醒")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            
            // 开始按钮
            Button {
                Task { await viewModel.startDiagnosis() }
            } label: {
                HStack {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "bell.fill")
                        Text("开始提醒")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(viewModel.isLoading)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showMapDetail) {
            if let selected = viewModel.selectedLocation {
                MapDetailView(viewModel: MapViewModel(
                    destination: selected,
                    geofenceRadius: viewModel.geofenceRadius,
                    mode: .preview
                ))
            }
        }
    }
    
    private func locationSection(title: String, locations: [Location], section: HomeViewModel.EditingSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题栏
            HStack {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            
            // 普通模式：地点列表
            LazyVStack(spacing: 8) {
                ForEach(locations) { location in
                    LocationRowWithLongPress(
                        location: location,
                        onTap: {
                            withAnimation(AnimationConstants.Curve.standard) {
                                viewModel.selectLocation(location)
                            }
                        },
                        onLongPress: {
                            viewModel.enterEditMode()
                        }
                    )
                }
            }
        }
    }
    
    /// 空状态提示（简化版，配合地图卡片使用）
    private var emptyStateHint: some View {
        VStack(spacing: 12) {
            Image(systemName: "hand.tap")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            
            Text("点击上方地图选择目的地")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Home Map Card

/// 首页地图入口卡片
struct HomeMapCard: View {
    let onTap: () -> Void
    
    @State private var cameraPosition: MapCameraPosition
    @StateObject private var locationManager = HomeMapLocationManager()
    @ObservedObject private var styleManager = MapStyleManager.shared
    
    init(onTap: @escaping () -> Void) {
        self.onTap = onTap
        // 默认显示一个较大范围的地图
        let defaultRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 39.9042, longitude: 116.4074), // 北京
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        _cameraPosition = State(initialValue: .region(defaultRegion))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 地图区域
            ZStack {
                Map(position: $cameraPosition, interactionModes: []) {
                    // 显示用户位置（如果有）
                    if let userLocation = locationManager.currentLocation {
                        Annotation("", coordinate: userLocation) {
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 20, height: 20)
                                    .shadow(radius: 2)
                                Circle()
                                    .fill(.blue)
                                    .frame(width: 12, height: 12)
                            }
                        }
                    }
                }
                .mapStyle(styleManager.currentStyle.mapKitStyle)
                
                // 中心提示
                VStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(.blue)
                        .shadow(color: .white, radius: 2)
                    
                    Text("点击选择目的地")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
            )
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onAppear {
            locationManager.requestLocation()
        }
        .task(id: locationManager.locationUpdateId) {
            if let location = locationManager.currentLocation {
                withAnimation(AnimationConstants.Curve.slow) {
                    cameraPosition = .region(MKCoordinateRegion(
                        center: location,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    ))
                }
            }
        }
    }
}

/// 首页地图位置管理器
class HomeMapLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var locationUpdateId: Int = 0
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    deinit {
        locationManager.stopUpdatingLocation()
        locationManager.delegate = nil
    }
    
    func requestLocation() {
        let status = locationManager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async { [weak self] in
            self?.currentLocation = location.coordinate
            self?.locationUpdateId += 1
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 静默处理错误，地图会显示默认位置
    }
}

/// 地点行
struct LocationRow: View {
    let location: Location
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: location.isFavorite ? "star.fill" : "mappin.circle.fill")
                    .foregroundStyle(location.isFavorite ? .yellow : .blue)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(location.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    Text(location.address)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

/// 支持长按的地点行
struct LocationRowWithLongPress: View {
    let location: Location
    let onTap: () -> Void
    let onLongPress: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: location.isFavorite ? "star.fill" : "mappin.circle.fill")
                .foregroundStyle(location.isFavorite ? .yellow : .blue)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(location.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(isPressed ? Color.gray.opacity(0.1) : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .scaleEffect(isPressed ? AnimationConstants.Scale.pressed : AnimationConstants.Scale.normal)
        .animation(AnimationConstants.Curve.fast, value: isPressed)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
            withAnimation(AnimationConstants.Curve.fast) {
                isPressed = pressing
            }
        }, perform: {
            onLongPress()
        })
    }
}

/// 监控状态视图
struct MonitoringView: View {
    @ObservedObject var viewModel: HomeViewModel
    @StateObject private var mapViewModel: MapViewModel
    @StateObject private var locationManager = MonitoringLocationManager()
    @State private var showRouteList = false
    
    init(viewModel: HomeViewModel) {
        self.viewModel = viewModel
        
        // 初始化地图视图模型
        let destination = viewModel.monitoringStatus.config?.destination
        let radius = viewModel.monitoringStatus.config?.geofenceRadius ?? 500
        
        // 尝试获取初始用户位置
        let initialUserLocation: CLLocationCoordinate2D?
        if let lastLocation = viewModel.monitoringStatus.lastLocation {
            initialUserLocation = CLLocationCoordinate2D(
                latitude: lastLocation.latitude,
                longitude: lastLocation.longitude
            )
        } else {
            initialUserLocation = nil
        }
        
        _mapViewModel = StateObject(wrappedValue: MapViewModel(
            destination: destination,
            userLocation: initialUserLocation,
            geofenceRadius: radius,
            mode: .monitoring
        ))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 地图区域
            MonitoringMapView(viewModel: mapViewModel)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.top, 8)
            
            // 信号质量指示器
            SignalQualityIndicator(signalQuality: viewModel.signalQuality)
                .padding(.horizontal)
                .padding(.top, 12)
            
            // 路线 ETA 来源指示（如果有路线数据）
            if viewModel.routeETAResult.hasRoutes {
                RouteETASourceIndicator(
                    result: viewModel.routeETAResult,
                    isLoading: viewModel.isLoadingRoutes,
                    onShowRoutes: { showRouteList = true }
                )
                .padding(.horizontal)
                .padding(.top, 8)
            }
            
            Spacer()
            
            // 目的地信息和 ETA
            if let destination = viewModel.monitoringStatus.config?.destination {
                VStack(spacing: 12) {
                    // 目的地名称和交通方式图标
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.selectedTransportMode.icon)
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                        Text(destination.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    // 距离和 ETA 信息（优先使用路线 ETA）
                    HStack(spacing: 24) {
                        // 距离（优先使用路线距离）
                        VStack(spacing: 4) {
                            if viewModel.selectedRoute?.distance != nil {
                                Text(viewModel.selectedRoute?.distanceText ?? "--")
                                    .font(.system(size: 28, weight: .light, design: .rounded))
                                    .foregroundStyle(isInsideGeofence ? .green : .blue)
                                    .contentTransition(.numericText())
                                    .animation(AnimationConstants.Curve.map, value: isInsideGeofence)
                            } else if let distance = viewModel.monitoringStatus.distanceToDestination {
                                Text("\(Int(distance))")
                                    .font(.system(size: 36, weight: .light, design: .rounded))
                                    .foregroundStyle(isInsideGeofence ? .green : .blue)
                                    .contentTransition(.numericText())
                                    .animation(AnimationConstants.Curve.map, value: isInsideGeofence)
                            } else {
                                Text("--")
                                    .font(.system(size: 36, weight: .light, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            Text(viewModel.selectedRoute != nil ? "" : "米")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        // 分隔线
                        Rectangle()
                            .fill(.secondary.opacity(0.3))
                            .frame(width: 1, height: 40)
                        
                        // ETA（优先使用路线 ETA）
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                if let routeETA = viewModel.selectedRoute?.etaMinutes {
                                    Text("\(routeETA)")
                                        .font(.system(size: 36, weight: .light, design: .rounded))
                                        .foregroundColor(viewModel.routeETAResult.isReliable ? .primary : .orange)
                                        .contentTransition(.numericText())
                                } else if let minutes = viewModel.currentETA.estimatedMinutes {
                                    Text("\(minutes)")
                                        .font(.system(size: 36, weight: .light, design: .rounded))
                                        .foregroundColor(viewModel.currentETA.isReliable ? .primary : .orange)
                                        .contentTransition(.numericText())
                                } else {
                                    Text("--")
                                        .font(.system(size: 36, weight: .light, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                
                                // 可靠性警告图标
                                if !viewModel.routeETAResult.isReliable && viewModel.selectedRoute != nil {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                } else if !viewModel.currentETA.isReliable && viewModel.currentETA.estimatedMinutes != nil {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                            
                            Text("分钟")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // ETA 状态文本
                    if let route = viewModel.selectedRoute {
                        Text(route.timeText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text(viewModel.currentETA.displayText)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // 状态指示
            VStack(spacing: 8) {
                if isInsideGeofence {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(.green)
                    Text("已进入提醒范围")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                } else {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("监控中...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 16)
            
            Spacer()
            
            // 停止按钮
            Button {
                Task { await viewModel.stopMonitoring() }
            } label: {
                Text("停止提醒")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .onChange(of: viewModel.monitoringStatus.lastLocation) { oldLocation, newLocation in
            if let location = newLocation {
                let coord = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
                mapViewModel.updateUserLocation(coord)
                
                // 更新围栏状态
                if let distance = viewModel.monitoringStatus.distanceToDestination,
                   let radius = viewModel.monitoringStatus.config?.geofenceRadius {
                    mapViewModel.updateGeofenceStatus(isInside: distance <= Double(radius))
                    
                    // 更新 ETA（使用模拟速度，实际应从位置更新中获取）
                    let speed = location.accuracy > 0 ? max(0, 5.0) : 0.0 // 默认步行速度约 5 m/s
                    let signalQuality: SignalQualityLevel = location.accuracy < 10 ? .good :
                                                           location.accuracy < 30 ? .fair :
                                                           location.accuracy < 100 ? .poor : .unknown
                    viewModel.updateETA(distance: distance, speed: speed, signalQuality: signalQuality)
                }
            }
        }
        .onChange(of: viewModel.availableRoutes) { _, newRoutes in
            // 更新地图上的路线显示
            mapViewModel.updateRoutes(
                newRoutes,
                selectedId: viewModel.selectedRoute?.id,
                isAirplane: viewModel.selectedTransportMode == .airplane
            )
        }
        .onAppear {
            // 请求当前位置
            locationManager.requestLocation()
            
            // 初始化路线显示
            if !viewModel.availableRoutes.isEmpty {
                mapViewModel.updateRoutes(
                    viewModel.availableRoutes,
                    selectedId: viewModel.selectedRoute?.id,
                    isAirplane: viewModel.selectedTransportMode == .airplane
                )
            }
        }
        .task(id: locationManager.locationUpdateId) {
            // 获取到用户位置时更新地图
            if let location = locationManager.currentLocation {
                mapViewModel.updateUserLocation(location)
            }
        }
        .sheet(isPresented: $showRouteList) {
            RouteListSheet(viewModel: viewModel)
                .presentationDetents([.medium])
        }
    }
    
    private var isInsideGeofence: Bool {
        guard let distance = viewModel.monitoringStatus.distanceToDestination,
              let radius = viewModel.monitoringStatus.config?.geofenceRadius else {
            return false
        }
        return distance <= Double(radius)
    }
}

// MARK: - Route ETA Source Indicator

/// 路线 ETA 来源指示器
struct RouteETASourceIndicator: View {
    let result: RouteETAResult
    let isLoading: Bool
    let onShowRoutes: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // 来源图标
            Image(systemName: result.isReliable ? "map.fill" : "line.diagonal")
                .font(.caption)
                .foregroundStyle(result.isReliable ? .blue : .orange)
            
            // 来源文本
            Text(result.source.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            // 可靠性指示
            if !result.isReliable {
                Text("(估算)")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
            
            Spacer()
            
            // 加载指示器
            if isLoading {
                ProgressView()
                    .scaleEffect(0.7)
            }
            
            // 查看路线按钮（如果有多条路线）
            if result.routes.count > 1 {
                Button(action: onShowRoutes) {
                    HStack(spacing: 4) {
                        Text("\(result.routes.count) 条路线")
                            .font(.caption)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundStyle(.blue)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Route List Sheet

/// 路线列表弹窗
struct RouteListSheet: View {
    @ObservedObject var viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.availableRoutes, id: \.id) { route in
                    RouteOptionRow(
                        route: route,
                        isSelected: route.id == viewModel.selectedRoute?.id
                    ) {
                        Task {
                            await viewModel.selectRoute(withId: route.id)
                        }
                        dismiss()
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("选择路线")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// 路线选项行
struct RouteOptionRow: View {
    let route: RouteOption
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 选中指示
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                
                // 路线信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(route.name)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 8) {
                        // 距离
                        Label(route.distanceText, systemImage: "arrow.left.and.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // 时间
                        Label(route.timeText, systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // 来源指示
                if route.source == .directLine {
                    Text("估算")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.1))
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

/// 监控页面位置管理器
class MonitoringLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocationCoordinate2D?
    @Published var locationUpdateId: Int = 0
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
    }
    
    deinit {
        locationManager.stopUpdatingLocation()
        locationManager.delegate = nil
    }
    
    func requestLocation() {
        let status = locationManager.authorizationStatus
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.requestLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        DispatchQueue.main.async { [weak self] in
            self?.currentLocation = location.coordinate
            self?.locationUpdateId += 1
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 静默处理错误
    }
}

/// 信号质量指示器
struct SignalQualityIndicator: View {
    let signalQuality: SignalQualityLevel
    
    var body: some View {
        HStack(spacing: 8) {
            // 信号图标
            Image(systemName: signalIcon)
                .foregroundStyle(signalColor)
                .font(.subheadline)
            
            // 信号强度条
            HStack(spacing: 2) {
                ForEach(0..<4) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(index < signalBars ? signalColor : Color.secondary.opacity(0.3))
                        .frame(width: 4, height: CGFloat(6 + index * 3))
                        .animation(AnimationConstants.Curve.fast, value: signalBars)
                }
            }
            
            // 信号质量文本
            Text(signalText)
                .font(.caption)
                .foregroundStyle(signalColor)
            
            Spacer()
            
            // 风险提示（信号差时显示）
            if signalQuality == .poor {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("信号较差")
                        .font(.caption2)
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .animation(AnimationConstants.Curve.fast, value: signalQuality)
    }
    
    private var signalIcon: String {
        switch signalQuality {
        case .good: return "antenna.radiowaves.left.and.right"
        case .fair: return "antenna.radiowaves.left.and.right"
        case .poor: return "antenna.radiowaves.left.and.right.slash"
        case .unknown: return "antenna.radiowaves.left.and.right"
        }
    }
    
    private var signalColor: Color {
        switch signalQuality {
        case .good: return .green
        case .fair: return .orange
        case .poor: return .red
        case .unknown: return .secondary
        }
    }
    
    private var signalBars: Int {
        switch signalQuality {
        case .good: return 4
        case .fair: return 2
        case .poor: return 1
        case .unknown: return 0
        }
    }
    
    private var signalText: String {
        switch signalQuality {
        case .good: return "信号良好"
        case .fair: return "信号一般"
        case .poor: return "信号较差"
        case .unknown: return "检测中..."
        }
    }
}

/// 风险警告弹窗
struct RiskWarningSheet: View {
    @ObservedObject var viewModel: HomeViewModel
    @State private var backupAlarmTime = Date().addingTimeInterval(30 * 60)
    @State private var enableBackupAlarm = false
    
    var body: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Image(systemName: riskIcon)
                    .foregroundStyle(riskColor)
                    .font(.title2)
                Text("风险提示")
                    .font(.headline)
            }
            .padding(.top, 8)
            
            if let assessment = viewModel.riskAssessment {
                // 风险等级指示
                HStack {
                    Text("风险等级")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(riskLevelText(assessment.overallRisk))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(riskColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // 详细信息卡片
                VStack(spacing: 0) {
                    // 目的地信号质量
                    RiskDetailRow(
                        icon: "antenna.radiowaves.left.and.right",
                        title: "目的地信号",
                        value: signalQualityText(assessment.destinationSignalQuality.level),
                        valueColor: signalQualityColor(assessment.destinationSignalQuality.level)
                    )
                    
                    Divider().padding(.leading, 44)
                    
                    // 路线信号质量
                    RiskDetailRow(
                        icon: "point.topleft.down.to.point.bottomright.curvepath",
                        title: "路线信号",
                        value: signalQualityText(assessment.routeSignalQuality.level),
                        valueColor: signalQualityColor(assessment.routeSignalQuality.level)
                    )
                    
                    Divider().padding(.leading, 44)
                    
                    // 历史成功率
                    RiskDetailRow(
                        icon: "chart.line.uptrend.xyaxis",
                        title: "历史成功率",
                        value: "\(Int(assessment.historicalSuccessRate))%",
                        valueColor: successRateColor(assessment.historicalSuccessRate)
                    )
                }
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                // 警告信息
                if !assessment.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(assessment.warnings, id: \.self) { warning in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundStyle(.orange)
                                    .font(.caption)
                                Text(warning)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                
                // 兜底闹钟选项
                if assessment.suggestBackupAlarm {
                    VStack(spacing: 8) {
                        Toggle(isOn: $enableBackupAlarm) {
                            HStack {
                                Image(systemName: "alarm.fill")
                                    .foregroundStyle(.blue)
                                Text("设置兜底闹钟")
                                    .font(.subheadline)
                            }
                        }
                        
                        if enableBackupAlarm {
                            DatePicker("闹钟时间", selection: $backupAlarmTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                        }
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            
            // 按钮
            HStack(spacing: 12) {
                Button("取消") {
                    viewModel.cancelRiskWarning()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.gray.opacity(0.1))
                .foregroundStyle(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                Button("继续") {
                    Task {
                        if enableBackupAlarm {
                            await viewModel.setBackupAlarm(at: backupAlarmTime)
                        }
                        await viewModel.confirmRiskAndStart()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
    }
    
    private var riskIcon: String {
        guard let assessment = viewModel.riskAssessment else { return "exclamationmark.triangle.fill" }
        switch assessment.overallRisk {
        case .high: return "exclamationmark.triangle.fill"
        case .medium: return "exclamationmark.circle.fill"
        case .low: return "checkmark.circle.fill"
        }
    }
    
    private var riskColor: Color {
        guard let assessment = viewModel.riskAssessment else { return .orange }
        switch assessment.overallRisk {
        case .high: return .red
        case .medium: return .orange
        case .low: return .green
        }
    }
    
    private func riskLevelText(_ level: RiskLevel) -> String {
        switch level {
        case .high: return "高风险"
        case .medium: return "中风险"
        case .low: return "低风险"
        }
    }
    
    private func signalQualityText(_ level: SignalQualityLevel) -> String {
        switch level {
        case .good: return "良好"
        case .fair: return "一般"
        case .poor: return "较差"
        case .unknown: return "未知"
        }
    }
    
    private func signalQualityColor(_ level: SignalQualityLevel) -> Color {
        switch level {
        case .good: return .green
        case .fair: return .orange
        case .poor: return .red
        case .unknown: return .secondary
        }
    }
    
    private func successRateColor(_ rate: Double) -> Color {
        if rate >= 85 { return .green }
        if rate >= 70 { return .orange }
        return .red
    }
}

/// 风险详情行
struct RiskDetailRow: View {
    let icon: String
    let title: String
    let value: String
    let valueColor: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(valueColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

/// 反馈弹窗
struct FeedbackSheet: View {
    @ObservedObject var viewModel: HomeViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部拖拽指示器
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 8)
                .padding(.bottom, 20)
            
            // 标题
            Text("提醒及时吗？")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.bottom, 24)
            
            // 反馈选项
            HStack(spacing: 12) {
                FeedbackOptionButton(
                    icon: "checkmark.circle.fill",
                    title: "及时",
                    color: .green
                ) {
                    Task { await viewModel.recordFeedback(.success) }
                    dismiss()
                }
                
                FeedbackOptionButton(
                    icon: "clock.fill",
                    title: "晚了",
                    color: .orange
                ) {
                    Task { await viewModel.recordFeedback(.late) }
                    dismiss()
                }
                
                FeedbackOptionButton(
                    icon: "xmark.circle.fill",
                    title: "漏响",
                    color: .red
                ) {
                    Task { await viewModel.recordFeedback(.missed) }
                    dismiss()
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
    }
}

/// 反馈选项按钮
struct FeedbackOptionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            HapticManager.shared.trigger(.selection)
            action()
        }) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 28))
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(color.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.pressable)
    }
}

struct FeedbackButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(color.opacity(0.1))
                .foregroundStyle(color)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Transport Mode Selector

/// 交通方式选择器
struct TransportModeSelector: View {
    @Binding var selectedMode: TransportMode
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TransportMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(AnimationConstants.Curve.listSelection) {
                        selectedMode = mode
                    }
                    HapticManager.shared.trigger(.light)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 20))
                        Text(mode.displayName)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedMode == mode ? Color.blue.opacity(0.1) : Color.clear)
                    .foregroundStyle(selectedMode == mode ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// 权限状态行
struct PermissionRow: View {
    let icon: String
    let title: String
    let status: String
    let statusColor: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(status)
                .font(.caption)
                .foregroundStyle(statusColor)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(PermissionManager())
}

// MARK: - Edit Mode Components

/// 统一编辑模式工具栏（支持同时编辑收藏和历史地点）
struct UnifiedEditModeToolbar: View {
    @ObservedObject var viewModel: HomeViewModel
    
    private var allLocations: [Location] {
        viewModel.favoriteLocations + viewModel.recentLocations
    }
    
    private var isAllSelected: Bool {
        !allLocations.isEmpty && viewModel.selectedLocationIds.count == allLocations.count
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 全选按钮
            Button {
                viewModel.toggleSelectAll()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isAllSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isAllSelected ? .blue : .secondary)
                    Text(isAllSelected ? "取消全选" : "全选")
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // 删除按钮
            if !viewModel.selectedLocationIds.isEmpty {
                Button {
                    Task { await viewModel.deleteSelectedLocations() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("删除 (\(viewModel.selectedLocationIds.count))")
                            .font(.caption)
                    }
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// 编辑模式工具栏（保留用于单独 section 编辑，如果需要）
struct EditModeToolbar: View {
    @ObservedObject var viewModel: HomeViewModel
    let section: HomeViewModel.EditingSection
    
    private var locations: [Location] {
        switch section {
        case .recent:
            return viewModel.recentLocations
        case .favorite:
            return viewModel.favoriteLocations
        case .all:
            return viewModel.favoriteLocations + viewModel.recentLocations
        }
    }
    
    private var isAllSelected: Bool {
        !locations.isEmpty && viewModel.selectedLocationIds.count == locations.count
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 全选按钮
            Button {
                viewModel.toggleSelectAll()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: isAllSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isAllSelected ? .blue : .secondary)
                    Text(isAllSelected ? "取消全选" : "全选")
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            // 删除按钮
            if !viewModel.selectedLocationIds.isEmpty {
                Button {
                    Task { await viewModel.deleteSelectedLocations() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("删除 (\(viewModel.selectedLocationIds.count))")
                            .font(.caption)
                    }
                    .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// 可编辑的地点列表
struct EditableLocationList: View {
    @ObservedObject var viewModel: HomeViewModel
    @Binding var locations: [Location]
    let section: HomeViewModel.EditingSection
    
    var body: some View {
        List {
            ForEach(locations) { location in
                EditableLocationRow(
                    location: location,
                    isSelected: viewModel.selectedLocationIds.contains(location.id),
                    onToggle: {
                        viewModel.toggleLocationSelection(location.id)
                    },
                    onDelete: {
                        Task { await viewModel.deleteLocation(location, from: section) }
                    }
                )
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onMove { source, destination in
                if section == .recent {
                    viewModel.moveRecentLocation(from: source, to: destination)
                } else {
                    viewModel.moveFavoriteLocation(from: source, to: destination)
                }
            }
        }
        .listStyle(.plain)
        .frame(minHeight: CGFloat(locations.count * 60 + 20))
        .scrollDisabled(true)
        .environment(\.editMode, .constant(.active))
    }
}

/// 可编辑的地点行
struct EditableLocationRow: View {
    let location: Location
    let isSelected: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 选择框
            Button(action: onToggle) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .blue : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            
            // 地点信息
            VStack(alignment: .leading, spacing: 2) {
                Text(location.name)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(location.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 单独删除按钮
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red.opacity(0.8))
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
