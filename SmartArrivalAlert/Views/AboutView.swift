import SwiftUI

/// 关于页面
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showTutorial = false
    
    private let githubURL = "https://github.com/user/arrival-alert"
    private let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    
    var body: some View {
        NavigationStack {
            List {
                // 品牌信息
                Section {
                    VStack(spacing: 16) {
                        // App 图标
                        ZStack {
                            Circle()
                                .fill(.blue.opacity(0.1))
                                .frame(width: 80, height: 80)
                            
                            Image(systemName: "bell.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(.blue)
                        }
                        
                        AppBrandView(size: .medium)
                        
                        Text("版本 \(version) (\(build))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                }
                
                // 项目信息
                Section {
                    Text("醒醒是一款开源的到站提醒 App，采用智能 ETA 算法，帮助你在公交、地铁、火车等交通工具上安心休息，不再错过下车站点。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                } header: {
                    Text("关于")
                }
                
                // 功能特点
                Section {
                    FeatureRow(icon: "brain.head.profile", title: "智能 ETA", description: "EWMA 速度平滑 + 历史数据融合")
                    FeatureRow(icon: "battery.75percent", title: "省电优化", description: "动态调整定位频率")
                    FeatureRow(icon: "bell.badge", title: "灵动岛", description: "实时显示距离和预计时间")
                    FeatureRow(icon: "shield.checkered", title: "多重保障", description: "提前触发 + 闹钟兜底")
                } header: {
                    Text("特点")
                }
                
                // 使用教程
                Section {
                    Button {
                        showTutorial = true
                    } label: {
                        HStack {
                            Image(systemName: "book.fill")
                                .foregroundStyle(.blue)
                            Text("使用教程")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                } header: {
                    Text("帮助")
                }
                
                // 开源信息
                Section {
                    Link(destination: URL(string: githubURL)!) {
                        HStack {
                            Image(systemName: "link")
                                .foregroundStyle(.blue)
                            Text("GitHub 仓库")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                    
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundStyle(.blue)
                        Text("开源协议")
                        Spacer()
                        Text("MIT")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("开源")
                } footer: {
                    Text("欢迎贡献代码和提交 Issue")
                }
                
                // 版权
                Section {
                    Text("© 2025 醒醒 Arrival Alert\n保留所有权利")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 8)
                }
            }
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showTutorial) {
                TutorialView()
            }
        }
    }
}

/// 功能行
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// 使用教程视图
struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 步骤 1
                    TutorialStep(
                        number: 1,
                        title: "选择目的地",
                        description: "点击主页地图，搜索或在地图上选择你的目的地。支持收藏常用地点。",
                        icon: "mappin.circle.fill"
                    )
                    
                    // 步骤 2
                    TutorialStep(
                        number: 2,
                        title: "设置提醒距离",
                        description: "拖动滑杆调整提醒距离。距离越大，提醒越早。建议地铁设置 500-1000 米，公交设置 200-500 米。",
                        icon: "slider.horizontal.3"
                    )
                    
                    // 步骤 3
                    TutorialStep(
                        number: 3,
                        title: "选择交通方式",
                        description: "选择你的出行方式（步行、公交、地铁、驾车等），系统会根据交通方式优化 ETA 计算。",
                        icon: "tram.fill"
                    )
                    
                    // 步骤 4
                    TutorialStep(
                        number: 4,
                        title: "开始提醒",
                        description: "点击「开始提醒」按钮，系统会在后台持续监控你的位置。到达提醒距离时会震动和响铃提醒你。",
                        icon: "bell.fill"
                    )
                    
                    // 提示
                    VStack(alignment: .leading, spacing: 12) {
                        Text("💡 小贴士")
                            .font(.headline)
                        
                        Text("• 首次使用请授予「始终允许」位置权限")
                        Text("• 开启灵动岛可在锁屏实时查看距离")
                        Text("• 信号差时系统会自动提前提醒")
                        Text("• 开启兜底闹钟可获得双重保障")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding()
            }
            .navigationTitle("使用教程")
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

/// 教程步骤
struct TutorialStep: View {
    let number: Int
    let title: String
    let description: String
    let icon: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // 步骤编号
            ZStack {
                Circle()
                    .fill(.blue)
                    .frame(width: 32, height: 32)
                
                Text("\(number)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(.blue)
                    Text(title)
                        .font(.headline)
                }
                
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    AboutView()
}
