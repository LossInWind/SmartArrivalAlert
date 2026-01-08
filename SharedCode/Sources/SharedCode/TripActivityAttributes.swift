import Foundation
import ActivityKit

// MARK: - Trip Activity Attributes
// 共享的 Live Activity 数据模型，主 App 和 Widget Extension 都使用这个定义

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
