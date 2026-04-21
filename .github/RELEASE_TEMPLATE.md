# CCFCal v1.0.1

## 修复

- **后台数据刷新**：修复 App 长时间运行时 DDL 数据不更新的问题。现在 App 每 24 小时会在后台自动刷新一次候选数据，无需重启。
- **订阅颜色自定义**：修复颜色选择不生效的问题，选色操作现在会正确保存并在下次启动时恢复。
- **订阅颜色读取**：修复颜色始终显示按等级默认值的问题，现在优先展示用户设置的自定义颜色。

## 数据

- DDL 候选数据来自 ccfddl 风格的数据源。
- App 启动时会检查本仓库托管的 `DDLCandidates.json`，每天最多自动刷新一次；长时间运行时同样每 24 小时在后台自动刷新。

## 安装

1. 下载 `CCFCal-1.0.1.dmg`。
2. 双击打开 `dmg`。
3. 将窗口中的 `CCFCal.app` 拖到旁边的 `Applications` 快捷方式。
4. 打开"应用程序"，右键点击 `CCFCal.app`，选择"打开"，并在弹窗中再次确认"打开"。
5. 首次启动后，系统会请求"日历"权限，请选择"允许"。CCFCal 需要这个权限来显示日历事件并同步你订阅的 DDL。

`dmg` 中附带了"如果打不开请看这里.txt"，如果安装或启动时被系统拦截，可以直接打开查看。

## 如果提示"CCFCal.app 已损坏"

当前发布包没有经过 Apple Developer ID 公证。部分 macOS 版本会把未公证 App 显示成"已损坏"，这不是文件真的损坏，而是 Gatekeeper 的拦截提示。

请先确认 `CCFCal.app` 已经放在"应用程序"文件夹，然后打开"终端"执行：

```bash
xattr -dr com.apple.quarantine /Applications/CCFCal.app
open /Applications/CCFCal.app
```

## 权限说明

- CCFCal 只请求日历访问和网络访问。
- 日历访问用于展示日历事件，并把你订阅的 DDL 写入独立的 `DDLCal Subscriptions` 日历。
- 网络访问用于自动刷新 DDL 数据。
- 1.0.1 不启用 Apple Events 和 App Groups 权限。
- 1.0.1 不启用 Sparkle 自动更新；App 本体更新需要手动下载新版 Release。

## 致谢

- CCFCal 基于 Itsycal 二次开发，并保留上游 MIT License 声明。
- DDL 数据来自 ccfddl 生态。
