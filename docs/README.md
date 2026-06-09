# Archipelago 交付物总览

本目录用于集中提交 Archipelago 项目的评审交付物，覆盖产品设计、技术实现、可运行 Demo、AI 协作开发记录，以及 3 分钟 Demo 视频脚本。

## 交付物索引

| 交付物 | 文件 | 说明 |
| :--- | :--- | :--- |
| 产品设计文档 | [product-design.md](./product-design.md) | 产品定位、用户场景、核心流程、交互设计、体验亮点 |
| 技术文档 | [technical-architecture.md](./technical-architecture.md) | Swift macOS Shell、嵌入式 Web/Rust Runtime、HTTP/WS 同步、多 Agent 调度、产物预览架构 |
| 可运行 Demo | [demo-deliverables.md](./demo-deliverables.md) | 构建、打包、启动、验收路径和 3 分钟视频脚本 |
| AI 协作开发记录 | [ai-collaboration-record.md](./ai-collaboration-record.md) | Trellis 工作流、Spec/Skill/Rules、任务记录、质量门禁 |
| Trellis 原始协作材料 | [trellis/README.md](./trellis/README.md) | 从 `.trellis/` 与 `.agents/skills/` 迁移的规范、技能、规则和 journal |

## 对考察要点的映射

| 维度 | 权重 | 本项目交付说明 |
| :--- | :--- | :--- |
| AI 协作能力 | 30% | `docs/trellis/` 保留 Trellis workflow、spec、skills、rules；`ai-collaboration-record.md` 总结如何用 PRD、规范注入、任务归档和 journal 驱动 AI 协作。 |
| 功能完整度 | 25% | `product-design.md` 和 `technical-architecture.md` 描述 IM 核心体验、群聊创建、Agent 管理、主 Agent 调度、委派协作和 Island/Web 双端同步。 |
| 生成效果质量 | 20% | 产品文档覆盖聊天 UI、macOS/Island 风格统一、消息气泡、产物预览卡片、iframe/Markdown/PPT/Diff/History/编辑体验。 |
| 代码理解度 | 15% | 技术文档按模块解释 Swift、Next/React、Rust、SQLite、ACP SDK、HTTP/WS、打包链路和关键文件。 |
| 创新与产品感 | 10% | 产品文档突出桌面 Island 入口、多 Agent 群聊、原生 + Web 融合、产物预览与对话式局部修改。 |

## 推荐评审阅读顺序

1. 先读 [product-design.md](./product-design.md)，理解产品目标和用户体验。
2. 再读 [technical-architecture.md](./technical-architecture.md)，对应代码结构和关键实现。
3. 运行 [demo-deliverables.md](./demo-deliverables.md) 中的 Demo 流程。
4. 最后读 [ai-collaboration-record.md](./ai-collaboration-record.md) 与 [trellis/README.md](./trellis/README.md)，核验 AI 协作沉淀。

