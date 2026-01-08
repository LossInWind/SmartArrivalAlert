import SwiftUI

/// 支持滑动的交通方式选择器
/// 支持左右滑动切换交通方式，同时保留点击选择功能
/// **Validates: Requirements 5.1, 5.2, 5.3, 5.4**
struct SwipeableTransportModeSelector: View {
    @Binding var selectedMode: TransportMode
    
    /// 交通方式变化时的回调（可选）
    var onModeChange: ((TransportMode) -> Void)?
    
    /// 滑动偏移量
    @State private var dragOffset: CGFloat = 0
    
    /// 滑动阈值（超过此值触发切换）
    private let swipeThreshold: CGFloat = 50
    
    /// 是否通过滑动触发的选择
    @State private var isSwipeSelection: Bool = false
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TransportMode.allCases, id: \.self) { mode in
                Button {
                    selectMode(mode, viaSwipe: false)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 20))
                        Text(mode.displayName)
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(selectedMode == mode ? Color.blue.opacity(0.1) : Color.clear)
                    .foregroundStyle(selectedMode == mode ? .blue : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    handleSwipeEnd(translation: value.translation.width)
                }
        )
    }
    
    /// 处理滑动结束
    /// **Validates: Requirements 5.1, 5.4**
    private func handleSwipeEnd(translation: CGFloat) {
        defer { dragOffset = 0 }
        
        // 判断滑动方向和是否超过阈值
        if translation < -swipeThreshold {
            // 向左滑动 = 选择后一个（视觉上向左滑动内容，选择右边的选项）
            let newMode = TransportModeSwipeHandler.nextMode(from: selectedMode, direction: .right)
            if newMode != selectedMode {
                selectMode(newMode, viaSwipe: true)
            }
        } else if translation > swipeThreshold {
            // 向右滑动 = 选择前一个（视觉上向右滑动内容，选择左边的选项）
            let newMode = TransportModeSwipeHandler.nextMode(from: selectedMode, direction: .left)
            if newMode != selectedMode {
                selectMode(newMode, viaSwipe: true)
            }
        }
        // 滑动距离不足时，弹性动画回弹（由 SwiftUI 自动处理）
    }
    
    /// 选择交通方式
    /// - Parameters:
    ///   - mode: 目标交通方式
    ///   - viaSwipe: 是否通过滑动触发
    /// **Validates: Requirements 5.1, 5.2**
    private func selectMode(_ mode: TransportMode, viaSwipe: Bool) {
        guard mode != selectedMode else { return }
        
        withAnimation(AnimationConstants.Curve.transportSelector) {
            selectedMode = mode
        }
        
        // 触发触觉反馈
        // 滑动切换使用 .selection 风格，点击切换使用 .light 风格
        if viaSwipe {
            HapticManager.shared.trigger(.selection)
        } else {
            HapticManager.shared.trigger(.light)
        }
        
        // 调用回调
        onModeChange?(mode)
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedMode: TransportMode = .walking
        
        var body: some View {
            VStack(spacing: 20) {
                Text("选中: \(selectedMode.displayName)")
                    .font(.headline)
                
                SwipeableTransportModeSelector(selectedMode: $selectedMode) { newMode in
                    print("交通方式变更为: \(newMode.displayName)")
                }
                .padding()
                
                Text("左右滑动或点击切换交通方式")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
    }
    
    return PreviewWrapper()
}
