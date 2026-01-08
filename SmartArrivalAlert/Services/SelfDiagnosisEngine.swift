import Foundation
import CoreLocation

/// 自检引擎协议
protocol SelfDiagnosisEngineProtocol {
    func performDiagnosis(destination: Location, route: [(latitude: Double, longitude: Double)]?) async -> RiskAssessment
    func checkPermissionStatus() async -> PermissionStatus
}

/// 自检引擎 - 负责在启动前评估行程风险
actor SelfDiagnosisEngine: SelfDiagnosisEngineProtocol {
    
    // MARK: - Constants
    
    /// 自检超时时间（秒）
    static let diagnosisTimeout: TimeInterval = 3.0
    
    /// 高风险阈值
    static let highRiskThreshold: Double = 70.0
    
    /// 中风险阈值
    static let mediumRiskThreshold: Double = 85.0
    
    // MARK: - Properties
    
    private let learningEngine: LearningEngine
    private let signalQualityRepository: SignalQualityRepository
    private let locationManager: CLLocationManager
    
    // MARK: - Initialization
    
    init(
        learningEngine: LearningEngine = .shared,
        signalQualityRepository: SignalQualityRepository = .shared
    ) {
        self.learningEngine = learningEngine
        self.signalQualityRepository = signalQualityRepository
        self.locationManager = CLLocationManager()
    }
    
    // MARK: - Public Methods
    
    /// 执行完整自检
    /// - Parameters:
    ///   - destination: 目的地
    ///   - route: 路线途经点（可选）
    /// - Returns: 风险评估结果
    func performDiagnosis(destination: Location, route: [(latitude: Double, longitude: Double)]? = nil) async -> RiskAssessment {
        // 并发执行所有检查项
        async let permissionCheck = checkPermissionStatus()
        async let destinationSignalCheck = queryDestinationSignalQuality(location: destination)
        async let routeSignalCheck = queryRouteSignalQuality(route: route)
        async let successRateCheck = queryHistoricalSuccessRate(destination: destination)
        
        // 等待所有检查完成
        let permissionStatus = await permissionCheck
        let destinationSignalQuality = await destinationSignalCheck
        let routeSignalQuality = await routeSignalCheck
        let historicalSuccessRate = await successRateCheck
        
        // 判断权限是否正常
        let permissionOk = permissionStatus == .authorized
        
        // 生成警告信息
        var warnings: [String] = []
        
        if !permissionOk {
            warnings.append("位置权限未授予，无法进行位置监控")
        }
        
        if destinationSignalQuality.level == .poor {
            warnings.append("目的地历史信号质量较差，提醒可能不准确")
        }
        
        if routeSignalQuality.level == .poor {
            warnings.append("路线沿途信号质量较差")
        }
        
        if historicalSuccessRate < Self.highRiskThreshold {
            warnings.append("该路线历史成功率较低（\(Int(historicalSuccessRate))%），建议手动盯着点")
        }
        
        // 判断是否建议提前触发
        let suggestEarlyTrigger = destinationSignalQuality.level == .poor
        
        // 判断是否建议设置兜底闹钟
        let suggestBackupAlarm = historicalSuccessRate < Self.mediumRiskThreshold || destinationSignalQuality.level == .poor
        
        // 计算总体风险等级
        let overallRisk = determineRiskLevel(
            permissionOk: permissionOk,
            destinationSignalQuality: destinationSignalQuality,
            routeSignalQuality: routeSignalQuality,
            historicalSuccessRate: historicalSuccessRate
        )
        
        return RiskAssessment(
            overallRisk: overallRisk,
            permissionOk: permissionOk,
            destinationSignalQuality: destinationSignalQuality,
            routeSignalQuality: routeSignalQuality,
            historicalSuccessRate: historicalSuccessRate,
            warnings: warnings,
            suggestEarlyTrigger: suggestEarlyTrigger,
            suggestBackupAlarm: suggestBackupAlarm
        )
    }
    
    /// 检查位置权限状态
    /// - Returns: 权限状态
    func checkPermissionStatus() async -> PermissionStatus {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .authorizedAlways, .authorizedWhenInUse:
            return .authorized
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
    }
    
    /// 查询目的地信号质量
    /// - Parameter location: 目的地
    /// - Returns: 信号质量
    func queryDestinationSignalQuality(location: Location) async -> SignalQuality {
        return await signalQualityRepository.getSignalQuality(
            latitude: location.latitude,
            longitude: location.longitude
        )
    }
    
    /// 查询路线沿途信号质量
    /// - Parameter route: 路线途经点
    /// - Returns: 信号质量
    func queryRouteSignalQuality(route: [(latitude: Double, longitude: Double)]?) async -> SignalQuality {
        guard let route = route, !route.isEmpty else {
            return .unknown
        }
        
        return await signalQualityRepository.getRouteSignalQuality(waypoints: route)
    }
    
    /// 查询历史成功率
    /// - Parameter destination: 目的地
    /// - Returns: 成功率 (0-100)
    func queryHistoricalSuccessRate(destination: Location) async -> Double {
        return await learningEngine.calculateReliabilityScore(forDestinationId: destination.id)
    }
    
    /// 快速检查（仅检查权限）
    /// - Returns: 权限是否正常
    func quickCheck() async -> Bool {
        let status = await checkPermissionStatus()
        return status == .authorized
    }
    
    // MARK: - Risk Level Determination
    
    /// 判断风险等级
    /// - Parameters:
    ///   - permissionOk: 权限是否正常
    ///   - destinationSignalQuality: 目的地信号质量
    ///   - routeSignalQuality: 路线信号质量
    ///   - historicalSuccessRate: 历史成功率
    /// - Returns: 风险等级
    func determineRiskLevel(
        permissionOk: Bool,
        destinationSignalQuality: SignalQuality,
        routeSignalQuality: SignalQuality,
        historicalSuccessRate: Double
    ) -> RiskLevel {
        // 权限问题 = 高风险
        if !permissionOk {
            return .high
        }
        
        // 目的地信号差 = 高风险
        if destinationSignalQuality.level == .poor {
            return .high
        }
        
        // 历史成功率低于70% = 高风险
        if historicalSuccessRate < Self.highRiskThreshold {
            return .high
        }
        
        // 目的地信号一般 或 历史成功率低于85% = 中风险
        if destinationSignalQuality.level == .fair {
            return .medium
        }
        
        if historicalSuccessRate < Self.mediumRiskThreshold {
            return .medium
        }
        
        // 路线信号差 = 中风险
        if routeSignalQuality.level == .poor {
            return .medium
        }
        
        return .low
    }
    
    /// 静态方法：判断风险等级（用于测试）
    static func determineRiskLevel(
        permissionOk: Bool,
        destinationSignalQuality: SignalQuality,
        historicalSuccessRate: Double
    ) -> RiskLevel {
        if !permissionOk {
            return .high
        }
        
        if destinationSignalQuality.level == .poor {
            return .high
        }
        
        if historicalSuccessRate < highRiskThreshold {
            return .high
        }
        
        if destinationSignalQuality.level == .fair {
            return .medium
        }
        
        if historicalSuccessRate < mediumRiskThreshold {
            return .medium
        }
        
        return .low
    }
}

// MARK: - Shared Instance

extension SelfDiagnosisEngine {
    /// 共享实例
    static let shared = SelfDiagnosisEngine()
}
