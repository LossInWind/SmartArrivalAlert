import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif

/// 电池监控器
/// 监听设备电池电量变化，支持自动省电模式切换
class BatteryMonitor: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = BatteryMonitor()
    
    // MARK: - Published Properties
    
    /// 当前电池电量 (0.0-1.0)
    @Published private(set) var batteryLevel: Float = 1.0
    
    /// 是否正在充电
    @Published private(set) var isCharging: Bool = false
    
    /// 是否正在监控
    @Published private(set) var isMonitoring: Bool = false
    
    // MARK: - Constants
    
    /// 迟滞缓冲区（防止频繁切换）
    static let hysteresisBuffer: Int = 10
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    #if canImport(UIKit)
    private var batteryLevelObserver: NSObjectProtocol?
    private var batteryStateObserver: NSObjectProtocol?
    #endif
    
    // MARK: - Initialization
    
    init() {
        #if canImport(UIKit)
        // 初始化时获取当前电池状态
        updateBatteryStatus()
        #endif
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// 开始监控电池状态
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        #if canImport(UIKit)
        // 启用电池监控
        UIDevice.current.isBatteryMonitoringEnabled = true
        
        // 更新当前状态
        updateBatteryStatus()
        
        // 监听电量变化
        batteryLevelObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateBatteryStatus()
        }
        
        // 监听充电状态变化
        batteryStateObserver = NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateBatteryStatus()
        }
        
        isMonitoring = true
        #endif
    }
    
    /// 停止监控电池状态
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        #if canImport(UIKit)
        if let observer = batteryLevelObserver {
            NotificationCenter.default.removeObserver(observer)
            batteryLevelObserver = nil
        }
        
        if let observer = batteryStateObserver {
            NotificationCenter.default.removeObserver(observer)
            batteryStateObserver = nil
        }
        
        UIDevice.current.isBatteryMonitoringEnabled = false
        #endif
        
        isMonitoring = false
    }
    
    /// 检查是否应该自动切换到省电模式
    /// - Parameter threshold: 低电量阈值 (0-100)
    /// - Returns: 是否应该切换
    func shouldSwitchToPowerSaving(threshold: Int) -> Bool {
        let currentPercentage = Int(batteryLevel * 100)
        return currentPercentage < threshold && !isCharging
    }
    
    /// 检查是否应该恢复之前的模式
    /// - Parameter threshold: 低电量阈值 (0-100)
    /// - Returns: 是否应该恢复
    func shouldRestorePreviousMode(threshold: Int) -> Bool {
        let currentPercentage = Int(batteryLevel * 100)
        // 使用迟滞缓冲区防止频繁切换
        return currentPercentage >= (threshold + Self.hysteresisBuffer) || isCharging
    }
    
    /// 获取当前电量百分比
    var batteryPercentage: Int {
        return Int(batteryLevel * 100)
    }
    
    // MARK: - Static Methods (for testing)
    
    /// 判断是否应该切换到省电模式（纯函数，用于测试）
    /// - Parameters:
    ///   - batteryPercentage: 电池电量百分比 (0-100)
    ///   - threshold: 低电量阈值 (0-100)
    ///   - isCharging: 是否正在充电
    /// - Returns: 是否应该切换
    static func shouldSwitchToPowerSaving(
        batteryPercentage: Int,
        threshold: Int,
        isCharging: Bool
    ) -> Bool {
        return batteryPercentage < threshold && !isCharging
    }
    
    /// 判断是否应该恢复之前的模式（纯函数，用于测试）
    /// - Parameters:
    ///   - batteryPercentage: 电池电量百分比 (0-100)
    ///   - threshold: 低电量阈值 (0-100)
    ///   - isCharging: 是否正在充电
    /// - Returns: 是否应该恢复
    static func shouldRestorePreviousMode(
        batteryPercentage: Int,
        threshold: Int,
        isCharging: Bool
    ) -> Bool {
        // 使用迟滞缓冲区防止频繁切换
        return batteryPercentage >= (threshold + hysteresisBuffer) || isCharging
    }
    
    /// 判断当前状态（纯函数，用于测试）
    /// - Parameters:
    ///   - batteryPercentage: 电池电量百分比 (0-100)
    ///   - threshold: 低电量阈值 (0-100)
    ///   - isCharging: 是否正在充电
    ///   - currentlyInPowerSaving: 当前是否处于省电模式
    /// - Returns: 应该处于的模式 (true = 省电模式, false = 正常模式, nil = 保持当前)
    static func determineMode(
        batteryPercentage: Int,
        threshold: Int,
        isCharging: Bool,
        currentlyInPowerSaving: Bool
    ) -> Bool? {
        // 充电时恢复正常模式
        if isCharging {
            return currentlyInPowerSaving ? false : nil
        }
        
        // 低于阈值，切换到省电模式
        if batteryPercentage < threshold {
            return currentlyInPowerSaving ? nil : true
        }
        
        // 高于阈值+缓冲区，恢复正常模式
        if batteryPercentage >= threshold + hysteresisBuffer {
            return currentlyInPowerSaving ? false : nil
        }
        
        // 在迟滞区间内，保持当前状态
        return nil
    }
    
    // MARK: - Private Methods
    
    #if canImport(UIKit)
    private func updateBatteryStatus() {
        let device = UIDevice.current
        batteryLevel = device.batteryLevel >= 0 ? device.batteryLevel : 1.0
        
        switch device.batteryState {
        case .charging, .full:
            isCharging = true
        case .unplugged, .unknown:
            isCharging = false
        @unknown default:
            isCharging = false
        }
    }
    #endif
}
