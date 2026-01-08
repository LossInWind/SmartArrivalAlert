import Foundation
import SwiftUI
import Combine
import CoreLocation
#if canImport(UIKit)
import UIKit
#endif

/// 主页面 ViewModel
@MainActor
class HomeViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var recentLocations: [Location] = []
    @Published var favoriteLocations: [Location] = []
    @Published var selectedLocation: Location?
    @Published var geofenceRadius: Int
    @Published var maxGeofenceRadius: Double
    @Published var isLoading = false
    @Published var showRiskWarning = false
    @Published var riskAssessment: RiskAssessment?
    @Published var monitoringStatus: MonitoringStatus = .idle
    @Published var showFeedbackDialog = false
    @Published var currentTripId: String?
    @Published var errorMessage: String?
    @Published var locationPermissionStatus: CLAuthorizationStatus = .notDetermined
    @Published var showPermissionAlert = false
    
    // MARK: - Edit Mode Properties
    
    @Published var isEditMode = false
    @Published var editingSection: EditingSection = .all
    @Published var selectedLocationIds: Set<String> = []
    
    /// 编辑的区域类型
    enum EditingSection {
        case recent
        case favorite
        case all  // 统一编辑模式：同时编辑收藏和历史地点
    }
    
    // MARK: - Dependencies
    
    private let locationRepository: LocationRepository
    private let selfDiagnosisEngine: SelfDiagnosisEngine
    private let monitoringEngine: MonitoringEngine
    private let tripRepository: TripRepository
    private let alertTrigger: any AlertTriggerProtocol
    private let locationManager: CLLocationManager
    private let etaCalculator: ETACalculator
    private let settingsStore: SettingsStore
    private let batteryMonitor: BatteryMonitor
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Battery Auto-Switch Properties
    
    /// 自动切换提示消息
    @Published var autoSwitchMessage: String?
    
    /// 是否显示自动切换提示
    @Published var showAutoSwitchToast = false
    
    // MARK: - ETA Properties
    
    @Published var currentETA: ETAResult = .calculating
    @Published var currentSpeed: Double = 0.0
    @Published var signalQuality: SignalQualityLevel = .unknown
    
    // MARK: - Transport Mode Properties
    
    @Published var selectedTransportMode: TransportMode = .walking
    
    /// 初始 ETA（基于交通方式基准速度计算，考虑围栏半径）
    var initialETA: Int? {
        guard let destination = selectedLocation else { return nil }
        let distance = calculateDistanceToDestination(destination)
        guard distance > 0 else { return nil }
        return selectedTransportMode.calculateInitialETA(distance: distance, geofenceRadius: geofenceRadius)
    }
    
    /// 计算到目的地的距离
    private func calculateDistanceToDestination(_ destination: Location) -> Double {
        guard let currentLocation = locationManager.location else { return 0 }
        return GeoUtils.calculateDistance(
            lat1: currentLocation.coordinate.latitude,
            lon1: currentLocation.coordinate.longitude,
            lat2: destination.latitude,
            lon2: destination.longitude
        )
    }
    
    // MARK: - Route ETA Properties
    
    /// 可用路线列表
    @Published var availableRoutes: [RouteOption] = []
    
    /// 选中的路线
    @Published var selectedRoute: RouteOption?
    
    /// 路线 ETA 结果
    @Published var routeETAResult: RouteETAResult = .empty
    
    /// 是否正在加载路线
    @Published var isLoadingRoutes = false
    
    /// 上次 ETA（用于检测显著变化）
    private var previousETAMinutes: Int?
    
    /// 路线刷新定时器
    private var routeRefreshTimer: Timer?
    
    /// 上次路线查询位置
    private var lastRouteQueryLocation: CLLocationCoordinate2D?
    
    // MARK: - Initialization
    
    init(
        locationRepository: LocationRepository = .shared,
        selfDiagnosisEngine: SelfDiagnosisEngine = .shared,
        monitoringEngine: MonitoringEngine = .shared,
        tripRepository: TripRepository = .shared,
        alertTrigger: any AlertTriggerProtocol = AlertTrigger.shared,
        etaCalculator: ETACalculator = .shared,
        settingsStore: SettingsStore = .shared,
        batteryMonitor: BatteryMonitor = .shared
    ) {
        self.locationRepository = locationRepository
        self.selfDiagnosisEngine = selfDiagnosisEngine
        self.monitoringEngine = monitoringEngine
        self.tripRepository = tripRepository
        self.alertTrigger = alertTrigger
        self.locationManager = CLLocationManager()
        self.etaCalculator = etaCalculator
        self.settingsStore = settingsStore
        self.batteryMonitor = batteryMonitor
        
        // 从设置中读取围栏配置
        self.geofenceRadius = Int(settingsStore.defaultGeofenceRadius)
        self.maxGeofenceRadius = settingsStore.maxGeofenceRadius
        
        // 检查当前权限状态
        self.locationPermissionStatus = locationManager.authorizationStatus
        
        // 设置监控引擎回调
        setupMonitoringCallbacks()
        
        // 监听设置变化
        setupSettingsObserver()
        
        // 设置电池监控
        setupBatteryMonitoring()
    }
    
    deinit {
        // 清理定时器
        routeRefreshTimer?.invalidate()
        routeRefreshTimer = nil
        // 清理 Combine 订阅
        cancellables.removeAll()
    }
    
    // MARK: - Private Methods
    
    /// 设置监控引擎回调
    private func setupMonitoringCallbacks() {
        Task {
            // 设置围栏事件回调 - 这是触发到站提醒的关键！
            await monitoringEngine.setGeofenceEventHandler { [weak self] event in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.handleGeofenceEvent(event)
                }
            }
            
            // 设置位置更新回调
            await monitoringEngine.setLocationUpdateHandler { [weak self] locationUpdate in
                guard let self = self else { return }
                Task { @MainActor in
                    self.handleLocationUpdate(locationUpdate)
                }
            }
            
            // 设置状态变化回调
            await monitoringEngine.setStatusChangeHandler { [weak self] status in
                guard let self = self else { return }
                Task { @MainActor in
                    self.monitoringStatus = status
                }
            }
        }
    }
    
    /// 设置电池监控
    private func setupBatteryMonitoring() {
        // 监听电池电量变化
        batteryMonitor.$batteryLevel
            .combineLatest(batteryMonitor.$isCharging)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (level, isCharging) in
                self?.handleBatteryChange(level: level, isCharging: isCharging)
            }
            .store(in: &cancellables)
        
        // 如果启用了自动切换，开始监控
        if settingsStore.autoBatterySwitch {
            batteryMonitor.startMonitoring()
        }
        
        // 监听自动切换设置变化
        settingsStore.$autoBatterySwitch
            .receive(on: DispatchQueue.main)
            .sink { [weak self] enabled in
                if enabled {
                    self?.batteryMonitor.startMonitoring()
                } else {
                    self?.batteryMonitor.stopMonitoring()
                }
            }
            .store(in: &cancellables)
    }
    
    /// 处理电池电量变化
    private func handleBatteryChange(level: Float, isCharging: Bool) {
        let percentage = Int(level * 100)
        
        // 检查并执行自动切换
        if let action = settingsStore.checkAndPerformAutoBatterySwitch(
            batteryPercentage: percentage,
            isCharging: isCharging
        ) {
            // 显示提示
            autoSwitchMessage = action.description
            showAutoSwitchToast = true
            
            // 3秒后隐藏提示
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                self?.showAutoSwitchToast = false
            }
        }
    }
    
    /// 设置设置变化观察者
    private func setupSettingsObserver() {
        // 监听默认围栏半径变化
        settingsStore.$defaultGeofenceRadius
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self = self else { return }
                // 只在没有选中目的地时更新（避免覆盖用户手动调整的值）
                if self.selectedLocation == nil {
                    self.geofenceRadius = Int(newValue)
                }
            }
            .store(in: &cancellables)
        
        // 监听最大围栏半径变化
        settingsStore.$maxGeofenceRadius
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newValue in
                guard let self = self else { return }
                self.maxGeofenceRadius = newValue
                // 如果当前半径超过新的最大值，调整到最大值
                if Double(self.geofenceRadius) > newValue {
                    self.geofenceRadius = Int(newValue)
                }
            }
            .store(in: &cancellables)
        
        // 监听交通方式变化，重新获取路线 ETA
        $selectedTransportMode
            .dropFirst() // 跳过初始值
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self,
                      self.selectedLocation != nil else { return }
                // 交通方式变化时重新获取路线
                Task {
                    await self.fetchRouteETA(forceRefresh: true)
                }
            }
            .store(in: &cancellables)
        
        // 监听围栏半径变化，更新路线 ETA
        $geofenceRadius
            .dropFirst() // 跳过初始值
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main) // 防抖，避免滑动时频繁更新
            .sink { [weak self] newRadius in
                guard let self = self,
                      self.selectedLocation != nil,
                      !self.routeETAResult.routes.isEmpty else { return }
                // 更新路线的围栏半径
                self.routeETAResult = self.routeETAResult.withGeofenceRadius(newRadius)
                self.availableRoutes = self.routeETAResult.routes
                self.selectedRoute = self.routeETAResult.selectedRoute
            }
            .store(in: &cancellables)
    }
    
    /// 处理围栏事件
    private func handleGeofenceEvent(_ event: GeofenceEvent) async {
        guard let destination = monitoringStatus.config?.destination else { return }
        
        switch event.type {
        case .enter:
            // 触发到站提醒（声音、震动、界面）
            await AlertManager.shared.triggerAlert(destination: destination)
            
            // 同时发送通知（后台时使用）
            do {
                try await alertTrigger.triggerArrivalAlert(destination: destination)
                // 取消兜底闹钟（已经到站了）
                await alertTrigger.cancelBackupAlarm()
                // 显示 Live Activity 到达状态
                let liveActivityManager = getLiveActivityManager()
                await liveActivityManager.showArrival()
            } catch {
                errorMessage = "发送提醒失败"
            }
        case .earlyTrigger:
            // 提前触发（信号差区域）
            await AlertManager.shared.triggerAlert(destination: destination)
            
            do {
                try await alertTrigger.triggerEarlyAlert(
                    destination: destination,
                    reason: "前方信号较差，提前提醒"
                )
                await alertTrigger.cancelBackupAlarm()
                // 显示 Live Activity 到达状态
                let liveActivityManager = getLiveActivityManager()
                await liveActivityManager.showArrival()
            } catch {
                errorMessage = "发送提醒失败"
            }
        }
    }
    
    /// 处理位置更新
    private func handleLocationUpdate(_ locationUpdate: LocationUpdate) {
        guard let config = monitoringStatus.config else { return }
        
        // 计算距离
        let distance = GeoUtils.calculateDistance(
            lat1: locationUpdate.latitude, lon1: locationUpdate.longitude,
            lat2: config.destination.latitude, lon2: config.destination.longitude
        )
        
        // 更新监控状态
        monitoringStatus = MonitoringStatus(
            state: .monitoring,
            config: config,
            currentTrip: monitoringStatus.currentTrip,
            lastLocation: locationUpdate,
            distanceToDestination: distance
        )
        
        // 根据精度估算信号质量
        let signalQuality: SignalQualityLevel = locationUpdate.accuracy < 10 ? .good :
                                                locationUpdate.accuracy < 30 ? .fair :
                                                locationUpdate.accuracy < 100 ? .poor : .unknown
        
        // 更新 ETA（使用默认步行速度 1.4 m/s，约 5 km/h）
        let estimatedSpeed = 1.4
        updateETA(distance: distance, speed: estimatedSpeed, signalQuality: signalQuality)
        
        // 更新 Live Activity
        if settingsStore.enableLiveActivity {
            Task {
                let liveActivityManager = getLiveActivityManager()
                await liveActivityManager.updateActivity(
                    distance: Int(distance),
                    etaMinutes: currentETA.estimatedMinutes,
                    isETAReliable: currentETA.isReliable,
                    geofenceRadius: config.geofenceRadius
                )
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// 加载地点数据
    func loadLocations() async {
        let start = Date()
        print("📍 开始加载地点...")
        
        isLoading = true
        
        recentLocations = await locationRepository.getRecentLocations()
        print("📍 最近地点加载完成，耗时: \(Date().timeIntervalSince(start))s")
        
        favoriteLocations = await locationRepository.getFavoriteLocations()
        print("📍 收藏地点加载完成，总耗时: \(Date().timeIntervalSince(start))s")
        
        isLoading = false
    }
    
    /// 选择地点
    func selectLocation(_ location: Location) {
        selectedLocation = location
        
        // 清除之前的路线数据
        clearRouteData()
        
        // 获取新目的地的路线 ETA
        Task {
            await fetchRouteETA(forceRefresh: true)
        }
        
        // 触发触觉反馈
        HapticManager.shared.trigger(.selection)
    }
    
    /// 清除选中的目的地
    func clearSelectedLocation() {
        selectedLocation = nil
        
        // 触发触觉反馈
        HapticManager.shared.trigger(.light)
    }
    
    /// 开始监控前的自检
    func startDiagnosis() async {
        guard let destination = selectedLocation else { return }
        
        isLoading = true
        
        // 执行自检
        let assessment = await selfDiagnosisEngine.performDiagnosis(destination: destination, route: nil)
        riskAssessment = assessment
        
        isLoading = false
        
        // 显示风险警告（如果有风险）
        if assessment.overallRisk != .low {
            showRiskWarning = true
        } else {
            // 低风险直接开始监控
            await startMonitoring()
        }
    }
    
    /// 开始监控
    func startMonitoring() async {
        guard let destination = selectedLocation else { return }
        
        // 添加到最近地点
        try? await locationRepository.addRecentLocation(destination)
        
        // 确保回调已设置（重新设置一次，确保在 startMonitoring 之前完成）
        await ensureCallbacksSetup()
        
        // 创建监控配置
        let config = MonitoringConfig(
            destination: destination,
            geofenceRadius: geofenceRadius,
            enableEarlyTrigger: riskAssessment?.suggestEarlyTrigger ?? false,
            transportMode: selectedTransportMode,
            batteryMode: settingsStore.batteryMode,
            selectedRouteId: selectedRoute?.id
        )
        
        do {
            try await monitoringEngine.startMonitoring(config: config)
            monitoringStatus = await monitoringEngine.getStatus()
            currentTripId = monitoringStatus.currentTrip?.id
            
            // 获取初始路线 ETA
            await fetchRouteETA(forceRefresh: true)
            
            // 启动路线刷新定时器
            startRouteRefreshTimer()
            
            // 启动 Live Activity（如果启用）
            if settingsStore.enableLiveActivity {
                let initialDistance = Int(calculateDistanceToDestination(destination))
                let liveActivityManager = getLiveActivityManager()
                await liveActivityManager.startActivity(
                    destinationName: destination.name,
                    destinationAddress: destination.address,
                    geofenceRadius: geofenceRadius,
                    transportMode: selectedTransportMode,
                    initialDistance: initialDistance
                )
            }
            
            // 刷新地点列表
            await loadLocations()
        } catch {
            errorMessage = "启动监控失败：\(error.localizedDescription)"
        }
    }
    
    /// 确保回调已设置
    private func ensureCallbacksSetup() async {
        // 设置围栏事件回调 - 这是触发到站提醒的关键！
        await monitoringEngine.setGeofenceEventHandler { [weak self] event in
            guard let self = self else { return }
            Task { @MainActor in
                await self.handleGeofenceEvent(event)
            }
        }
        
        // 设置位置更新回调
        await monitoringEngine.setLocationUpdateHandler { [weak self] locationUpdate in
            guard let self = self else { return }
            Task { @MainActor in
                self.handleLocationUpdate(locationUpdate)
            }
        }
        
        // 设置状态变化回调
        await monitoringEngine.setStatusChangeHandler { [weak self] status in
            guard let self = self else { return }
            Task { @MainActor in
                self.monitoringStatus = status
            }
        }
    }
    
    /// 停止监控
    func stopMonitoring() async {
        await monitoringEngine.stopMonitoring()
        monitoringStatus = .idle
        
        // 停止路线刷新定时器
        stopRouteRefreshTimer()
        
        // 清除路线数据
        clearRouteData()
        
        // 结束 Live Activity
        let liveActivityManager = getLiveActivityManager()
        await liveActivityManager.endActivity()
        
        // 重置 ETA 计算器
        etaCalculator.reset()
        currentETA = .calculating
        currentSpeed = 0.0
        
        // 显示反馈对话框
        if currentTripId != nil {
            showFeedbackDialog = true
        }
    }
    
    /// 更新 ETA 计算（预计提醒时间）
    /// - Parameters:
    ///   - distance: 距离目的地的距离（米）
    ///   - speed: 当前速度（米/秒）
    ///   - signalQuality: 信号质量等级
    func updateETA(distance: Double, speed: Double, signalQuality: SignalQualityLevel) {
        self.currentSpeed = speed
        self.signalQuality = signalQuality
        self.currentETA = etaCalculator.calculateETA(
            distance: distance,
            currentSpeed: speed,
            signalQuality: signalQuality,
            geofenceRadius: geofenceRadius
        )
    }
    
    /// 记录用户反馈
    func recordFeedback(_ feedback: UserFeedback) async {
        guard let tripId = currentTripId else { return }
        
        try? await tripRepository.recordFeedback(tripId: tripId, feedback: feedback)
        
        showFeedbackDialog = false
        currentTripId = nil
        
        // 触发触觉反馈
        HapticManager.shared.trigger(.success)
    }
    
    /// 切换收藏状态
    func toggleFavorite(_ location: Location) async {
        if location.isFavorite {
            try? await locationRepository.removeFavorite(locationId: location.id)
        } else {
            try? await locationRepository.addFavorite(location)
        }
        
        await loadLocations()
        
        // 更新 selectedLocation 的收藏状态
        if var selected = selectedLocation, selected.id == location.id {
            selected.isFavorite = !location.isFavorite
            selectedLocation = selected
        }
        
        // 触发触觉反馈
        HapticManager.shared.trigger(.success)
    }
    
    /// 设置兜底闹钟
    func setBackupAlarm(at time: Date) async {
        guard let destination = selectedLocation else { return }
        
        do {
            try await alertTrigger.setBackupAlarm(at: time, destination: destination)
        } catch {
            errorMessage = "设置兜底闹钟失败"
        }
    }
    
    /// 取消兜底闹钟
    func cancelBackupAlarm() async {
        await alertTrigger.cancelBackupAlarm()
    }
    
    /// 确认风险并开始监控
    func confirmRiskAndStart() async {
        showRiskWarning = false
        await startMonitoring()
    }
    
    /// 取消风险警告
    func cancelRiskWarning() {
        showRiskWarning = false
        riskAssessment = nil
    }
    
    /// 添加最近地点
    func addRecentLocation(_ location: Location) async {
        try? await locationRepository.addRecentLocation(location)
        // 直接更新本地状态，避免重复加载
        if !recentLocations.contains(where: { $0.id == location.id }) {
            var updated = location
            updated.lastVisited = Date()
            recentLocations.insert(updated, at: 0)
            if recentLocations.count > 10 {
                recentLocations = Array(recentLocations.prefix(10))
            }
        }
    }
    
    // MARK: - Route ETA Methods
    
    /// 获取路线 ETA
    /// - Parameter forceRefresh: 是否强制刷新（忽略缓存）
    func fetchRouteETA(forceRefresh: Bool = false) async {
        guard let destination = selectedLocation,
              let currentLocation = locationManager.location else { return }
        
        // 检查是否需要刷新
        if !forceRefresh, let lastLocation = lastRouteQueryLocation {
            let shouldRefresh = await RouteETAService.shared.shouldRefresh(
                currentLocation: currentLocation.coordinate,
                lastQueryLocation: lastLocation
            )
            if !shouldRefresh {
                // 即使不刷新路线，也要更新围栏半径
                routeETAResult = routeETAResult.withGeofenceRadius(geofenceRadius)
                availableRoutes = routeETAResult.routes
                selectedRoute = routeETAResult.selectedRoute
                return
            }
        }
        
        isLoadingRoutes = true
        
        let destCoord = CLLocationCoordinate2D(
            latitude: destination.latitude,
            longitude: destination.longitude
        )
        
        let result = await RouteETAService.shared.fetchRoutes(
            from: currentLocation.coordinate,
            to: destCoord,
            transportMode: selectedTransportMode,
            geofenceRadius: geofenceRadius
        )
        
        // 更新状态
        routeETAResult = result
        availableRoutes = result.routes
        selectedRoute = result.selectedRoute
        lastRouteQueryLocation = currentLocation.coordinate
        
        // 检测 ETA 显著变化
        if let newETA = result.selectedETAMinutes,
           let previousETA = previousETAMinutes {
            if ETAChangeDetector.isSignificantChange(previousETA: previousETA, currentETA: newETA) {
                // 可以在这里触发通知或 UI 更新
                if let description = ETAChangeDetector.changeDescription(previousETA: previousETA, currentETA: newETA) {
                    print("📍 ETA 变化: \(description)")
                }
            }
        }
        previousETAMinutes = result.selectedETAMinutes
        
        isLoadingRoutes = false
    }
    
    /// 选择路线
    /// - Parameter routeId: 路线 ID
    func selectRoute(withId routeId: String) async {
        guard let updated = await RouteETAService.shared.selectRoute(withId: routeId) else { return }
        
        routeETAResult = updated
        availableRoutes = updated.routes
        selectedRoute = updated.selectedRoute
        previousETAMinutes = updated.selectedETAMinutes
        
        // 触发触觉反馈
        HapticManager.shared.trigger(.selection)
    }
    
    /// 开始路线刷新定时器
    func startRouteRefreshTimer() {
        stopRouteRefreshTimer()
        
        // 计算刷新间隔
        let etaMinutes = routeETAResult.selectedETAMinutes ?? 30
        let interval = RefreshIntervalCalculator.calculate(
            etaMinutes: etaMinutes,
            batteryMode: settingsStore.batteryMode
        )
        
        routeRefreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchRouteETA()
                // 重新计算下次刷新间隔
                self?.updateRouteRefreshInterval()
            }
        }
    }
    
    /// 停止路线刷新定时器
    func stopRouteRefreshTimer() {
        routeRefreshTimer?.invalidate()
        routeRefreshTimer = nil
    }
    
    /// 更新路线刷新间隔
    private func updateRouteRefreshInterval() {
        let etaMinutes = routeETAResult.selectedETAMinutes ?? 30
        let newInterval = RefreshIntervalCalculator.calculate(
            etaMinutes: etaMinutes,
            batteryMode: settingsStore.batteryMode
        )
        
        // 如果间隔变化，重新设置定时器
        stopRouteRefreshTimer()
        
        routeRefreshTimer = Timer.scheduledTimer(withTimeInterval: newInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.fetchRouteETA()
                self?.updateRouteRefreshInterval()
            }
        }
    }
    
    /// 清除路线数据
    func clearRouteData() {
        stopRouteRefreshTimer()
        availableRoutes = []
        selectedRoute = nil
        routeETAResult = .empty
        previousETAMinutes = nil
        lastRouteQueryLocation = nil
        Task {
            await RouteETAService.shared.clearCache()
        }
    }
    
    // MARK: - Edit Mode Methods
    
    /// 进入编辑模式（统一编辑所有地点）
    func enterEditMode() {
        isEditMode = true
        editingSection = .all
        selectedLocationIds.removeAll()
        
        HapticManager.shared.trigger(.medium)
    }
    
    /// 退出编辑模式
    func exitEditMode() {
        isEditMode = false
        editingSection = .all
        selectedLocationIds.removeAll()
    }
    
    /// 切换地点选中状态
    func toggleLocationSelection(_ locationId: String) {
        if selectedLocationIds.contains(locationId) {
            selectedLocationIds.remove(locationId)
        } else {
            selectedLocationIds.insert(locationId)
        }
    }
    
    /// 全选/取消全选
    func toggleSelectAll() {
        let section = editingSection
        
        let locations: [Location]
        switch section {
        case .recent:
            locations = recentLocations
        case .favorite:
            locations = favoriteLocations
        case .all:
            locations = favoriteLocations + recentLocations
        }
        
        let allIds = Set(locations.map { $0.id })
        
        if selectedLocationIds == allIds {
            selectedLocationIds.removeAll()
        } else {
            selectedLocationIds = allIds
        }
    }
    
    /// 删除单个地点
    func deleteLocation(_ location: Location, from section: EditingSection) async {
        do {
            if section == .recent {
                try await locationRepository.removeRecentLocation(locationId: location.id)
                recentLocations.removeAll { $0.id == location.id }
            } else {
                try await locationRepository.removeFavorite(locationId: location.id)
                favoriteLocations.removeAll { $0.id == location.id }
                // 更新最近地点中的收藏状态
                if let index = recentLocations.firstIndex(where: { $0.id == location.id }) {
                    recentLocations[index].isFavorite = false
                }
            }
            
            // 如果删除的是当前选中的地点，清除选中状态
            if selectedLocation?.id == location.id {
                selectedLocation = nil
            }
            
            HapticManager.shared.trigger(.warning)
        } catch {
            errorMessage = "删除失败"
        }
    }
    
    /// 批量删除选中的地点
    func deleteSelectedLocations() async {
        guard !selectedLocationIds.isEmpty else { return }
        
        let section = editingSection
        
        do {
            switch section {
            case .recent:
                try await locationRepository.removeRecentLocations(locationIds: selectedLocationIds)
                recentLocations.removeAll { selectedLocationIds.contains($0.id) }
                
            case .favorite:
                try await locationRepository.removeFavorites(locationIds: selectedLocationIds)
                favoriteLocations.removeAll { selectedLocationIds.contains($0.id) }
                // 更新最近地点中的收藏状态
                for i in recentLocations.indices {
                    if selectedLocationIds.contains(recentLocations[i].id) {
                        recentLocations[i].isFavorite = false
                    }
                }
                
            case .all:
                // 分别处理收藏和历史地点
                let favoriteIds = Set(favoriteLocations.map { $0.id }).intersection(selectedLocationIds)
                let recentIds = Set(recentLocations.map { $0.id }).intersection(selectedLocationIds)
                
                if !favoriteIds.isEmpty {
                    try await locationRepository.removeFavorites(locationIds: favoriteIds)
                    favoriteLocations.removeAll { favoriteIds.contains($0.id) }
                }
                
                if !recentIds.isEmpty {
                    try await locationRepository.removeRecentLocations(locationIds: recentIds)
                    recentLocations.removeAll { recentIds.contains($0.id) }
                }
                
                // 更新最近地点中的收藏状态
                for i in recentLocations.indices {
                    if favoriteIds.contains(recentLocations[i].id) {
                        recentLocations[i].isFavorite = false
                    }
                }
            }
            
            // 如果删除的包含当前选中的地点，清除选中状态
            if let selected = selectedLocation, selectedLocationIds.contains(selected.id) {
                selectedLocation = nil
            }
            
            selectedLocationIds.removeAll()
            
            HapticManager.shared.trigger(.warning)
        } catch {
            errorMessage = "删除失败"
        }
    }
    
    /// 移动最近地点
    func moveRecentLocation(from source: IndexSet, to destination: Int) {
        recentLocations.move(fromOffsets: source, toOffset: destination)
        Task {
            try? await locationRepository.reorderRecentLocations(recentLocations)
        }
    }
    
    /// 移动收藏地点
    func moveFavoriteLocation(from source: IndexSet, to destination: Int) {
        favoriteLocations.move(fromOffsets: source, toOffset: destination)
        Task {
            try? await locationRepository.reorderFavoriteLocations(favoriteLocations)
        }
    }
}
