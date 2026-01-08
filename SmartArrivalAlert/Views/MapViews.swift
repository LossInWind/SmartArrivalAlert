import SwiftUI
import MapKit
import CoreLocation

// MARK: - MapPreviewView

/// 小地图预览组件 - 用于主页显示选中目的地
struct MapPreviewView: View {
    let destination: Location
    let geofenceRadius: Int
    let onTap: () -> Void
    
    @State private var cameraPosition: MapCameraPosition
    @ObservedObject private var styleManager = MapStyleManager.shared
    
    init(destination: Location, geofenceRadius: Int, onTap: @escaping () -> Void) {
        self.destination = destination
        self.geofenceRadius = geofenceRadius
        self.onTap = onTap
        
        // 初始化相机位置
        let coordinate = CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
        let region = MKCoordinateRegion.containing(
            coordinate: coordinate,
            radius: Double(geofenceRadius),
            padding: 2.5
        )
        _cameraPosition = State(initialValue: .region(region))
    }
    
    var body: some View {
        Map(position: $cameraPosition, interactionModes: []) {
            // 目的地标记
            Annotation(destination.name, coordinate: destinationCoordinate) {
                DestinationMarker()
            }
            
            // 围栏圆圈
            MapCircle(center: destinationCoordinate, radius: CLLocationDistance(geofenceRadius))
                .foregroundStyle(.blue.opacity(0.15))
                .stroke(.blue.opacity(0.5), lineWidth: 2)
        }
        .mapStyle(styleManager.currentStyle.mapKitStyle)
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onChange(of: geofenceRadius) { _, newRadius in
            // 围栏半径变化时更新相机位置以适应新的范围
            let coordinate = CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
            let region = MKCoordinateRegion.containing(
                coordinate: coordinate,
                radius: Double(newRadius),
                padding: 2.5
            )
            withAnimation(AnimationConstants.Curve.map) {
                cameraPosition = .region(region)
            }
        }
    }
    
    private var destinationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
    }
}

// MARK: - MapDetailView

/// 全屏地图视图 - 用于监控状态和详细查看
struct MapDetailView: View {
    @ObservedObject var viewModel: MapViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Map(position: $viewModel.cameraPosition) {
                // 路线折线（显示所有路线，选中的高亮）
                ForEach(viewModel.routes, id: \.id) { route in
                    if let polyline = route.polyline {
                        MapPolyline(polyline)
                            .stroke(
                                route.id == viewModel.selectedRouteId ? Color.blue : Color.gray.opacity(0.5),
                                lineWidth: route.id == viewModel.selectedRouteId ? 5 : 3
                            )
                    }
                }
                
                // 标注
                ForEach(viewModel.annotations) { annotation in
                    Annotation(annotation.title, coordinate: annotation.coordinate) {
                        switch annotation.type {
                        case .userLocation:
                            UserLocationMarker()
                        case .destination:
                            DestinationMarker()
                        }
                    }
                }
                
                // 围栏圆圈
                if let circle = viewModel.geofenceCircle {
                    MapCircle(center: circle.center, radius: circle.radius)
                        .foregroundStyle(circle.isInside ? .green.opacity(0.2) : .blue.opacity(0.15))
                        .stroke(circle.isInside ? .green : .blue.opacity(0.5), lineWidth: 2)
                }
            }
            .mapStyle(viewModel.mapStyle.mapKitStyle)
            .mapControls {
                MapCompass()
                MapScaleView()
                MapUserLocationButton()
            }
            .navigationTitle(viewModel.destination?.name ?? "地图")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                MapStyleSelector(selectedStyle: $viewModel.mapStyle) { style in
                    viewModel.setMapStyle(style)
                }
                .padding()
            }
        }
    }
}

// MARK: - MonitoringMapView

/// 监控状态地图视图 - 嵌入在监控页面中
struct MonitoringMapView: View {
    @ObservedObject var viewModel: MapViewModel
    
    var body: some View {
        Map(position: $viewModel.cameraPosition) {
            // 路线折线（显示所有路线，选中的高亮）
            ForEach(viewModel.routes, id: \.id) { route in
                if let polyline = route.polyline {
                    MapPolyline(polyline)
                        .stroke(
                            route.id == viewModel.selectedRouteId ? Color.blue : Color.gray.opacity(0.5),
                            lineWidth: route.id == viewModel.selectedRouteId ? 5 : 3
                        )
                }
            }
            
            // 用户位置
            if let userCoord = viewModel.userLocation {
                Annotation("我的位置", coordinate: userCoord) {
                    UserLocationMarker(isAnimating: true)
                }
            }
            
            // 目的地
            if let dest = viewModel.destination {
                let destCoord = CLLocationCoordinate2D(latitude: dest.latitude, longitude: dest.longitude)
                Annotation(dest.name, coordinate: destCoord) {
                    DestinationMarker()
                }
            }
            
            // 围栏圆圈
            if let circle = viewModel.geofenceCircle {
                MapCircle(center: circle.center, radius: circle.radius)
                    .foregroundStyle(circle.isInside ? .green.opacity(0.25) : .blue.opacity(0.15))
                    .stroke(circle.isInside ? .green : .blue, lineWidth: circle.isInside ? 3 : 2)
            }
        }
        .mapStyle(viewModel.mapStyle.mapKitStyle)
        .mapControls {
            MapCompass()
        }
    }
}

// MARK: - MapPickerView (Updated)

/// 地图选点视图 - 允许用户在地图上直接选择位置
struct MapPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MapViewModel
    @StateObject private var locationManager = PickerLocationManager()
    @State private var isLoading = false
    @State private var showStyleSelector = false
    @State private var hasInitializedLocation = false
    
    // 搜索相关状态
    @State private var searchText = ""
    @State private var searchResults: [Location] = []
    @State private var isSearching = false
    @State private var showSearchResults = false
    
    // 设置存储（用于保存/读取上次位置）
    private let settingsStore = SettingsStore()
    
    let initialLocation: CLLocationCoordinate2D?
    let onSelect: (Location) -> Void
    
    init(initialLocation: CLLocationCoordinate2D? = nil, onSelect: @escaping (Location) -> Void) {
        self.initialLocation = initialLocation
        self.onSelect = onSelect
        
        // 优先级：传入的位置 > 上次位置 > 默认位置
        let settingsStore = SettingsStore()
        let startLocation: CLLocationCoordinate2D
        
        if let initial = initialLocation {
            startLocation = initial
        } else if let lastLocation = settingsStore.lastMapLocation {
            startLocation = CLLocationCoordinate2D(latitude: lastLocation.latitude, longitude: lastLocation.longitude)
        } else {
            startLocation = .defaultLocation
        }
        
        _viewModel = StateObject(wrappedValue: MapViewModel(
            userLocation: startLocation,
            mode: .picker
        ))
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // 地图 - 使用 MapReader 支持点击选点
                MapReader { proxy in
                    Map(position: $viewModel.cameraPosition, interactionModes: [.pan, .zoom]) {
                        // 显示用户位置蓝点
                        if viewModel.showUserLocation, let userCoord = locationManager.currentLocation {
                            Annotation("我的位置", coordinate: userCoord) {
                                UserLocationMarker()
                            }
                        }
                        
                        // 显示选中的 POI
                        if let poi = viewModel.selectedPOI {
                            Annotation(poi.name, coordinate: poi.coordinate) {
                                POIMarker()
                            }
                        }
                    }
                    .mapStyle(viewModel.mapStyle.mapKitStyle)
                    .mapControls {
                        MapCompass()
                        MapScaleView()
                    }
                    .onMapCameraChange { context in
                        viewModel.region = context.region
                    }
                    .onTapGesture { screenCoord in
                        // 将屏幕坐标转换为地理坐标
                        if let coordinate = proxy.convert(screenCoord, from: .local) {
                            handleMapTap(at: coordinate)
                        }
                    }
                }
                
                // 固定中心标记（仅在没有选中 POI 时显示）
                if viewModel.selectedPOI == nil {
                    VStack {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.red)
                            .shadow(radius: 3)
                        
                        // 标记阴影
                        Ellipse()
                            .fill(.black.opacity(0.2))
                            .frame(width: 20, height: 8)
                            .offset(y: -5)
                    }
                    .offset(y: -20)
                }
                
                // 搜索栏和结果
                VStack(spacing: 0) {
                    // 搜索栏
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        
                        TextField("搜索地点", text: $searchText)
                            .textFieldStyle(.plain)
                            .onSubmit {
                                performSearch()
                            }
                        
                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                                searchResults = []
                                showSearchResults = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .padding(12)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    
                    // 搜索结果列表
                    if showSearchResults && !searchResults.isEmpty {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(searchResults) { location in
                                    SearchResultRow(location: location) {
                                        selectSearchResult(location)
                                    }
                                    
                                    if location.id != searchResults.last?.id {
                                        Divider()
                                            .padding(.leading, 44)
                                    }
                                }
                            }
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .frame(maxHeight: 250)
                        .padding(.horizontal, 12)
                        .padding(.top, 4)
                    }
                    
                    Spacer()
                }
                
                // 右上角控制按钮
                VStack {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            // 地图样式按钮
                            Button {
                                showStyleSelector.toggle()
                            } label: {
                                Image(systemName: viewModel.mapStyle.icon)
                                    .font(.system(size: 18))
                                    .frame(width: 40, height: 40)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                            
                            // 定位到用户位置按钮
                            Button {
                                centerOnUserLocation()
                            } label: {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 18))
                                    .frame(width: 40, height: 40)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.trailing, 12)
                        .padding(.top, 70) // 避开搜索栏
                    }
                    Spacer()
                }
                
                // POI 信息卡片
                if let poi = viewModel.selectedPOI {
                    VStack {
                        Spacer()
                        POIInfoCard(poi: poi, onConfirm: {
                            confirmPOISelection()
                        }, onCancel: {
                            viewModel.clearPOISelection()
                        })
                        .padding()
                    }
                } else {
                    // 确认按钮
                    VStack {
                        Spacer()
                        
                        Button {
                            confirmLocation()
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("确认位置")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(isLoading)
                        .padding()
                    }
                }
                
                // 地图样式选择器弹出
                if showStyleSelector {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showStyleSelector = false
                        }
                    
                    VStack {
                        Spacer()
                        MapStyleSelector(selectedStyle: $viewModel.mapStyle) { style in
                            viewModel.setMapStyle(style)
                            showStyleSelector = false
                        }
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding()
                    }
                }
            }
            .navigationTitle("选择位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                locationManager.requestLocation()
            }
            .task(id: locationManager.locationUpdateId) {
                // 首次获取到用户位置时，居中到用户位置
                if !hasInitializedLocation, let location = locationManager.currentLocation, initialLocation == nil {
                    hasInitializedLocation = true
                    viewModel.centerOnCoordinate(location, span: 0.01)
                }
            }
            .onChange(of: searchText) { _, newValue in
                if newValue.isEmpty {
                    showSearchResults = false
                }
            }
        }
    }
    
    // MARK: - Search Methods
    
    private func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        isSearching = true
        showSearchResults = true
        
        Task {
            let results = await LocationSearchService.shared.search(query: searchText)
            
            await MainActor.run {
                searchResults = results
                isSearching = false
            }
        }
    }
    
    private func selectSearchResult(_ location: Location) {
        // 居中到选中的位置
        let coord = CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
        viewModel.centerOnCoordinate(coord, span: 0.005)
        
        // 设置为 POI 选择
        let poi = POISelection(
            coordinate: coord,
            name: location.name,
            address: location.address
        )
        viewModel.selectPOI(poi)
        
        // 关闭搜索结果
        showSearchResults = false
        searchText = ""
    }
    
    private func confirmPOISelection() {
        guard let location = viewModel.confirmPOISelection() else { return }
        
        // 保存当前位置作为下次默认位置
        settingsStore.saveMapLocation(latitude: location.latitude, longitude: location.longitude)
        
        onSelect(location)
        dismiss()
    }
    
    private func confirmLocation() {
        isLoading = true
        let center = viewModel.getCenterCoordinate()
        
        // 保存当前位置作为下次默认位置
        settingsStore.saveMapLocation(latitude: center.latitude, longitude: center.longitude)
        
        Task {
            let location = await GeocodingService.shared.createLocation(
                latitude: center.latitude,
                longitude: center.longitude
            )
            
            await MainActor.run {
                isLoading = false
                onSelect(location)
                dismiss()
            }
        }
    }
    
    private func centerOnUserLocation() {
        guard let location = locationManager.currentLocation else {
            locationManager.requestLocation()
            return
        }
        viewModel.centerOnCoordinate(location, span: 0.01)
    }
    
    // MARK: - Map Tap Handler
    
    /// 处理地图点击事件，反向地理编码获取地点信息
    private func handleMapTap(at coordinate: CLLocationCoordinate2D) {
        // 显示加载状态
        isLoading = true
        
        Task {
            // 反向地理编码获取地点名称
            let location = await GeocodingService.shared.createLocation(
                latitude: coordinate.latitude,
                longitude: coordinate.longitude
            )
            
            await MainActor.run {
                isLoading = false
                
                // 创建 POI 并选中
                let poi = POISelection(
                    coordinate: coordinate,
                    name: location.name,
                    address: location.address
                )
                viewModel.selectPOI(poi)
                
                // 居中到点击位置
                viewModel.centerOnCoordinate(coordinate, span: viewModel.region.span.latitudeDelta)
            }
        }
    }
}

/// 搜索结果行
struct SearchResultRow: View {
    let location: Location
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .foregroundStyle(.blue)
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
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Picker Location Manager

/// 用于 MapPickerView 的位置管理器
class PickerLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
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
        
        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        default:
            break
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
        print("Location error: \(error.localizedDescription)")
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedWhenInUse ||
           manager.authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        }
    }
}

// MARK: - MapStyleSelector

/// 地图样式选择器组件
struct MapStyleSelector: View {
    @Binding var selectedStyle: MapDisplayStyle
    let onSelect: (MapDisplayStyle) -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            ForEach(MapDisplayStyle.allCases, id: \.self) { style in
                MapStyleButton(
                    style: style,
                    isSelected: selectedStyle == style
                ) {
                    selectedStyle = style
                    onSelect(style)
                }
            }
        }
    }
}

/// 地图样式按钮
struct MapStyleButton: View {
    let style: MapDisplayStyle
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: style.icon)
                    .font(.system(size: 20))
                    .frame(width: 48, height: 48)
                    .background(isSelected ? .blue : .gray.opacity(0.2))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Text(style.displayName)
                    .font(.caption2)
                    .foregroundStyle(isSelected ? .blue : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - POI Marker

/// POI 选中标记
struct POIMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 36, height: 36)
                .shadow(radius: 3)
            
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
        }
    }
}

// MARK: - POI Info Card

/// POI 信息卡片
struct POIInfoCard: View {
    let poi: POISelection
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(poi.name)
                        .font(.headline)
                    
                    if let address = poi.address {
                        Text(address)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    if let category = poi.category {
                        Text(category)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                
                Spacer()
                
                Button {
                    onCancel()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
            }
            
            Button {
                onConfirm()
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("选择此地点")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Custom Markers

/// 目的地标记
struct DestinationMarker: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 32, height: 32)
                .shadow(radius: 2)
            
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.red)
        }
    }
}

/// 用户位置标记
struct UserLocationMarker: View {
    var isAnimating: Bool = false
    @State private var scale: CGFloat = 1.0
    @State private var animationTask: Task<Void, Never>?
    
    var body: some View {
        ZStack {
            // 外圈动画 - 使用可控的动画方式
            if isAnimating {
                Circle()
                    .stroke(.blue.opacity(0.3), lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .scaleEffect(scale)
                    .opacity(2 - scale)
            }
            
            // 内圈
            Circle()
                .fill(.white)
                .frame(width: 24, height: 24)
                .shadow(radius: 2)
            
            Circle()
                .fill(.blue)
                .frame(width: 16, height: 16)
        }
        .onAppear {
            if isAnimating {
                startAnimation()
            }
        }
        .onDisappear {
            stopAnimation()
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }
    
    private func startAnimation() {
        stopAnimation()
        animationTask = Task { @MainActor in
            while !Task.isCancelled {
                scale = 1.0
                withAnimation(.easeOut(duration: 1.5)) {
                    scale = 2.0
                }
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }
    
    private func stopAnimation() {
        animationTask?.cancel()
        animationTask = nil
        scale = 1.0
    }
}

// MARK: - Search Map Preview

/// 搜索结果地图预览
struct SearchMapPreview: View {
    let location: Location?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @ObservedObject private var styleManager = MapStyleManager.shared
    
    var body: some View {
        Group {
            if let location = location {
                Map(position: $cameraPosition, interactionModes: [.pan, .zoom]) {
                    Annotation(location.name, coordinate: coordinate(for: location)) {
                        DestinationMarker()
                    }
                }
                .mapStyle(styleManager.currentStyle.mapKitStyle)
                .onChange(of: location.id) { _, _ in
                    updateCamera(for: location)
                }
                .onAppear {
                    updateCamera(for: location)
                }
            } else {
                // 空状态
                Rectangle()
                    .fill(Color.gray.opacity(0.1))
                    .overlay {
                        VStack(spacing: 8) {
                            Image(systemName: "map")
                                .font(.system(size: 32))
                                .foregroundStyle(.secondary)
                            Text("选择地点查看位置")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
            }
        }
        .frame(height: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func coordinate(for location: Location) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude)
    }
    
    private func updateCamera(for location: Location) {
        let coord = coordinate(for: location)
        let region = MKCoordinateRegion.centered(on: coord, span: 0.005)
        withAnimation(AnimationConstants.Curve.map) {
            cameraPosition = .region(region)
        }
    }
}
