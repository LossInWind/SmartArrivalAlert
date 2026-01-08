import SwiftUI

/// 到站提醒全屏界面
/// 参考 iOS 闹钟设计：延迟按钮大而醒目，确认按钮小而低调
struct ArrivalAlertView: View {
    @StateObject private var viewModel = AlertViewModel()
    @ObservedObject var alertManager: AlertManager
    
    var body: some View {
        ZStack {
            // 背景
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                Spacer()
                
                // 提示文字
                Text("即将到达")
                    .font(.title3)
                    .foregroundStyle(.gray)
                    .padding(.bottom, 8)
                
                // 目的地名称
                Text(viewModel.destinationName)
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Spacer()
                
                // 延迟按钮区域
                VStack(spacing: 24) {
                    if viewModel.isSnoozed {
                        // 延迟状态：显示倒计时
                        snoozeCountdownView
                    } else {
                        // 提醒状态：显示延迟按钮
                        snoozeButton
                    }
                    
                    // 确认按钮（小灰色文字）
                    Button {
                        HapticManager.shared.trigger(.success)
                        viewModel.confirm()
                    } label: {
                        Text("确认到达")
                            .font(.body)
                            .foregroundStyle(.gray)
                    }
                }
                .padding(.bottom, 80)
            }
        }
        .onAppear {
            // 界面出现时触发强烈警告反馈（到站提醒关键场景，使用强制触发）
            HapticManager.shared.triggerForced(.warning)
        }
    }
    
    // MARK: - Subviews
    
    /// 延迟按钮
    private var snoozeButton: some View {
        Button {
            HapticManager.shared.trigger(.success)
            viewModel.snooze()
        } label: {
            Text("延迟 5 分钟")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(viewModel.canSnooze ? Color.orange : Color.gray.opacity(0.5))
                )
                .padding(.horizontal, 40)
        }
        .disabled(!viewModel.canSnooze)
        .opacity(viewModel.canSnooze ? 1.0 : 0.5)
    }
    
    /// 延迟倒计时视图
    private var snoozeCountdownView: some View {
        VStack(spacing: 8) {
            // 倒计时数字
            Text(viewModel.snoozeRemainingText)
                .font(.system(size: 64, weight: .light, design: .rounded))
                .foregroundStyle(.orange)
                .monospacedDigit()
            
            // 提示文字
            Text("后再次提醒")
                .font(.body)
                .foregroundStyle(.gray)
            
            // 剩余延迟次数提示
            if viewModel.remainingSnoozeCount > 0 {
                Text("还可延迟 \(viewModel.remainingSnoozeCount) 次")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.6))
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 40)
    }
}

// MARK: - Preview

#Preview {
    ArrivalAlertView(alertManager: .shared)
}
