import Foundation
import CoreLocation
import Combine

/// 监控引擎协议
protocol MonitoringEngineProtocol {
    func startMonitoring(config: MonitoringConfig) async throws
    func stopMonitoring() async
    func getStatus() async -> MonitoringStatus
}

/// 监控引擎 - 负责位置监控和围栏检测
actor MonitoringEngine: NSObject, MonitoringEngineProtocol {
    
    // MARK: - Constants
    
    /// 信号记录节流间隔（秒）
    static let signalRecordingThrottleInterval: TimeInterval = 5.0
    
    /// 位置更新最小距离（米）
    static let minimumDistanceFilter: CLLocationDistance = 10.0
    
    // MARK: - Properties
    
    private let locationManager: CLLocationManager
    private let signalQualityRepository: SignalQualityRepository
    private let tripRepository: TripRepository
    private let learningEngine: LearningEngine
    
    /// 智能间隔管理器
    private let intervalManager: LocationCheckIntervalManager
    
    /// 速度计算器
    private let speedCalculator: SpeedCalculator
    
    /// 增强 ETA 计算器
    private let etaCalculator: EnhancedETACalculator
    
    private var currentConfig: MonitoringConfig?
    private var currentTrip: TripRecord?
    private var previousLocation: CLLocation?
    private var lastSignalRecordTime: Date?
    private var state: MonitoringState = .idle
    
    /// 当前交通方式
    private var currentTransportMode: TransportMode = .walking
    
    /// 当前电池模式
    private var currentBatteryMode: BatteryMode = .balanced
    
    /// 当前检查间隔
    private var currentCheckInterval: TimeInterval = 30.0
    
    /// 设置存储（用于读取提前触发倍数等设置）
    private let settingsStore: SettingsStore
    
    /// 提醒触发器（用于设置兜底闹钟）
    private let alertTrigger: AlertTrigger
    
    /// 学习引擎（用于获取历史数据和可靠性评分）
    private let learningEngineRef: LearningEngine
    
    /// 设置变化订阅
    private var settingsCancellables = Set<AnyCancellable>()
    
    /// 当前提前触发倍数
    private var currentEarlyTriggerMultiplier: Double = 1.5
    
    /// 当前是否启用提前触发
    private var currentEnableEarlyTrigger: Bool = true
    
    /// 当前是否启用兜底闹钟
    private var currentEnableBackupAlarm: Bool = true
    
    /// 当前兜底闹钟偏移（分钟）
    private var currentBackupAlarmOffset: Int = 5
    
    /// 当前兜底闹钟状态
    private var backupAlarmState: BackupAlarmState?
    
    /// 上次 ETA（用于检测显著变化）
    private var lastETAMinutes: Int?
    
    /// 当前路线可靠性评分
    private var currentReliabilityScore: Double = 100.0
    
    /// 是否因高风险自动启用了提前触发
    private var autoEnabledEarlyTriggerDueToRisk: Bool = false
    
    /// 位置更新回调
    var onLocationUpdate: ((LocationUpdate) -> Void)?
    
    /// 围栏事件回调
    var onGeofenceEvent: ((GeofenceEvent) -> Void)?
    
    /// 状态变化回调
    var onStatusChange: ((MonitoringStatus) -> Void)?
    
    /// ETA 更新回调
    var onETAUpdate: ((EnhancedETAResult) -> Void)?
    
    // MARK: - Callback Setters
    
    /// 设置围栏事件处理器
    func setGeofenceEventHandler(_ handler: @escaping (GeofenceEvent) -> Void) {
        onGeofenceEvent = handler
    }
    
    /// 设置位置更新处理器
    func setLocationUpdateHandler(_ handler: @escaping (LocationUpdate) -> Void) {
        onLocationUpdate = handler
    }
    
    /// 设置状态变化处理器
    func setStatusChangeHandler(_ handler: @escaping (MonitoringStatus) -> Void) {
        onStatusChange = handler
    }
    
    /// 设置 ETA 更新处理器
    func setETAUpdateHandler(_ handler: @escaping (EnhancedETAResult) -> Void) {
        onETAUpdate = handler
    }
    
    // MARK: - Initialization
    
    override init() {
        self.locationManager = CLLocationManager()
        self.signalQualityRepository = .shared
        self.tripRepository = .shared
        self.learningEngine = .shared
        self.learningEngineRef = .shared
        self.intervalManager = LocationCheckIntervalManager()
        self.speedCalculator = SpeedCalculator()
        self.etaCalculator = EnhancedETACalculator()
        self.settingsStore = .shared
        self.alertTrigger = .shared
        super.init()
        
        // 初始化设置值并订阅变化
        Task {
            await loadSettingsValues()
            await subscribeToSettingsChanges()
        }
    }
    
    init(
        signalQualityRepository: SignalQualityRepository = .shared,
        tripRepository: TripRepository = .shared,
        learningEngine: LearningEngine = .shared,
        settingsStore: SettingsStore = .shared,
        alertTrigger: AlertTrigger = .shared
    ) {
        self.locationManager = CLLocationManager()
        self.signalQualityRepository = signalQualityRepository
        self.tripRepository = tripRepository
        self.learningEngine = learningEngine
        self.learningEngineRef = learningEngine
        self.intervalManager = LocationCheckIntervalManager()
        self.speedCalculator = SpeedCalculator()
        self.etaCalculator = EnhancedETACalculator()
        self.settingsStore = settingsStore
        self.alertTrigger = alertTrigger
        super.init()
        
        // 初始化设置值并订阅变化
        Task {
            await loadSettingsValues()
            await subscribeToSettingsChanges()
        }
    }
    
    /// 加载设置值
    private func loadSettingsValues() {
        currentEarlyTriggerMultiplier = settingsStore.earlyTriggerMultiplier
        currentBatteryMode = settingsStore.batteryMode
        currentEnableEarlyTrigger = settingsStore.enableEarlyTrigger
        currentEnableBackupAlarm = settingsStore.enableBackupAlarm
        currentBackupAlarmOffset = settingsStore.backupAlarmOffset
    }
    
    /// 订阅设置变化（实时生效）
    private func subscribeToSettingsChanges() {
        // 订阅提前触发倍数变化
        settingsStore.$earlyTriggerMultiplier
            .dropFirst()
            .sink { [weak self] newValue in
                Task { [weak self] in
                    await self?.updateEarlyTriggerMultiplier(newValue)
                }
            }
            .store(in: &settingsCancellables)
        
        // 订阅提前触发开关变化
        settingsStore.$enableEarlyTrigger
            .dropFirst()
            .sink { [weak self] newValue in
                Task { [weak self] in
                    await self?.updateEnableEarlyTrigger(newValue)
                }
            }
            .store(in: &settingsCancellables)
        
        // 订阅兜底闹钟开关变化
        settingsStore.$enableBackupAlarm
            .dropFirst()
            .sink { [weak self] newValue in
                Task { [weak self] in
                    await self?.updateEnableBackupAlarm(newValue)
                }
            }
            .store(in: &settingsCancellables)
        
        // 订阅兜底闹钟偏移变化
        settingsStore.$backupAlarmOffset
            .dropFirst()
            .sink { [weak self] newValue in
                Task { [weak self] in
                    await self?.updateBackupAlarmOffset(newValue)
                }
            }
            .store(in: &settingsCancellables)
        
        // 订阅电池模式变化
        settingsStore.$batteryMode
            .dropFirst()
            .sink { [weak self] newValue in
                Task { [weak self] in
                    await self?.updateBatteryMode(newValue)
                }
            }
            .store(in: &settingsCancellables)
    }
    
    /// 更新是否启用提前触发
    private func updateEnableEarlyTrigger(_ enabled: Bool) {
        currentEnableEarlyTrigger = enabled
    }
    
    /// 更新是否启用兜底闹钟
    private func updateEnableBackupAlarm(_ enabled: Bool) async {
        currentEnableBackupAlarm = enabled
        
        // 如果禁用了兜底闹钟，取消当前的闹钟
        if !enabled {
            await cancelBackupAlarm()
        } else if let config = currentConfig, let etaMinutes = lastETAMinutes {
            // 如果启用了，且正在监控，设置闹钟
            await setupBackupAlarm(
                etaMinutes: etaMinutes,
                offsetMinutes: currentBackupAlarmOffset,
                destination: config.destination
            )
        }
    }
    
    /// 更新兜底闹钟偏移
    private func updateBackupAlarmOffset(_ offset: Int) async {
        let oldOffset = currentBackupAlarmOffset
        currentBackupAlarmOffset = offset
        
        // 如果正在监控且有 ETA，更新闹钟
        if let config = currentConfig, let etaMinutes = lastETAMinutes, currentEnableBackupAlarm {
            // 偏移变化超过 1 分钟才更新
            if abs(offset - oldOffset) >= 1 {
                await setupBackupAlarm(
                    etaMinutes: etaMinutes,
                    offsetMinutes: offset,
                    destination: config.destination
                )
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// 开始监控
    /// - Parameter config: 监控配置
    func startMonitoring(config: MonitoringConfig) async throws {
        guard state == .idle else { return }
        
        currentConfig = config
        state = .monitoring
        
        // 设置交通方式和电池模式
        currentTransportMode = config.transportMode ?? .walking
        currentBatteryMode = config.batteryMode ?? .balanced
        
        // 重置计算器和状态
        speedCalculator.clearSamples()
        etaCalculator.reset()
        lastETAMinutes = nil
        backupAlarmState = nil
        autoEnabledEarlyTriggerDueToRisk = false
        
        // 查询并应用可靠性评分
        await applyReliabilityScore(forDestinationId: config.destination.id)
        
        // 创建行程记录
        let trip = TripRecord(
            id: UUID().uuidString,
            destinationId: config.destination.id,
            destination: config.destination,
            geofenceRadius: config.geofenceRadius
        )
        currentTrip = trip
        try await tripRepository.addTrip(trip)
        
        // 配置位置管理器
        await setupLocationManager()
        
        // 通知状态变化
        let status = MonitoringStatus(
            state: .monitoring,
            config: config,
            currentTrip: trip,
            lastLocation: nil,
            distanceToDestination: nil
        )
        onStatusChange?(status)
        
        // 检查启动时是否已在围栏内（放在最后，确保回调已设置）
        // 使用短暂延迟确保位置管理器有时间获取位置
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1秒
        await checkInitialLocationInGeofence(config: config)
    }
    
    /// 检查启动时是否已在围栏内
    /// 如果用户启动监控时已经在目的地附近，立即触发提醒
    private func checkInitialLocationInGeofence(config: MonitoringConfig) async {
        // 获取当前位置（尝试多种方式）
        var location: CLLocation? = await MainActor.run { locationManager.location }
        
        // 如果没有位置，尝试请求一次位置更新
        if location == nil {
            await MainActor.run {
                locationManager.requestLocation()
            }
            // 等待位置更新
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
            location = await MainActor.run { locationManager.location }
        }
        
        guard let currentLocation = location else {
            print("⚠️ MonitoringEngine: 无法获取当前位置，跳过初始围栏检查")
            return
        }
        
        let distance = GeoUtils.calculateDistance(
            lat1: currentLocation.coordinate.latitude,
            lon1: currentLocation.coordinate.longitude,
            lat2: config.destination.latitude,
            lon2: config.destination.longitude
        )
        
        print("📍 MonitoringEngine: 初始位置检查 - 距离: \(Int(distance))m, 围栏半径: \(config.geofenceRadius)m")
        
        // 如果已经在围栏内，立即触发提醒
        if distance <= Double(config.geofenceRadius) {
            print("🔔 MonitoringEngine: 已在围栏内，触发提醒！")
            
            let locationUpdate = LocationUpdate(
                latitude: currentLocation.coordinate.latitude,
                longitude: currentLocation.coordinate.longitude,
                accuracy: currentLocation.horizontalAccuracy,
                timestamp: Date()
            )
            
            let event = GeofenceEvent(
                type: .enter,
                location: locationUpdate,
                distanceToDestination: distance
            )
            
            // 确保回调存在
            if let handler = onGeofenceEvent {
                handler(event)
            } else {
                print("⚠️ MonitoringEngine: onGeofenceEvent 回调未设置！")
            }
            
            // 更新行程记录
            if var trip = currentTrip {
                trip.alertTriggered = true
                trip.alertType = .arrival
                trip.alertTimestamp = Date()
                try? await tripRepository.updateTrip(trip)
                currentTrip = trip
            }
        }
    }
    
    /// 停止监控
    func stopMonitoring() async {
        guard state == .monitoring else { return }
        
        state = .idle
        currentConfig = nil
        previousLocation = nil
        lastSignalRecordTime = nil
        lastETAMinutes = nil
        autoEnabledEarlyTriggerDueToRisk = false
        
        // 重置计算器
        speedCalculator.clearSamples()
        etaCalculator.reset()
        
        // 取消兜底闹钟
        await cancelBackupAlarm()
        
        // 停止位置更新
        await MainActor.run {
            locationManager.stopUpdatingLocation()
            locationManager.stopMonitoringSignificantLocationChanges()
        }
        
        // 结束行程
        if let trip = currentTrip {
            try? await tripRepository.endTrip(tripId: trip.id)
        }
        currentTrip = nil
        
        // 通知状态变化
        onStatusChange?(MonitoringStatus.idle)
    }
    
    /// 获取当前监控状态
    func getStatus() async -> MonitoringStatus {
        var lastLocation: LocationUpdate? = nil
        var distance: Double? = nil
        
        if let location = previousLocation, let config = currentConfig {
            lastLocation = LocationUpdate(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                accuracy: location.horizontalAccuracy,
                timestamp: location.timestamp
            )
            distance = GeoUtils.calculateDistance(
                lat1: location.coordinate.latitude, lon1: location.coordinate.longitude,
                lat2: config.destination.latitude, lon2: config.destination.longitude
            )
        }
        
        return MonitoringStatus(
            state: state,
            config: currentConfig,
            currentTrip: currentTrip,
            lastLocation: lastLocation,
            distanceToDestination: distance
        )
    }
    
    /// 更新交通方式
    func updateTransportMode(_ mode: TransportMode) {
        currentTransportMode = mode
    }
    
    /// 更新电池模式
    func updateBatteryMode(_ mode: BatteryMode) {
        currentBatteryMode = mode
        updateLocationManagerSettings()
    }
    
    /// 获取当前 ETA
    func getCurrentETA() -> EnhancedETAResult? {
        guard let config = currentConfig,
              let location = previousLocation else {
            return nil
        }
        
        let distance = GeoUtils.calculateDistance(
            lat1: location.coordinate.latitude, lon1: location.coordinate.longitude,
            lat2: config.destination.latitude, lon2: config.destination.longitude
        )
        
        let speed = speedCalculator.getAverageSpeed() ?? currentTransportMode.baselineSpeed
        
        return etaCalculator.calculateETA(
            distance: distance,
            currentSpeed: speed,
            transportMode: currentTransportMode
        )
    }
    
    // MARK: - Private Methods
    
    /// 配置位置管理器
    private func setupLocationManager() async {
        await MainActor.run {
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyBest
            locationManager.distanceFilter = Self.minimumDistanceFilter
            locationManager.allowsBackgroundLocationUpdates = true
            locationManager.pausesLocationUpdatesAutomatically = false
            
            // 使用显著位置变化来省电
            locationManager.startMonitoringSignificantLocationChanges()
            locationManager.startUpdatingLocation()
        }
    }
    
    /// 更新位置管理器设置（基于电池模式）
    private func updateLocationManagerSettings() {
        let mode = currentBatteryMode
        Task { @MainActor in
            switch mode {
            case .powerSaving:
                locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
                locationManager.distanceFilter = 50.0
            case .balanced:
                locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
                locationManager.distanceFilter = Self.minimumDistanceFilter
            case .highAccuracy:
                locationManager.desiredAccuracy = kCLLocationAccuracyBest
                locationManager.distanceFilter = 5.0
            }
        }
    }
    
    /// 处理位置更新
    private func handleLocationUpdate(_ location: CLLocation) async {
        guard let config = currentConfig else { return }
        
        let coordinate = location.coordinate
        let destination = config.destination
        
        // 计算到目的地的距离
        let distance = GeoUtils.calculateDistance(
            lat1: coordinate.latitude, lon1: coordinate.longitude,
            lat2: destination.latitude, lon2: destination.longitude
        )
        
        // 计算速度
        var currentSpeed: Double = 0
        if let previous = previousLocation {
            let speedResult = speedCalculator.calculateSpeed(from: previous, to: location)
            if speedResult.isValid {
                currentSpeed = speedResult.speed
                speedCalculator.addSample(from: speedResult, accuracy: location.horizontalAccuracy)
            }
        }
        
        // 更新检查间隔
        currentCheckInterval = intervalManager.calculateInterval(
            distance: distance,
            speed: currentSpeed,
            batteryMode: currentBatteryMode
        )
        
        // 获取历史平均速度（用于 ETA 融合）
        let historicalSpeed = await getHistoricalAverageSpeed(
            destinationId: destination.id,
            transportMode: currentTransportMode
        )
        
        // 计算 ETA（融合历史数据）
        let etaResult = etaCalculator.calculateETA(
            distance: distance,
            currentSpeed: currentSpeed > 0 ? currentSpeed : currentTransportMode.baselineSpeed,
            transportMode: currentTransportMode,
            historicalAverage: historicalSpeed
        )
        onETAUpdate?(etaResult)
        
        // 更新兜底闹钟
        if let etaMinutes = etaResult.estimatedMinutes {
            await updateBackupAlarmIfNeeded(newETAMinutes: etaMinutes, destination: destination)
        }
        
        // 记录信号质量（节流处理）
        await recordSignalQualityThrottled(location: location)
        
        // 创建位置更新对象
        let locationUpdate = LocationUpdate(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            timestamp: Date()
        )
        
        // 检测围栏进入
        if let previous = previousLocation {
            let previousCoord = previous.coordinate
            let currentCoord = coordinate
            let center = CLLocationCoordinate2D(latitude: destination.latitude, longitude: destination.longitude)
            
            if GeoUtils.didEnterGeofence(
                previousLocation: previousCoord,
                currentLocation: currentCoord,
                center: center,
                radius: Double(config.geofenceRadius)
            ) {
                // 触发围栏进入事件
                let event = GeofenceEvent(
                    type: .enter,
                    location: locationUpdate,
                    distanceToDestination: distance
                )
                onGeofenceEvent?(event)
                
                // 取消兜底闹钟（已到达）
                await cancelBackupAlarm()
                
                // 更新行程记录
                if var trip = currentTrip {
                    trip.alertTriggered = true
                    trip.alertType = .arrival
                    trip.alertTimestamp = Date()
                    try? await tripRepository.updateTrip(trip)
                    currentTrip = trip
                }
            }
        }
        
        previousLocation = location
        
        // 通知位置更新
        onLocationUpdate?(locationUpdate)
    }
    
    /// 获取历史平均速度
    /// - Parameters:
    ///   - destinationId: 目的地 ID
    ///   - transportMode: 交通方式
    /// - Returns: 历史平均速度（米/秒），如果没有历史数据则返回 nil
    private func getHistoricalAverageSpeed(destinationId: String, transportMode: TransportMode) async -> Double? {
        return await learningEngineRef.getHistoricalAverageSpeed(
            forDestinationId: destinationId,
            transportMode: transportMode
        )
    }
    
    /// 节流记录信号质量
    private func recordSignalQualityThrottled(location: CLLocation) async {
        let now = Date()
        
        if let lastTime = lastSignalRecordTime,
           now.timeIntervalSince(lastTime) < Self.signalRecordingThrottleInterval {
            return
        }
        
        lastSignalRecordTime = now
        
        let sample = SignalSample(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracy: location.horizontalAccuracy,
            timestamp: now
        )
        
        try? await signalQualityRepository.recordSignalSample(sample)
    }
    
    /// 检查是否应该提前触发
    func shouldTriggerEarly(currentLocation: CLLocation) async -> Bool {
        guard let config = currentConfig,
              config.enableEarlyTrigger else {
            return false
        }
        
        // 获取目的地信号质量
        let signalQuality = await signalQualityRepository.getSignalQuality(
            latitude: config.destination.latitude,
            longitude: config.destination.longitude
        )
        
        // 如果目的地信号差，检查当前位置是否是最后的良好信号点
        if signalQuality.level == .poor {
            let currentSignalLevel = SignalQualityEvaluator.determineQualityLevel(accuracy: currentLocation.horizontalAccuracy)
            
            // 当前信号良好，且距离目的地较近时提前触发
            if currentSignalLevel == .good {
                let distance = GeoUtils.calculateDistance(
                    lat1: currentLocation.coordinate.latitude, lon1: currentLocation.coordinate.longitude,
                    lat2: config.destination.latitude, lon2: config.destination.longitude
                )
                
                // 使用设置中的提前触发倍数
                let earlyTriggerDistance = calculateEarlyTriggerDistance(
                    geofenceRadius: config.geofenceRadius,
                    multiplier: currentEarlyTriggerMultiplier
                )
                
                if distance <= earlyTriggerDistance {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// 计算提前触发距离
    /// - Parameters:
    ///   - geofenceRadius: 围栏半径
    ///   - multiplier: 提前触发倍数
    /// - Returns: 提前触发距离
    func calculateEarlyTriggerDistance(geofenceRadius: Int, multiplier: Double) -> Double {
        return Double(geofenceRadius) * multiplier
    }
    
    /// 更新提前触发倍数（设置变化时调用）
    func updateEarlyTriggerMultiplier(_ multiplier: Double) {
        currentEarlyTriggerMultiplier = multiplier
    }
    
    /// 记录提前触发
    func recordEarlyTrigger() async {
        if var trip = currentTrip {
            trip.alertTriggered = true
            trip.alertType = .earlyArrival
            trip.alertTimestamp = Date()
            try? await tripRepository.updateTrip(trip)
            currentTrip = trip
        }
    }
    
    // MARK: - Backup Alarm Methods
    
    /// 设置兜底闹钟
    /// - Parameters:
    ///   - etaMinutes: 预计到达时间（分钟）
    ///   - offsetMinutes: 提前偏移（分钟）
    ///   - destination: 目的地
    func setupBackupAlarm(etaMinutes: Int, offsetMinutes: Int, destination: Location) async {
        // 检查是否启用兜底闹钟
        guard currentEnableBackupAlarm else { return }
        
        // ETA 必须大于偏移才有意义
        guard etaMinutes > offsetMinutes else { return }
        
        let alarmTime = BackupAlarmCalculator.calculateAlarmTime(
            currentTime: Date(),
            etaMinutes: etaMinutes,
            offsetMinutes: offsetMinutes
        )
        
        // 确保闹钟时间在未来
        guard alarmTime > Date() else { return }
        
        do {
            try await alertTrigger.setBackupAlarm(at: alarmTime, destination: destination)
            
            // 记录闹钟状态
            backupAlarmState = BackupAlarmState(
                alarmId: UUID().uuidString,
                scheduledTime: alarmTime,
                destinationId: destination.id,
                etaMinutesWhenSet: etaMinutes
            )
            
            print("⏰ MonitoringEngine: 设置兜底闹钟 - ETA: \(etaMinutes)分钟, 偏移: \(offsetMinutes)分钟, 闹钟时间: \(alarmTime)")
        } catch {
            print("⚠️ MonitoringEngine: 设置兜底闹钟失败 - \(error.localizedDescription)")
        }
    }
    
    /// 更新兜底闹钟（ETA 变化时）
    /// - Parameters:
    ///   - newETAMinutes: 新的 ETA（分钟）
    ///   - destination: 目的地
    func updateBackupAlarmIfNeeded(newETAMinutes: Int, destination: Location) async {
        guard currentEnableBackupAlarm else { return }
        
        let previousETA = lastETAMinutes ?? newETAMinutes
        lastETAMinutes = newETAMinutes
        
        // 检查是否需要更新（ETA 变化超过 5 分钟）
        let shouldUpdate = BackupAlarmCalculator.shouldUpdateAlarm(
            previousETAMinutes: previousETA,
            newETAMinutes: newETAMinutes
        )
        
        if shouldUpdate || backupAlarmState == nil {
            await setupBackupAlarm(
                etaMinutes: newETAMinutes,
                offsetMinutes: currentBackupAlarmOffset,
                destination: destination
            )
        }
    }
    
    /// 取消兜底闹钟
    func cancelBackupAlarm() async {
        await alertTrigger.cancelBackupAlarm()
        backupAlarmState = nil
        print("⏰ MonitoringEngine: 已取消兜底闹钟")
    }
    
    // MARK: - Reliability Score Methods
    
    /// 查询并应用可靠性评分
    /// - Parameter destinationId: 目的地 ID
    func applyReliabilityScore(forDestinationId destinationId: String) async {
        // 获取可靠性评分
        currentReliabilityScore = await learningEngineRef.calculateReliabilityScore(forDestinationId: destinationId)
        
        // 根据评分调整策略
        let riskLevel = RiskLevelCalculator.determineRiskLevel(reliabilityScore: currentReliabilityScore)
        
        switch riskLevel {
        case .high:
            // 高风险：自动启用提前触发
            if !currentEnableEarlyTrigger {
                autoEnabledEarlyTriggerDueToRisk = true
                currentEnableEarlyTrigger = true
                print("⚠️ MonitoringEngine: 高风险路线，自动启用提前触发")
            }
        case .medium:
            // 中风险：建议启用兜底闹钟（如果未启用）
            if !currentEnableBackupAlarm {
                print("💡 MonitoringEngine: 中风险路线，建议启用兜底闹钟")
            }
        case .low:
            // 低风险：无自动调整
            break
        }
    }
    
    /// 获取当前可靠性评分
    func getCurrentReliabilityScore() -> Double {
        return currentReliabilityScore
    }
    
    /// 是否因风险自动启用了提前触发
    func isEarlyTriggerAutoEnabledDueToRisk() -> Bool {
        return autoEnabledEarlyTriggerDueToRisk
    }
}

// MARK: - CLLocationManagerDelegate

extension MonitoringEngine: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        Task {
            await handleLocationUpdate(location)
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // 记录错误但不中断监控
        print("Location manager error: \(error.localizedDescription)")
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        
        if status == .denied || status == .restricted {
            Task {
                await stopMonitoring()
            }
        }
    }
}

// MARK: - Shared Instance

extension MonitoringEngine {
    /// 共享实例
    static let shared = MonitoringEngine()
}
