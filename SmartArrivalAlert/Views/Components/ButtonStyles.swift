import SwiftUI

// MARK: - PressableButtonStyle

/// 可按压按钮样式
/// 支持按压缩放效果和触觉反馈
/// **Validates: Requirements 3.1, 3.2**
public struct PressableButtonStyle: ButtonStyle {
    
    /// 触觉反馈风格
    let hapticStyle: HapticStyle
    
    /// 按下时的缩放比例
    let scaleEffect: CGFloat
    
    /// 是否启用触觉反馈
    let enableHaptic: Bool
    
    /// 初始化
    /// - Parameters:
    ///   - hapticStyle: 触觉反馈风格，默认为 .light
    ///   - scaleEffect: 按下时的缩放比例，默认为 0.98
    ///   - enableHaptic: 是否启用触觉反馈，默认为 true
    public init(
        hapticStyle: HapticStyle = .light,
        scaleEffect: CGFloat = AnimationConstants.Scale.pressed,
        enableHaptic: Bool = true
    ) {
        self.hapticStyle = hapticStyle
        self.scaleEffect = scaleEffect
        self.enableHaptic = enableHaptic
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleEffect : AnimationConstants.Scale.normal)
            .animation(AnimationConstants.Curve.fast, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && enableHaptic {
                    HapticManager.shared.trigger(hapticStyle)
                }
            }
    }
}

// MARK: - SecondaryButtonStyle

/// 次要按钮样式
/// 仅透明度变化，不触发触觉反馈
/// **Validates: Requirements 3.3**
public struct SecondaryButtonStyle: ButtonStyle {
    
    /// 按下时的透明度
    let pressedOpacity: Double
    
    /// 初始化
    /// - Parameter pressedOpacity: 按下时的透明度，默认为 0.7
    public init(pressedOpacity: Double = AnimationConstants.Opacity.pressed) {
        self.pressedOpacity = pressedOpacity
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? pressedOpacity : AnimationConstants.Opacity.normal)
            .animation(AnimationConstants.Curve.fast, value: configuration.isPressed)
    }
}

// MARK: - DangerButtonStyle

/// 危险操作按钮样式
/// 红色背景，warning 触觉反馈
/// **Validates: Requirements 3.2**
public struct DangerButtonStyle: ButtonStyle {
    
    /// 按下时的缩放比例
    let scaleEffect: CGFloat
    
    /// 初始化
    /// - Parameter scaleEffect: 按下时的缩放比例，默认为 0.98
    public init(scaleEffect: CGFloat = AnimationConstants.Scale.pressed) {
        self.scaleEffect = scaleEffect
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleEffect : AnimationConstants.Scale.normal)
            .animation(AnimationConstants.Curve.fast, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticManager.shared.trigger(.warning)
                }
            }
    }
}

// MARK: - SuccessButtonStyle

/// 成功操作按钮样式
/// 用于开始监控、确认到达等重要操作
/// **Validates: Requirements 1.3**
public struct SuccessButtonStyle: ButtonStyle {
    
    /// 按下时的缩放比例
    let scaleEffect: CGFloat
    
    /// 初始化
    /// - Parameter scaleEffect: 按下时的缩放比例，默认为 0.98
    public init(scaleEffect: CGFloat = AnimationConstants.Scale.pressed) {
        self.scaleEffect = scaleEffect
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleEffect : AnimationConstants.Scale.normal)
            .animation(AnimationConstants.Curve.fast, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticManager.shared.trigger(.success)
                }
            }
    }
}

// MARK: - SelectionButtonStyle

/// 选择按钮样式
/// 用于列表选择、选项切换
/// **Validates: Requirements 1.5**
public struct SelectionButtonStyle: ButtonStyle {
    
    /// 按下时的缩放比例
    let scaleEffect: CGFloat
    
    /// 初始化
    /// - Parameter scaleEffect: 按下时的缩放比例，默认为 0.98
    public init(scaleEffect: CGFloat = AnimationConstants.Scale.pressed) {
        self.scaleEffect = scaleEffect
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleEffect : AnimationConstants.Scale.normal)
            .animation(AnimationConstants.Curve.fast, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    HapticManager.shared.trigger(.selection)
                }
            }
    }
}

// MARK: - Button Style Extensions

extension ButtonStyle where Self == PressableButtonStyle {
    /// 主要按钮样式（蓝色背景）
    public static var pressable: PressableButtonStyle {
        PressableButtonStyle()
    }
    
    /// 自定义触觉反馈的按钮样式
    public static func pressable(haptic: HapticStyle) -> PressableButtonStyle {
        PressableButtonStyle(hapticStyle: haptic)
    }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    /// 次要按钮样式
    public static var secondary: SecondaryButtonStyle {
        SecondaryButtonStyle()
    }
}

extension ButtonStyle where Self == DangerButtonStyle {
    /// 危险操作按钮样式
    public static var danger: DangerButtonStyle {
        DangerButtonStyle()
    }
}

extension ButtonStyle where Self == SuccessButtonStyle {
    /// 成功操作按钮样式
    public static var success: SuccessButtonStyle {
        SuccessButtonStyle()
    }
}

extension ButtonStyle where Self == SelectionButtonStyle {
    /// 选择按钮样式
    public static var selection: SelectionButtonStyle {
        SelectionButtonStyle()
    }
}


// MARK: - HapticSlider

/// 带触觉反馈的滑杆
/// 在值变化时提供轻柔的触觉反馈
public struct HapticSlider<V: BinaryFloatingPoint>: View where V.Stride: BinaryFloatingPoint {
    
    @Binding var value: V
    let range: ClosedRange<V>
    let step: V.Stride
    let tint: Color
    
    /// 上一次触发反馈时的值（用于节流）
    @State private var lastHapticValue: V
    
    /// 初始化
    /// - Parameters:
    ///   - value: 绑定的值
    ///   - range: 值范围
    ///   - step: 步进值
    ///   - tint: 滑杆颜色
    public init(
        value: Binding<V>,
        in range: ClosedRange<V>,
        step: V.Stride = 1,
        tint: Color = .blue
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.tint = tint
        self._lastHapticValue = State(initialValue: value.wrappedValue)
    }
    
    public var body: some View {
        Slider(value: $value, in: range, step: step)
            .tint(tint)
            .onChange(of: value) { oldValue, newValue in
                // 只在值实际变化时触发反馈（避免过于频繁）
                let threshold = V(step)
                if abs(newValue - lastHapticValue) >= threshold {
                    HapticManager.shared.trigger(.light)
                    lastHapticValue = newValue
                }
            }
    }
}

// MARK: - HapticSlider for Int

/// 带触觉反馈的整数滑杆
public struct HapticIntSlider: View {
    
    @Binding var value: Int
    let range: ClosedRange<Double>
    let step: Double
    let tint: Color
    
    /// 上一次触发反馈时的值
    @State private var lastHapticValue: Int
    
    /// 初始化
    /// - Parameters:
    ///   - value: 绑定的整数值
    ///   - range: 值范围
    ///   - step: 步进值
    ///   - tint: 滑杆颜色
    public init(
        value: Binding<Int>,
        in range: ClosedRange<Double>,
        step: Double = 1,
        tint: Color = .blue
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.tint = tint
        self._lastHapticValue = State(initialValue: value.wrappedValue)
    }
    
    public var body: some View {
        Slider(
            value: Binding(
                get: { Double(value) },
                set: { value = Int($0) }
            ),
            in: range,
            step: step
        )
        .tint(tint)
        .onChange(of: value) { oldValue, newValue in
            // 每次整数值变化时触发轻柔反馈
            if newValue != lastHapticValue {
                HapticManager.shared.trigger(.light)
                lastHapticValue = newValue
            }
        }
    }
}
