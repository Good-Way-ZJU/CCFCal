# CCFCal v1.0.0

## 亮点

- 在 macOS 菜单栏追踪 CCF 会议与期刊 DDL。
- 只订阅你真正关注的会议/期刊，减少无关提醒。
- DDL 设置页支持“只看已订阅”，方便集中管理已订阅会议。
- 已订阅 DDL 会在日历中高亮，并同步到独立的 `DDLCal Subscriptions` 日历。
- 菜单栏显示最近一个已订阅 DDL 的倒计时。

## 数据

- DDL 候选数据来自 ccfddl 风格的数据源。
- App 启动时会检查本仓库托管的 `DDLCandidates.json`，每天最多自动刷新一次。

## 安装

1. 下载 `CCFCal-1.0.0.dmg`。
2. 双击打开 `dmg`。
3. 将窗口中的 `CCFCal.app` 拖到旁边的 `Applications` 快捷方式。
4. 打开“应用程序”，右键点击 `CCFCal.app`，选择“打开”，并在弹窗中再次确认“打开”。
5. 首次启动后，系统会请求“日历”权限，请选择“允许”。CCFCal 需要这个权限来显示日历事件并同步你订阅的 DDL。

`dmg` 中附带了“如果打不开请看这里.txt”，如果安装或启动时被系统拦截，可以直接打开查看。

## 如果提示“CCFCal.app 已损坏”

当前发布包没有经过 Apple Developer ID 公证。部分 macOS 版本会把未公证 App 显示成“已损坏”，这不是文件真的损坏，而是 Gatekeeper 的拦截提示。

请先确认 `CCFCal.app` 已经放在“应用程序”文件夹，然后打开“终端”执行：

```bash
xattr -dr com.apple.quarantine /Applications/CCFCal.app
open /Applications/CCFCal.app
```

## 权限说明

- CCFCal 只请求日历访问和网络访问。
- 日历访问用于展示日历事件，并把你订阅的 DDL 写入独立的 `DDLCal Subscriptions` 日历。
- 网络访问用于自动刷新 DDL 数据。
- 1.0.0 不启用 Apple Events 和 App Groups 权限。
- 1.0.0 不启用 Sparkle 自动更新；App 本体更新需要手动下载新版 Release。

## 致谢

- CCFCal 基于 Itsycal 二次开发，并保留上游 MIT License 声明。
- DDL 数据来自 ccfddl 生态。
