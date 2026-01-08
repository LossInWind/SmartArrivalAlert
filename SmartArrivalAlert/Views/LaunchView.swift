import SwiftUI

/// 启动页视图
/// 显示品牌名称和简短的加载动画
struct LaunchView: View {
    @State private var isAnimating = false
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            // 背景
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                // 图标占位（可以替换为实际 app 图标）
                ZStack {
                    Circle()
                        .fill(.blue.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "bell.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.blue)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                        .opacity(isAnimating ? 1.0 : 0.5)
                }
                .animation(.easeOut(duration: 0.6), value: isAnimating)
                
                // 品牌名称
                AppBrandView(size: .large)
                    .opacity(showContent ? 1.0 : 0.0)
                    .offset(y: showContent ? 0 : 10)
                    .animation(.easeOut(duration: 0.5).delay(0.2), value: showContent)
                
                Spacer()
                
                // 底部标语
                Text("让每一次出行都安心")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .opacity(showContent ? 1.0 : 0.0)
                    .animation(.easeOut(duration: 0.5).delay(0.4), value: showContent)
                    .padding(.bottom, 60)
            }
        }
        .onAppear {
            isAnimating = true
            showContent = true
        }
    }
}

#Preview {
    LaunchView()
}
