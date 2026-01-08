// =============================================================================
// Widget Extension 完整代码
// =============================================================================
//
// 使用说明：
// 1. 在 Xcode 中创建 Widget Extension target (File → New → Target → Widget Extension)
// 2. 命名为 "TripActivityWidget"
// 3. 删除 Xcode 自动生成的模板代码
// 4. 将此文件的内容复制到 Widget Extension 的主文件中
// 5. 在 Info.plist 中添加：
//    - NSSupportsLiveActivities = YES
//    - NSSupportsLiveActivitiesFrequentUpdates = YES
//
// =============================================================================

import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - Trip Activity Attributes (必须与主 App 中的定义完全一致)

@available(iOS 16.1, *)
struct TripActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var distance: Int
        var etaMinutes: Int?
        var isETAReliable: Bool
        var isInsideGeofence: Bool
    }
    
    var destinationName: String
    var destinationAddress: String
    var geofenceRadius: Int
    var transportModeIcon: String
    var transportModeName: String
}

// MARK: - Live Activity Formatters (复制自主 App)

enum LiveActivityFormatters {
    static let kilometerThreshold: Int = 1000
    static let maxDistanceMultiplier: Double = 10.0
    
    static func formatDistance(_ meters: Int) -> String {
        guard meters >= 0 else { return "0 m" }
        if meters < kilometerThreshold {
            return "\(meters) m"
        } else {
            let km = Double(meters) / 1000.0
            return String(format: "%.1f km", km)
        }
    }
    
    static func formatCompactDistance(_ meters: Int) -> String {
        guard meters >= 0 else { return "0m" }
        if meters < kilometerThreshold {
            return "\(meters)m"
        } else {
            let km = Double(meters) / 1000.0
            return String(format: "%.1fkm", km)
        }
    }
    
    static func calculateProgress(distance: Int, geofenceRadius: Int) -> Double {
        guard geofenceRadius > 0 else { return 0.0 }
        guard distance >= 0 else { return 1.0 }
        
        let distanceDouble = Double(distance)
        let radiusDouble = Double(geofenceRadius)
        let maxDistance = radiusDouble * maxDistanceMultiplier
        
        if distanceDouble <= radiusDouble { return 1.0 }
        if distanceDouble >= maxDistance { return 0.0 }
        
        let progress = 1.0 - (distanceDouble - radiusDouble) / (maxDistance - radiusDouble)
        return max(0.0, min(1.0, progress))
    }
    
    static func formatETA(_ minutes: Int?) -> String {
        guard let minutes = minutes else { return "--" }
        if minutes <= 0 { return "即将到达" }
        else if minutes < 60 { return "\(minutes) 分钟" }
        else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 { return "\(hours) 小时" }
            else { return "\(hours) 小时 \(remainingMinutes) 分钟" }
        }
    }
}

// MARK: - Main Widget

@available(iOS 16.1, *)
@main
struct TripActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            TripLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                CompactLeadingView(context: context)
            } compactTrailing: {
                CompactTrailingView(context: context)
            } minimal: {
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Lock Screen View

@available(iOS 16.1, *)
struct TripLockScreenView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    
    private var isArrived: Bool { context.state.isInsideGeofence }
    
    private var progressValue: Double {
        LiveActivityFormatters.calculateProgress(
            distance: context.state.distance,
            geofenceRadius: context.attributes.geofenceRadius
        )
    }
    
    private var formattedDistance: String {
        LiveActivityFormatters.formatDistance(context.state.distance)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: context.attributes.transportModeIcon)
                    .font(.title3)
                    .foregroundStyle(isArrived ? .green : .blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.destinationName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                    
                    Text(context.attributes.destinationAddress)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isArrived {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("已到达")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.green)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            
            // Stats
            HStack(spacing: 0) {
                VStack(alignment: .center, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundStyle((isArrived ? Color.green : Color.blue).opacity(0.7))
                        Text(formattedDistance)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(isArrived ? .green : .blue)
                    }
                    Text("距离")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Rectangle()
                    .fill(Color.secondary.opacity(0.3))
                    .frame(width: 1, height: 40)
                
                Spacer()
                
                HStack(spacing: 4) {
                    VStack(alignment: .center, spacing: 4) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption2)
                                .foregroundStyle((isArrived ? Color.green : (context.state.isETAReliable ? Color.primary : Color.orange)).opacity(0.7))
                            Text(context.state.etaMinutes.map { "\($0)" } ?? "--")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundStyle(isArrived ? .green : (context.state.isETAReliable ? .primary : .orange))
                        }
                        Text("分钟")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    
                    if !context.state.isETAReliable && !isArrived {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }
            
            // Progress
            VStack(alignment: .leading, spacing: 4) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.2))
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isArrived ? Color.green : Color.blue)
                            .frame(width: geometry.size.width * progressValue)
                    }
                }
                .frame(height: 8)
                
                HStack {
                    Text("围栏半径: \(LiveActivityFormatters.formatDistance(context.attributes.geofenceRadius))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if isArrived {
                        Text("已进入提醒范围")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    } else {
                        Text("距提醒还有 \(formattedDistance)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .activityBackgroundTint(isArrived ? Color.green.opacity(0.2) : Color.blue.opacity(0.1))
        .activitySystemActionForegroundColor(isArrived ? .green : .blue)
    }
}

// MARK: - Compact Views

@available(iOS 16.1, *)
struct CompactLeadingView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    private var isArrived: Bool { context.state.isInsideGeofence }
    
    var body: some View {
        Image(systemName: context.attributes.transportModeIcon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isArrived ? .green : .blue)
    }
}

@available(iOS 16.1, *)
struct CompactTrailingView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    private var isArrived: Bool { context.state.isInsideGeofence }
    
    var body: some View {
        if isArrived {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.green)
        } else {
            Text(LiveActivityFormatters.formatCompactDistance(context.state.distance))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
    }
}

@available(iOS 16.1, *)
struct MinimalView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    private var isArrived: Bool { context.state.isInsideGeofence }
    
    var body: some View {
        if isArrived {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.green)
        } else {
            Image(systemName: context.attributes.transportModeIcon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.blue)
        }
    }
}

// MARK: - Expanded Views

@available(iOS 16.1, *)
struct ExpandedLeadingView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    private var isArrived: Bool { context.state.isInsideGeofence }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: context.attributes.transportModeIcon)
                .font(.title2)
                .foregroundStyle(isArrived ? .green : .blue)
            Text(context.attributes.transportModeName)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedTrailingView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    private var isArrived: Bool { context.state.isInsideGeofence }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if isArrived {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                Text("已到达")
                    .font(.caption2)
                    .foregroundStyle(.green)
            } else if let eta = context.state.etaMinutes {
                HStack(spacing: 2) {
                    Text("\(eta)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(context.state.isETAReliable ? .primary : .orange)
                    if !context.state.isETAReliable {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Text("分钟")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("--")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text("计算中")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedCenterView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    private var isArrived: Bool { context.state.isInsideGeofence }
    
    var body: some View {
        VStack(spacing: 2) {
            Text(context.attributes.destinationName)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .foregroundStyle(isArrived ? .green : .primary)
            if isArrived {
                Text("已进入提醒范围")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }
    }
}

@available(iOS 16.1, *)
struct ExpandedBottomView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    private var isArrived: Bool { context.state.isInsideGeofence }
    
    private var progressValue: Double {
        LiveActivityFormatters.calculateProgress(
            distance: context.state.distance,
            geofenceRadius: context.attributes.geofenceRadius
        )
    }
    
    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.3))
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isArrived ? Color.green : Color.blue)
                        .frame(width: geometry.size.width * progressValue)
                }
            }
            .frame(height: 6)
            
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(isArrived ? .green : .blue)
                    Text(LiveActivityFormatters.formatDistance(context.state.distance))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(isArrived ? .green : .primary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: "circle.dashed")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("提醒范围: \(LiveActivityFormatters.formatCompactDistance(context.attributes.geofenceRadius))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
