import SwiftUI
import WidgetKit

#if canImport(ActivityKit)
import ActivityKit

// MARK: - Compact Views

/// 紧凑视图 - 左侧（交通方式图标）
@available(iOS 16.1, *)
struct CompactLeadingView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    
    /// 是否已到达
    private var isArrived: Bool {
        context.state.isInsideGeofence
    }
    
    var body: some View {
        Image(systemName: context.attributes.transportModeIcon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isArrived ? .green : .blue)
    }
}

/// 紧凑视图 - 右侧（距离或到达状态）
@available(iOS 16.1, *)
struct CompactTrailingView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    
    /// 是否已到达
    private var isArrived: Bool {
        context.state.isInsideGeofence
    }
    
    /// 格式化的紧凑距离
    private var compactDistance: String {
        LiveActivityFormatters.formatCompactDistance(context.state.distance)
    }
    
    var body: some View {
        if isArrived {
            // 已到达：显示勾选图标
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.green)
        } else {
            // 未到达：显示距离
            Text(compactDistance)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
    }
}

// MARK: - Minimal View

/// 最小视图（当有多个 Live Activity 时显示）
@available(iOS 16.1, *)
struct MinimalView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    
    /// 是否已到达
    private var isArrived: Bool {
        context.state.isInsideGeofence
    }
    
    var body: some View {
        ZStack {
            if isArrived {
                // 已到达：显示勾选图标
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
            } else {
                // 未到达：显示交通方式图标
                Image(systemName: context.attributes.transportModeIcon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.blue)
            }
        }
    }
}

// MARK: - Expanded Views

/// 展开视图 - 左侧（交通方式）
@available(iOS 16.1, *)
struct ExpandedLeadingView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    
    /// 是否已到达
    private var isArrived: Bool {
        context.state.isInsideGeofence
    }
    
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

/// 展开视图 - 右侧（ETA）
@available(iOS 16.1, *)
struct ExpandedTrailingView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    
    /// 是否已到达
    private var isArrived: Bool {
        context.state.isInsideGeofence
    }
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if isArrived {
                // 已到达
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                
                Text("已到达")
                    .font(.caption2)
                    .foregroundStyle(.green)
            } else if let eta = context.state.etaMinutes {
                // 显示 ETA
                HStack(spacing: 2) {
                    Text("\(eta)")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundStyle(context.state.isETAReliable ? .primary : .orange)
                    
                    // ETA 不可靠警告
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
                // 无 ETA
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

/// 展开视图 - 中间（目的地名称）
@available(iOS 16.1, *)
struct ExpandedCenterView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    
    /// 是否已到达
    private var isArrived: Bool {
        context.state.isInsideGeofence
    }
    
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

/// 展开视图 - 底部（距离和进度）
@available(iOS 16.1, *)
struct ExpandedBottomView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    
    /// 是否已到达
    private var isArrived: Bool {
        context.state.isInsideGeofence
    }
    
    /// 格式化的距离
    private var formattedDistance: String {
        LiveActivityFormatters.formatDistance(context.state.distance)
    }
    
    /// 进度值
    private var progressValue: Double {
        LiveActivityFormatters.calculateProgress(
            distance: context.state.distance,
            geofenceRadius: context.attributes.geofenceRadius
        )
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.secondary.opacity(0.3))
                    
                    // 进度
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isArrived ? Color.green : Color.blue)
                        .frame(width: geometry.size.width * progressValue)
                }
            }
            .frame(height: 6)
            
            // 距离信息
            HStack {
                // 当前距离
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundStyle(isArrived ? .green : .blue)
                    
                    Text(formattedDistance)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(isArrived ? .green : .primary)
                }
                
                Spacer()
                
                // 围栏半径
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

// MARK: - Preview Helpers

@available(iOS 16.1, *)
struct DynamicIslandViews_Previews: PreviewProvider {
    static var previews: some View {
        // 预览需要在 Widget 预览中查看
        Text("请在 TripActivityWidget 预览中查看灵动岛视图")
    }
}
#endif
