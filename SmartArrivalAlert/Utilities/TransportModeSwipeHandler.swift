import Foundation

/// 交通方式滑动处理器
/// 处理左右滑动手势切换交通方式的逻辑
struct TransportModeSwipeHandler {
    
    /// 滑动方向
    enum SwipeDirection {
        case left   // 向左滑动 = 选择前一个
        case right  // 向右滑动 = 选择后一个
    }
    
    /// 根据滑动方向获取下一个交通方式
    /// - Parameters:
    ///   - currentMode: 当前交通方式
    ///   - direction: 滑动方向 (.left 或 .right)
    /// - Returns: 新的交通方式，如果到达边界则返回当前方式（不循环）
    static func nextMode(
        from currentMode: TransportMode,
        direction: SwipeDirection
    ) -> TransportMode {
        let allModes = TransportMode.allCases
        guard let currentIndex = allModes.firstIndex(of: currentMode) else {
            return currentMode
        }
        
        switch direction {
        case .left:
            // 向左滑动 = 选择前一个
            let newIndex = currentIndex - 1
            // 边界检查：如果已经是第一个，返回当前模式
            return newIndex >= 0 ? allModes[newIndex] : currentMode
            
        case .right:
            // 向右滑动 = 选择后一个
            let newIndex = currentIndex + 1
            // 边界检查：如果已经是最后一个，返回当前模式
            return newIndex < allModes.count ? allModes[newIndex] : currentMode
        }
    }
    
    /// 检查是否可以向指定方向滑动
    /// - Parameters:
    ///   - currentMode: 当前交通方式
    ///   - direction: 滑动方向
    /// - Returns: 是否可以滑动（未到达边界）
    static func canSwipe(
        from currentMode: TransportMode,
        direction: SwipeDirection
    ) -> Bool {
        let allModes = TransportMode.allCases
        guard let currentIndex = allModes.firstIndex(of: currentMode) else {
            return false
        }
        
        switch direction {
        case .left:
            return currentIndex > 0
        case .right:
            return currentIndex < allModes.count - 1
        }
    }
    
    /// 获取当前模式的索引
    /// - Parameter mode: 交通方式
    /// - Returns: 索引，如果未找到返回 nil
    static func index(of mode: TransportMode) -> Int? {
        return TransportMode.allCases.firstIndex(of: mode)
    }
    
    /// 获取交通方式总数
    static var totalModes: Int {
        return TransportMode.allCases.count
    }
}
