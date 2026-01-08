import SwiftUI

// MARK: - AnimationConstants

/// 统一的动画常量定义
/// 确保全应用的动画体验一致、流畅、克制
/// **Validates: Requirements 2.1, 2.2**
public enum AnimationConstants {
    
    // MARK: - Duration
    
    /// 动画时长
    /// **Validates: Requirements 2.1**
    public enum Duration {
        /// 快速动画 - 按钮状态变化
        public static let fast: Double = 0.15
        
        /// 标准动画 - 列表选择、一般过渡
        public static let standard: Double = 0.25
        
        /// 慢速动画 - 页面过渡
        public static let slow: Double = 0.35
        
        /// 地图动画 - 相机移动
        public static let map: Double = 0.3
        
        /// 按钮按下状态
        public static let buttonPress: Double = 0.1
        
        /// 列表项选中
        public static let listSelection: Double = 0.2
    }
    
    // MARK: - Curve
    
    /// 动画曲线
    /// **Validates: Requirements 2.2**
    public enum Curve {
        /// 标准动画 - 大多数过渡
        public static let standard = Animation.easeInOut(duration: Duration.standard)
        
        /// 快速动画 - 按钮状态
        public static let fast = Animation.easeInOut(duration: Duration.fast)
        
        /// 慢速动画 - 页面过渡
        public static let slow = Animation.easeInOut(duration: Duration.slow)
        
        /// 地图动画 - 相机移动
        public static let map = Animation.easeInOut(duration: Duration.map)
        
        /// 按钮按下动画
        public static let buttonPress = Animation.easeInOut(duration: Duration.buttonPress)
        
        /// 列表选择动画
        public static let listSelection = Animation.easeInOut(duration: Duration.listSelection)
        
        /// 弹性动画 - 弹性效果
        public static let spring = Animation.spring(response: 0.3, dampingFraction: 0.7)
        
        /// 弹跳动画 - 更明显的弹性
        public static let bouncy = Animation.spring(response: 0.4, dampingFraction: 0.6)
        
        /// 交通方式选择器动画
        public static let transportSelector = Animation.spring(response: 0.2, dampingFraction: 0.8)
    }
    
    // MARK: - Scale
    
    /// 按钮缩放效果
    public enum Scale {
        /// 按下状态缩放
        public static let pressed: CGFloat = 0.98
        
        /// 正常状态缩放
        public static let normal: CGFloat = 1.0
    }
    
    // MARK: - Opacity
    
    /// 透明度效果
    public enum Opacity {
        /// 按下状态透明度
        public static let pressed: Double = 0.7
        
        /// 正常状态透明度
        public static let normal: Double = 1.0
        
        /// 禁用状态透明度
        public static let disabled: Double = 0.5
    }
}

// MARK: - Animation Extensions

extension Animation {
    /// 标准 UI 动画
    public static var uiStandard: Animation {
        AnimationConstants.Curve.standard
    }
    
    /// 快速 UI 动画
    public static var uiFast: Animation {
        AnimationConstants.Curve.fast
    }
    
    /// 地图动画
    public static var uiMap: Animation {
        AnimationConstants.Curve.map
    }
    
    /// 弹性动画
    public static var uiSpring: Animation {
        AnimationConstants.Curve.spring
    }
}
