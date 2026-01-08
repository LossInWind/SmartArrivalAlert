import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - HapticStyle

/// 触觉反馈风格
/// **Validates: Requirements 1.1**
public enum HapticStyle: String, CaseIterable {
    case light          // 轻触反馈 - 普通按钮点击
    case medium         // 中等反馈 - 重要操作
    case heavy          // 重度反馈 - 强调操作
    case selection      // 选择反馈 - 列表选择、滑动切换
    case success        // 成功反馈 - 操作完成
    case warning        // 警告反馈 - 删除、取消
    case error          // 错误反馈 - 操作失败
}

// MARK: - HapticManagerProtocol

/// 触觉反馈管理器协议
public protocol HapticManagerProtocol {
    /// 是否启用触觉反馈
    var isEnabled: Bool { get }
    
    /// 触发触觉反馈
    /// - Parameter style: 反馈风格
    func trigger(_ style: HapticStyle)
    
    /// 准备触觉反馈生成器（减少延迟）
    /// - Parameter style: 反馈风格
    func prepare(_ style: HapticStyle)
}

// MARK: - HapticManager

/// 统一的触觉反馈管理器
/// 负责协调全应用的震动反馈，确保一致且克制的用户体验
/// **Validates: Requirements 1.1, 1.6, 1.7**
public final class HapticManager: HapticManagerProtocol {
    
    // MARK: - Singleton
    
    public static let shared = HapticManager()
    
    // MARK: - Properties
    
    #if os(iOS)
    /// Impact 反馈生成器缓存
    private var impactGenerators: [UIImpactFeedbackGenerator.FeedbackStyle: UIImpactFeedbackGenerator] = [:]
    
    /// 通知反馈生成器
    private lazy var notificationGenerator: UINotificationFeedbackGenerator = {
        let generator = UINotificationFeedbackGenerator()
        return generator
    }()
    
    /// 选择反馈生成器
    private lazy var selectionGenerator: UISelectionFeedbackGenerator = {
        let generator = UISelectionFeedbackGenerator()
        return generator
    }()
    #endif
    
    /// 是否启用触觉反馈
    /// **Validates: Requirements 1.6, 8.2**
    public var isEnabled: Bool {
        return SettingsStore.shared.enableHapticFeedback
    }
    
    // MARK: - Initialization
    
    private init() {
        #if os(iOS)
        // 预创建常用的 impact 生成器
        impactGenerators[.light] = UIImpactFeedbackGenerator(style: .light)
        impactGenerators[.medium] = UIImpactFeedbackGenerator(style: .medium)
        impactGenerators[.heavy] = UIImpactFeedbackGenerator(style: .heavy)
        #endif
    }
    
    // MARK: - Public Methods
    
    /// 触发触觉反馈
    /// **Validates: Requirements 1.2, 1.3, 1.4, 1.5, 1.6**
    public func trigger(_ style: HapticStyle) {
        // 如果用户禁用了触觉反馈，直接返回
        guard isEnabled else { return }
        
        #if os(iOS)
        switch style {
        case .light:
            // 轻触反馈 - 普通按钮点击
            impactGenerators[.light]?.impactOccurred()
            impactGenerators[.light]?.prepare()
            
        case .medium:
            // 中等反馈 - 重要操作
            impactGenerators[.medium]?.impactOccurred()
            impactGenerators[.medium]?.prepare()
            
        case .heavy:
            // 重度反馈 - 强调操作
            impactGenerators[.heavy]?.impactOccurred()
            impactGenerators[.heavy]?.prepare()
            
        case .selection:
            // 选择反馈 - 列表选择、滑动切换
            selectionGenerator.selectionChanged()
            selectionGenerator.prepare()
            
        case .success:
            // 成功反馈 - 操作完成
            notificationGenerator.notificationOccurred(.success)
            notificationGenerator.prepare()
            
        case .warning:
            // 警告反馈 - 删除、取消
            notificationGenerator.notificationOccurred(.warning)
            notificationGenerator.prepare()
            
        case .error:
            // 错误反馈 - 操作失败
            notificationGenerator.notificationOccurred(.error)
            notificationGenerator.prepare()
        }
        #endif
    }
    
    /// 准备触觉反馈生成器（减少延迟）
    /// **Validates: Requirements 1.7**
    public func prepare(_ style: HapticStyle) {
        guard isEnabled else { return }
        
        #if os(iOS)
        switch style {
        case .light:
            impactGenerators[.light]?.prepare()
        case .medium:
            impactGenerators[.medium]?.prepare()
        case .heavy:
            impactGenerators[.heavy]?.prepare()
        case .selection:
            selectionGenerator.prepare()
        case .success, .warning, .error:
            notificationGenerator.prepare()
        }
        #endif
    }
    
    /// 触发强制触觉反馈（忽略用户设置，用于到站提醒等关键场景）
    /// **Validates: Requirements 8.2** - 到站提醒除外
    public func triggerForced(_ style: HapticStyle) {
        #if os(iOS)
        switch style {
        case .light:
            impactGenerators[.light]?.impactOccurred()
        case .medium:
            impactGenerators[.medium]?.impactOccurred()
        case .heavy:
            impactGenerators[.heavy]?.impactOccurred()
        case .selection:
            selectionGenerator.selectionChanged()
        case .success:
            notificationGenerator.notificationOccurred(.success)
        case .warning:
            notificationGenerator.notificationOccurred(.warning)
        case .error:
            notificationGenerator.notificationOccurred(.error)
        }
        #endif
    }
}
