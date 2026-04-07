# 第三方开源声明 (CCFCal Notices)

CCFCal 项目的自有修改部分基于 MIT License 开源，详细条款请查阅根目录下的 `LICENSE` 文件。本项目站在了众多优秀开源项目的肩膀上，特此声明并致谢。

## 💻 上游应用程序 (Upstream Application)

CCFCal 基于 **Itsycal** 二次开发。Itsycal 是由 Sanjay Madan 开发的一款优秀的 macOS 菜单栏日历应用（基于 MIT 许可）。
- **源码地址**: [https://github.com/sfsam/Itsycal](https://github.com/sfsam/Itsycal)
- **原许可证保留**: `CCFCal/LICENSE.txt`

*合规提醒：在重新分发 CCFCal 的源码或二进制包时，请务必同时保留 CCFCal 的 MIT 许可文本以及上游 Itsycal 的版权声明/许可文本。*

## 🗂️ 截稿数据源 (Deadline Data)

本应用内展示的会议与期刊 DDL 数据衍生自 **ccfddl / ccf4sc** 开源生态。
- **数据源官网**: [https://ccfddl.github.io/](https://ccfddl.github.io/)
- 相关的 ccf4sc 风格数据适配器实现在本代码库的 `pipeline/` 目录下。

## 📦 打包框架 (Bundled Frameworks)

CCFCal 的二进制文件中打包了以下 macOS 第三方框架（位于 `CCFCal/CCFCal/_frameworks/` 目录）。在分发源码或二进制文件时，请遵守其对应的开源协议：

- **Sparkle 1.27.1** (MIT License)
  - 源码与协议: [Sparkle 1.x GitHub](https://github.com/sparkle-project/Sparkle/blob/1.x/LICENSE)
- **MASShortcut 2.4.0** (BSD-2-Clause License)
  - 源码: [MASShortcut GitHub](https://github.com/cocoabits/MASShortcut)

## 🎨 品牌声明 (Branding)

CCFCal 采用独立的产品图标和视觉品牌资产。
虽然 Itsycal 的源码资产受上游 MIT 协议管辖，但为避免与上游项目产生不必要的混淆，CCFCal 不会将 Itsycal 的原始应用图标作为本项目的最终公开品牌视觉。
