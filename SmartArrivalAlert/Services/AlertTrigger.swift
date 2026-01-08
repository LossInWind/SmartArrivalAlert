import Foundation
import UserNotifications
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

/// 提醒触发器协议
protocol AlertTriggerProtocol {
    func triggerArrivalAlert(destination: Location) async throws
    func triggerEarlyAlert(destination: Location, reason: String) async throws
    func setBackupAlarm(at time: Date, destination: Location) async throws
    func cancelBackupAlarm() async
}

/// 提醒触发器 - 负责发送通知和触发提醒
actor AlertTrigger: AlertTriggerProtocol {
    
    // MARK: - Constants
    
    /// 通知类别标识符
    static let arrivalCategoryId = "ARRIVAL_ALERT"
    static let earlyArrivalCategoryId = "EARLY_ARRIVAL_ALERT"
    static let backupAlarmCategoryId = "BACKUP_ALARM"
    
    /// 通知动作标识符
    static let successActionId = "SUCCESS_ACTION"
    static let missedActionId = "MISSED_ACTION"
    static let lateActionId = "LATE_ACTION"
    static let confirmActionId = "CONFIRM_ACTION"
    static let snoozeActionId = "SNOOZE_ACTION"
    
    /// 后续通知标识符前缀
    static let followUpNotificationPrefix = "followup_"
    
    // MARK: - Properties
    
    private let notificationCenter: UNUserNotificationCenter
    private var backupAlarmId: String?
    private var followUpNotificationId: String?
    
    // MARK: - Initialization
    
    init() {
        self.notificationCenter = UNUserNotificationCenter.current()
    }
    
    // MARK: - Setup
    
    /// 配置通知类别
    func setupNotificationCategories() async {
        // 确认动作（主要操作）
        let confirmAction = UNNotificationAction(
            identifier: Self.confirmActionId,
            title: "确认到达",
            options: [.foreground]
        )
        
        // 延迟动作
        let snoozeAction = UNNotificationAction(
            identifier: Self.snoozeActionId,
            title: "延迟 5 分钟",
            options: []
        )
        
        // 成功动作（反馈用）
        let successAction = UNNotificationAction(
            identifier: Self.successActionId,
            title: "及时 👍",
            options: []
        )
        
        // 漏响动作
        let missedAction = UNNotificationAction(
            identifier: Self.missedActionId,
            title: "漏响了 😢",
            options: []
        )
        
        // 晚响动作
        let lateAction = UNNotificationAction(
            identifier: Self.lateActionId,
            title: "晚了点 😅",
            options: []
        )
        
        // 到站提醒类别（带确认和延迟按钮）
        let arrivalCategory = UNNotificationCategory(
            identifier: Self.arrivalCategoryId,
            actions: [confirmAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // 提前提醒类别（带确认和延迟按钮）
        let earlyCategory = UNNotificationCategory(
            identifier: Self.earlyArrivalCategoryId,
            actions: [confirmAction, snoozeAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // 兜底闹钟类别（带反馈按钮）
        let backupCategory = UNNotificationCategory(
            identifier: Self.backupAlarmCategoryId,
            actions: [successAction, missedAction, lateAction],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([arrivalCategory, earlyCategory, backupCategory])
    }
    
    // MARK: - Public Methods
    
    /// 触发到站提醒
    /// - Parameter destination: 目的地
    func triggerArrivalAlert(destination: Location) async throws {
        // 取消之前的后续通知
        await cancelFollowUpNotification()
        
        let content = UNMutableNotificationContent()
        content.title = "到站提醒"
        content.body = "即将到达：\(destination.name)"
        content.sound = .defaultCritical
        content.categoryIdentifier = Self.arrivalCategoryId
        content.userInfo = ["destinationId": destination.id]
        
        // 设置为 Time Sensitive，可突破专注模式
        content.interruptionLevel = .timeSensitive
        
        // 立即触发
        let request = UNNotificationRequest(
            identifier: "arrival_\(destination.id)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        try await notificationCenter.add(request)
        
        // 触发振动
        await triggerHapticFeedback()
        
        // 设置后续通知（30秒后）
        await scheduleFollowUpNotification(destination: destination)
    }
    
    /// 触发提前提醒
    /// - Parameters:
    ///   - destination: 目的地
    ///   - reason: 提前触发原因
    func triggerEarlyAlert(destination: Location, reason: String) async throws {
        let content = UNMutableNotificationContent()
        content.title = "提前提醒"
        content.body = "即将到达：\(destination.name)\n\(reason)"
        content.sound = .defaultCritical
        content.categoryIdentifier = Self.earlyArrivalCategoryId
        content.userInfo = ["destinationId": destination.id, "isEarly": true]
        
        // 设置为 Time Sensitive，可突破专注模式
        content.interruptionLevel = .timeSensitive
        
        let request = UNNotificationRequest(
            identifier: "early_\(destination.id)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        try await notificationCenter.add(request)
        
        await triggerHapticFeedback()
    }
    
    /// 设置兜底闹钟
    /// - Parameters:
    ///   - time: 闹钟时间
    ///   - destination: 目的地
    func setBackupAlarm(at time: Date, destination: Location) async throws {
        // 取消之前的兜底闹钟
        await cancelBackupAlarm()
        
        let content = UNMutableNotificationContent()
        content.title = "兜底提醒"
        content.body = "预计到达时间已到：\(destination.name)\n请确认是否已到站"
        content.sound = .defaultCritical
        content.categoryIdentifier = Self.backupAlarmCategoryId
        content.userInfo = ["destinationId": destination.id, "isBackup": true]
        
        // 兜底闹钟也设置为 Time Sensitive
        content.interruptionLevel = .timeSensitive
        
        // 计算触发时间
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: time)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        
        let alarmId = "backup_\(destination.id)_\(Date().timeIntervalSince1970)"
        backupAlarmId = alarmId
        
        let request = UNNotificationRequest(
            identifier: alarmId,
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(request)
    }
    
    /// 取消兜底闹钟
    func cancelBackupAlarm() async {
        if let alarmId = backupAlarmId {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: [alarmId])
            backupAlarmId = nil
        }
    }
    
    /// 取消所有待处理的通知
    func cancelAllPendingNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
        backupAlarmId = nil
        followUpNotificationId = nil
    }
    
    /// 设置后续通知（用户无响应时）
    /// - Parameter destination: 目的地
    func scheduleFollowUpNotification(destination: Location) async {
        // 取消之前的后续通知
        await cancelFollowUpNotification()
        
        let content = UNMutableNotificationContent()
        content.title = "到站提醒"
        content.body = "请确认是否已到达：\(destination.name)"
        content.sound = .defaultCritical
        content.categoryIdentifier = Self.arrivalCategoryId
        content.userInfo = ["destinationId": destination.id, "isFollowUp": true]
        content.interruptionLevel = .timeSensitive
        
        // 30秒后触发
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: AlertConfiguration.followUpNotificationDelay,
            repeats: false
        )
        
        let notificationId = "\(Self.followUpNotificationPrefix)\(destination.id)_\(Date().timeIntervalSince1970)"
        followUpNotificationId = notificationId
        
        let request = UNNotificationRequest(
            identifier: notificationId,
            content: content,
            trigger: trigger
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            print("⚠️ AlertTrigger: 设置后续通知失败 - \(error.localizedDescription)")
        }
    }
    
    /// 取消后续通知
    func cancelFollowUpNotification() async {
        if let notificationId = followUpNotificationId {
            notificationCenter.removePendingNotificationRequests(withIdentifiers: [notificationId])
            followUpNotificationId = nil
        }
    }
    
    /// 请求通知权限
    /// - Returns: 是否获得权限
    func requestNotificationPermission() async -> Bool {
        do {
            // 请求 Time Sensitive 权限，可以突破专注模式
            let granted = try await notificationCenter.requestAuthorization(
                options: [.alert, .sound, .badge, .criticalAlert, .timeSensitive]
            )
            return granted
        } catch {
            return false
        }
    }
    
    /// 检查通知权限状态
    /// - Returns: 是否有权限
    func checkNotificationPermission() async -> Bool {
        let settings = await notificationCenter.notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    // MARK: - Private Methods
    
    /// 触发触觉反馈
    private func triggerHapticFeedback() async {
        await MainActor.run {
            #if os(iOS)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
            #endif
        }
    }
}

// MARK: - Shared Instance

extension AlertTrigger {
    /// 共享实例
    static let shared = AlertTrigger()
}
