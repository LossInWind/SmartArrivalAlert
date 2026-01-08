import SwiftUI
import WidgetKit

#if canImport(ActivityKit)
import ActivityKit

/// 锁屏视图
/// 在锁屏上显示行程进度信息
@available(iOS 16.1, *)
struct TripLockScreenView: View {
    let context: ActivityViewContext<TripActivityAttributes>
    
    /// 是否已到达
    private var isArrived: Bool {
        context.state.isInsideGeofence
    }
    
    /// 进度值
    private var progressValue: Double {
        LiveActivityFormatters.calculateProgress(
            distance: context.state.distance,
            geofenceRadius: context.attributes.geofenceRadius
        )
    }
    
    /// 格式化的距离
    private var formattedDistance: String {
        LiveActivityFormatters.formatDistance(context.state.distance)
    }
    
    /// 格式化的 ETA
    private var formattedETA: String {
        LiveActivityFormatters.formatETA(context.state.etaMinutes)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 顶部：目的地信息
            headerSection
            
            // 中部：距离和 ETA
            statsSection
            
            // 底部：进度条
            progressSection
        }
        .padding(16)
        .activityBackgroundTint(isArrived ? Color.green.opacity(0.2) : Color.blue.opacity(0.1))
        .activitySystemActionForegroundColor(isArrived ? .green : .blue)
    }
    
    // MARK: - Header Section
    
    /// 顶部区域：目的地名称和交通方式
    private var headerSection: some View {
        HStack(spacing: 8) {
            // 交通方式图标
            Image(systemName: context.attributes.transportModeIcon)
                .font(.title3)
                .foregroundStyle(isArrived ? .green : .blue)
            
            // 目的地名称
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
            
            // 到达状态指示
            if isArrived {
                arrivedBadge
            }
        }
    }
    
    /// 到达徽章
    private var arrivedBadge: some View {
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
    
    // MARK: - Stats Section
    
    /// 中部区域：距离和 ETA 统计
    private var statsSection: some View {
        HStack(spacing: 0) {
            // 距离
            statItem(
                value: formattedDistance,
                label: "距离",
                icon: "location.fill",
                color: isArrived ? .green : .blue
            )
            
            Spacer()
            
            // 分隔线
            Rectangle()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 1, height: 40)
            
            Spacer()
            
            // ETA
            HStack(spacing: 4) {
                statItem(
                    value: context.state.etaMinutes.map { "\($0)" } ?? "--",
                    label: "分钟",
                    icon: "clock.fill",
                    color: isArrived ? .green : (context.state.isETAReliable ? .primary : .orange)
                )
                
                // ETA 不可靠警告
                if !context.state.isETAReliable && !isArrived {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
    
    /// 统计项
    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .center, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color.opacity(0.7))
                
                Text(value)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Progress Section
    
    /// 底部区域：进度条
    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            // 进度条
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // 背景
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                    
                    // 进度
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isArrived ? Color.green : Color.blue)
                        .frame(width: geometry.size.width * progressValue)
                }
            }
            .frame(height: 8)
            
            // 进度说明
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
}

// MARK: - Preview

@available(iOS 16.1, *)
struct TripLockScreenView_Previews: PreviewProvider {
    static var previews: some View {
        // 预览需要在 Widget 预览中查看
        Text("请在 TripActivityWidget 预览中查看锁屏视图")
    }
}
#endif
