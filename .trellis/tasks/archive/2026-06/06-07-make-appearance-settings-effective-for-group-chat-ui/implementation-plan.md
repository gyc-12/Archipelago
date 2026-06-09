## 完整方案总结

### 目标
让外观设置真正生效：移除无用的会话相关设置，保留并接线群聊排序功能。

### 改动清单

**1. 保留（已生效）**
- ✅ rightSlot — 关闭 notch 时右侧显示内容
- ✅ centerLabel — 外接屏中央标签
- ✅ completedStaleThreshold — 完成超时阈值

**2. 移除（死代码）**
- ❌ usageDisplay (hidden/compact)
- ❌ sessionStateIndicator (animatedDot/bar/glyph/tint)
- ❌ sessionGroup (none/state/agent/project)

**3. 重命名并接线**
- sessionSort → groupChatSort
- 新增排序选项：
  - **name** — 按名称 A-Z
  - **recentActivity** — 按最近活动时间（最近有回复的在前）
  - **createdAt** — 按创建时间（最新创建的在前）

### 实现步骤

1. **更新数据模型** (AppModelTypes.swift)
   - 移除 `IslandUsageDisplay`、`IslandSessionStateIndicator`、`IslandSessionGroup` enum
   - 将 `IslandSessionSort` 改名为 `GroupChatSort`，更新 case 为 name/recentActivity/createdAt
   - 更新 `IslandAppearancePreferences` 结构体

2. **更新 AppModel** (AppModel.swift)
   - 移除 usageDisplay、sessionStateIndicator、sessionGroup 相关属性和持久化逻辑
   - 重命名 sessionSort 相关代码

3. **接线到 GroupChatListView** (GroupChatListView.swift)
   - 添加 `sortOrder: GroupChatSort` 参数
   - 实现排序逻辑（根据 sortOrder 对 coordinator.groupChats 排序）

4. **传递参数** (IslandPanelView.swift)
   - 在调用 GroupChatListView 时传递 `model.groupChatSort`

5. **更新设置界面** (AppearanceSettingsPane.swift)
   - 移除 usageDisplaySection、stateIndicatorSection、sessionGroupSection
   - 更新 sessionSortSection 为 groupChatSortSection（3 个选项卡片）
   - 更新预览数据以匹配新排序逻辑

6. **更新本地化** (Localizable.strings)
   - 删除 usageDisplay、stateIndicator、sessionGroup 相关字符串
   - 更新排序相关字符串（name/recentActivity/createdAt）

### 验证方式
1. 打开设置 → 外观 → 群聊列表
2. 切换排序选项（名称/最近活动/创建时间）
3. 打开 Island，确认群聊列表顺序改变

这个方案清晰吗？如果没问题，我将准备 jsonl 并开始实现。
