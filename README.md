# 醒醒 Arrival Alert

<p align="center">
  <img src="docs/icon.png" width="120" alt="醒醒 App Icon">
</p>

<p align="center">
  <strong>让每一次出行都安心</strong>
</p>

<p align="center">
  一款开源的智能到站提醒 iOS App，采用 EWMA 速度平滑算法，帮助你在公交、地铁、火车上安心休息，不再错过下车站点。
</p>

## ✨ 特性

- 🧠 **智能 ETA 算法** - EWMA 速度平滑 + 历史数据融合 + 置信度评估
- 🔋 **省电优化** - 动态调整定位频率，智能省电模式
- 🏝️ **灵动岛支持** - 实时显示距离和预计到达时间
- 🛡️ **多重保障** - 提前触发 + 闹钟兜底，确保不错过站点
- 🗺️ **路线规划** - 支持多种交通方式，智能路线选择
- 🎯 **地理围栏** - 精准的到站检测

## 🧮 ETA 算法详解

醒醒的核心是一套智能 ETA（预计到达时间）算法，专为移动场景优化设计。

### 算法架构

```
┌─────────────────────────────────────────────────────────────┐
│                    EnhancedETACalculator                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │   Speed     │───▶│    EWMA     │───▶│  Historical │     │
│  │  Calculator │    │  Smoothing  │    │   Blending  │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
│         │                  │                  │             │
│         ▼                  ▼                  ▼             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐     │
│  │    GPS      │    │  Stationary │    │ Confidence  │     │
│  │   Filter    │    │  Detection  │    │   Scoring   │     │
│  └─────────────┘    └─────────────┘    └─────────────┘     │
└─────────────────────────────────────────────────────────────┘
```

### 1. EWMA 速度平滑

使用指数加权移动平均（Exponential Weighted Moving Average）平滑 GPS 速度数据，有效过滤噪声：

```
EWMA_speed = α × current_speed + (1 - α) × previous_EWMA
```

- **α = 0.3**：平滑系数，平衡响应速度和稳定性
- **窗口大小 = 10**：保留最近 10 个速度样本用于方差计算

### 2. 历史数据融合

结合当前速度和历史平均速度，提高预测准确性：

```
blended_speed = 0.7 × current_speed + 0.3 × historical_average
```

当当前速度异常低时，自动回退到交通方式基准速度。

### 3. 置信度评估

根据速度与交通方式基准的偏差，计算 ETA 置信度：

| 置信度 | 条件 | 显示方式 |
|--------|------|----------|
| 高 | 速度在容差范围内 | `15 分钟` |
| 中 | 偏差 ≤ 70% | `约 15 分钟` |
| 低 | 偏差 > 70% | `12 - 18 分钟` |

### 4. 静止状态检测

连续 30 秒速度低于 0.5 m/s 时判定为静止，避免无效 ETA 计算。

### 5. GPS 噪声过滤

SpeedCalculator 负责从原始位置数据提取可靠速度：

- **最小距离阈值**：5 米（过滤 GPS 漂移）
- **最大速度限制**：50 m/s（约 180 km/h，过滤异常值）
- **精度权重**：根据 GPS 精度动态调整置信度

```swift
// 置信度计算
if accuracy <= 10m → confidence = 1.0
if accuracy <= 50m → confidence = 1.0 - (accuracy - 10) / 40 × 0.5
if accuracy > 50m  → confidence = max(0.1, 0.5 - (accuracy - 50) / 100)
```

### 交通方式基准速度

| 交通方式 | 基准速度 | 容差范围 |
|----------|----------|----------|
| 步行 | 1.4 m/s | ±50% |
| 公交 | 8.3 m/s | ±60% |
| 地铁 | 13.9 m/s | ±40% |
| 驾车 | 11.1 m/s | ±70% |
| 骑行 | 4.2 m/s | ±50% |

## 📱 系统要求

- iOS 17.0+
- iPhone（支持灵动岛的设备可获得最佳体验）

## 🛠️ 构建

```bash
# 克隆仓库
git clone https://github.com/user/arrival-alert.git

# 使用 Xcode 打开
open SmartArrivalAlert.xcodeproj

# 构建并运行
# 选择目标设备，按 Cmd + R
```

## 📁 项目结构

```
SmartArrivalAlert/
├── Models/          # 数据模型
├── Views/           # SwiftUI 视图
├── ViewModels/      # 视图模型
├── Services/        # 核心服务
│   ├── EnhancedETACalculator.swift  # ETA 算法核心
│   ├── SpeedCalculator.swift        # 速度计算
│   ├── MonitoringEngine.swift       # 监控引擎
│   └── ...
├── Utilities/       # 工具类
└── TripActivityWidget/  # 灵动岛组件
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 提交 Pull Request

## 📄 开源协议

本项目采用 MIT 协议开源，详见 [LICENSE](LICENSE) 文件。

## 🙏 致谢

- SwiftUI 和 MapKit 框架
- 所有贡献者和用户

---

<p align="center">
  Made with ❤️ by 醒醒 Team
</p>
