import Foundation

/// 监控状态
enum MonitoringState: String, Codable, Equatable {
    case idle = "idle"
    case monitoring = "monitoring"
    case paused = "paused"
}

/// 监控配置
struct MonitoringConfig: Codable, Equatable {
    let destination: Location
    let geofenceRadius: Int  // 100-50000 米
    let enableEarlyTrigger: Bool
    let earlyTriggerDistance: Int?  // 提前触发距离
    let transportMode: TransportMode?  // 交通方式
    let batteryMode: BatteryMode?  // 电池模式
    let selectedRouteId: String?  // 选中的路线 ID
    
    init(
        destination: Location,
        geofenceRadius: Int,
        enableEarlyTrigger: Bool = false,
        earlyTriggerDistance: Int? = nil,
        transportMode: TransportMode? = nil,
        batteryMode: BatteryMode? = nil,
        selectedRouteId: String? = nil
    ) {
        self.destination = destination
        // 确保围栏半径在有效范围内 (100m - 50km)
        self.geofenceRadius = min(max(geofenceRadius, 100), 50000)
        self.enableEarlyTrigger = enableEarlyTrigger
        self.earlyTriggerDistance = earlyTriggerDistance
        self.transportMode = transportMode
        self.batteryMode = batteryMode
        self.selectedRouteId = selectedRouteId
    }
}

/// 监控状态信息
struct MonitoringStatus: Codable, Equatable {
    let state: MonitoringState
    let config: MonitoringConfig?
    let currentTrip: TripRecord?
    let lastLocation: LocationUpdate?
    let distanceToDestination: Double?
    
    init(
        state: MonitoringState = .idle,
        config: MonitoringConfig? = nil,
        currentTrip: TripRecord? = nil,
        lastLocation: LocationUpdate? = nil,
        distanceToDestination: Double? = nil
    ) {
        self.state = state
        self.config = config
        self.currentTrip = currentTrip
        self.lastLocation = lastLocation
        self.distanceToDestination = distanceToDestination
    }
    
    /// 空闲状态
    static let idle = MonitoringStatus()
}

/// 位置更新
struct LocationUpdate: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let accuracy: Double
    let timestamp: Date
    let signalQuality: SignalQuality
    
    init(
        latitude: Double,
        longitude: Double,
        accuracy: Double,
        timestamp: Date = Date(),
        signalQuality: SignalQuality = .unknown
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.accuracy = accuracy
        self.timestamp = timestamp
        self.signalQuality = signalQuality
    }
}

/// 地理围栏事件
struct GeofenceEvent: Codable, Equatable {
    enum EventType: String, Codable, Equatable {
        case enter = "enter"
        case earlyTrigger = "early_trigger"
    }
    
    let type: EventType
    let location: LocationUpdate
    let distanceToDestination: Double
    
    init(type: EventType, location: LocationUpdate, distanceToDestination: Double) {
        self.type = type
        self.location = location
        self.distanceToDestination = distanceToDestination
    }
}
