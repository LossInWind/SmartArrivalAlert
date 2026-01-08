import Foundation

#if os(iOS)
import ActivityKit

// MARK: - Trip Activity Attributes
// 注意：这个定义必须与 Widget Extension 中的 TripActivityAttributes 完全一致

@available(iOS 16.1, *)
public struct TripActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var distance: Int
        public var etaMinutes: Int?
        public var isETAReliable: Bool
        public var isInsideGeofence: Bool
        
        public init(distance: Int, etaMinutes: Int?, isETAReliable: Bool, isInsideGeofence: Bool) {
            self.distance = distance
            self.etaMinutes = etaMinutes
            self.isETAReliable = isETAReliable
            self.isInsideGeofence = isInsideGeofence
        }
    }
    
    public var destinationName: String
    public var destinationAddress: String
    public var geofenceRadius: Int
    public var transportModeIcon: String
    public var transportModeName: String
    
    public init(destinationName: String, destinationAddress: String, geofenceRadius: Int, transportModeIcon: String, transportModeName: String) {
        self.destinationName = destinationName
        self.destinationAddress = destinationAddress
        self.geofenceRadius = geofenceRadius
        self.transportModeIcon = transportModeIcon
        self.transportModeName = transportModeName
    }
}

// MARK: - Live Activity Manager

@available(iOS 16.1, *)
@MainActor
class LiveActivityManager: ObservableObject, LiveActivityManaging {
    
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<TripActivityAttributes>?
    
    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }
    
    private init() {}
    
    func startActivity(
        destinationName: String,
        destinationAddress: String,
        geofenceRadius: Int,
        transportMode: TransportMode,
        initialDistance: Int
    ) async {
        guard isSupported else {
            print("❌ Live Activity 不支持")
            return
        }
        
        await endActivity()
        
        let attributes = TripActivityAttributes(
            destinationName: destinationName,
            destinationAddress: destinationAddress,
            geofenceRadius: geofenceRadius,
            transportModeIcon: transportMode.icon,
            transportModeName: transportMode.displayName
        )
        
        let state = TripActivityAttributes.ContentState(
            distance: initialDistance,
            etaMinutes: transportMode.calculateInitialETA(distance: Double(initialDistance)),
            isETAReliable: true,
            isInsideGeofence: initialDistance <= geofenceRadius
        )
        
        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("✅ Live Activity 启动: \(activity.id)")
        } catch {
            print("❌ Live Activity 失败: \(error)")
        }
    }
    
    func updateActivity(
        distance: Int,
        etaMinutes: Int?,
        isETAReliable: Bool,
        geofenceRadius: Int
    ) async {
        guard let activity = currentActivity else { return }
        
        let state = TripActivityAttributes.ContentState(
            distance: distance,
            etaMinutes: etaMinutes,
            isETAReliable: isETAReliable,
            isInsideGeofence: distance <= geofenceRadius
        )
        
        await activity.update(ActivityContent(state: state, staleDate: nil))
    }
    
    func showArrival() async {
        guard let activity = currentActivity else { return }
        
        let state = TripActivityAttributes.ContentState(
            distance: 0,
            etaMinutes: 0,
            isETAReliable: true,
            isInsideGeofence: true
        )
        
        await activity.update(ActivityContent(state: state, staleDate: nil))
        try? await Task.sleep(nanoseconds: 3_000_000_000)
        await endActivity()
    }
    
    func endActivity() async {
        guard let activity = currentActivity else { return }
        
        let state = TripActivityAttributes.ContentState(
            distance: 0,
            etaMinutes: nil,
            isETAReliable: true,
            isInsideGeofence: true
        )
        
        await activity.end(
            ActivityContent(state: state, staleDate: nil),
            dismissalPolicy: .immediate
        )
        currentActivity = nil
    }
}
#endif

// MARK: - Protocol & Fallback

@MainActor
protocol LiveActivityManaging {
    var isSupported: Bool { get }
    func startActivity(destinationName: String, destinationAddress: String, geofenceRadius: Int, transportMode: TransportMode, initialDistance: Int) async
    func updateActivity(distance: Int, etaMinutes: Int?, isETAReliable: Bool, geofenceRadius: Int) async
    func showArrival() async
    func endActivity() async
}

@MainActor
class LiveActivityManagerFallback: LiveActivityManaging, ObservableObject {
    static let shared = LiveActivityManagerFallback()
    var isSupported: Bool { false }
    private init() {}
    func startActivity(destinationName: String, destinationAddress: String, geofenceRadius: Int, transportMode: TransportMode, initialDistance: Int) async {}
    func updateActivity(distance: Int, etaMinutes: Int?, isETAReliable: Bool, geofenceRadius: Int) async {}
    func showArrival() async {}
    func endActivity() async {}
}

@MainActor
func getLiveActivityManager() -> any LiveActivityManaging {
    #if os(iOS)
    if #available(iOS 16.1, *) {
        return LiveActivityManager.shared
    }
    #endif
    return LiveActivityManagerFallback.shared
}
