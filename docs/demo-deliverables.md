# Demo 交付说明

## 1. 可运行 Demo

### 环境要求

- macOS 14+
- Xcode Command Line Tools / Swift Package Manager
- Node.js + pnpm
- Rust + Cargo
- 已配置可用的 Agent CLI/SDK，例如 Claude Code、Codex、Gemini CLI、OpenCode

### 完整构建命令

```bash
cd modules/collaboration-runtime
pnpm install
pnpm build
```

```bash
cd modules/collaboration-runtime/src-tauri
cargo build --release --bin archipelago-server --bin archipelago-mcp --no-default-features
```

```bash
cd apps/archipelago-macos
swift build --product ArchipelagoApp
```

### 启动集成 Demo

```bash
cd apps/archipelago-macos
zsh scripts/launch-packaged-app.sh
```

启动后使用的真实 bundle：

```text
apps/archipelago-macos/output/package/Archipelago.app
```

### 快速验收路径

1. 打开 `Archipelago.app`。
2. 展开 Island。
3. 新建群聊，选择一个本地 workspace。
4. 选择多个 Agent，例如 Claude Code + Codex。
5. 设置主 Agent。
6. 打开群聊会话窗口。
7. 发送一个开发任务，观察 Agent 状态变为 busy。
8. 使用 `@all` 或指定 Agent 触发多 Agent 协作。
9. 查看 `group_collaboration_plan` 和成员状态变化。
10. 让 Agent 生成 HTML/Markdown/PPT/代码/Diff 类产物。
11. 点击消息内 artifact card，验证 iframe/PPT/Diff/编辑器/全屏预览。
12. 选中代码片段，回到聊天中描述局部修改。

## 2. 3 分钟 Demo 视频脚本

### 0:00 - 0:20 产品定位

画面：打开 Archipelago，展示桌面 Island。

讲解：

> Archipelago 是一个 macOS 多 Agent 协作应用。它把 AI 编码群聊放在桌面 Island 入口里，用户可以从这里创建项目群聊、管理 Agent、查看运行状态，并打开完整的协作运行时。

### 0:20 - 0:55 创建群聊

画面：展开 Island，新建群聊，选择 workspace，勾选 Agent，设置主 Agent。

讲解：

> 一个群聊绑定一个项目 workspace。每个 Agent 都有自己的角色、conversation 和运行状态。Archipelago Server 是数据源，Island 展示实时投影。

### 0:55 - 1:25 IM 与多 Agent 协作

画面：打开嵌入式会话窗口，在输入框中发送任务，使用 `@all` 或 mention 某个 Agent。

讲解：

> 主 Agent 负责组织协作。用户可以 mention 指定 Agent，也可以让主 Agent 自动委派。协作计划会作为 live event 显示，Island 也会同步每个 Agent 的 busy/idle 状态。

### 1:25 - 2:05 产物预览

画面：展示 Agent 消息中的 HTML/PPT/Diff/文件预览卡片，点击打开全屏或文件工作区。

讲解：

> Agent 产物不是只在聊天里显示路径，而是直接变成可点击的预览卡片。HTML 可以 iframe 预览，PPT 可以浏览真实内容，代码进入 Monaco，Diff 进入已有 diff 视图。

### 2:05 - 2:35 对话式局部修改

画面：在编辑器/预览中选中一段代码，发送“把这段改成...”。

讲解：

> 选中的内容会作为局部修改上下文回到聊天里，用户不用复制粘贴文件路径和片段，Agent 可以围绕具体产物继续修改。

### 2:35 - 3:00 AI 协作工程化

画面：展示 `docs/trellis/`、spec、skill、journal 和 README。

讲解：

> 开发过程使用 Trellis 管理。需求写成 PRD，跨层契约沉淀到 spec，开发流程封装成 skill，验证和提交进入 journal。评审可以看到完整的 AI 协作记录，而不是只有最终代码。

## 3. 视频拍摄检查清单

- 确认使用 packaged app：`apps/archipelago-macos/output/package/Archipelago.app`。
- 录屏前关闭旧的开发版本进程，避免演示错 bundle。
- 准备一个 workspace，里面包含可以生成或修改的 HTML/Markdown/代码文件。
- 确认至少一个 Agent CLI/SDK 可用。
- 准备一个能触发产物的 prompt，例如：

```text
请在当前项目里生成一个 HTML 预览页，并给出对应的 Markdown 说明和一个小的代码改动 diff。
```

- 准备一个能触发多 Agent 的 prompt，例如：

```text
@all 请分工检查这个项目的 UI、状态同步和文档交付风险，最后由主 Agent 汇总。
```

