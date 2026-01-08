// Widget Extension - Live Activity
// Feature: live-activity-enhancement
import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - Activity Attributes (Widget Extension 专用)
// 注意：这个定义必须与主 App 中的 TripActivityAttributes 完全一致

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

// MARK: - Formatters (Widget Extension 专用)
// 注意：Widget Extension 无法访问主 App 代码，需要复制格式化逻辑

@available(iOS 16.1, *)
enum WidgetFormatters {
    /// 千米阈值（米）
    static let kilometerThreshold: Int = 1000
    
    /// 最大显示距离倍数
    static let maxDistanceMultiplier: Double = 10.0
    
    /// 格式化距离（紧凑格式）
    /// **Validates: Requirements 2.2, 3.2**
    static func formatCompactDistance(_ meters: Int) -> String {
        guard meters >= 0 else { return "0m" }
        if meters < kilometerThreshold {
            return "\(meters)m"
        } else {
            let km = Double(meters) / 1000.0
            return String(format: "%.1fkm", km)
        }
    }
    
    /// 格式化距离（完整格式）
    static func formatDistance(_ meters: Int) -> String {
        guard meters >= 0 else { return "0 m" }
        if meters < kilometerThreshold {
            return "\(meters) m"
        } else {
            let km = Double(meters) / 1000.0
            return String(format: "%.1f km", km)
        }
    }
    
    /// 计算进度
    /// **Validates: Requirements 3.5**
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
    
    /// 判断是否应该显示到达状态
    /// **Validates: Requirements 1.4, 2.6, 3.7, 5.3**
    static func shouldShowArrival(isInsideGeofence: Bool, distance: Int, geofenceRadius: Int) -> Bool {
        return isInsideGeofence || distance <= geofenceRadius
    }
}

// MARK: - Widget

@available(iOS 16.1, *)
@main
struct TripActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            // 锁屏视图
            TripLockScreenView(context: context)
            
        } dynamicIsland: { context in
            DynamicIsland {
                // 展开视图
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
                // 收起状态左侧：交通方式图标
                // **Validates: Requirements 1.1**
                CompactLeadingView(context: context)
            } compactTrailing: {
                // 收起状态右侧：ETA 或距离
                // **Validates: Requirements 1.2, 1.3, 1.4**
                CompactTrailingView(context: context)
            } minimal: {
                // 最小视图
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Compact Views

/// 收起状态左侧视图 - 交通方式图标
/// **Validates: Requirements 1.1**
@available(iOS 16.1, *)
struct CompactLeadingView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    
    var body: some View {
        Image(systemName: context.attributes.transportModeIcon)
            .foregroundColor(.cyan)
    }
}

/// 收起状态右侧视图 - ETA/距离/到达状态
/// **Validates: Requirements 1.2, 1.3, 1.4**
@available(iOS 16.1, *)
struct CompactTrailingView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    
    private var isArrived: Bool {
        WidgetFormatters.shouldShowArrival(
            isInsideGeofence: context.state.isInsideGeofence,
            distance: context.state.distance,
            geofenceRadius: context.attributes.geofenceRadius
        )
    }
    
    var body: some View {
        if isArrived {
            // 已到达：显示 ✓ 图标
            // **Validates: Requirements 1.4**
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        } else if context.state.isETAReliable, let eta = context.state.etaMinutes {
            // ETA 可靠：显示分钟数
            // **Validates: Requirements 1.2**
            Text("\(eta)分")
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.cyan)
        } else {
            // ETA 不可靠：显示距离
            // **Validates: Requirements 1.3**
            Text(WidgetFormatters.formatCompactDistance(context.state.distance))
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
        }
    }
}

/// 最小视图
@available(iOS 16.1, *)
struct MinimalView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    
    private var isArrived: Bool {
        WidgetFormatters.shouldShowArrival(
            isInsideGeofence: context.state.isInsideGeofence,
            distance: context.state.distance,
            geofenceRadius: context.attributes.geofenceRadius
        )
    }
    
    var body: some View {
        if isArrived {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        } else {
            Image(systemName: "location.fill")
                .foregroundColor(.cyan)
        }
    }
}

// MARK: - Expanded Views

/// 展开视图左侧 - 交通方式图标
/// **Validates: Requirements 2.4**
@available(iOS 16.1, *)
struct ExpandedLeadingView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: context.attributes.transportModeIcon)
                .font(.title3)
                .foregroundColor(.cyan)
            Text(context.attributes.transportModeName)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

/// 展开视图右侧 - 距离
/// **Validates: Requirements 2.2**
@available(iOS 16.1, *)
struct ExpandedTrailingView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    
    private var isArrived: Bool {
        WidgetFormatters.shouldShowArrival(
            isInsideGeofence: context.state.isInsideGeofence,
            distance: context.state.distance,
            geofenceRadius: context.attributes.geofenceRadius
        )
    }
    
    var body: some View {
        if isArrived {
            VStack(spacing: 2) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.green)
                Text("到达")
                    .font(.caption2)
                    .foregroundColor(.green)
            }
        } else {
            VStack(spacing: 2) {
                Text(WidgetFormatters.formatCompactDistance(context.state.distance))
                    .font(.headline)
                    .foregroundColor(.cyan)
                Text("距离")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// 展开视图中央 - 目的地名称
/// **Validates: Requirements 2.1**
@available(iOS 16.1, *)
struct ExpandedCenterView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    
    var body: some View {
        Text(context.attributes.destinationName)
            .font(.subheadline)
            .fontWeight(.medium)
            .lineLimit(1)
    }
}

/// 展开视图底部 - ETA 和警告
/// **Validates: Requirements 2.3, 2.5, 2.6**
@available(iOS 16.1, *)
struct ExpandedBottomView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    
    private var isArrived: Bool {
        WidgetFormatters.shouldShowArrival(
            isInsideGeofence: context.state.isInsideGeofence,
            distance: context.state.distance,
            geofenceRadius: context.attributes.geofenceRadius
        )
    }
    
    var body: some View {
        HStack {
            if isArrived {
                // 已到达状态
                // **Validates: Requirements 2.6**
                Label("即将到达", systemImage: "bell.fill")
                    .font(.caption)
                    .foregroundColor(.green)
            } else if let eta = context.state.etaMinutes {
                // 显示 ETA
                // **Validates: Requirements 2.3**
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("预计 \(eta) 分钟后提醒")
                        .font(.caption)
                }
                .foregroundColor(context.state.isETAReliable ? .secondary : .orange)
                
                // ETA 不可靠警告
                // **Validates: Requirements 2.5**
                if !context.state.isETAReliable {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            } else {
                // 无 ETA 数据
                Text("计算中...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Lock Screen View

/// 锁屏视图
/// **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 3.7**
@available(iOS 16.1, *)
struct TripLockScreenView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    
    private var isArrived: Bool {
        WidgetFormatters.shouldShowArrival(
            isInsideGeofence: context.state.isInsideGeofence,
            distance: context.state.distance,
            geofenceRadius: context.attributes.geofenceRadius
        )
    }
    
    private var progress: Double {
        WidgetFormatters.calculateProgress(
            distance: context.state.distance,
            geofenceRadius: context.attributes.geofenceRadius
        )
    }
    
    /// 状态颜色
    private var statusColor: Color {
        if isArrived {
            return .green  // **Validates: Requirements 3.7**
        } else if !context.state.isETAReliable {
            return .orange  // **Validates: Requirements 3.6**
        } else {
            return .cyan
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 顶部：交通图标、目的地名称、距离
            // **Validates: Requirements 3.1, 3.2, 3.4**
            HStack(spacing: 12) {
                // 交通方式图标
                Image(systemName: context.attributes.transportModeIcon)
                    .font(.title2)
                    .foregroundColor(statusColor)
                
                // 目的地名称
                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.destinationName)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    // 目的地地址
                    Text(context.attributes.destinationAddress)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // 距离或到达状态
                if isArrived {
                    VStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        Text("到达")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                } else {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(WidgetFormatters.formatCompactDistance(context.state.distance))
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(statusColor)
                        
                        if !context.state.isETAReliable {
                            HStack(spacing: 2) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                Text("不准确")
                                    .font(.caption2)
                            }
                            .foregroundColor(.orange)
                        }
                    }
                }
            }
            
            // 底部：进度条 + ETA
            // **Validates: Requirements 3.3, 3.5**
            HStack(spacing: 12) {
                // 进度条
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // 背景
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.2))
                        
                        // 进度
                        RoundedRectangle(cornerRadius: 4)
                            .fill(statusColor)
                            .frame(width: geometry.size.width * progress)
                    }
                }
                .frame(height: 8)
                
                // ETA
                if isArrived {
                    Text("即将到达")
                        .font(.caption)
                        .foregroundColor(.green)
                        .frame(minWidth: 70, alignment: .trailing)
                } else if let eta = context.state.etaMinutes {
                    Text("约 \(eta) 分钟")
                        .font(.caption)
                        .foregroundColor(context.state.isETAReliable ? .white.opacity(0.8) : .orange)
                        .frame(minWidth: 70, alignment: .trailing)
                } else {
                    Text("--")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .frame(minWidth: 70, alignment: .trailing)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .activityBackgroundTint(.black)
    }
}
