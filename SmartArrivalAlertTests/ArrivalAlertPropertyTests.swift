import XCTest
import SwiftCheck
@testable import SmartArrivalAlert

/// 到站提醒体验属性测试
final class ArrivalAlertPropertyTests: XCTestCase {
    
    // MARK: - Property 9: Alert state round-trip persistence
    
    /// 测试 AlertInfo 序列化往返
    func testAlertInfoRoundTrip() {
        property("AlertInfo 序列化后反序列化应该得到相同的对象") <- forAll { (seed: Int) in
            let info = self.generateAlertInfo(seed: seed)
            
            // 序列化
            guard let data = try? JSONEncoder().encode(info) else {
                return false
            }
            
            // 反序列化
            guard let decoded = try? JSONDecoder().decode(AlertInfo.self, from: data) else {
                return false
            }
            
            // 验证相等
            return info == decoded
        }
    }
    
    /// 测试 AlertState 序列化往返
    func testAlertStateRoundTrip() {
        property("AlertState 序列化后反序列化应该得到相同的值") <- forAll { (seed: Int) in
            let states: [AlertState] = [.idle, .alerting, .snoozed, .confirmed]
            let state = states[abs(seed) % states.count]
            
            // 序列化
            guard let data = try? JSONEncoder().encode(state) else {
                return false
            }
            
            // 反序列化
            guard let decoded = try? JSONDecoder().decode(AlertState.self, from: data) else {
                return false
            }
            
            return state == decoded
        }
    }
    
    // MARK: - Property 5: Snooze count is limited
    
    /// 测试延迟次数限制
    func testSnoozeCountLimit() {
        property("延迟次数不应超过最大限制") <- forAll { (seed: Int) in
            var info = self.generateAlertInfo(seed: seed)
            info.state = .alerting
            info.snoozeCount = 0
            
            var snoozeAttempts = 0
            var successfulSnoozes = 0
            
            // 尝试多次延迟
            while snoozeAttempts < 10 {
                if let snoozed = info.snoozed() {
                    info = snoozed
                    successfulSnoozes += 1
                    // 模拟延迟到期后重新触发
                    info = info.retriggered()
                } else {
                    break
                }
                snoozeAttempts += 1
            }
            
            // 成功延迟次数不应超过最大限制
            return successfulSnoozes <= AlertInfo.maxSnoozeCount
        }
    }
    
    /// 测试达到最大延迟次数后无法继续延迟
    func testCannotSnoozeAfterMaxCount() {
        property("达到最大延迟次数后 canSnooze 应为 false") <- forAll { (seed: Int) in
            var info = self.generateAlertInfo(seed: seed)
            info.state = .alerting
            info.snoozeCount = AlertInfo.maxSnoozeCount
            
            return !info.canSnooze
        }
    }
    
    // MARK: - Property 8: State transitions are valid
    
    /// 测试有效的状态转换
    func testValidStateTransitions() {
        property("状态转换应该遵循有效的转换规则") <- forAll { (seed: Int) in
            let info = self.generateAlertInfo(seed: seed)
            
            // idle -> alerting (通过 triggerAlert)
            // alerting -> confirmed (通过 confirm)
            // alerting -> snoozed (通过 snooze)
            // snoozed -> alerting (通过 retriggered)
            // snoozed -> confirmed (通过 confirm)
            // any -> idle (通过 cancel)
            
            // 测试 alerting -> confirmed
            var alertingInfo = info
            alertingInfo.state = .alerting
            let confirmed = alertingInfo.confirmed()
            guard confirmed.state == .confirmed else { return false }
            
            // 测试 alerting -> snoozed
            alertingInfo.snoozeCount = 0
            if let snoozed = alertingInfo.snoozed() {
                guard snoozed.state == .snoozed else { return false }
                
                // 测试 snoozed -> alerting
                let retriggered = snoozed.retriggered()
                guard retriggered.state == .alerting else { return false }
                
                // 测试 snoozed -> confirmed
                let confirmedFromSnoozed = snoozed.confirmed()
                guard confirmedFromSnoozed.state == .confirmed else { return false }
            }
            
            // 测试 any -> idle
            let cancelled = alertingInfo.cancelled()
            guard cancelled.state == .idle else { return false }
            
            return true
        }
    }
    
    /// 测试无效的状态转换
    func testInvalidStateTransitions() {
        property("idle 状态不能直接延迟") <- forAll { (seed: Int) in
            var info = self.generateAlertInfo(seed: seed)
            info.state = .idle
            
            return info.snoozed() == nil
        }
        
        property("confirmed 状态不能延迟") <- forAll { (seed: Int) in
            var info = self.generateAlertInfo(seed: seed)
            info.state = .confirmed
            
            return info.snoozed() == nil
        }
        
        property("snoozed 状态不能再次延迟") <- forAll { (seed: Int) in
            var info = self.generateAlertInfo(seed: seed)
            info.state = .snoozed
            
            return info.snoozed() == nil
        }
    }
    
    // MARK: - Property 6: Confirm during snooze cancels timer
    
    /// 测试延迟状态下确认会清除延迟结束时间
    func testConfirmDuringSnoozeClearsEndTime() {
        property("延迟状态下确认应该清除延迟结束时间") <- forAll { (seed: Int) in
            var info = self.generateAlertInfo(seed: seed)
            info.state = .alerting
            info.snoozeCount = 0
            
            // 执行延迟
            guard var snoozed = info.snoozed() else { return true }
            guard snoozed.snoozeEndTime != nil else { return false }
            
            // 确认
            let confirmed = snoozed.confirmed()
            
            return confirmed.snoozeEndTime == nil && confirmed.state == .confirmed
        }
    }
    
    // MARK: - Property 3: Snooze stops feedback and schedules restart
    
    /// 测试延迟会设置延迟结束时间
    func testSnoozeSchedulesRestart() {
        property("延迟应该设置延迟结束时间") <- forAll { (seed: Int) in
            var info = self.generateAlertInfo(seed: seed)
            info.state = .alerting
            info.snoozeCount = 0
            
            guard let snoozed = info.snoozed() else { return true }
            
            // 验证延迟结束时间已设置
            guard let endTime = snoozed.snoozeEndTime else { return false }
            
            // 验证延迟结束时间在未来
            return endTime > Date()
        }
    }
    
    /// 测试延迟会增加延迟次数
    func testSnoozeIncrementsCount() {
        property("延迟应该增加延迟次数") <- forAll { (seed: Int) in
            var info = self.generateAlertInfo(seed: seed)
            info.state = .alerting
            let initialCount = abs(seed) % AlertInfo.maxSnoozeCount
            info.snoozeCount = initialCount
            
            guard let snoozed = info.snoozed() else { return true }
            
            return snoozed.snoozeCount == initialCount + 1
        }
    }
    
    // MARK: - Property 7: Alert view displays required info
    
    /// 测试 AlertInfo 提供必要的显示信息
    func testAlertInfoProvidesRequiredInfo() {
        property("AlertInfo 应该提供目的地名称和地址") <- forAll { (seed: Int) in
            let info = self.generateAlertInfo(seed: seed)
            
            return !info.destinationName.isEmpty && !info.destinationAddress.isEmpty
        }
    }
    
    /// 测试延迟剩余时间计算
    func testSnoozeRemainingTimeCalculation() {
        property("延迟剩余时间应该正确计算") <- forAll { (seed: Int) in
            var info = self.generateAlertInfo(seed: seed)
            info.state = .alerting
            info.snoozeCount = 0
            
            guard var snoozed = info.snoozed() else { return true }
            
            // 验证剩余时间存在且为正数
            guard let remaining = snoozed.snoozeRemainingTime else { return false }
            
            return remaining > 0 && remaining <= AlertInfo.defaultSnoozeDuration
        }
    }
    
    // MARK: - Property 10: Stop monitoring resets state
    
    /// 测试取消会重置状态
    func testCancelResetsState() {
        property("取消应该将状态重置为 idle") <- forAll { (seed: Int) in
            var info = self.generateAlertInfo(seed: seed)
            let states: [AlertState] = [.alerting, .snoozed, .confirmed]
            info.state = states[abs(seed) % states.count]
            
            let cancelled = info.cancelled()
            
            return cancelled.state == .idle
        }
    }
    
    /// 测试取消会清除延迟结束时间
    func testCancelClearsSnoozeEndTime() {
        property("取消应该清除延迟结束时间") <- forAll { (seed: Int) in
            var info = self.generateAlertInfo(seed: seed)
            info.state = .alerting
            info.snoozeCount = 0
            
            // 先延迟
            guard var snoozed = info.snoozed() else { return true }
            
            // 然后取消
            let cancelled = snoozed.cancelled()
            
            return cancelled.snoozeEndTime == nil
        }
    }
    
    // MARK: - AlertState Properties
    
    /// 测试 AlertState.canSnooze 属性
    func testAlertStateCanSnooze() {
        XCTAssertFalse(AlertState.idle.canSnooze)
        XCTAssertTrue(AlertState.alerting.canSnooze)
        XCTAssertFalse(AlertState.snoozed.canSnooze)
        XCTAssertFalse(AlertState.confirmed.canSnooze)
    }
    
    /// 测试 AlertState.canConfirm 属性
    func testAlertStateCanConfirm() {
        XCTAssertFalse(AlertState.idle.canConfirm)
        XCTAssertTrue(AlertState.alerting.canConfirm)
        XCTAssertTrue(AlertState.snoozed.canConfirm)
        XCTAssertFalse(AlertState.confirmed.canConfirm)
    }
    
    /// 测试 AlertState.isActive 属性
    func testAlertStateIsActive() {
        XCTAssertFalse(AlertState.idle.isActive)
        XCTAssertTrue(AlertState.alerting.isActive)
        XCTAssertTrue(AlertState.snoozed.isActive)
        XCTAssertFalse(AlertState.confirmed.isActive)
    }
    
    // MARK: - AlertSoundType Properties
    
    /// 测试 AlertSoundType 显示名称
    func testAlertSoundTypeDisplayNames() {
        XCTAssertEqual(AlertSoundType.radar.displayName, "雷达")
        XCTAssertEqual(AlertSoundType.beacon.displayName, "信标")
        XCTAssertEqual(AlertSoundType.chime.displayName, "铃声")
        XCTAssertEqual(AlertSoundType.signal.displayName, "信号")
    }
    
    /// 测试 AlertSoundType 文件名
    func testAlertSoundTypeFileNames() {
        for soundType in AlertSoundType.allCases {
            XCTAssertEqual(soundType.fileName, soundType.rawValue)
        }
    }
    
    // MARK: - AlertConfiguration Constants
    
    /// 测试配置常量
    func testAlertConfigurationConstants() {
        XCTAssertEqual(AlertConfiguration.defaultSnoozeDuration, 300)
        XCTAssertEqual(AlertConfiguration.maxSnoozeCount, 3)
        XCTAssertEqual(AlertConfiguration.hapticInterval, 2.0)
        XCTAssertEqual(AlertConfiguration.followUpNotificationDelay, 30.0)
    }
    
    // MARK: - Helper Methods
    
    private func generateAlertInfo(seed: Int) -> AlertInfo {
        let random = SeededRandom(seed: seed)
        let states: [AlertState] = [.idle, .alerting, .snoozed, .confirmed]
        
        return AlertInfo(
            destinationName: "Destination_\(random.nextInt(bound: 1000))",
            destinationAddress: "Address_\(random.nextInt(bound: 1000))",
            destinationId: UUID().uuidString,
            triggeredAt: Date(),
            snoozeCount: random.nextInt(bound: AlertInfo.maxSnoozeCount + 1),
            snoozeEndTime: random.nextBool() ? Date().addingTimeInterval(Double(random.nextInt(min: 60, max: 600))) : nil,
            state: states[random.nextInt(bound: states.count)]
        )
    }
}
