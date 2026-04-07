# 更新日志 (Changelog)

本项目所有的显著更新都会记录在此文件中。

格式基于 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.0.0/) 规范，并遵循 [语义化版本控制](https://semver.org/lang/zh-CN/)。

## [1.0.0] - 2026-04-07

### 新增

- **首个公开版本**：为 Good-Way-ZJU/CCFCal 准备了首次公开的 GitHub 发布版本。
- **菜单栏工作流**：新增 macOS 菜单栏原生界面，支持浏览、多维筛选并订阅 CCF 推荐会议和期刊的截稿日期 DDL。
- **可视化提示**：新增日历视图中的 DDL 关键日期高亮功能，并在系统菜单栏常驻显示距离最近一个已订阅 DDL 的极限倒计时。
- **数据管道**：新增基于 CCF DDL 原始数据的 `DDLCandidates.json` 每日自动刷新数据管道。
- **自动化工作流**：新增 GitHub Actions 支持，用于自动化执行并提交 JSON 数据快照的日常更新。
- **开源合规**：完善了项目文档，完整记录了 CCFCal, Itsycal, Sparkle, MASShortcut 的开源许可声明及截稿数据源归属。
