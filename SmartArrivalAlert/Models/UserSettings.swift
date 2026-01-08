import Foundation

/// 用户设置
struct UserSettings: Codable, Equatable {
    var defaultGeofenceRadius: Int
    var soundEnabled: Bool
    var vibrationEnabled: Bool
    var autoBackupAlarm: Bool
    
    init(
        defaultGeofenceRadius: Int = 200,
        soundEnabled: Bool = true,
        vibrationEnabled: Bool = true,
        autoBackupAlarm: Bool = false
    ) {
        self.defaultGeofenceRadius = defaultGeofenceRadius
        self.soundEnabled = soundEnabled
        self.vibrationEnabled = vibrationEnabled
        self.autoBackupAlarm = autoBackupAlarm
    }
    
    /// 默认设置
    static let `default` = UserSettings()
}
