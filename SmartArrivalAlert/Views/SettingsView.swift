import SwiftUI

/// 设置页面
struct SettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // 围栏设置
                Section {
                    // 最大围栏半径
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("最大提醒距离")
                            Spacer()
                            Text(GeofenceRadiusConfig.formatRadius(settings.maxGeofenceRadius))
                                .foregroundStyle(.secondary)
                        }
                        
                        HapticSlider(
                            value: $settings.maxGeofenceRadius,
                            in: 1000...50000,
                            step: 500,
                            tint: .blue
                        )
                        
                        Text("主界面滑杆的最大值")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    
                    // 默认围栏半径
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("默认提醒距离")
                            Spacer()
                            Text(GeofenceRadiusConfig.formatRadius(settings.defaultGeofenceRadius))
                                .foregroundStyle(.secondary)
                        }
                        
                        HapticSlider(
                            value: $settings.defaultGeofenceRadius,
                            in: 100...min(settings.maxGeofenceRadius, 10000),
                            step: 50,
                            tint: .blue
                        )
                    }
                } header: {
                    Text("围栏设置")
                }
                
                // 省电策略
                Section {
                    // 电池模式选择
                    Picker("省电模式", selection: $settings.batteryMode) {
                        ForEach(BatteryMode.allCases, id: \.self) { mode in
                            HStack {
                                Image(systemName: mode.icon)
                                Text(mode.displayName)
                            }
                            .tag(mode)
                        }
                    }
                    
                    // 自动切换
                    Toggle("低电量自动省电", isOn: $settings.autoBatterySwitch)
                    
                    if settings.autoBatterySwitch {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("切换阈值")
                                Spacer()
                                Text("\(settings.lowBatteryThreshold)%")
                                    .foregroundStyle(.secondary)
                            }
                            
                            HapticIntSlider(
                                value: $settings.lowBatteryThreshold,
                                in: 10...50,
                                step: 5,
                                tint: .orange
                            )
                        }
                    }
                } header: {
                    Text("省电策略")
                } footer: {
                    Text(settings.batteryMode.description)
                }
                
                // 提醒策略
                Section {
                    // 提醒声音
                    Picker("提醒声音", selection: $settings.alertSound) {
                        ForEach(AlertSound.allCases, id: \.self) { sound in
                            Text(sound.displayName).tag(sound)
                        }
                    }
                    
                    // 触觉反馈
                    Toggle("触觉反馈", isOn: $settings.enableHapticFeedback)
                    
                    // 触觉反馈预览按钮
                    if settings.enableHapticFeedback {
                        Button {
                            HapticManager.shared.trigger(.success)
                        } label: {
                            HStack {
                                Text("预览触觉反馈")
                                Spacer()
                                Image(systemName: "hand.tap")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                    
                    // 提前触发
                    Toggle("信号差时提前提醒", isOn: $settings.enableEarlyTrigger)
                    
                    if settings.enableEarlyTrigger {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("提前倍数")
                                Spacer()
                                Text(String(format: "%.1fx", settings.earlyTriggerMultiplier))
                                    .foregroundStyle(.secondary)
                            }
                            
                            HapticSlider(
                                value: $settings.earlyTriggerMultiplier,
                                in: 1.2...2.0,
                                step: 0.1,
                                tint: .blue
                            )
                            
                            Text("在围栏半径的 \(String(format: "%.1f", settings.earlyTriggerMultiplier)) 倍距离时提前触发")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    // 兜底闹钟
                    Toggle("兜底闹钟", isOn: $settings.enableBackupAlarm)
                    
                    if settings.enableBackupAlarm {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("提前时间")
                                Spacer()
                                Text("\(settings.backupAlarmOffset) 分钟")
                                    .foregroundStyle(.secondary)
                            }
                            
                            HapticIntSlider(
                                value: $settings.backupAlarmOffset,
                                in: 1...30,
                                step: 1,
                                tint: .orange
                            )
                            
                            Text("在预计到达前设置系统闹钟作为兜底")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("提醒策略")
                }
                
                // 通知设置
                Section {
                    Toggle("实时状态显示", isOn: $settings.enableLiveActivity)
                } header: {
                    Text("通知")
                } footer: {
                    Text("在灵动岛和锁屏实时显示距离和预计时间")
                }
                
                // 重置
                Section {
                    Button(role: .destructive) {
                        settings.resetToDefaults()
                    } label: {
                        HStack {
                            Spacer()
                            Text("恢复默认设置")
                            Spacer()
                        }
                    }
                }
                
                // 关于
                Section {
                    VStack(spacing: 12) {
                        AppBrandView(size: .small)
                        
                        Text("版本 \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
