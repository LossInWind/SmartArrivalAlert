import Foundation

/// 提醒类型
enum AlertType: String, Codable, Equatable {
    case arrival = "arrival"
    case earlyArrival = "early_arrival"
    case backupAlarm = "backup_alarm"
}

/// 用户反馈类型
enum UserFeedback: String, Codable, Equatable {
    case success = "success"
    case missed = "missed"
    case late = "late"
}

/// 行程记录
struct TripRecord: Codable, Equatable, Identifiable {
    let id: String
    let destinationId: String
    let destination: Location
    let startTime: Date
    var endTime: Date?
    let geofenceRadius: Int
    var alertTriggered: Bool
    var alertType: AlertType?
    var alertTimestamp: Date?
    var userFeedback: UserFeedback?
    var signalSamples: [SignalSample]
    var backupAlarmSet: Bool
    var backupAlarmTriggered: Bool
    
    init(
        id: String = UUID().uuidString,
        destinationId: String,
        destination: Location,
        startTime: Date = Date(),
        endTime: Date? = nil,
        geofenceRadius: Int,
        alertTriggered: Bool = false,
        alertType: AlertType? = nil,
        alertTimestamp: Date? = nil,
        userFeedback: UserFeedback? = nil,
        signalSamples: [SignalSample] = [],
        backupAlarmSet: Bool = false,
        backupAlarmTriggered: Bool = false
    ) {
        self.id = id
        self.destinationId = destinationId
        self.destination = destination
        self.startTime = startTime
        self.endTime = endTime
        self.geofenceRadius = geofenceRadius
        self.alertTriggered = alertTriggered
        self.alertType = alertType
        self.alertTimestamp = alertTimestamp
        self.userFeedback = userFeedback
        self.signalSamples = signalSamples
        self.backupAlarmSet = backupAlarmSet
        self.backupAlarmTriggered = backupAlarmTriggered
    }
}
