import SwiftUI
import WidgetKit

#if canImport(ActivityKit)
import ActivityKit

/// 行程活动 Widget
/// 用于在灵动岛和锁屏上显示行程进度
@available(iOS 16.1, *)
struct TripActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            // 锁屏视图
            TripLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // 展开视图 - 左侧：交通方式
                DynamicIslandExpandedRegion(.leading) {
                    ExpandedLeadingView(context: context)
                }
                
                // 展开视图 - 右侧：ETA
                DynamicIslandExpandedRegion(.trailing) {
                    ExpandedTrailingView(context: context)
                }
                
                // 展开视图 - 中间：目的地名称
                DynamicIslandExpandedRegion(.center) {
                    ExpandedCenterView(context: context)
                }
                
                // 展开视图 - 底部：距离和状态
                DynamicIslandExpandedRegion(.bottom) {
                    ExpandedBottomView(context: context)
                }
            } compactLeading: {
                // 紧凑视图 - 左侧
                CompactLeadingView(context: context)
            } compactTrailing: {
                // 紧凑视图 - 右侧
                CompactTrailingView(context: context)
            } minimal: {
                // 最小视图
                MinimalView(context: context)
            }
        }
    }
}

// MARK: - Preview Provider

@available(iOS 16.1, *)
struct TripActivityWidget_Previews: PreviewProvider {
    static let attributes = TripActivityAttributes(
        destinationName: "北京南站",
        destinationAddress: "北京市丰台区",
        geofenceRadius: 500,
        transportModeIcon: "tram.fill",
        transportModeName: "地铁"
    )
    
    static let normalState = TripActivityAttributes.ContentState(
        distance: 2500,
        etaMinutes: 8,
        isETAReliable: true,
        isInsideGeofence: false
    )
    
    static let arrivedState = TripActivityAttributes.ContentState(
        distance: 200,
        etaMinutes: 1,
        isETAReliable: true,
        isInsideGeofence: true
    )
    
    static let unreliableState = TripActivityAttributes.ContentState(
        distance: 5000,
        etaMinutes: 15,
        isETAReliable: false,
        isInsideGeofence: false
    )
    
    static var previews: some View {
        Group {
            // 锁屏视图预览 - 正常状态
            attributes
                .previewContext(normalState, viewKind: .content)
                .previewDisplayName("锁屏 - 正常")
            
            // 锁屏视图预览 - 已到达
            attributes
                .previewContext(arrivedState, viewKind: .content)
                .previewDisplayName("锁屏 - 已到达")
            
            // 锁屏视图预览 - ETA 不可靠
            attributes
                .previewContext(unreliableState, viewKind: .content)
                .previewDisplayName("锁屏 - ETA不可靠")
            
            // 灵动岛紧凑视图预览
            attributes
                .previewContext(normalState, viewKind: .dynamicIsland(.compact))
                .previewDisplayName("灵动岛 - 紧凑")
            
            // 灵动岛展开视图预览
            attributes
                .previewContext(normalState, viewKind: .dynamicIsland(.expanded))
                .previewDisplayName("灵动岛 - 展开")
            
            // 灵动岛最小视图预览
            attributes
                .previewContext(normalState, viewKind: .dynamicIsland(.minimal))
                .previewDisplayName("灵动岛 - 最小")
        }
    }
}
#endif
