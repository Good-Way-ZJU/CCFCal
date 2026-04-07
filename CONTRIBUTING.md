# 参与贡献 (Contributing to CCFCal)

感谢你对 CCFCal 的关注！我们非常欢迎来自社区的 Issue 报告和 Pull Request (PR)。
Thanks for helping improve CCFCal!

为了确保顺畅的协作体验，请在开始前阅读以下本地开发与代码提交流程。

## ⚙️ 本地环境设置 (Setup)

CCFCal 使用本地的 `xcconfig` 文件来隔离个人的代码签名配置，避免这些隐私信息被意外提交到代码库。在用 Xcode 打开工程之前，请先在终端执行以下命令复制示例配置文件：

```bash
cp CCFCal/Local.xcconfig.example CCFCal/Local.xcconfig
```

> **注意**：`CCFCal/Local.xcconfig` 已经在 `.gitignore` 中配置拦截，**绝对不要**将其提交到 Git。

## 🔑 代码签名 (Code Signing)

- **如果你没有 Apple 开发者账号**：直接保持默认配置即可。Xcode 会为应用进行本地自签名，仅供你的设备测试使用。
- **如果你有 Apple 开发者账号**：请打开并编辑 `CCFCal/Local.xcconfig`，填入你 10 位长度的 Team ID：

```text
DEVELOPMENT_TEAM = XXXXXXXXXX
CODE_SIGN_IDENTITY = Apple Development
CODE_SIGN_STYLE = Manual
ENABLE_HARDENED_RUNTIME = YES
```

## 🧪 运行测试 (Tests)

在提交任何代码前，请确保通过了相关的 Pipeline 测试。

**运行 Python 数据处理管道测试：**

```bash
python3 -m unittest discover -s pipeline/tests
```

**运行免签名的 Xcode 构建检查（确保代码可编译）：**

```bash
xcodebuild \
  -project "CCFCal/CCFCal.xcodeproj" \
  -scheme CCFCal \
  -configuration Debug \
  -derivedDataPath ".build/xcode" \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## 🔄 数据刷新与生成 (Data Refresh)

如果你修改了数据解析逻辑，或需要手动拉取最新的候选池数据：

```bash
python3 pipeline/update_ccfcal_candidates.py
cp CCFCal/CCFCal/DDLCandidates.json docs/DDLCandidates.json
```

这会在 `pipeline/output/` 目录下生成 App 包数据、可发布的 JSON 快照以及本地的 `.ics` 订阅源。`.ics` 文件为本地生成产物，默认不提交。 *注：如果启用了 `.github/workflows/update-ddl-data.yml`，GitHub Actions 会根据计划任务自动每日刷新 JSON 快照并提交。*

## 📦 发布构建 (Release Build)

1. 在 Xcode 中选择 `Product > Archive`。
2. 在 Xcode Organizer 中选择 `Distribute App`，按 Developer ID 公证流程导出 app。
3. 等待公证成功通知后，将公证后的 `CCFCal.app` 导出到桌面。
4. 在 `CCFCal/` 目录下运行 `./make_zips_and_appcast.sh` 生成 zip 和 Sparkle appcast。

发布 appcast 前，请确认 `CCFCal/make_zips_and_appcast.sh` 里的下载地址与实际托管位置一致。

## 📥 提交 Pull Request (PR 规范)

为保持代码库整洁，提交 PR 时请遵循以下原则：

1. **单一职责**：保持每次更改专注于解决一个 Issue 或实现一个具体功能。
2. **禁止提交的内容**：
   - 包含个人签名的 `CCFCal/Local.xcconfig`
   - Xcode 用户设置文件 (`xcuserdata`)
   - 编译缓存 (`.build/`)
   - Python 缓存 (`__pycache__`)
   - 本地数据输出 (`pipeline/output/`)
3. **禁止修改的工程文件配置**：不要提交 `CCFCal/CCFCal.xcodeproj/project.pbxproj` 中关于本地签名的修改（例如 `DEVELOPMENT_TEAM`, `DevelopmentTeam`, `ProvisioningStyle` 等）。
4. **文档同步**：如果你更改了面向用户的行为、发布流程或涉及了新的第三方库，请同步更新 `README.md`, `CHANGELOG.md` 或 `NOTICE.md`。
