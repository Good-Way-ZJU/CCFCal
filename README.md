<p align="center">
  <img src="docs/images/ccfcal-logo.png" alt="CCFCal logo" width="144">
</p>

# CCFCal: 桌面版 ccfddl，你的专属 macOS 顶会倒计时

![macOS 11.0+](https://img.shields.io/badge/macOS-11.0%2B-lightgrey)
![License MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Data ccfddl](https://img.shields.io/badge/Data-ccfddl-success)

🔥 **告别繁琐的网页和小程序，将顶会 DDL 无缝接入你的工作流。**

在过去，为了追踪会议的截稿日期，我们要么得特意切出编辑器打开浏览器刷新 `ccfddl` 网页，要么得掏出手机翻找小程序——这种频繁的“上下文切换”无形中打断了宝贵的专注力。

**CCFCal** 正是为了解决这一痛点而生。作为专为计算机科学与人工智能领域科研人员打造的 **macOS 菜单栏日历 / 桌面版 ccfddl**，它将庞大的会议数据池以最轻量的方式直接集成到你的 macOS 系统中。

现在，你可以专注于模型架构和论文打磨。只需筛选并订阅你关注的会议（例如 ACL, ICLR, AAAI 等），最近的 DDL 就会常驻在系统菜单栏。抬眼一瞥，极限倒计时清晰可见，绝不让你错过任何一个关键节点。

<p align="center">
  <img src="docs/images/ccfcal-calendar.png" alt="CCFCal calendar view" width="180">
</p>

## ✨ 核心功能

- **🎯 桌面级的数据源接入**：内置基于开源 `ccfddl` 生态的最新会议和期刊数据。无需打开网页，本地原生支持按 `CCF-A / CCF-B / CCF-C`、具体细分领域以及关键词进行多维筛选。
- **📥 订阅制管理**：弱水三千只取一瓢，过滤海量无关噪音，只订阅你真正准备投稿的会议。
- **📅 原生日历同步**：订阅的 DDL 会自动同步到 CCFCal 在 macOS 中创建的专属日历，与系统级体验无缝融合。
- **🔦 可视化高亮**：在极简的日历视图中，清晰高亮所有已订阅的 DDL 日期。
- **🚨 菜单栏倒计时**：在 macOS 菜单栏直观显示最近一个 DDL 的极限倒计时（例如 `8 d`, `3 h` 或 `24 m`），给你恰到好处的紧迫感。

<p align="center">
  <img src="docs/images/ccfcal-subscriptions.png" alt="CCFCal subscription preferences" width="560">
</p>

## 🚀 快速安装

1. 前往 [GitHub Releases](https://github.com/Good-Way-ZJU/CCFCal/releases/latest) 页面下载最新的 `CCFCal-1.0.0.dmg`。
2. 双击打开 `dmg`，将其中的 `CCFCal.app` 拖拽到同一窗口里的 `Applications`（应用程序）快捷方式。
3. 打开“应用程序”文件夹，找到 `CCFCal.app`，右键点击并选择**打开**，再在弹窗中再次确认**打开**。
4. 首次打开 CCFCal 时，系统会弹出日历权限请求，请点击**允许授予权限**。

`dmg` 中附带了“如果打不开请看这里.txt”，如果安装或启动时被系统拦截，可以直接打开查看。

> **系统要求**：macOS 11.0 或更高版本。
> 当前发布包未经过 Apple Developer ID 签名与公证，因此首次启动可能需要手动确认。

如果 macOS 提示“`CCFCal.app` 已损坏”，请先确认它已经通过 `dmg` 拖入“应用程序”文件夹，然后在“终端”执行：

```bash
xattr -dr com.apple.quarantine /Applications/CCFCal.app
open /Applications/CCFCal.app
```

## 🔐 权限与隐私

CCFCal 仅需要日历权限来展示日历事件，并同步你订阅的 DDL。订阅数据会写入名为 "DDLCal Subscriptions" 的独立专用日历中，**不会**写入或修改你的其他私人日历。
`系统设置 -> 隐私与安全性 -> 日历 -> 勾选 CCFCal`

## 🔄 数据更新机制

- **自动获取**：CCFCal 每次启动时会检查云端最新的 DDL 数据，每天最多在后台静默刷新一次。
- **本地缓存**：数据快照由本仓库的 `docs/DDLCandidates.json` 托管，并在本地生成缓存，确保离线也能随时查看。
- **应用更新**：目前 v1.0.0 版本暂不包含 App 本体的自动更新模块（Sparkle 未启用）。DDL 列表会自动刷新，但如果发布了新的应用功能版本，请关注 GitHub Releases 手动下载替换。

## 📚 数据来源声明

应用的 DDL 基础数据源自优秀的开源生态 [`ccfddl`](https://ccfddl.github.io/)。
*注意：会议和期刊的官方截稿时间可能会发生临时延期或变更，在最终提交论文前，请务必以各会议/期刊官方网站的通告为准。*

## 🤝 致谢与开源许可

- **核心框架**：CCFCal 基于 [Itsycal](https://github.com/sfsam/Itsycal) 二次开发。Itsycal 是由 Sanjay Madan 开发的一款极简 macOS 菜单栏日历（基于 MIT 许可）。原始许可文本保留在 `CCFCal/LICENSE.txt` 中。
- **开源协议**：CCFCal 的修改与新增代码部分基于 `MIT License` 并在根目录 `LICENSE` 中发布。
- **第三方组件**：涉及的第三方框架与数据源详细说明请参阅 `NOTICE.md`。

如果你对开发感兴趣或想提交代码，请查阅 `CONTRIBUTING.md` 获取本地编译与贡献指南。
