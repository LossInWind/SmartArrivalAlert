import SwiftUI
import CoreLocation
import UserNotifications

@main
struct SmartArrivalAlertApp: App {
    @StateObject private var permissionManager = PermissionManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(permissionManager)
                .task {
                    await permissionManager.requestAllPermissions()
                }
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
