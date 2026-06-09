# Fix Agent Badge Layout and Naming Issues

## Goal

Polish the agent badge display after expanding the MVP agent list. Three issues identified during testing:

1. Group chat list badges overflow horizontally when 5 agents are shown — need wrapping layout
2. OpenClaw should be removed from `agentHubMVPTypes` (user doesn't want it in create page)
3. OpenCode's `shortName` is "OC" but should display as "OpenCode"

## Requirements

1. **Wrapping badge layout** in `GroupChatListView` `GroupChatRow`: Replace the `HStack` containing `AgentBadge` items with a wrapping/flow layout so badges wrap to a second line when space is tight.
2. **Remove `.openClaw` from `agentHubMVPTypes`**: Change from `[.claudeCode, .codex, .gemini, .openCode, .openClaw]` to `[.claudeCode, .codex, .gemini, .openCode]`.
3. **Fix OpenCode shortName**: Change `.openCode` case in `shortName` from `"OC"` to `"OpenCode"`.

## Acceptance Criteria

- [ ] Group list badges wrap to multiple lines instead of cramming into one row
- [ ] OpenClaw no longer appears in the create group chat agent selection
- [ ] OpenCode displays as "OpenCode" not "OC" in badge/chip text

## Technical Notes

- `GroupChatListView.swift:130-143` — the HStack with ForEach(group.agents) AgentBadge
- `CodegTypes.swift:17` — agentHubMVPTypes array
- `CodegTypes.swift:39` — shortName for .openCode
- SwiftUI doesn't have a built-in FlowLayout; options: use a custom FlowLayout, or a LazyVGrid with flexible columns, or a simple wrapping VStack/HStack combo
