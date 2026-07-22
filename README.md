# 经期助手 CycleTracker

SwiftUI 经期记录应用，最低支持 iOS 26。数据全部保存在本机（SwiftData），不联网。

## 功能

- **智能预测（越用越准）**：根据历史周期做加权平均（近期权重更高），自动剔除异常周期，并显示预测可信度
- **日历标色**：
  - 🔴 月经期（实心水滴）
  - 🩷 预测经期（虚线框 + 空心水滴）
  - 🟢 排卵期 / 易孕窗口（叶子）
  - 🟣 排卵日（星标）
  - 🟠 黄体期（月亮）
  - 🔵 卵泡期
- **历史导入**：手动选择"几号到几号"批量添加历史经期；支持 JSON 导出 / 恢复
- **每日记录**：流量、疼痛、心情、备注
- **统计**：周期长度趋势图、疼痛记录图（Swift Charts）
- **提醒**：经期前 0~7 天本地通知提醒

## 自动打包

推送到 `main` 分支即触发 GitHub Actions（macOS 26 runner + XcodeGen）：

1. 打开仓库 **Actions** 页 → 最新的 "Build unsigned IPA" 运行
2. 下载 Artifact `CycleTracker-ipa`（解压得到 `CycleTracker.ipa`）
3. 打 tag（如 `v1.0.0`）推送则会自动创建 Release 并附带 ipa

产物为**未签名 ipa**，可用 AltStore / Sideloadly / TrollStore / LiveContainer / Signum 等工具自签安装。

## 本地开发

```bash
brew install xcodegen
xcodegen generate
open CycleTracker.xcodeproj
```

## 使用建议

首次使用请通过右上角"导入历史"添加最近 3~6 次经期记录，预测会立刻可用；之后每次经期来时在日历上点当天 →"经期从这天开始"，结束时点"经期到这天结束"即可，预测会随记录增多自动校准。
