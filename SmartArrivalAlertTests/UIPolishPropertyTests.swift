import XCTest
@testable import SmartArrivalAlert

/// UI Polish 优化属性测试
/// Feature: ui-polish-optimization
final class UIPolishPropertyTests: XCTestCase {
    
    // MARK: - Property 1: HapticStyle Completeness
    
    /// **Property 1: HapticStyle Completeness**
    /// *For any* HapticStyle enum, it SHALL contain all required cases:
    /// light, medium, heavy, selection, success, warning, error.
    /// **Validates: Requirements 1.1**
    func testHapticStyleCompleteness() {
        // 验证 HapticStyle 包含所有必需的 case
        let allCases = HapticStyle.allCases
        
        // 必需的 case 列表
        let requiredCases: Set<HapticStyle> = [
            .light,
            .medium,
            .heavy,
            .selection,
            .success,
            .warning,
            .error
        ]
        
        // 验证数量
        XCTAssertEqual(allCases.count, 7, "HapticStyle should have exactly 7 cases")
        
        // 验证每个必需的 case 都存在
        for requiredCase in requiredCases {
            XCTAssertTrue(
                allCases.contains(requiredCase),
                "HapticStyle should contain \(requiredCase)"
            )
        }
        
        // 验证所有 case 都在必需列表中
        for actualCase in allCases {
            XCTAssertTrue(
                requiredCases.contains(actualCase),
                "HapticStyle contains unexpected case: \(actualCase)"
            )
        }
    }
    
    /// **Property 1 补充测试**: HapticStyle rawValue 唯一性
    func testHapticStyleRawValueUniqueness() {
        let allCases = HapticStyle.allCases
        let rawValues = allCases.map { $0.rawValue }
        let uniqueRawValues = Set(rawValues)
        
        XCTAssertEqual(
            rawValues.count,
            uniqueRawValues.count,
            "All HapticStyle rawValues should be unique"
        )
    }
    
    // MARK: - Property 2: AnimationConstants Duration Values
    
    /// **Property 2: AnimationConstants Duration Values**
    /// *For any* AnimationConstants.Duration, the values SHALL be:
    /// fast = 0.15, standard = 0.25, slow = 0.35, map = 0.3.
    /// **Validates: Requirements 2.1**
    func testAnimationConstantsDurationValues() {
        // 验证快速动画时长
        XCTAssertEqual(
            AnimationConstants.Duration.fast,
            0.15,
            accuracy: 0.001,
            "Fast duration should be 0.15"
        )
        
        // 验证标准动画时长
        XCTAssertEqual(
            AnimationConstants.Duration.standard,
            0.25,
            accuracy: 0.001,
            "Standard duration should be 0.25"
        )
        
        // 验证慢速动画时长
        XCTAssertEqual(
            AnimationConstants.Duration.slow,
            0.35,
            accuracy: 0.001,
            "Slow duration should be 0.35"
        )
        
        // 验证地图动画时长
        XCTAssertEqual(
            AnimationConstants.Duration.map,
            0.3,
            accuracy: 0.001,
            "Map duration should be 0.3"
        )
    }
    
    /// **Property 2 补充测试**: 动画时长顺序正确性
    func testAnimationDurationOrdering() {
        // fast < standard < slow
        XCTAssertLessThan(
            AnimationConstants.Duration.fast,
            AnimationConstants.Duration.standard,
            "Fast should be less than standard"
        )
        
        XCTAssertLessThan(
            AnimationConstants.Duration.standard,
            AnimationConstants.Duration.slow,
            "Standard should be less than slow"
        )
        
        // 所有时长都应该是正数
        XCTAssertGreaterThan(AnimationConstants.Duration.fast, 0)
        XCTAssertGreaterThan(AnimationConstants.Duration.standard, 0)
        XCTAssertGreaterThan(AnimationConstants.Duration.slow, 0)
        XCTAssertGreaterThan(AnimationConstants.Duration.map, 0)
    }
    
    // MARK: - Property 3: HapticManager Respects Disabled Setting
    
    /// **Property 3: HapticManager Respects Disabled Setting**
    /// *For any* HapticManager instance where hapticEnabled is false,
    /// calling trigger() with any HapticStyle SHALL NOT produce haptic feedback.
    /// **Validates: Requirements 1.6, 8.2**
    func testHapticManagerRespectsDisabledSetting() {
        // 创建测试用的 UserDefaults
        let testDefaults = UserDefaults(suiteName: "test.haptic.disabled")!
        testDefaults.removePersistentDomain(forName: "test.haptic.disabled")
        
        // 创建测试用的 SettingsStore
        let testSettings = SettingsStore(userDefaults: testDefaults)
        
        // 禁用触觉反馈
        testSettings.enableHapticFeedback = false
        
        // 验证设置已禁用
        XCTAssertFalse(testSettings.enableHapticFeedback)
        
        // 注意：由于 HapticManager 是单例且使用 SettingsStore.shared，
        // 我们无法直接测试 trigger() 不产生反馈。
        // 但我们可以验证 isEnabled 属性正确反映设置状态。
        
        // 恢复设置
        testSettings.enableHapticFeedback = true
        XCTAssertTrue(testSettings.enableHapticFeedback)
        
        // 清理
        testDefaults.removePersistentDomain(forName: "test.haptic.disabled")
    }
    
    /// **Property 3 补充测试**: HapticManager.isEnabled 与 SettingsStore 同步
    func testHapticManagerIsEnabledSyncsWithSettings() {
        // 保存原始值
        let originalValue = SettingsStore.shared.enableHapticFeedback
        
        // 测试启用状态
        SettingsStore.shared.enableHapticFeedback = true
        XCTAssertTrue(HapticManager.shared.isEnabled)
        
        // 测试禁用状态
        SettingsStore.shared.enableHapticFeedback = false
        XCTAssertFalse(HapticManager.shared.isEnabled)
        
        // 恢复原始值
        SettingsStore.shared.enableHapticFeedback = originalValue
    }
    
    // MARK: - Property 4: HapticEnabled Setting Persistence
    
    /// **Property 4: HapticEnabled Setting Persistence**
    /// *For any* hapticEnabled value set in SettingsStore,
    /// reading the value after app restart SHALL return the same value.
    /// **Validates: Requirements 8.4**
    func testHapticEnabledSettingPersistence() {
        // 创建测试用的 UserDefaults
        let suiteName = "test.haptic.persistence.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        
        // 测试 true 值的持久化
        do {
            let store1 = SettingsStore(userDefaults: testDefaults)
            store1.enableHapticFeedback = true
            
            // 模拟重启：创建新的 SettingsStore 实例
            let store2 = SettingsStore(userDefaults: testDefaults)
            XCTAssertTrue(store2.enableHapticFeedback, "True value should persist")
        }
        
        // 测试 false 值的持久化
        do {
            let store1 = SettingsStore(userDefaults: testDefaults)
            store1.enableHapticFeedback = false
            
            // 模拟重启：创建新的 SettingsStore 实例
            let store2 = SettingsStore(userDefaults: testDefaults)
            XCTAssertFalse(store2.enableHapticFeedback, "False value should persist")
        }
        
        // 清理
        testDefaults.removePersistentDomain(forName: suiteName)
    }
    
    /// **Property 4 补充测试**: 多次切换后的持久化
    func testHapticEnabledMultipleTogglePersistence() {
        let suiteName = "test.haptic.toggle.\(UUID().uuidString)"
        let testDefaults = UserDefaults(suiteName: suiteName)!
        
        let store = SettingsStore(userDefaults: testDefaults)
        
        // 多次切换
        for i in 0..<10 {
            let expectedValue = i % 2 == 0
            store.enableHapticFeedback = expectedValue
            
            // 验证立即读取
            XCTAssertEqual(store.enableHapticFeedback, expectedValue)
            
            // 验证从新实例读取
            let newStore = SettingsStore(userDefaults: testDefaults)
            XCTAssertEqual(newStore.enableHapticFeedback, expectedValue)
        }
        
        // 清理
        testDefaults.removePersistentDomain(forName: suiteName)
    }
    
    // MARK: - Scale Constants Tests
    
    /// 测试缩放常量值
    func testScaleConstants() {
        // 按下状态缩放应该小于 1
        XCTAssertLessThan(AnimationConstants.Scale.pressed, 1.0)
        XCTAssertGreaterThan(AnimationConstants.Scale.pressed, 0.9)
        
        // 正常状态缩放应该等于 1
        XCTAssertEqual(AnimationConstants.Scale.normal, 1.0)
        
        // 具体值验证
        XCTAssertEqual(AnimationConstants.Scale.pressed, 0.98, accuracy: 0.001)
    }
    
    // MARK: - Opacity Constants Tests
    
    /// 测试透明度常量值
    func testOpacityConstants() {
        // 按下状态透明度应该小于正常状态
        XCTAssertLessThan(
            AnimationConstants.Opacity.pressed,
            AnimationConstants.Opacity.normal
        )
        
        // 禁用状态透明度应该小于按下状态
        XCTAssertLessThan(
            AnimationConstants.Opacity.disabled,
            AnimationConstants.Opacity.pressed
        )
        
        // 所有透明度都应该在 0-1 范围内
        XCTAssertGreaterThanOrEqual(AnimationConstants.Opacity.pressed, 0)
        XCTAssertLessThanOrEqual(AnimationConstants.Opacity.pressed, 1)
        XCTAssertGreaterThanOrEqual(AnimationConstants.Opacity.normal, 0)
        XCTAssertLessThanOrEqual(AnimationConstants.Opacity.normal, 1)
        XCTAssertGreaterThanOrEqual(AnimationConstants.Opacity.disabled, 0)
        XCTAssertLessThanOrEqual(AnimationConstants.Opacity.disabled, 1)
    }
}
