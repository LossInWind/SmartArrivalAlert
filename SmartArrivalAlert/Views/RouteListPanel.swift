import SwiftUI

// MARK: - Route Card

/// 单个路线卡片
/// 显示路线名称、距离、时间，支持选中状态高亮
struct RouteCard: View {
    let route: RouteOption
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // 路线名称
                HStack(spacing: 4) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    Text(route.name)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? .blue : .primary)
                        .lineLimit(1)
                }
                
                // 距离和时间
                HStack(spacing: 12) {
                    // 距离
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.left.and.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(route.distanceText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // 时间
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(route.timeText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                // 来源标识（仅直线距离显示）
                if route.source == .directLine {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text("直线距离")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .padding(12)
            .frame(minWidth: 140)
            .background(isSelected ? Color.blue.opacity(0.1) : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
            .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Route List Panel

/// 底部路线列表面板
/// 水平滚动显示所有可用路线
struct RouteListPanel: View {
    let routes: [RouteOption]
    let selectedRouteId: String?
    let isLoading: Bool
    let onSelectRoute: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题
            HStack {
                Text("可选路线")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
                
                Text("\(routes.count) 条")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            
            // 路线列表
            if routes.isEmpty && !isLoading {
                emptyState
            } else {
                routeScrollView
            }
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    /// 空状态
    private var emptyState: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "map.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("暂无可用路线")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 20)
            Spacer()
        }
    }
    
    /// 路线滚动视图
    private var routeScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(routes) { route in
                    RouteCard(
                        route: route,
                        isSelected: route.id == selectedRouteId,
                        onTap: { onSelectRoute(route.id) }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Compact Route Info

/// 紧凑路线信息显示（用于目的地卡片）
struct CompactRouteInfo: View {
    let route: RouteOption
    let isLoading: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // 距离
            HStack(spacing: 4) {
                Image(systemName: "arrow.left.and.right")
                    .font(.caption)
                    .foregroundStyle(.blue)
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Text(route.distanceText)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
            
            // 时间
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundStyle(.blue)
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                } else {
                    Text(route.timeText)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                }
            }
            
            // 可靠性警告
            if route.source == .directLine {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }
}

// MARK: - Preview

#Preview("Route Card") {
    VStack(spacing: 16) {
        RouteCard(
            route: RouteOption(
                id: "1",
                name: "经由长安街",
                distance: 5200,
                expectedTravelTime: 1800,
                polyline: nil,
                isSelected: true,
                source: .mapKit
            ),
            isSelected: true,
            onTap: {}
        )
        
        RouteCard(
            route: RouteOption(
                id: "2",
                name: "经由二环路",
                distance: 6800,
                expectedTravelTime: 2400,
                polyline: nil,
                isSelected: false,
                source: .mapKit
            ),
            isSelected: false,
            onTap: {}
        )
        
        RouteCard(
            route: RouteOption(
                id: "3",
                name: "直线距离",
                distance: 4500,
                expectedTravelTime: 1200,
                polyline: nil,
                isSelected: false,
                source: .directLine
            ),
            isSelected: false,
            onTap: {}
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Route List Panel") {
    RouteListPanel(
        routes: [
            RouteOption(
                id: "1",
                name: "经由长安街",
                distance: 5200,
                expectedTravelTime: 1800,
                polyline: nil,
                isSelected: true,
                source: .mapKit
            ),
            RouteOption(
                id: "2",
                name: "经由二环路",
                distance: 6800,
                expectedTravelTime: 2400,
                polyline: nil,
                isSelected: false,
                source: .mapKit
            ),
            RouteOption(
                id: "3",
                name: "经由三环路",
                distance: 7500,
                expectedTravelTime: 2700,
                polyline: nil,
                isSelected: false,
                source: .mapKit
            )
        ],
        selectedRouteId: "1",
        isLoading: false,
        onSelectRoute: { _ in }
    )
}
