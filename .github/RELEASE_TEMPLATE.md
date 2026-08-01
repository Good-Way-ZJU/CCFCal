# CCFCal v1.0.3

CCFCal 是一款面向 CS / AI 研究者的 macOS 菜单栏目标会议倒计时工具。

## 新增

- **目标会议追踪器**：订阅会议后，菜单栏直接显示最近的目标和紧凑倒计时，例如 `AAAI 1d`。
- **CCF-NONE 支持**：数据、筛选、日历和菜单全面支持暂未评级的会议与期刊，默认使用绿色标识。
- **摘要截止日期**：同时追踪摘要注册和正式投稿 DDL。

## 修复

- 避免 macOS 自动终止常驻菜单栏进程造成的异常退出。
- 按 Mac 本地时区显示截止时间，并正确处理 PT 夏令时。
- 改善日历同步错误处理，避免零时长事件和重复 ICS UID。
- 验证远程数据快照，避免损坏或异常数据覆盖本地数据。

## 数据

- DDL 候选数据来自 ccfddl 风格的数据源。
- App 启动时会检查本仓库托管的 `DDLCandidates.json`，每天最多自动刷新一次；长时间运行时同样每 24 小时在后台自动刷新。

## 安装

1. 下载 `CCFCal-1.0.3.zip`。
2. 双击解压得到 `CCFCal.app`。
3. 将 `CCFCal.app` 拖到"应用程序"文件夹。
4. 打开"应用程序"，右键点击 `CCFCal.app`，选择"打开"，并在弹窗中再次确认"打开"。
5. 首次启动后，系统会请求"日历"权限，请选择"允许"。CCFCal 需要这个权限来显示日历事件并同步你订阅的 DDL。

压缩包中附带了"如果打不开请看这里.txt"，如果安装或启动时被系统拦截，可以直接打开查看。

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
- 1.0.3 不启用 Apple Events 和 App Groups 权限。
- 1.0.3 不启用 Sparkle 自动更新；App 本体更新需要手动下载新版 Release。

## 致谢

- CCFCal 基于 Itsycal 二次开发，并保留上游 MIT License 声明。
- DDL 数据来自 ccfddl 生态。
