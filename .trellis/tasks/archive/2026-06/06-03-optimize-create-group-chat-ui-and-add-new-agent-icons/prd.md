# Optimize Create-Group-Chat UI and Add New Agent Icons

## Goal

Unify the visual style of the "新建群聊" (Create Group Chat) page agent selection with the main group list page. Currently the create page uses a plain checkbox + text-only `AgentChip`, while the list page uses a rich `AgentBadge` with colorful icons. Also expand agent support beyond the current MVP set (Claude Code + Codex) to include Gemini CLI, OpenCode, and OpenClaw.

## What I already know

- **Create page** (`CreateGroupChatView.swift`): Uses `AgentChip` (text-only, no icon, minimal color), plus checkbox for toggle and star for primary.
- **List page** (`GroupChatListView.swift`): Uses `AgentBadge` with `CodegAgentIconView` + star + shortName + role — richer and more visually engaging.
- **Agent icon view** (`CodegAgentIconView.swift`): Already has glyphs for ALL agent types (Claude, Codex, Gemini, OpenCode, OpenClaw, Cline).
- **Agent types** (`CodegTypes.swift`): `agentHubMVPTypes = [.claudeCode, .codex]` — this is the gate that limits which agents appear in Create/Detail pages.
- **Design tokens** (`CodegDesignTokens.swift`): Already has `agentColor()` for all agent types.
- The `AgentChip` component in `CreateGroupChatView` is a local struct separate from `AgentBadge` in `GroupChatListView`.

## Requirements

1. **Create page agent rows**: Replace the current plain checkbox + text `AgentChip` style with a richer visual that includes the colorful `CodegAgentIconView` icon, matching the `AgentBadge` look on the list page.
2. **Expand agent list**: Add `.gemini`, `.openCode`, `.openClaw` to `agentHubMVPTypes` so they appear in both create and detail views.
3. **Consistent visual language**: Both the create page and group detail view should use the same badge-style rendering for agents.
4. **Follow DESIGN.md style**: Dark overlay context, use existing `CodegDesign` tokens.

## Assumptions (temporary)

- The checkbox + star interaction pattern in create page is still useful (toggle selection + mark primary); we're upgrading the visual, not the interaction model.
- Gemini CLI maps to the existing `.gemini` agent type (already has icon + color).

## Decision (ADR-lite)

**Context**: The create page uses a text-only `AgentChip`, while the list page uses a rich `AgentBadge` with icon + color. User wants consistency.
**Decision**: Reuse the existing `AgentBadge` component from `GroupChatListView` directly in the create page. Make it `internal` (remove `private`). The checkbox + star interaction wraps the badge.
**Consequences**: Minimal code change, immediate visual unity. `AgentChip` becomes dead code and can be removed.

## Acceptance Criteria

- [ ] Create page shows agents with colorful icon (CodegAgentIconView) + name, not just text
- [ ] Gemini, OpenCode, OpenClaw appear in the agent selection list
- [ ] GroupDetailView (and GroupChatListView) properly displays the new agent types
- [ ] Visual style of agent items in create page matches the DESIGN.md color/token system
- [ ] No regression in existing Claude Code + Codex functionality

## Definition of Done

- `swift build` passes
- Manual verification: create page shows colorful agent badges
- No regressions in list page rendering

## Out of Scope

- Adding `.cline` to the MVP list (user didn't mention it)
- Backend/server-side changes for new agents
- Changing the interaction model (checkbox + star stays)

## Technical Notes

- Key files to modify:
  - `CodegTypes.swift:17` — expand `agentHubMVPTypes`
  - `CreateGroupChatView.swift` — upgrade `AgentChip` or replace with icon-based badge
  - `GroupDetailView.swift` — verify new agent types render correctly
- `CodegAgentIconView` already supports all needed agent types
- `CodegDesign.agentColor()` already has colors for all agent types
- The `AgentBadge` in `GroupChatListView.swift:161-195` is the target visual
