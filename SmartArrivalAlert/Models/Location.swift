import Foundation

/// 地点模型
struct Location: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var address: String
    var latitude: Double
    var longitude: Double
    var lastVisited: Date?
    var isFavorite: Bool
    var lastGeofenceRadius: Int?
    
    init(
        id: String = UUID().uuidString,
        name: String,
        address: String,
        latitude: Double,
        longitude: Double,
        lastVisited: Date? = nil,
        isFavorite: Bool = false,
        lastGeofenceRadius: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.lastVisited = lastVisited
        self.isFavorite = isFavorite
        self.lastGeofenceRadius = lastGeofenceRadius
    }
}
