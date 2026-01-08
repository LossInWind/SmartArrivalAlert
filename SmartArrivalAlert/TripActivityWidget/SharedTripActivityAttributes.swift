import Foundation

#if canImport(ActivityKit)
import ActivityKit

// MARK: - Shared Trip Activity Attributes
// 
// 这个文件包含 TripActivityAttributes 的定义，需要在主 App 和 Widget Extension 之间共享。
// 
// 重要说明：
// 1. 主 App 中的定义在 LiveActivityManager.swift
// 2. Widget Extension 需要复制这个定义或通过共享 Framework 引用
// 3. 两边的定义必须完全一致，否则 Live Activity 无法正常工作
//
// 共享方案：
// 方案 A（推荐）：创建共享 Framework
//   1. 在 Xcode 中创建新的 Framework target (如 "SharedModels")
//   2. 将 TripActivityAttributes 移到共享 Framework
//   3. 主 App 和 Widget Extension 都引用该 Framework
//
// 方案 B（简单）：复制定义
//   1. 在 Widget Extension 中创建 TripActivityAttributes.swift
//   2. 复制下面的定义
//   3. 确保两边定义完全一致

/*
 复制以下代码到 Widget Extension：
 
 import Foundation
 import ActivityKit
 
 @available(iOS 16.1, *)
 struct TripActivityAttributes: ActivityAttributes {
     public struct ContentState: Codable, Hashable {
         var distance: Int
         var etaMinutes: Int?
         var isETAReliable: Bool
         var isInsideGeofence: Bool
     }
     
     var destinationName: String
     var destinationAddress: String
     var geofenceRadius: Int
     var transportModeIcon: String
     var transportModeName: String
 }
 */

// 注意：实际的 TripActivityAttributes 定义在 LiveActivityManager.swift 中
// 这个文件仅作为文档和参考

#endif
