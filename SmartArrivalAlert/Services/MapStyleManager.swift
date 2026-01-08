import Foundation
import SwiftUI
import Combine

/// 地图样式管理器 - 单例，管理全局地图样式
/// 确保所有地图视图使用一致的样式
class MapStyleManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = MapStyleManager()
    
    // MARK: - Published Properties
    
    /// 当前地图样式
    @Published private(set) var currentStyle: MapDisplayStyle = .explore
    
    // MARK: - Private Properties
    
    private let userDefaults: UserDefaults
    private let storageKey = "map_display_style"
    
    // MARK: - Initialization
    
    /// 初始化，支持依赖注入用于测试
    /// - Parameter userDefaults: UserDefaults 实例，默认为 .standard
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        loadStyle()
    }
    
    // MARK: - Public Methods
    
    /// 设置地图样式并持久化
    /// - Parameter style: 新的地图样式
    func setStyle(_ style: MapDisplayStyle) {
        guard style != currentStyle else { return }
        currentStyle = style
        saveStyle()
    }
    
    /// 重置为默认样式
    func resetToDefault() {
        setStyle(.explore)
    }
    
    // MARK: - Persistence
    
    /// 从 UserDefaults 加载样式
    private func loadStyle() {
        guard let rawValue = userDefaults.string(forKey: storageKey),
              let style = MapDisplayStyle(rawValue: rawValue) else {
            // 使用默认样式
            currentStyle = .explore
            return
        }
        currentStyle = style
    }
    
    /// 保存样式到 UserDefaults
    private func saveStyle() {
        userDefaults.set(currentStyle.rawValue, forKey: storageKey)
    }
    
    // MARK: - Testing Support
    
    /// 清除存储的样式（用于测试）
    func clearStoredStyle() {
        userDefaults.removeObject(forKey: storageKey)
        currentStyle = .explore
    }
    
    /// 直接加载样式（用于测试验证）
    func reloadStyle() {
        loadStyle()
    }
}
