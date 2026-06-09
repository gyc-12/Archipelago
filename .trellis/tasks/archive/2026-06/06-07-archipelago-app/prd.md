# 启动 Archipelago app

## Goal

在本地启动 Archipelago.app 进行开发测试，验证 macOS Island UI 和嵌入式 collaboration runtime 的集成是否正常工作。

## What I already know

* 项目结构：
  - `apps/archipelago-macos/`: SwiftPM macOS app (Island UI)
  - `modules/collaboration-runtime/`: Rust HTTP/WS server + Web UI
  - 打包后的 app 路径：`apps/archipelago-macos/output/package/Archipelago.app`
  
* 当前环境状态（已验证）：
  - Node.js v24.15.0, pnpm 11.5.0 ✅
  - Cargo 1.96.0 ✅
  - Swift 6.3.2 ✅
  - Runtime binary 已构建：`modules/collaboration-runtime/src-tauri/target/release/archipelago-server` (30MB, 2026-06-06)
  - Runtime dependencies 已安装：`modules/collaboration-runtime/node_modules/` 存在
  - 打包的 app 已存在：`apps/archipelago-macos/output/package/Archipelago.app`

* 启动方式（从 README）：
  ```bash
  cd apps/archipelago-macos
  zsh scripts/launch-packaged-app.sh
  ```

* 打包脚本会：
  - 打包并打开 `apps/archipelago-macos/output/package/Archipelago.app`
  - 验证 app bundle 包含嵌入式 runtime helpers 和静态资源

## Assumptions (temporary)

* 现有的构建产物（二进制、打包的 app）是最新的，无需重新构建 ✅ 用户确认
* 启动脚本会自动处理路径和环境变量配置

## Requirements

* 使用现有构建产物直接启动（无需重新构建）
* 执行 `launch-packaged-app.sh` 脚本启动 Archipelago.app
* 基础验证范围 ✅ 用户确认：
  - App 进程成功启动
  - Island UI 窗口可见
  - 控制台日志无严重错误
  - Runtime server 正常运行（HTTP/WebSocket）

## Acceptance Criteria

* [ ] `launch-packaged-app.sh` 脚本执行成功
* [ ] Archipelago.app 进程启动
* [ ] Island UI 窗口显示
* [ ] 控制台日志中无 fatal/critical 级别错误
* [ ] Runtime server 端口监听正常

## Definition of Done (team quality bar)

* App 成功启动并运行
* 基本功能可交互
* 启动过程和结果文档化到 journal

## Out of Scope (explicit)

* 重新构建 runtime 或 macOS app（使用现有构建产物）
* 深度功能测试（创建 group、配置 agents、测试多 agent 协作）
* 性能测试或压力测试
* 打包分发或签名
* 调试具体功能问题

## Technical Approach

**直接启动流程：**
1. 进入 `apps/archipelago-macos` 目录
2. 执行 `zsh scripts/launch-packaged-app.sh`
3. 观察启动日志输出
4. 验证 app 进程和 UI 窗口
5. 检查 runtime server 日志（如果有）
6. 记录启动状态到 journal

**验证方式：**
- 进程检查：`ps aux | grep Archipelago`
- 日志分析：观察 stdout/stderr 输出
- UI 验证：确认窗口显示
- 端口检查（如果需要）：`lsof -i` 或检查 runtime server 配置的端口

## Implementation Plan

单步执行（无需拆分 PR）：
1. 执行启动脚本
2. 验证基础功能
3. 记录结果

## Technical Notes

* 启动脚本路径：`apps/archipelago-macos/scripts/launch-packaged-app.sh`
* App bundle 路径：`apps/archipelago-macos/output/package/Archipelago.app`
* Runtime server 二进制：`modules/collaboration-runtime/src-tauri/target/release/archipelago-server`
* macOS 14+ 要求已满足（当前系统 Darwin 25.5.0）
