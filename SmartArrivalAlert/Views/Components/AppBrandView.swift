import SwiftUI

/// App 品牌名称视图
/// 显示中文名"醒醒"和英文名"Arrival Alert"
struct AppBrandView: View {
    
    enum Size {
        case small      // 设置页关于
        case medium     // 导航标题
        case large      // 启动页
    }
    
    let size: Size
    
    var body: some View {
        VStack(spacing: spacing) {
            Text("醒醒")
                .font(chineseFont)
                .fontWeight(.semibold)
            
            Text("Arrival Alert")
                .font(englishFont)
                .foregroundStyle(.secondary)
                .tracking(0.5)
        }
    }
    
    private var spacing: CGFloat {
        switch size {
        case .small: return 2
        case .medium: return 2
        case .large: return 4
        }
    }
    
    private var chineseFont: Font {
        switch size {
        case .small: return .title3
        case .medium: return .title2
        case .large: return .system(size: 42, weight: .semibold)
        }
    }
    
    private var englishFont: Font {
        switch size {
        case .small: return .caption2
        case .medium: return .caption
        case .large: return .subheadline
        }
    }
}

/// 导航栏标题品牌视图（紧凑版）
struct NavTitleBrandView: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("醒醒")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("Arrival Alert")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .tracking(0.3)
        }
    }
}

#Preview("Small") {
    AppBrandView(size: .small)
}

#Preview("Medium") {
    AppBrandView(size: .medium)
}

#Preview("Large") {
    AppBrandView(size: .large)
}

#Preview("Nav Title") {
    NavTitleBrandView()
}
