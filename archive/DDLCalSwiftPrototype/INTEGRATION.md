# macOS 集成说明

当前仓库已经提供了可直接复用的核心模块，接入 CCFCal 主工程时建议按下面拆分：

## 主应用

- 用 `CandidateStore` 加载由 `pipeline/` 生成的候选数据
- 用 `DeadlineFilter` 做 `CCF A/B/C + 细分领域 + 类型 + 关键词` 过滤
- 用 `SubscriptionStore` 保存用户已订阅的会议/期刊 ID
- 用 `CalendarSyncEngine.payloads(...)` 把已订阅项转换成系统日历事件载荷
- 用 `EventKitCalendarManager.sync(...)` 写入专用系统日历 `DDLCal Subscriptions`
- 用 `UpcomingDeadlineResolver.nextSummary(...)` 生成最近一个未来 DDL，并写入 App Group 的 `UserDefaults`

## CCFCal 高亮

- 继续沿用 CCFCal 读取系统日历的方式
- 识别规则以事件标题中的 `[DDL]` 为主
- 若事件 `notes` 里存在 `ddlcal_id:`，则视为 DDLCal 管理事件
- 日历格子只要命中任一 DDLCal 管理事件，就切换成高亮渲染

## Widget

- Widget 读取主应用写入的 `UpcomingDeadlineSummary`
- 展示 `title / stage / timestamp`
- 用时间差渲染 `xx day xx hours xx min`

当前主工程位于 `CCFCal/CCFCal.xcodeproj`，这部分文档只作为早期原型接线记录保留。
