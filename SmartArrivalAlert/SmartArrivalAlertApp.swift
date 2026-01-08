import SwiftUI
import CoreLocation
import UserNotifications

@main
struct SmartArrivalAlertApp: App {
    @StateObject private var permissionManager = PermissionManager()
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(permissionManager)
                .task {
                    await permissionManager.requestAllPermissions()
                    // 设置通知类别
                    await AlertTrigger.shared.setupNotificationCategories()
                }
        }
    }
}

// MARK: - App Delegate

/// 应用代理 - 处理通知响应
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 设置通知代理
        UNUserNotificationCenter.current().delegate = self
        return true
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    /// 前台收到通知时的处理
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let categoryId = notification.request.content.categoryIdentifier
        
        // 兜底闹钟通知：直接触发完整提醒体验
        if categoryId == AlertTrigger.backupAlarmCategoryId {
            Task { @MainActor in
                await handleBackupAlarmNotification(notification)
            }
            // 不显示系统通知横幅（因为我们会显示全屏提醒）
            completionHandler([])
        } else {
            // 其他通知正常显示
            completionHandler([.banner, .sound, .badge])
        }
    }
    
    /// 用户点击通知时的处理
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let categoryId = response.notification.request.content.categoryIdentifier
        let actionId = response.actionIdentifier
        
        // 处理兜底闹钟通知
        if categoryId == AlertTrigger.backupAlarmCategoryId {
            Task { @MainActor in
                await handleBackupAlarmResponse(response)
            }
        }
        // 处理到站提醒通知
        else if categoryId == AlertTrigger.arrivalCategoryId || categoryId == AlertTrigger.earlyArrivalCategoryId {
            Task { @MainActor in
                await handleArrivalAlertResponse(response)
            }
        }
        
        completionHandler()
    }
    
    // MARK: - Private Methods
    
    /// 处理兜底闹钟通知（前台收到时）
    @MainActor
    private func handleBackupAlarmNotification(_ notification: UNNotification) async {
        let userInfo = notification.request.content.userInfo
        
        // 获取目的地信息
        guard let destinationId = userInfo["destinationId"] as? String else { return }
        
        // 创建临时目的地（用于触发提醒）
        let destination = Location(
            id: destinationId,
            name: notification.request.content.body.components(separatedBy: "：").last?.components(separatedBy: "\n").first ?? "目的地",
            address: "",
            latitude: 0,
            longitude: 0
        )
        
        // 触发完整提醒体验（声音、震动、界面）
        await AlertManager.shared.triggerAlert(destination: destination)
    }
    
    /// 处理兜底闹钟响应（用户点击通知时）
    @MainActor
    private func handleBackupAlarmResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        let actionId = response.actionIdentifier
        
        // 获取目的地信息
        guard let destinationId = userInfo["destinationId"] as? String else { return }
        
        // 创建临时目的地
        let destination = Location(
            id: destinationId,
            name: response.notification.request.content.body.components(separatedBy: "：").last?.components(separatedBy: "\n").first ?? "目的地",
            address: "",
            latitude: 0,
            longitude: 0
        )
        
        switch actionId {
        case UNNotificationDefaultActionIdentifier:
            // 用户点击通知本身 - 触发完整提醒
            await AlertManager.shared.triggerAlert(destination: destination)
            
        case AlertTrigger.successActionId:
            // 用户反馈：及时
            // 可以记录反馈数据
            break
            
        case AlertTrigger.missedActionId:
            // 用户反馈：漏响了
            break
            
        case AlertTrigger.lateActionId:
            // 用户反馈：晚了点
            break
            
        default:
            // 默认触发提醒
            await AlertManager.shared.triggerAlert(destination: destination)
        }
    }
    
    /// 处理到站提醒响应
    @MainActor
    private func handleArrivalAlertResponse(_ response: UNNotificationResponse) async {
        let actionId = response.actionIdentifier
        
        switch actionId {
        case AlertTrigger.confirmActionId:
            // 确认到达
            await AlertManager.shared.confirmAlert()
            
        case AlertTrigger.snoozeActionId:
            // 延迟提醒
            await AlertManager.shared.snoozeAlert()
            
        case UNNotificationDefaultActionIdentifier:
            // 点击通知本身 - 显示提醒界面
            AlertManager.shared.showAlertView = true
            
        default:
            break
        }
    }
}

/// 权限管理器
@MainActor
class PermissionManager: NSObject, ObservableObject {
    @Published var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published var notificationStatus: UNAuthorizationStatus = .notDetermined
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationStatus = locationManager.authorizationStatus
    }
    
    /// 请求所有权限
    func requestAllPermissions() async {
        // 请求位置权限
        await requestLocationPermission()
        
        // 请求通知权限
        await requestNotificationPermission()
    }
    
    /// 请求位置权限
    func requestLocationPermission() async {
        let status = locationManager.authorizationStatus
        
        switch status {
        case .notDetermined:
            locationManager.requestAlwaysAuthorization()
        case .authorizedWhenInUse:
            // 升级到始终允许
            locationManager.requestAlwaysAuthorization()
        default:
            break
        }
    }
    
    /// 请求通知权限
    func requestNotificationPermission() async {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert])
            let settings = await center.notificationSettings()
            notificationStatus = settings.authorizationStatus
            
            if granted {
                print("通知权限已授予")
            }
        } catch {
            print("请求通知权限失败: \(error)")
        }
    }
    
    /// 打开系统设置
    func openSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
    
    /// 检查是否有足够权限
    var hasRequiredPermissions: Bool {
        let hasLocation = locationStatus == .authorizedAlways || locationStatus == .authorizedWhenInUse
        let hasNotification = notificationStatus == .authorized
        return hasLocation && hasNotification
    }
    
    /// 检查位置权限是否被拒绝
    var isLocationDenied: Bool {
        locationStatus == .denied || locationStatus == .restricted
    }
    
    /// 检查通知权限是否被拒绝
    var isNotificationDenied: Bool {
        notificationStatus == .denied
    }
}

// MARK: - CLLocationManagerDelegate

extension PermissionManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            locationStatus = manager.authorizationStatus
        }
    }
}
