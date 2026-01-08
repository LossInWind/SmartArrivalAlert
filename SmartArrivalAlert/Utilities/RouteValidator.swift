import Foundation

/// 路线验证器
/// 提供路线数据验证功能
struct RouteValidator {
    
    /// 验证路线数据完整性
    /// - Parameter route: 要验证的路线
    /// - Returns: 是否有效（名称非空、距离>0、时间>0）
    static func isValidRoute(_ route: RouteOption) -> Bool {
        return !route.name.isEmpty &&
               route.distance > 0 &&
               route.expectedTravelTime > 0
    }
    
    /// 过滤有效路线
    /// - Parameter routes: 路线列表
    /// - Returns: 有效的路线列表
    static func filterValidRoutes(_ routes: [RouteOption]) -> [RouteOption] {
        return routes.filter { isValidRoute($0) }
    }
    
    /// 验证路线列表是否全部有效
    /// - Parameter routes: 路线列表
    /// - Returns: 是否全部有效
    static func areAllRoutesValid(_ routes: [RouteOption]) -> Bool {
        return routes.allSatisfy { isValidRoute($0) }
    }
}
